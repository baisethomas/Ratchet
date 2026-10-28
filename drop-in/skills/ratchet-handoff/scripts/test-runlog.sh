#!/usr/bin/env bash
# Tests for runlog.sh. Run from anywhere: it stages its own temp directory.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
log="$here/runlog.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); }
no() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }
# Real path on purpose: the script refuses any symlinked component in the path
# it is given, and on macOS the temp directory sits under a symlink (/var).
tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT

echo "== header on first use, rows appended, never rewritten =="
f="$tmp/.ratchet/run.tsv"
"$log" "$f" frame "counted the work" "size before start" "commit 3a9f1c2" "open" || no "first append exited non-zero"
[ "$(head -1 "$f")" = "$(printf 'ts\tphase\tdecision\twhy\tevidence\tresult')" ] && ok || no "header missing or wrong"
[ "$(wc -l < "$f")" -eq 2 ] && ok || no "expected header plus one row"
"$log" "$f" widget "moved styles" "keep it small" "commit 7c21e0a" "tests green" || no "second append exited non-zero"
[ "$(wc -l < "$f")" -eq 3 ] && ok || no "second row was not appended"
[ "$(grep -c '^ts' "$f")" -eq 1 ] && ok || no "header was written twice"
[ "$(sed -n 2p "$f" | cut -f2)" = "frame" ] && ok || no "first row was rewritten or reordered"

echo "== every row has six tab-separated cells and an ISO timestamp =="
awk -F'\t' 'NR>1 && NF!=6 {bad=1} END {exit bad}' "$f" && ok || no "a row does not have six cells"
sed -n 2p "$f" | cut -f1 | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' && ok || no "timestamp is not ISO 8601 UTC"

echo "== tabs, newlines and carriage returns inside a cell stay on one line =="
"$log" "$f" phase "$(printf 'two\tcells')" "$(printf 'line one\nline two')" "$(printf 'cr\rhere')" open
[ "$(wc -l < "$f")" -eq 4 ] && ok || no "an embedded newline split the row"
awk -F'\t' 'NR==4 && NF!=6 {exit 1}' "$f" && ok || no "an embedded tab added a cell"
sed -n 4p "$f" | cut -f3 | grep -q 'two cells' && ok || no "embedded tab was not replaced with a space"

echo "== cells that a spreadsheet would read as a formula are quote-prefixed =="
"$log" "$f" phase "=HYPERLINK(\"x\")" "+1" "-rf" "@cmd"
row=$(sed -n 5p "$f")
[ "$(printf '%s' "$row" | cut -f3)" = "'=HYPERLINK(\"x\")" ] && ok || no "= cell not prefixed"
[ "$(printf '%s' "$row" | cut -f4)" = "'+1" ] && ok || no "+ cell not prefixed"
[ "$(printf '%s' "$row" | cut -f5)" = "'-rf" ] && ok || no "- cell not prefixed"
[ "$(printf '%s' "$row" | cut -f6)" = "'@cmd" ] && ok || no "@ cell not prefixed"
[ "$(printf '%s' "$row" | cut -f2)" = "phase" ] && ok || no "a plain cell was altered"

