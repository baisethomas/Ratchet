#!/usr/bin/env bash
# Reproduce-revert-restore: prove a regression test can fail without the fix.
#
#   rrr.sh [--base REF] --test 'COMMAND' -- FIX_FILE [FIX_FILE...]
#
# Runs COMMAND three times: with the fix (must pass), with FIX_FILEs put back to
# their content at REF (must FAIL), and with the fix restored (must pass).
# REF defaults to HEAD, which is right while the fix is uncommitted. If the fix is
# already committed, pass the commit before it: --base <sha>^.
#
# List only the files that contain the fix. Never list the test file: reverting it
# makes the test disappear, and "test not found" is not evidence of anything.
#
# The fix is backed up first and restored on every exit path, including Ctrl-C.
# Git's index, stash, and branches are never touched; only the listed files change.
#
# Exit: 0 = PROVEN, 1 = NOT PROVEN, 2 = usage or setup error.

set -uo pipefail

base="HEAD"
test_cmd=""
paths=()

usage() {
  sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --base) [ $# -ge 2 ] || usage; base="$2"; shift 2 ;;
    --test) [ $# -ge 2 ] || usage; test_cmd="$2"; shift 2 ;;
    --) shift; while [ $# -gt 0 ]; do paths+=("$1"); shift; done ;;
    *) usage ;;
  esac
done

[ -n "$test_cmd" ] || usage
[ "${#paths[@]}" -gt 0 ] || usage

die() { printf 'rrr: %s\n' "$1" >&2; exit 2; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "not inside a git work tree"
git rev-parse --verify --quiet "$base^{commit}" >/dev/null || die "unknown base ref: $base"

at_base() { git cat-file -e "$base:./$1" 2>/dev/null; }

for p in "${paths[@]}"; do
  [ -d "$p" ] && die "$p is a directory; list the fix files individually"
  [ -e "$p" ] || at_base "$p" || die "$p exists neither in the work tree nor at $base"
done

backup="$(mktemp -d "${TMPDIR:-/tmp}/rrr.XXXXXX")" || die "could not create a backup directory"
restored=0
keep_backup=0

restore() {
  [ "$restored" -eq 1 ] && return 0
  local i=0 p
  for p in "${paths[@]}"; do
    if [ -e "$backup/$i" ]; then
      cp -p "$backup/$i" "$p"
    else
      rm -f "$p"
    fi
    i=$((i + 1))
  done
  restored=1
}

cleanup() {
  restore
  [ "$keep_backup" -eq 1 ] || rm -rf "$backup"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

i=0
for p in "${paths[@]}"; do
  [ -e "$p" ] && { cp -p "$p" "$backup/$i" || die "could not back up $p"; }
  i=$((i + 1))
done

# run_phase <label> — runs the test, prints the tail of its output, returns its exit code.
run_phase() {
  local out="$backup/out" code
  printf '\n== %s ==\n$ %s\n' "$1" "$test_cmd"
  bash -c "$test_cmd" >"$out" 2>&1
  code=$?
  tail -n 40 "$out"
  printf -- '-- exit %s\n' "$code"
  return "$code"
}

verdict() {
  printf '\nRRR: %s\n' "$1"
}

run_phase "1/3 WITH THE FIX (must pass)"
if [ $? -ne 0 ]; then
  verdict "NOT PROVEN — the test does not pass with the fix in place. Nothing was reverted."
  exit 1
fi

changed=0
i=0
for p in "${paths[@]}"; do
  if at_base "$p"; then
    git show "$base:./$p" >"$backup/base" || die "could not read $p at $base"
    if [ ! -e "$p" ] || ! cmp -s "$backup/base" "$p"; then
      changed=1
      mkdir -p "$(dirname "$p")"
      cat "$backup/base" >"$p"
    fi
  elif [ -e "$p" ]; then
    changed=1
    rm -f "$p"
  fi
  i=$((i + 1))
done

if [ "$changed" -eq 0 ]; then
  verdict "NOT PROVEN — the listed files are identical to $base, so there was no fix to revert. If the fix is committed, pass --base <commit-before-the-fix>."
  exit 1
fi

run_phase "2/3 FIX REVERTED to $base (must FAIL)"
reverted_code=$?

restore
i=0
for p in "${paths[@]}"; do
  if [ -e "$backup/$i" ]; then
    cmp -s "$backup/$i" "$p" || { keep_backup=1; die "RESTORE FAILED for $p — your fix is preserved in $backup"; }
  fi
  i=$((i + 1))
done

if [ "$reverted_code" -eq 0 ]; then
  verdict "NOT PROVEN — the test passed with the fix reverted. It does not exercise the bug. The fix has been restored."
  exit 1
fi

run_phase "3/3 FIX RESTORED (must pass)"
if [ $? -ne 0 ]; then
  verdict "NOT PROVEN — the test fails after restoring the fix. It is flaky or order-dependent. The fix has been restored."
  exit 1
fi

verdict "PROVEN — passes with the fix, fails without it, passes again. Read the phase 2 output above: it must fail on the bug's assertion, not on an import, syntax, or missing-file error."
exit 0
