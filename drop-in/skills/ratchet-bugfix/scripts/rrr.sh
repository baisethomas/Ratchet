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
# FIX_FILEs must be regular files inside this repository: absolute paths, paths that
# resolve outside the repo, symlinks, and directories are refused before anything runs.
# Both content and the executable bit are reverted, so a chmod-only fix can be proven.
#
# The fix is backed up first and restored on every exit path, including Ctrl-C and a
# test that deletes the file's directory. If a restore ever fails, the backup directory
# is kept and its path printed. Git's index, stash, and branches are never touched.
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

# base_mode <path> — git's mode for the path at $base (100644, 100755, 120000), or empty.
base_mode() { git ls-tree "$base" -- "$1" 2>/dev/null | awk 'NR==1 { print $1 }'; }

# inside_worktree <path> — true only if the path's real location is under the repo root.
# Resolves the nearest existing parent physically, so neither ../ nor a symlinked
# directory can point the script at a file outside the repository.
root="$(cd "$(git rev-parse --show-toplevel)" && pwd -P)" || die "could not resolve the repo root"
inside_worktree() {
  local dir
  dir="$(dirname "$1")"
  while [ ! -d "$dir" ]; do dir="$(dirname "$dir")"; done
  dir="$(cd "$dir" && pwd -P)" || return 1
  case "$dir/" in "$root/"*) return 0 ;; *) return 1 ;; esac
}

# Everything below rewrites and deletes the listed paths, so refuse anything that is
# not an ordinary file inside this repository before touching a single byte.
for p in "${paths[@]}"; do
  case "$p" in
    /*) die "$p is outside the work tree; list fix files relative to the repo" ;;
  esac
  inside_worktree "$p" || die "$p is outside the work tree; list fix files relative to the repo"
  [ -L "$p" ] && die "$p is a symlink; list the real file it points to"
  [ "$(base_mode "$p")" = "120000" ] && die "$p is a symlink at $base; list the real file it points to"
  [ -d "$p" ] && die "$p is a directory; list the fix files individually"
  [ -e "$p" ] && [ ! -f "$p" ] && die "$p is not a regular file"
  [ -e "$p" ] || at_base "$p" || die "$p exists neither in the work tree nor at $base"
done

backup="$(mktemp -d "${TMPDIR:-/tmp}/rrr.XXXXXX")" || die "could not create a backup directory"
restored=0
keep_backup=0

# restore — put every fix file back. Only marks itself done if every copy succeeded;
# otherwise the backup directory is kept and its location printed.
restore() {
  [ "$restored" -eq 1 ] && return 0
  local i=0 p ok=1
  for p in "${paths[@]}"; do
    if [ -e "$backup/$i" ]; then
      # The test may have deleted the file's directory; recreate it.
      { mkdir -p "$(dirname "$p")" && cp -p "$backup/$i" "$p" && cmp -s "$backup/$i" "$p"; } || ok=0
    else
      rm -f "$p" || ok=0
    fi
    i=$((i + 1))
  done
  if [ "$ok" -eq 1 ]; then
    restored=1
    return 0
  fi
  keep_backup=1
  printf 'rrr: RESTORE FAILED — your fix files are preserved, numbered in argument order, in %s\n' "$backup" >&2
  return 1
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
    # A fix can be content, the executable bit, or both; revert both.
    base_exec=0; [ "$(base_mode "$p")" = "100755" ] && base_exec=1
    now_exec=0; [ -x "$p" ] && now_exec=1
    if [ ! -e "$p" ] || ! cmp -s "$backup/base" "$p" || [ "$base_exec" -ne "$now_exec" ]; then
      changed=1
      mkdir -p "$(dirname "$p")"
      cat "$backup/base" >"$p"
      if [ "$base_exec" -eq 1 ]; then chmod +x "$p"; else chmod -x "$p"; fi
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

restore || exit 2

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
