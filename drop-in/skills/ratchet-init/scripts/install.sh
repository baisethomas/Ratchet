#!/usr/bin/env bash
# Install Ratchet's drop-in files into a repository without overwriting anything.
#
#   install.sh --from <ratchet>/drop-in --to <repo root> [--claude] [--codex]
#
# Always installs: AGENTS.md, .ratchet/STATE.md, .ratchet/DECISIONS.md, .agents/skills/*.
# --claude adds CLAUDE.md, .claude/hooks/*, and makes the skills visible under
#          .claude/skills (one symlink to ../.agents/skills, or one link per skill if
#          .claude/skills already exists as a real directory).
# --codex  adds CODEX.md.
#
# Anything that already exists at a destination — file, directory, or symlink — is
# left exactly as it is and reported as SKIP. Nothing is merged, overwritten, or
# deleted, so running this twice is safe and the second run changes nothing.
# It does not touch .claude/settings.json: merging the hooks block is a judgement
# call and is left to the caller.
#
# Exit: 0 = done (see the summary), 2 = usage or setup error.

set -uo pipefail

from=""
to=""
claude=0
codex=0

usage() {
  sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --from) [ $# -ge 2 ] || usage; from="$2"; shift 2 ;;
    --to) [ $# -ge 2 ] || usage; to="$2"; shift 2 ;;
    --claude) claude=1; shift ;;
    --codex) codex=1; shift ;;
    *) usage ;;
  esac
done

die() { printf 'install: %s\n' "$1" >&2; exit 2; }

[ -n "$from" ] && [ -n "$to" ] || usage
[ -f "$from/AGENTS.md" ] || die "$from does not look like Ratchet's drop-in directory (no AGENTS.md)"
[ -d "$to" ] || die "$to is not a directory"
git -C "$to" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$to is not inside a git work tree"

from="$(cd "$from" && pwd -P)"
to="$(cd "$to" && pwd -P)"
[ "$from" = "$to" ] && die "source and destination are the same directory"

added=0
skipped=0

taken() { [ -e "$1" ] || [ -L "$1" ]; }

# put <source file> <destination relative to $to>
put() {
  local dest="$to/$2"
  if taken "$dest"; then
    printf 'SKIP  %s (exists)\n' "$2"; skipped=$((skipped + 1)); return 0
  fi
  mkdir -p "$(dirname "$dest")" && cp -p "$1" "$dest" || die "could not write $2"
  printf 'ADD   %s\n' "$2"; added=$((added + 1))
}

# put_tree <source dir> <destination dir relative to $to> — file by file, so an existing
# directory only gains the files it lacks.
put_tree() {
  local f rel
  while IFS= read -r f; do
    rel="${f#"$1"/}"
    put "$f" "$2/$rel"
  done < <(find "$1" -type f | sort)
}

# link <target> <link path relative to $to>
link() {
  local dest="$to/$2"
  if taken "$dest"; then
    printf 'SKIP  %s (exists)\n' "$2"; skipped=$((skipped + 1)); return 0
  fi
  mkdir -p "$(dirname "$dest")" && ln -s "$1" "$dest" || die "could not link $2"
  printf 'LINK  %s -> %s\n' "$2" "$1"; added=$((added + 1))
}

put "$from/AGENTS.md" "AGENTS.md"
put "$from/STATE.md" ".ratchet/STATE.md"
put "$from/DECISIONS.md" ".ratchet/DECISIONS.md"
[ -d "$from/skills" ] && put_tree "$from/skills" ".agents/skills"

if [ "$codex" -eq 1 ]; then
  put "$from/CODEX.md" "CODEX.md"
fi

if [ "$claude" -eq 1 ]; then
  put "$from/CLAUDE.md" "CLAUDE.md"
  put_tree "$from/hooks" ".claude/hooks"
  if [ -d "$to/.claude/skills" ] && [ ! -L "$to/.claude/skills" ]; then
    # A real directory is already there: add one link per Ratchet skill beside what it holds.
    for d in "$from"/skills/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      link "../../.agents/skills/$name" ".claude/skills/$name"
    done
  else
    link "../.agents/skills" ".claude/skills"
  fi
fi

printf '\n%s added, %s skipped\n' "$added" "$skipped"
if [ "$claude" -eq 1 ]; then
  printf 'NEXT  merge the "hooks" block of %s into .claude/settings.json, fill CHECKS in .claude/hooks/check-on-stop.sh, then run .claude/hooks/test-hooks.sh\n' "$from/claude-code-hooks-settings.json"
fi
exit 0
