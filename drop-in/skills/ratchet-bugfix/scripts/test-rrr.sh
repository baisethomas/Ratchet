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
  elif [ -n "$(git status --porcelain --untracked-files=no | grep -v '^ M lib.sh$')" ]; then
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