echo "== a formula wrapped in double quotes still cannot reach the sheet =="
# A TSV importer strips enclosing quotes before it looks at the cell, so a raw
# "=1+1" would decode to =1+1 and run. Check the decoded value, not the bytes.
"$log" "$f" phase '"=1+1"' '"+1"' 'plain "quoted" middle' open
row=$(sed -n 6p "$f")
[ "$(printf '%s' "$row" | cut -f3)" = "'\"=1+1\"" ] && ok || no "leading double quote not prefixed"
[ "$(printf '%s' "$row" | cut -f5)" = 'plain "quoted" middle' ] && ok || no "a quote in the middle of a cell was altered"
if command -v python3 >/dev/null 2>&1; then
  decoded=$(python3 -I -c 'import csv,sys
rows=list(csv.reader(open(sys.argv[1], newline=""), dialect="excel-tab"))
print(rows[5][2]); print(rows[5][3])' "$f")
  printf '%s\n' "$decoded" | grep -q '^=' && no "excel-tab decode exposed a cell starting with =" || ok
  printf '%s\n' "$decoded" | grep -q '^+' && no "excel-tab decode exposed a cell starting with +" || ok
else
  echo "SKIP: python3 not installed; decoded-cell check not run"
fi

echo "== wrong argument count exits 2 and writes nothing =="
before=$(wc -l < "$f")
"$log" "$f" only two 2>/dev/null; [ $? -eq 2 ] && ok || no "too few arguments should exit 2"
"$log" "$f" a b c d e f g 2>/dev/null; [ $? -eq 2 ] && ok || no "too many arguments should exit 2"
[ "$(wc -l < "$f")" -eq "$before" ] && ok || no "a refused call still wrote a row"

echo "== a symlinked log file is refused =="
target="$tmp/elsewhere.tsv"; : > "$target"
ln -s "$target" "$tmp/link.tsv"
"$log" "$tmp/link.tsv" p d w e r 2>/dev/null; [ $? -eq 2 ] && ok || no "symlink should be refused with exit 2"
[ ! -s "$target" ] && ok || no "the symlink target was written through"

echo "== a symlinked parent directory is refused, absolute or relative =="
mkdir "$tmp/real"; ln -s "$tmp/real" "$tmp/linkdir"
"$log" "$tmp/linkdir/run.tsv" p d w e r 2>/dev/null; [ $? -eq 2 ] && ok || no "absolute path through a symlinked directory should exit 2"
[ ! -e "$tmp/real/run.tsv" ] && ok || no "the log was written through the symlinked directory"
mkdir -p "$tmp/rel/real"; ln -s real "$tmp/rel/.ratchet"
( cd "$tmp/rel" && "$log" .ratchet/run.tsv p d w e r 2>/dev/null ); [ $? -eq 2 ] && ok || no "relative .ratchet symlink should exit 2"
[ ! -e "$tmp/rel/real/run.tsv" ] && ok || no "the log was written through the .ratchet symlink"
( cd "$tmp" && "$log" real/run.tsv p d w e r ) && [ -s "$tmp/real/run.tsv" ] && ok || no "a relative path through a real directory should work"

echo "== concurrent first writers produce exactly one header =="
concurrent() {   # $1 log path, $2 label; runs 40 writers at once with the current PATH
  local c="$1" label="$2" n=40 i
  for i in $(seq "$n"); do "$log" "$c" phase "writer $i" why evidence open & done
  wait
  [ "$(grep -c '^ts	phase' "$c")" -eq 1 ] && ok || no "$label: expected exactly one header, got $(grep -c '^ts	phase' "$c")"
  [ "$(wc -l < "$c")" -eq $((n + 1)) ] && ok || no "$label: expected $((n + 1)) lines, got $(wc -l < "$c")"
  awk -F'\t' 'NF!=6 {bad=1} END {exit bad}' "$c" && ok || no "$label: a concurrent write produced a malformed row"
}
if command -v flock >/dev/null 2>&1; then
  concurrent "$tmp/concurrent-flock.tsv" "with flock"
else
  echo "SKIP: flock not installed; the flock path is not exercised here"
fi
# The portable fallback: a shim flock that always fails stands in for a
# platform without it (macOS), so the mkdir lock is what serializes the writers.
shim="$tmp/shim"; mkdir "$shim"
printf '#!/bin/sh\nexit 1\n' > "$shim/flock"; chmod +x "$shim/flock"
PATH="$shim:$PATH" concurrent "$tmp/concurrent-mkdir.tsv" "mkdir fallback"
[ ! -d "$tmp/concurrent-mkdir.tsv.lock" ] && ok || no "mkdir fallback left its lock directory behind"

echo "== a lock whose holder is dead is taken over; a held or unknown lock refuses the write =="
sh -c 'exit 0' & deadpid=$!; wait "$deadpid"   # a pid that is certainly not running
stale="$tmp/stale.tsv"; mkdir "$stale.lock"; printf '%s\n' "$deadpid" > "$stale.lock/pid"
start=$(date +%s)
PATH="$shim:$PATH" "$log" "$stale" p d w e r 2>/dev/null; rc=$?
[ "$rc" -eq 0 ] && [ "$(wc -l < "$stale")" -eq 2 ] && ok || no "dead-holder lock should be taken over and the row written (exit $rc)"
[ ! -d "$stale.lock" ] && ok || no "taken-over lock was not released"
[ $(( $(date +%s) - start )) -le 10 ] && ok || no "stale lock wait exceeded the bound"
held="$tmp/held.tsv"; mkdir "$held.lock"; printf '%s\n' "$$" > "$held.lock/pid"   # this test shell is alive
PATH="$shim:$PATH" "$log" "$held" p d w e r 2>"$tmp/held.err"; rc=$?
[ "$rc" -eq 2 ] && ok || no "a lock held by a live pid should refuse with exit 2 (got $rc)"
[ ! -s "$held" ] && ok || no "a refused write still appended a row"
grep -q "$held.lock" "$tmp/held.err" && ok || no "the refusal should name the lock directory"
[ -d "$held.lock" ] && ok || no "a live holder's lock was removed"
rm -rf "$held.lock"
unknown="$tmp/unknown.tsv"; mkdir "$unknown.lock"   # no pid file: holder unknown
PATH="$shim:$PATH" "$log" "$unknown" p d w e r 2>/dev/null; rc=$?
[ "$rc" -eq 2 ] && [ ! -s "$unknown" ] && ok || no "a lock with no pid should refuse with exit 2 and write nothing (got $rc)"
rm -rf "$unknown.lock"

echo "== concurrent writers behind a stale lock still produce exactly one header =="
cs="$tmp/concurrent-stale.tsv"; mkdir "$cs.lock"; printf '%s\n' "$deadpid" > "$cs.lock/pid"
PATH="$shim:$PATH" concurrent "$cs" "stale lock then 40 writers"
[ ! -d "$cs.lock" ] && ok || no "lock directory left behind after the stale-lock takeover"

echo "== a missing parent directory is created =="
"$log" "$tmp/deep/er/run.tsv" p d w e r && [ -s "$tmp/deep/er/run.tsv" ] && ok || no "parent directory was not created"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
