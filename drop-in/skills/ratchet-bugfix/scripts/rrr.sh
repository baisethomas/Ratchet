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
# Containment is re-checked at every write, and the script never writes through an
# existing path, so a test that swaps a fix file or its directory for a symlink cannot
# redirect a write outside the repo. This guards against accidents, not against a
# hostile test command: that command already runs with your full permissions.
#
# The fix is backed up first and restored on every exit path, including Ctrl-C and a
# test that deletes the file's directory. If a restore ever fails, the backup directory
# is kept and its path printed. A file is only ever deleted if it did not exist when
# the script started; a missing backup never counts as that. Backups live in the git
# directory. Git's index, stash, and branches are never touched.
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

# place <source> <path> — write <source>'s bytes to <path> as a fresh regular file.
# The test command runs between our checks and our writes and may have replaced a fix
# file or one of its parent directories with a symlink, so: re-check containment at the
# moment of writing, and remove whatever is at the path first so nothing is ever written
# *through* it. rm on a symlink removes the link, not its target.
place() {
  inside_worktree "$2" || return 1
  [ -d "$2" ] && [ ! -L "$2" ] && return 1
  mkdir -p "$(dirname "$2")" || return 1
  inside_worktree "$2" || return 1
  rm -f "$2" && cat "$1" >"$2"
}

# unplace <path> — remove <path> (file or symlink), only if it is still inside the repo.
unplace() {
  inside_worktree "$1" || return 1
  [ -d "$1" ] && [ ! -L "$1" ] && return 1
  rm -f "$1"
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

# Backups live in the git directory, not $TMPDIR: tests routinely clean temp directories.
backup="$(mktemp -d "$(git rev-parse --absolute-git-dir)/rrr.XXXXXX")" || die "could not create a backup directory"
restored=0
keep_backup=0
# existed[i] is 1 if paths[i] was present when we started. It is kept in memory, never
# inferred from the backup directory: a missing backup must never read as "this file
# did not exist, delete it".
existed=()

# restore — put every fix file back. Only marks itself done if every copy succeeded;
# otherwise the backup directory is kept and its location printed.
restore() {
  [ "$restored" -eq 1 ] && return 0
  local i=0 p ok=1
  for p in "${paths[@]}"; do
    if [ "${existed[$i]}" -eq 0 ]; then
      unplace "$p" || ok=0
    elif [ -f "$backup/$i" ]; then
      # The test may have deleted the file's directory (place recreates it) or moved
      # the path outside the repo (place refuses, and the backup is kept).
      if place "$backup/$i" "$p" && cmp -s "$backup/$i" "$p"; then
        if [ -x "$backup/$i" ]; then chmod +x "$p"; else chmod -x "$p"; fi
      else
        printf 'rrr: could not safely restore %s (its location now resolves outside the repo, or is a directory)\n' "$p" >&2
        ok=0
      fi
    else
      # The backup is gone. Leave the file exactly as it is rather than guess.
      printf 'rrr: the backup of %s is missing; the file was left untouched\n' "$p" >&2
      ok=0
    fi
    i=$((i + 1))
  done
  if [ "$ok" -eq 1 ]; then
    restored=1
    return 0
  fi
  keep_backup=1
  printf 'rrr: RESTORE FAILED — any surviving backups are in %s, numbered in argument order\n' "$backup" >&2
  return 1
}

# fix_intact — every listed path is exactly as it was when we started: same bytes, same
# executable bit, still absent if it was absent. Paths whose backup is gone are skipped;
# restore reports those.
fix_intact() {
  local i=0 p
  for p in "${paths[@]}"; do
    if [ "${existed[$i]}" -eq 0 ]; then
      { [ -e "$p" ] || [ -L "$p" ]; } && return 1
    elif [ -f "$backup/$i" ]; then
      [ -f "$p" ] && [ ! -L "$p" ] && cmp -s "$backup/$i" "$p" || return 1
      if [ -x "$backup/$i" ]; then [ -x "$p" ] || return 1; else [ -x "$p" ] && return 1; fi
    fi
    i=$((i + 1))
  done
  return 0
}

cleanup() {
  # "Restored" is only true until the test command runs again, so check the files
  # themselves rather than trusting the flag.
  if [ "$restored" -eq 1 ] && [ "$keep_backup" -eq 0 ] && ! fix_intact; then restored=0; fi
  restore
  [ "$keep_backup" -eq 1 ] || rm -rf "$backup"
}
# backups_intact — every file that existed still has a byte-identical backup.
backups_intact() {
  local i=0 p
  for p in "${paths[@]}"; do
    if [ "${existed[$i]}" -eq 1 ]; then
      [ -f "$backup/$i" ] || return 1
    fi
    i=$((i + 1))
  done
  return 0
}

# Back everything up before the restore trap exists. Until every copy is verified,
# nothing in the work tree has been touched, so a failure here must only clean up.
i=0
for p in "${paths[@]}"; do
  if [ -e "$p" ]; then
    existed[$i]=1
    { cp -p "$p" "$backup/$i" && cmp -s "$p" "$backup/$i"; } || { rm -rf "$backup"; die "could not back up $p; nothing was changed"; }
  else
    existed[$i]=0
  fi
  i=$((i + 1))
done

trap cleanup EXIT
trap 'exit 130' INT TERM

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

# The test has now run once. If it removed our backups, stop before reverting anything.
if ! backups_intact; then
  restored=1
  die "the test command removed rrr's backup directory ($backup); nothing was reverted"
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
      place "$backup/base" "$p" || die "$p no longer resolves to a regular file inside the repo after the test ran; refusing to write"
      if [ "$base_exec" -eq 1 ]; then chmod +x "$p"; else chmod -x "$p"; fi
    fi
  elif [ -e "$p" ] || [ -L "$p" ]; then
    changed=1
    unplace "$p" || die "$p no longer resolves inside the repo after the test ran; refusing to delete"
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
final_code=$?

# The test ran once more after the restore. If it touched the fix, put the fix back and
# refuse the proof: a test that rewrites the code under test has not proven anything.
if ! fix_intact; then
  restored=0
  restore || exit 2
  verdict "NOT PROVEN — the test command changed the fix files while it ran. They have been restored. Make the test leave the files it is testing alone, then run this again."
  exit 1
fi

if [ "$final_code" -ne 0 ]; then
  verdict "NOT PROVEN — the test fails after restoring the fix. It is flaky or order-dependent. The fix has been restored."
  exit 1
fi

verdict "PROVEN — passes with the fix, fails without it, passes again. Read the phase 2 output above: it must fail on the bug's assertion, not on an import, syntax, or missing-file error."
exit 0
