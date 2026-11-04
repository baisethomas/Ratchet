#!/usr/bin/env bash
# Resolve the Ratchet drop-in/plugin root by walking up from START_DIR
# (default: this script's directory).
#
# A directory is the source only if it is a complete Ratchet drop-in/plugin
# root, not merely a repo that happens to have AGENTS.md and a skills/
# directory. Required: AGENTS.md, skills/, STATE.md, DECISIONS.md, and
# .claude-plugin/plugin.json whose name is "ratchet".
#
# Plugin layout: SKILL.md → ratchet-init/ → skills/ → plugin root (3 levels).
# Installed .agents/skills layout: SKILL.md → ratchet-init/ → skills/ →
# .agents/ → repo root (4 levels); drop-in/ lives at the checkout root.
#
# Usage: source-root.sh [START_DIR]
# Prints the source root on stdout. Exit 0 if found, 1 if not. Never skips.

set -uo pipefail

# is_ratchet_source <dir> — true only for a Ratchet drop-in/plugin root.
is_ratchet_source() {
  local d="$1"
  [ -f "$d/AGENTS.md" ] && [ -d "$d/skills" ] || return 1
  [ -f "$d/STATE.md" ] && [ -f "$d/DECISIONS.md" ] || return 1
  [ -f "$d/.claude-plugin/plugin.json" ] || return 1
  grep -q '"name"[[:space:]]*:[[:space:]]*"ratchet"' "$d/.claude-plugin/plugin.json"
}

start="${1:-$(dirname "$0")}"
dir="$(cd "$start" && pwd)" || exit 1

while :; do
  if is_ratchet_source "$dir"; then
    printf '%s\n' "$dir"
    exit 0
  fi
  if is_ratchet_source "$dir/drop-in"; then
    printf '%s\n' "$dir/drop-in"
    exit 0
  fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

printf 'source-root: no drop-in/plugin root above %s (need a Ratchet drop-in: AGENTS.md, skills/, STATE.md, DECISIONS.md, .claude-plugin/plugin.json name ratchet)\n' "$start" >&2
exit 1
