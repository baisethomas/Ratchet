#!/usr/bin/env bash
# PostToolUse(Edit|Write) hook: lint the file that was just edited so the error
# lands in-loop, whether or not the model would have checked on its own. One
# linter per file type (see lint_command_for); a mapped type whose linter is
# missing is reported, never silently skipped.
#
# Contract (https://code.claude.com/docs/en/hooks):
#   - input arrives as JSON on stdin; the path is at .tool_input.file_path
#     (there is NO $CLAUDE_FILE_PATHS environment variable)
#   - exit 2 surfaces stderr back to Claude; exit 0 is silent success

set -uo pipefail

# shellcheck source=lib-payload.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib-payload.sh"

input=$(cat)

# Without a parser this hook would skip every file and look like it was passing.
# Surface that once, visibly, rather than pretending to lint.
file=$(payload_field "$input" '.tool_input.file_path' '?.tool_input?.file_path')
case $? in
  1) no_parser_message "lint hook disabled"; exit 2 ;;
  2) echo "lint hook disabled: could not parse the hook payload, so edited files are not being linted. Fix the JSON parser (jq/node)." >&2
     exit 2 ;;
esac

[ -z "$file" ] && exit 0

# FILL-ME: one linter per file type; the edited file's path is appended to the
# command. Delete the rows this repo does not use and add its own. The ESLint
# row is exercised by this template's tests; the others are common defaults —
# run each once against your installed version before trusting it (Ratchet
# rule: never a library or CLI call from memory). A row whose tool is not
# installed is REPORTED on every edit, not skipped: a lint hook that silently
# does nothing looks exactly like one that works.
lint_command_for() {
  case "$1" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) echo "npx eslint --no-warn-ignored" ;;
    *.py)                              echo "ruff check" ;;
    *.swift)                           echo "swiftlint lint --quiet" ;;
    *.go)                              echo "gofmt -l" ;;
    *.rs)                              echo "rustfmt --check" ;;
    *.rb)                              echo "rubocop --format simple" ;;
    *.sh|*.bash)                       echo "shellcheck" ;;
    *)                                 echo "" ;;
  esac
}

lint_cmd=$(lint_command_for "$file")
# Not a file type this repo lints (docs, config, data): nothing to do.
[ -z "$lint_cmd" ] && exit 0

tool=${lint_cmd%% *}
if ! command -v "$tool" >/dev/null 2>&1; then
  echo "lint hook: ${file##*.} files are mapped to '${lint_cmd}' but '${tool}' is not installed, so ${file} was NOT linted. Install it, or remove that row from lint_command_for in .claude/hooks/lint-edited-file.sh." >&2
  exit 2
fi

# Say so rather than skipping silently: an unlinted edit that looks linted is
# the failure mode this hook exists to remove.
if ! cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null; then
  echo "lint hook disabled: cannot enter CLAUDE_PROJECT_DIR (${CLAUDE_PROJECT_DIR:-.}), so ${file} was not linted." >&2
  exit 2
fi

# Capture rather than pipe: a pipeline would report tail's status, not the linter's.
# shellcheck disable=SC2086  # lint_cmd is a command with flags, split on purpose
output=$($lint_cmd "$file" 2>&1)
status=$?

# Several linters exit 0 with warnings (ESLint) or only print offending file
# names (gofmt -l), so an exit-code check alone would stay silent on real
# problems. Surface any output at all.
if [ "$status" -eq 0 ] && [ -z "${output//[[:space:]]/}" ]; then
  exit 0
fi

{
  echo "${tool} reported problems in ${file} (note: a linter does not typecheck; run the build or tests for type errors):"
  printf '%s\n' "$output" | head -40
} >&2
exit 2
