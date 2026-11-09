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

echo "== leading spaces, tabs and CR before = + - @ \" are still formula-scrubbed =="
# The first-byte check missed these: tr turns tab and CR into a space, then a
# sheet that trims before parsing still sees a formula. Prefix the flattened
# value (space + formula char) so the stored cell cannot decode to a formula.
n=0
for prefix in ' ' $'\t' $'\r'; do
  for char in '=' '+' '-' '@' '"'; do
    n=$((n + 1))
    val="${prefix}${char}payload${n}"
    "$log" "$f" "p${n}" "$val" "why${n}" "ev${n}" "open" || no "append of leading-ws formula $n exited non-zero"
    cell=$(tail -1 "$f" | cut -f3)
    expected="' ${char}payload${n}"
    [ "$cell" = "$expected" ] && ok || no "leading $(printf %q "$prefix") before $char not scrubbed: got $(printf %q "$cell")"
  done
done
# A leading space in front of ordinary text is not a formula and must stay unprefixed.
"$log" "$f" phase " not a formula" why evidence open
[ "$(tail -1 "$f" | cut -f3)" = " not a formula" ] && ok || no "a leading space on a non-formula cell was altered"

echo "== non-ASCII leading whitespace before = + - @ \" is still formula-scrubbed =="
# ASCII-space stripping left these through. A sheet that trims Unicode spaces
# (or a reviewer who sees an "empty" prefix) then parses = + - @ " as a formula.
# Cover the Unicode space/BOM characters that actually show up as a leading
# prefix, not every Cf/bidi/homoglyph attack (different class).
#   U+00A0 NO-BREAK SPACE — HTML/Word paste
#   U+1680 OGHAM SPACE MARK — Zs
#   U+2000–U+200A — en quad through hair space
#   U+200B ZERO WIDTH SPACE — invisible prefix
#   U+2028 LINE SEPARATOR / U+2029 PARAGRAPH SEPARATOR
#   U+202F NARROW NO-BREAK SPACE / U+205F MEDIUM MATHEMATICAL SPACE
#   U+3000 IDEOGRAPHIC SPACE — CJK
#   U+FEFF BOM / ZERO WIDTH NO-BREAK SPACE — UTF-8 BOM on a cell
uni_prefixes=(
  $'\u00a0' $'\u1680'
  $'\u2000' $'\u2001' $'\u2002' $'\u2003' $'\u2004' $'\u2005'
  $'\u2006' $'\u2007' $'\u2008' $'\u2009' $'\u200a' $'\u200b'
  $'\u2028' $'\u2029' $'\u202f' $'\u205f' $'\u3000' $'\ufeff'
)
n=0
for prefix in "${uni_prefixes[@]}"; do
  for char in '=' '+' '-' '@' '"'; do
    n=$((n + 1))
    val="${prefix}${char}Upayload${n}"
    "$log" "$f" "u${n}" "$val" "why${n}" "ev${n}" "open" || no "append of unicode-ws formula $n exited non-zero"
    cell=$(tail -1 "$f" | cut -f3)
    expected="'${val}"
    [ "$cell" = "$expected" ] && ok || no "unicode leading ws before $char not scrubbed (case $n): got $(printf %q "$cell")"
  done
done
# The same characters in front of ordinary text are not a formula.
"$log" "$f" phase $'\u00a0'"not a formula" why evidence open
[ "$(tail -1 "$f" | cut -f3)" = $'\u00a0'"not a formula" ] && ok || no "a leading NBSP on a non-formula cell was altered"

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
[ ! -d "$stale.lock.takeover" ] && ok || no "takeover directory left behind after a takeover"
[ $(( $(date +%s) - start )) -le 10 ] && ok || no "stale lock wait exceeded the bound"
# A takeover dir left behind by a crashed waiter must not block the next
# takeover of a dead lock. mkdir of the serializer would otherwise fail and
# the write would be refused forever.
left="$tmp/leftover-takeover.tsv"
mkdir "$left.lock"; printf '%s\n' "$deadpid" > "$left.lock/pid"
mkdir "$left.lock.takeover"
start=$(date +%s)
PATH="$shim:$PATH" "$log" "$left" p d w e r 2>/dev/null; rc=$?
[ "$rc" -eq 0 ] && [ "$(wc -l < "$left")" -eq 2 ] && ok || no "leftover takeover dir should not block a dead-holder takeover (exit $rc)"
[ ! -d "$left.lock" ] && ok || no "lock directory left behind after reclaiming a leftover takeover"
[ ! -d "$left.lock.takeover" ] && ok || no "reclaimed takeover directory was not removed"
[ $(( $(date +%s) - start )) -le 10 ] && ok || no "leftover-takeover wait exceeded the bound"
held="$tmp/held.tsv"; mkdir "$held.lock"; printf '%s\n' "$$" > "$held.lock/pid"   # this test shell is alive
PATH="$shim:$PATH" "$log" "$held" p d w e r 2>"$tmp/held.err"; rc=$?
[ "$rc" -eq 2 ] && ok || no "a lock held by a live pid should refuse with exit 2 (got $rc)"
[ ! -e "$held" ] && ok || no "a refused write left an empty log (or appended a row)"
grep -q "$held.lock" "$tmp/held.err" && ok || no "the refusal should name the lock directory"
[ -d "$held.lock" ] && ok || no "a live holder's lock was removed"
rm -rf "$held.lock"
unknown="$tmp/unknown.tsv"; mkdir "$unknown.lock"   # no pid file: holder unknown
PATH="$shim:$PATH" "$log" "$unknown" p d w e r 2>/dev/null; rc=$?
[ "$rc" -eq 2 ] && [ ! -e "$unknown" ] && ok || no "a lock with no pid should refuse with exit 2 and leave no log (got $rc)"
rm -rf "$unknown.lock"

