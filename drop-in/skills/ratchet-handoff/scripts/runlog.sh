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

# Refuse to append through a symlink: a log that quietly lands somewhere else
# is a log that cannot be audited.
if [ -L "$logfile" ]; then
  printf 'runlog: %s is a symlink; refusing to append through it\n' "$logfile" >&2
  exit 2
fi

logdir=$(dirname "$logfile")
[ -d "$logdir" ] || mkdir -p "$logdir"

# Header on first use. `>>` rather than `>` on purpose: if the existence test is
# wrong (a network mount, a race with another writer) the cost is one stray
# header line, not the rows that were already there.
if [ ! -s "$logfile" ]; then
  printf 'ts\tphase\tdecision\twhy\tevidence\tresult\n' >> "$logfile"
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
  >> "$logfile"
