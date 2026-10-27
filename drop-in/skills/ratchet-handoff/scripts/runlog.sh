#!/usr/bin/env bash
# Append one row to a Ratchet run log: an append-only TSV with one line per
# decision point in a long or unattended run, so a reviewer who was not there
# can see what was chosen, why, and what proved it.
#
#   runlog.sh <logfile> <phase> <decision> <why> <evidence> <result>
#
#   logfile   by convention .ratchet/run.tsv; gitignored unless the owner wants
#             the trail committed. Created with a header on first use.
#   phase     the step or workstream, one word or two.
#   decision  what was chosen or done, one line.
#   why       the reason, plain words.
#   evidence  a pointer, never prose: a commit, a PR number, file:line, or the
#             path of an artifact (test output, screenshot, trace).
#   result    a state: "tests green", "reverted", "INCONCLUSIVE", "open".
#
# Rules the script enforces so no row has to be trusted on sight:
#   - append-only: it never rewrites the file. A wrong call gets a new row that
#     supersedes it.
#   - one line per row: tabs, newlines and carriage returns inside a cell are
#     replaced with spaces.
#   - a cell that starts with = + - @ or a double quote is prefixed with a
#     single quote. The log is meant to be opened in a spreadsheet, and
#     evidence cells can carry text an agent did not write (PR titles, file
#     names, tool output); none of it may become a formula when the reviewer
#     opens the file. The double quote is included because a TSV importer
#     strips enclosing quotes before it looks at the cell, so "=1+1" would
#     decode to =1+1 and run; with the prefix the cell no longer starts with
#     a quote, so the importer leaves it alone and the sheet reads it as text.
#
# Rewritten from pstack's show-me-your-work/scripts/log.sh (MIT, Lauren Tan),
# keeping its formula-injection scrub. See ../../CREDITS.md.

set -euo pipefail

if [ "$#" -ne 6 ]; then
  printf 'usage: runlog.sh <logfile> <phase> <decision> <why> <evidence> <result>\n' >&2
  exit 2
fi

logfile="$1"
shift

# Refuse to append through a symlink, whether it is the log itself or any
# directory the caller named on the way to it: a log that quietly lands
# somewhere else is a log that cannot be audited, and a repository-controlled
# `.ratchet` symlink would do exactly that. Same policy as ratchet-init's
# installer. Every component of the path as written is checked, except the
# root, so on a system where /tmp or /var is itself a symlink pass the real
# path (`pwd -P`).
if [ -L "$logfile" ]; then
  printf 'runlog: %s is a symlink; refusing to append through it\n' "$logfile" >&2
  exit 2
fi
p="$logfile"
while p=$(dirname "$p"); [ "$p" != "." ] && [ "$p" != "/" ]; do
  if [ -L "$p" ]; then
    printf 'runlog: %s is a symlink; refusing to write the log through it (use the real path)\n' "$p" >&2
    exit 2
  fi
done

logdir=$(dirname "$logfile")
[ -d "$logdir" ] || mkdir -p "$logdir"

# One open in append mode, then every write goes through that descriptor. The
# header check happens under a lock so two writers that start on an empty log
# cannot both see it empty and both write a header. flock on the descriptor
# where it exists; where it is missing or fails (macOS ships without it), a
# directory beside the log is the lock, because mkdir is atomic on every POSIX
# filesystem, and the holder's pid sits inside it. The fallback waits a bounded
# two seconds. A lock whose recorded holder is no longer running is stale and
# is taken over once. A lock that is still held, or whose holder is unknown,
# refuses the write with exit 2 and names the directory: a row that may have
# interleaved with another writer is worse than a row the caller is told was
# not written. The script never appends unlocked.
exec 9>>"$logfile"
lockdir="$logfile.lock"
acquire() {
  mkdir "$lockdir" 2>/dev/null || return 1
  trap 'rm -rf "$lockdir"' EXIT
  printf '%s\n' "$$" > "$lockdir/pid"
}
locked=0
if command -v flock >/dev/null 2>&1 && flock 9 2>/dev/null; then
  locked=1
else
  for _ in $(seq 40); do
    acquire && { locked=1; break; }
    sleep 0.05
  done
  if [ "$locked" -eq 0 ]; then
    holder=$(cat "$lockdir/pid" 2>/dev/null || true)
    # A pid that is not running left this lock behind. An empty pid means a
    # holder that is still setting up, or one killed in that instant; the
    # script cannot tell, so it leaves that lock for a human. The takeover
    # itself is serialized through a second directory, and the pid is read
    # again under it, so several waiters that all saw the same dead holder
    # remove the stale lock once and never remove a lock a new live holder
    # created in the meantime.
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null && mkdir "$lockdir.takeover" 2>/dev/null; then
      [ "$(cat "$lockdir/pid" 2>/dev/null || true)" = "$holder" ] && rm -rf "$lockdir"
      rmdir "$lockdir.takeover" 2>/dev/null || true
    fi
    for _ in $(seq 40); do
      acquire && { locked=1; break; }
      sleep 0.05
    done
  fi
  if [ "$locked" -eq 0 ]; then
    printf 'runlog: %s is locked by %s (pid %s) and nothing was written. Remove that directory only once you know the writer is gone.\n' "$logfile" "$lockdir" "${holder:-unknown}" >&2
    exit 2
  fi
fi
if [ ! -s "$logfile" ]; then
  printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' >&9
fi

clean() {
  local v
  v=$(printf '%s' "$1" | tr '\t\n\r' '   ')
  case "$v" in
    =*|+*|-*|@*|\"*) printf "'%s" "$v" ;;
    *) printf '%s' "$v" ;;
  esac
}

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$ts" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$(clean "$4")" "$(clean "$5")" \
  >&9