echo "== concurrent writers behind a stale lock still produce exactly one header =="
cs="$tmp/concurrent-stale.tsv"; mkdir "$cs.lock"; printf '%s\n' "$deadpid" > "$cs.lock/pid"
PATH="$shim:$PATH" concurrent "$cs" "stale lock then 40 writers"
[ ! -d "$cs.lock" ] && ok || no "lock directory left behind after the stale-lock takeover"
[ ! -d "$cs.lock.takeover" ] && ok || no "takeover directory left behind after the stale-lock takeover"

echo "== a timed-out waiter must not unlink a concurrent holder's log =="
# Codex/Ternary schedule on the mkdir fallback. Pin it so the waiter samples
# a missing log (log_existed=0 on 3d57180) and later times out while the
# holder still owns the lock: hold the lock ourselves, start the waiter,
# SIGSTOP it in its wait loop, drop our lock, start a holder that stalls at
# date, then CONT the waiter. The holder's row must still be on disk.
race="$tmp/race-unlink.tsv"
raceshim="$tmp/race-shim"; mkdir "$raceshim"
printf '#!/bin/sh\nexit 1\n' > "$raceshim/flock"; chmod +x "$raceshim/flock"
reald=$(command -v date)
printf '#!/bin/sh\nsleep 6\nexec %s "$@"\n' "$reald" > "$raceshim/date"; chmod +x "$raceshim/date"
mkdir "$race.lock"; printf '%s\n' "$$" > "$race.lock/pid"
PATH="$raceshim:$PATH" "$log" "$race" waiter "waiter-row" why evidence open 2>"$tmp/race-waiter.err" & waiterpid=$!
for _ in $(seq 40); do
  kill -0 "$waiterpid" 2>/dev/null || break
  [ -e "$race" ] && break
  sleep 0.05
done
sleep 0.2
kill -STOP "$waiterpid" 2>/dev/null || no "could not SIGSTOP the waiter"
rm -rf "$race.lock"
PATH="$raceshim:$PATH" "$log" "$race" holder "holder-row" why evidence open & holderpid=$!
for _ in $(seq 80); do
  [ -d "$race.lock" ] && break
  sleep 0.05
done
[ -d "$race.lock" ] && ok || no "holder never acquired the mkdir lock"
kill -CONT "$waiterpid" 2>/dev/null || no "could not SIGCONT the waiter"
wait "$waiterpid"; waiterrc=$?
wait "$holderpid"; holderrc=$?
[ "$waiterrc" -eq 2 ] && ok || no "waiter should time out with exit 2 (got $waiterrc)"
[ "$holderrc" -eq 0 ] && ok || no "holder should exit 0 (got $holderrc)"
[ -e "$race" ] && ok || no "timed-out waiter unlinked the concurrent holder's log"
grep -q 'holder-row' "$race" 2>/dev/null && ok || no "holder's row did not survive"
! grep -q 'waiter-row' "$race" 2>/dev/null && ok || no "timed-out waiter still wrote a row"
[ ! -d "$race.lock" ] && ok || no "holder left its lock directory behind"
[ ! -d "$race.lock.takeover" ] && ok || no "race left a takeover directory behind"

echo "== flock path does not create the log before it holds the sidecar lock =="
if command -v flock >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  flocklog="$tmp/flock-before-open.tsv"
  exec 7>>"$flocklog.flock"
  if flock -n 7; then
    timeout 1 "$log" "$flocklog" p d w e r >/dev/null 2>&1
    [ $? -ne 0 ] && ok || no "runlog should not finish while the sidecar flock is held"
    [ ! -e "$flocklog" ] && ok || no "flock path created the log before holding the lock"
  else
    no "could not hold the sidecar flock"
  fi
  exec 7>&-
  rm -f "$flocklog.flock"
else
  echo "SKIP: flock or timeout not installed; flock-before-open not exercised"
fi

echo "== a missing parent directory is created =="
"$log" "$tmp/deep/er/run.tsv" p d w e r && [ -s "$tmp/deep/er/run.tsv" ] && ok || no "parent directory was not created"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
