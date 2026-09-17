#!/usr/bin/env bash
# Regression tests for rrr.sh. Run: .agents/skills/ratchet-bugfix/scripts/test-rrr.sh
#
# A proof tool that cannot say "NOT PROVEN" proves nothing, so most cases here
# are the ways a regression test can be worthless. Every case also asserts the
# fix is byte-identical afterwards: losing the user's work is the worst failure.

set -uo pipefail
rrr="$(cd "$(dirname "$0")" && pwd)/rrr.sh"

pass=0
fail=0
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/test-rrr.XXXXXX")"
trap 'rm -rf "$sandbox"' EXIT

# new_repo — a repo with a committed bug (add subtracts) and an uncommitted fix.
new_repo() {
  repo="$sandbox/repo.$((pass + fail))"
  mkdir -p "$repo" && cd "$repo" || exit 2
  git init -q .
  git config user.email t@example.com
  git config user.name t
  printf 'add() { echo $(( $1 - $2 )); }\n' >lib.sh
  git add lib.sh && git commit -qm "buggy"
  printf 'add() { echo $(( $1 + $2 )); }\n' >lib.sh
  printf '. ./lib.sh\n[ "$(add 2 3)" = 5 ]\n' >good_test.sh
  printf '. ./lib.sh\n[ "$(add 0 0)" = 0 ]\n' >vacuous_test.sh
  cp lib.sh "$sandbox/expected"
}

# check <name> <expected_exit> <expected_text> <rrr args...>
# Only lib.sh and $fix_file may show as modified (or type-changed) afterwards.
check() {
  local name="$1" want="$2" text="$3" out got
  shift 3
  out="$("$rrr" "$@" 2>&1)"
  got=$?
  if [ "$got" -ne "$want" ]; then
    fail=$((fail + 1)); printf 'FAIL: %s — expected exit %s, got %s\n%s\n' "$name" "$want" "$got" "$out"
  elif ! printf '%s' "$out" | grep -q -- "$text"; then
    fail=$((fail + 1)); printf 'FAIL: %s — output lacks "%s"\n%s\n' "$name" "$text" "$out"
  elif ! cmp -s lib.sh "$sandbox/expected"; then
    fail=$((fail + 1)); printf 'FAIL: %s — the fix was not restored byte-for-byte\n' "$name"
  elif [ -n "$(git status --porcelain --untracked-files=no | grep -Ev "^ [MT] (lib\.sh|${fix_file:-lib\.sh})\$")" ]; then
    fail=$((fail + 1)); printf 'FAIL: %s — git state changed beyond the fix file\n' "$name"
  else
    pass=$((pass + 1))
  fi
}

echo "== a test that exercises the bug is PROVEN =="
new_repo
check "good test" 0 "RRR: PROVEN" --test "bash good_test.sh" -- lib.sh

echo "== worthless tests are NOT PROVEN =="
new_repo
check "vacuous test passes without the fix" 1 "does not exercise the bug" --test "bash vacuous_test.sh" -- lib.sh
new_repo
check "test fails even with the fix" 1 "does not pass with the fix" --test "false" -- lib.sh
new_repo
git commit -qam "fix" && cp lib.sh "$sandbox/expected"
check "fix already committed, default base" 1 "no fix to revert" --test "bash good_test.sh" -- lib.sh
new_repo
printf '#!/usr/bin/env bash\n[ -e flaky.marker ] && exit 1; . ./lib.sh; [ "$(add 2 3)" = 5 ] || { touch flaky.marker; exit 1; }\n' >flaky_test.sh
check "test stays red after restore" 1 "flaky or order-dependent" --test "bash flaky_test.sh" -- lib.sh

