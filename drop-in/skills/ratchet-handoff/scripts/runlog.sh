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
#   - a cell whose first non-space character is = + - @ or a double quote is
#     prefixed with a single quote. Tabs and CR are already turned into spaces,
#     so a tab or CR before =cmd still matches after flattening. "Space" here
#     is ASCII space plus the Unicode White_Space/BOM characters a trim-before-
#     parse sheet (or a visually empty prefix) will skip, leaving a formula:
#     U+0009–U+000D (tab, LF, VT, FF, CR — flattened to space), U+0020 space,
#     U+0085 NEL, U+00A0 NBSP (HTML/Word paste), U+1680 Ogham space,
#     U+2000–U+200A (en quad through hair space), U+200B zero-width space
#     (invisible, not White_Space but a visually empty prefix), U+2028
#     line separator, U+2029 paragraph separator, U+202F NNBSP, U+205F
#     medium mathematical space, U+3000 ideographic space (CJK), U+FEFF BOM.
#     Bidi overrides and homoglyphs are a different attack and are not
#     stripped. The log is meant to be opened in a spreadsheet, and evidence
#     cells can carry text an agent did not write (PR titles, file names, tool
#     output); none of it may become a formula when the reviewer opens the
#     file. A sheet that trims leading whitespace before parsing would
#     otherwise run the formula. The double quote is included because a TSV
#     importer strips enclosing quotes before it looks at the cell, so "=1+1"
#     would decode to =1+1 and run; with the prefix the cell no longer starts
#     with a quote, so the importer leaves it alone and the sheet reads it as
#     text.
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

# The log is opened only after this process holds a separate lock, so a
# refused write never creates the file and never unlinks a pathname another
# writer could have populated. flock on a sidecar file beside the log where
# flock exists; where it is missing or fails (macOS ships without it), a
# directory beside the log is the lock, because mkdir is atomic on every POSIX
# filesystem, and the holder's pid sits inside it. The fallback waits a bounded
# two seconds. A lock whose recorded holder is no longer running is stale and
# is taken over once. A lock that is still held, or whose holder is unknown,
# refuses the write with exit 2 and names the directory: a row that may have
# interleaved with another writer is worse than a row the caller is told was
# not written. The script never appends unlocked. The header check happens
# under that lock so two writers that start on an empty log cannot both see
# it empty and both write a header.
# After the sidecar flock is held and the log is open, also flock the log
# descriptor. 1.3.1 (efb2dc7) flocks only that descriptor, never the sidecar,
# so a mixed-version pair serializes on fd 9 and cannot deadlock: the old
# writer never waits on the sidecar, and the new writer waits on fd 9 only
# after it already holds the sidecar.
lockdir="$logfile.lock"
flockfile="$logfile.flock"
acquire() {
  mkdir "$lockdir" 2>/dev/null || return 1
  trap 'rm -rf "$lockdir"' EXIT
  printf '%s\n' "$$" > "$lockdir/pid"
}
locked=0
locked_via_flock=0
if command -v flock >/dev/null 2>&1; then
  exec 8>>"$flockfile"
  if flock 8 2>/dev/null; then
    locked=1
    locked_via_flock=1
  else
    exec 8>&-
  fi
fi
if [ "$locked" -eq 0 ]; then
  # A waiter killed between mkdir and rmdir of the takeover mutex used to
  # leave it behind, so the next mkdir failed and a dead lock could never
  # be taken over. Reap only when the mutex is provably stale: its recorded
  # pid is dead, or it has no pid and its mtime is older than
  # TAKEOVER_STALE_S. mkdir-to-pid-write is sub-millisecond; 8s is well
  # beyond that window, so a live waiter between those two steps is not
  # reaped, and a crashed waiter does not wedge takeover forever. Do not
  # reap after the wait: that would steal an empty mutex from a concurrent
  # winner who has not yet written a pid.
  TAKEOVER_STALE_S=8
  takeover_age_s() {
    local m now
    now=$(date +%s)
    m=$(stat -c '%Y' "$1" 2>/dev/null) || m=$(stat -f '%m' "$1" 2>/dev/null) || return 1
    echo $((now - m))
  }
  if [ -d "$lockdir.takeover" ]; then
    tpid=$(cat "$lockdir.takeover/pid" 2>/dev/null || true)
    if [ -n "$tpid" ]; then
      if ! kill -0 "$tpid" 2>/dev/null; then
        rm -rf "$lockdir.takeover"
      fi
    else
      tage=$(takeover_age_s "$lockdir.takeover" || echo 0)
      if [ "$tage" -ge "$TAKEOVER_STALE_S" ]; then
        rm -rf "$lockdir.takeover"
      fi
    fi
  fi
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
      printf '%s\n' "$$" > "$lockdir.takeover/pid" || true
      [ "$(cat "$lockdir/pid" 2>/dev/null || true)" = "$holder" ] && rm -rf "$lockdir"
      rm -rf "$lockdir.takeover"
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
exec 9>>"$logfile"
if [ "$locked_via_flock" -eq 1 ]; then
  # Already hold the sidecar. flock 9 failing (a shim, a non-regular file)
  # must not abort the write: same-version writers are already serialized.
  flock 9 2>/dev/null || true
