#!/usr/bin/env bash
# Resolve the Ratchet drop-in/plugin root by walking up from START_DIR
# (default: this script's directory).
#
# A directory is the source if it contains AGENTS.md beside a skills/
# directory (the plugin / drop-in root). A Ratchet checkout is a directory
# that contains drop-in/AGENTS.md; the source is then drop-in/.
#
# Plugin layout: SKILL.md → ratchet-init/ → skills/ → plugin root (3 levels).
# Installed .agents/skills layout: SKILL.md → ratchet-init/ → skills/ →
# .agents/ → repo root (4 levels); drop-in/ lives at the checkout root.
#
# Usage: source-root.sh [START_DIR]
# Prints the source root on stdout. Exit 0 if found, 1 if not. Never skips.

set -uo pipefail

start="${1:-$(dirname "$0")}"
dir="$(cd "$start" && pwd)" || exit 1

while :; do
  if [ -f "$dir/AGENTS.md" ] && [ -d "$dir/skills" ]; then
    printf '%s\n' "$dir"
    exit 0
  fi
  if [ -f "$dir/drop-in/AGENTS.md" ] && [ -d "$dir/drop-in/skills" ]; then
    printf '%s\n' "$dir/drop-in"
    exit 0
  fi
  parent="$(dirname "$dir")"
  [ "$parent" = "$dir" ] && break
  dir="$parent"
done

printf 'source-root: no drop-in/plugin root above %s (need AGENTS.md beside skills/, or drop-in/AGENTS.md)\n' "$start" >&2
exit 1
