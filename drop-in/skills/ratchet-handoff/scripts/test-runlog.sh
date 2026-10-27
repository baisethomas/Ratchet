#!/usr/bin/env bash
# Tests for runlog.sh. Run from anywhere: it stages its own temp directory.
set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
log="$here/runlog.sh"
pass=0; fail=0
ok() { pass=$((pass + 1)); }
no() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }
tmp=$(mktemp -d)
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

echo "== a missing parent directory is created =="
"$log" "$tmp/deep/er/run.tsv" p d w e r && [ -s "$tmp/deep/er/run.tsv" ] && ok || no "parent directory was not created"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