fi
if [ ! -s "$logfile" ]; then
  printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' >&9
fi

clean() {
  local v stripped
  v=$(printf '%s' "$1" | tr '\t\n\r\v\f' '     ')
  # First non-space character, not the first byte: leading ASCII spaces
  # (tab/LF/VT/FF/CR already flattened above) and the Unicode White_Space/BOM
  # listed in the header must not bypass the formula prefix.
  stripped="$v"
  while :; do
    # Hex byte sequences, not $'\uXXXX': bash leaves Unicode escapes
    # literal under LC_ALL=C, so those patterns would never match.
    case "$stripped" in
      ' '*) stripped="${stripped# }" ;;
      $'\xc2\x85'*) stripped="${stripped#$'\xc2\x85'}" ;;                 # U+0085 NEL
      $'\xc2\xa0'*) stripped="${stripped#$'\xc2\xa0'}" ;;                 # U+00A0
      $'\xe1\x9a\x80'*) stripped="${stripped#$'\xe1\x9a\x80'}" ;;         # U+1680
      $'\xe2\x80\x80'*) stripped="${stripped#$'\xe2\x80\x80'}" ;;         # U+2000
      $'\xe2\x80\x81'*) stripped="${stripped#$'\xe2\x80\x81'}" ;;         # U+2001
      $'\xe2\x80\x82'*) stripped="${stripped#$'\xe2\x80\x82'}" ;;         # U+2002
      $'\xe2\x80\x83'*) stripped="${stripped#$'\xe2\x80\x83'}" ;;         # U+2003
      $'\xe2\x80\x84'*) stripped="${stripped#$'\xe2\x80\x84'}" ;;         # U+2004
      $'\xe2\x80\x85'*) stripped="${stripped#$'\xe2\x80\x85'}" ;;         # U+2005
      $'\xe2\x80\x86'*) stripped="${stripped#$'\xe2\x80\x86'}" ;;         # U+2006
      $'\xe2\x80\x87'*) stripped="${stripped#$'\xe2\x80\x87'}" ;;         # U+2007
      $'\xe2\x80\x88'*) stripped="${stripped#$'\xe2\x80\x88'}" ;;         # U+2008
      $'\xe2\x80\x89'*) stripped="${stripped#$'\xe2\x80\x89'}" ;;         # U+2009
      $'\xe2\x80\x8a'*) stripped="${stripped#$'\xe2\x80\x8a'}" ;;         # U+200A
      $'\xe2\x80\x8b'*) stripped="${stripped#$'\xe2\x80\x8b'}" ;;         # U+200B
      $'\xe2\x80\xa8'*) stripped="${stripped#$'\xe2\x80\xa8'}" ;;         # U+2028
      $'\xe2\x80\xa9'*) stripped="${stripped#$'\xe2\x80\xa9'}" ;;         # U+2029
      $'\xe2\x80\xaf'*) stripped="${stripped#$'\xe2\x80\xaf'}" ;;         # U+202F
      $'\xe2\x81\x9f'*) stripped="${stripped#$'\xe2\x81\x9f'}" ;;         # U+205F
      $'\xe3\x80\x80'*) stripped="${stripped#$'\xe3\x80\x80'}" ;;         # U+3000
      $'\xef\xbb\xbf'*) stripped="${stripped#$'\xef\xbb\xbf'}" ;;         # U+FEFF
      *) break ;;
    esac
  done
  case "$stripped" in
    =*|+*|-*|@*|\"*) printf "'%s" "$v" ;;
    *) printf '%s' "$v" ;;
  esac
}

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
  "$ts" "$(clean "$1")" "$(clean "$2")" "$(clean "$3")" "$(clean "$4")" "$(clean "$5")" \
  >&9