echo "== base ref and new-file fixes =="
new_repo
git commit -qam "fix" && cp lib.sh "$sandbox/expected"
check "committed fix with --base" 0 "RRR: PROVEN" --base "HEAD^" --test "bash good_test.sh" -- lib.sh
new_repo
git checkout -q lib.sh && cp lib.sh "$sandbox/expected"
printf 'add() { echo $(( $1 + $2 )); }\n' >override.sh
printf '. ./lib.sh\n[ -e override.sh ] && . ./override.sh\n[ "$(add 2 3)" = 5 ]\n' >new_file_test.sh
cp override.sh "$sandbox/override.expected"
check "fix is a brand-new file" 0 "RRR: PROVEN" --test "bash new_file_test.sh" -- override.sh
if cmp -s override.sh "$sandbox/override.expected"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: new fix file was not restored"; fi

echo "== the fix survives an interrupted run =="
new_repo
"$rrr" --test 'bash good_test.sh || kill -TERM $PPID' -- lib.sh >/dev/null 2>&1
if cmp -s lib.sh "$sandbox/expected"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: fix lost when interrupted mid-revert"; fi

echo "== paths that could damage something are refused before anything runs =="
new_repo
echo precious >"$sandbox/outside.txt"
check "absolute path outside the repo" 2 "outside the work tree" --test "true" -- "$sandbox/outside.txt"
mkdir -p sub
(cd sub && "$rrr" --test "true" -- ../../outside.txt >/dev/null 2>&1)
check "relative path escaping the repo" 2 "outside the work tree" --test "true" -- "../outside.txt"
if [ "$(cat "$sandbox/outside.txt" 2>/dev/null)" = precious ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: a file outside the repo was modified or removed"; fi
new_repo
echo target >real.sh && ln -s real.sh link.sh
check "symlink fix file" 2 "symlink" --test "true" -- link.sh
if [ -L link.sh ] && [ "$(cat real.sh)" = target ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: symlink or its target was changed"; fi
new_repo
ln -s missing-target dangling.sh && git add dangling.sh && git commit -qm "dangling link"
check "tracked dangling symlink" 2 "symlink" --test "true" -- dangling.sh
if [ -L dangling.sh ] && [ ! -e missing-target ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: dangling symlink was replaced or its target created"; fi
new_repo
echo target >real.sh && ln -s real.sh was_link.sh && git add real.sh was_link.sh && git commit -qm "link"
rm was_link.sh && echo replaced >was_link.sh
fix_file=was_link.sh check "regular file now, symlink at base" 2 "symlink at" --test "true" -- was_link.sh
if [ ! -L was_link.sh ] && [ "$(cat was_link.sh)" = replaced ] && [ "$(cat real.sh)" = target ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: reverting to a base symlink changed files"; fi

echo "== the fix survives a test that deletes its directory =="
new_repo
mkdir -p src && printf 'add() { echo $(( $1 - $2 )); }\n' >src/lib.sh && git add src && git commit -qm "buggy in src"
printf 'add() { echo $(( $1 + $2 )); }\n' >src/lib.sh && cp src/lib.sh "$sandbox/src.expected"
printf '. ./src/lib.sh\n[ "$(add 2 3)" = 5 ] || { rm -rf src; exit 1; }\n' >rm_test.sh
"$rrr" --test "bash rm_test.sh" -- src/lib.sh >/dev/null 2>&1
if cmp -s src/lib.sh "$sandbox/src.expected"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: fix lost when the test removed its parent directory"; fi

echo "== a fix that could not be backed up is never deleted =="
new_repo
chmod 000 lib.sh
if [ -r lib.sh ]; then
  # Root (common in containers) can read a mode-000 file, so the copy would succeed.
  chmod 644 lib.sh
  echo "SKIP: unreadable fix file — this user can read mode-000 files"
else
  "$rrr" --test "true" -- lib.sh >/dev/null 2>&1
  code=$?
  chmod 644 lib.sh 2>/dev/null
  if [ "$code" -eq 2 ] && cmp -s lib.sh "$sandbox/expected"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: unreadable fix file — expected exit 2 with the fix intact, got exit $code"; fi
fi
new_repo
mkdir -p "$sandbox/tmp"
out="$(TMPDIR="$sandbox/tmp" "$rrr" --test 'rm -rf "$TMPDIR"/rrr.* "$(git rev-parse --git-dir)"/rrr.*; bash good_test.sh' -- lib.sh 2>&1)"
code=$?
if [ "$code" -eq 2 ] && cmp -s lib.sh "$sandbox/expected" && printf '%s' "$out" | grep -q "nothing was reverted"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: test deleted the backup — expected exit 2, the fix intact, and \"nothing was reverted\"; got exit $code"; fi

echo "== a test that swaps a fix path for a symlink cannot redirect writes =="
new_repo
echo precious >"$sandbox/victim.txt"
cat >swap_test.sh <<SWAP
. ./lib.sh; [ "\$(add 2 3)" = 5 ]; rc=\$?
[ -e swapped.marker ] || { touch swapped.marker; rm -f lib.sh; ln -s "$sandbox/victim.txt" lib.sh; }
exit \$rc
SWAP
"$rrr" --test "bash swap_test.sh" -- lib.sh >/dev/null 2>&1
if [ "$(cat "$sandbox/victim.txt")" = precious ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: wrote through a swapped-in symlink to a file outside the repo"; fi
if [ ! -L lib.sh ] && cmp -s lib.sh "$sandbox/expected"; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: fix not restored as a regular file after a symlink swap"; fi
new_repo
mkdir -p src "$sandbox/outdir" && printf 'add() { echo $(( $1 - $2 )); }\n' >src/lib.sh && git add src && git commit -qm "buggy in src"
printf 'add() { echo $(( $1 + $2 )); }\n' >src/lib.sh
echo precious >"$sandbox/outdir/lib.sh"
cat >swapdir_test.sh <<SWAP
[ -L src ] && exit 1
. ./src/lib.sh; [ "\$(add 2 3)" = 5 ]; rc=\$?
mv src src.real && ln -s "$sandbox/outdir" src
exit \$rc
SWAP
"$rrr" --test "bash swapdir_test.sh" -- src/lib.sh >/dev/null 2>&1
if [ "$(cat "$sandbox/outdir/lib.sh")" = precious ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: wrote through a swapped-in parent directory to a file outside the repo"; fi

echo "== a test that damages the fix on its final run is caught and undone =="
for damage in 'rm -f lib.sh' 'echo "# junk" >>lib.sh'; do
  new_repo
  cat >third_run_test.sh <<THIRD
n=\$(cat runs 2>/dev/null || echo 0); n=\$((n + 1)); echo \$n >runs
. ./lib.sh; [ "\$(add 2 3)" = 5 ]; rc=\$?
[ \$n -eq 3 ] && { $damage; }
exit \$rc
THIRD
  check "final run does: $damage" 1 "changed the fix files" --test "bash third_run_test.sh" -- lib.sh
done

echo "== a fix that only changes the executable bit =="
new_repo
git checkout -q lib.sh && cp lib.sh "$sandbox/expected"
printf '#!/bin/sh\nexit 0\n' >tool.sh && git add tool.sh && git commit -qm "tool not executable"
chmod +x tool.sh
fix_file=tool.sh check "mode-only fix" 0 "RRR: PROVEN" --test "test -x tool.sh" -- tool.sh
if [ -x tool.sh ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: executable bit was not restored"; fi

echo "== setup errors exit 2 and touch nothing =="
new_repo
check "no test command" 2 "rrr.sh" -- lib.sh
check "no fix files" 2 "rrr.sh" --test "true"
check "unknown base" 2 "unknown base ref" --base "no-such-ref" --test "true" -- lib.sh
check "missing file" 2 "exists neither" --test "true" -- nope.sh
mkdir -p dir
check "directory" 2 "is a directory" --test "true" -- dir

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
