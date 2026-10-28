#!/usr/bin/env bash
# ratchet-version: 1.2.0
# Upgrade Ratchet's per-repo drop-ins to a newer release without losing the owner's edits.
#
#   upgrade.sh --from <ratchet>/drop-in --to <repo root> [--base <drop-in at the installed version>]
#              [--installed-version X.Y.Z] [--apply <path> ...] [--apply-all]
#
# The installer never overwrites, so a repo set up from an older release keeps the old
# contract, adapters, and hooks forever. This script closes that gap in two modes.
#
# Report mode (default) writes nothing inside the repo. For every file the installer
# would have placed it prints one line:
#   SAME      installed copy is identical to the new release
#   MERGE     the owner's edits replay cleanly onto the new release (proposal staged)
#   CONFLICT  the owner and the release changed the same lines (proposal with markers)
#   NOBASE    changed, but no base to merge against; diff only (pass --base)
#   MEMORY    .ratchet/STATE.md or DECISIONS.md: live project memory, never written
#   NEW       in the release, not in the repo, inside an installed tree (apply copies it)
#   ABSENT    not installed at all; install.sh is the tool for that, not this one
#   SKIP      the destination is a symlink or sits under one; never written through
# Proposals go to a staging directory named on the STAGE line, mirroring repo paths.
#
# Apply mode (--apply <path>..., or --apply-all) writes only MERGE and NEW results, by
# recomputing them; CONFLICT, NOBASE, MEMORY, SKIP and ABSENT are refused with exit 1.
# The owner's yes, per file, is the skill's job and happens before --apply.
#
# The merge is a three-way merge (git merge-file): base = the template as it was in the
# release the repo was installed from, ours = the installed copy with the owner's edits,
# theirs = the new template. A slot the owner filled and the release left alone keeps the
# owner's value; a line both changed is a conflict, shown, never guessed. The base comes
# from --base, or from the Ratchet checkout's own history: the newest commit whose
# plugin.json carries the installed version, read from the installed file's
# "ratchet-version" marker or --installed-version. Installs older than the markers
# (1.0.0 and 1.1.0) need --installed-version once; after that the marker travels.
#
# Exit: 0 = report written or every requested apply done, 1 = an apply was refused,
# 2 = usage or setup error.

set -uo pipefail

from=""; to=""; base=""; installed_version=""; apply_all=0
apply=()

usage() {
  sed -n '3,5p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

while [ $# -gt 0 ]; do
  case "$1" in
    --from) [ $# -ge 2 ] || usage; from="$2"; shift 2 ;;
    --to) [ $# -ge 2 ] || usage; to="$2"; shift 2 ;;
    --base) [ $# -ge 2 ] || usage; base="$2"; shift 2 ;;
    --installed-version) [ $# -ge 2 ] || usage; installed_version="$2"; shift 2 ;;
    --apply) [ $# -ge 2 ] || usage; apply+=("$2"); shift 2 ;;
    --apply-all) apply_all=1; shift ;;
    *) usage ;;
  esac
done

die() { printf 'upgrade: %s\n' "$1" >&2; exit 2; }

[ -n "$from" ] && [ -n "$to" ] || usage
[ -f "$from/AGENTS.md" ] || die "$from does not look like Ratchet's drop-in directory (no AGENTS.md)"
[ -d "$to" ] || die "$to is not a directory"
git -C "$to" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$to is not inside a git work tree"
command -v git >/dev/null 2>&1 || die "git is required (for merge-file)"

from="$(cd "$from" && pwd -P)"
to="$(cd "$to" && pwd -P)"
[ "$from" = "$to" ] && die "source and destination are the same directory"
root="$(cd "$(git -C "$to" rev-parse --show-toplevel)" && pwd -P)" || die "could not resolve the repo root"
[ "$to" = "$root" ] || die "$to is a subdirectory; --to must be the repo root ($root)"
if [ -n "$base" ]; then
  [ -f "$base/AGENTS.md" ] || die "$base does not look like a Ratchet drop-in directory (no AGENTS.md)"
  base="$(cd "$base" && pwd -P)"
fi

# marker <file> — the ratchet-version a file carries, or nothing.
marker() { sed -n 's/.*ratchet-version: *\([0-9][0-9.]*\).*/\1/p' "$1" 2>/dev/null | head -n 1; }

new_version="$(marker "$from/AGENTS.md")"
[ -n "$new_version" ] || die "$from/AGENTS.md carries no ratchet-version marker; is the source older than this script?"

if [ -z "$installed_version" ] && [ -f "$to/AGENTS.md" ] && [ ! -L "$to/AGENTS.md" ]; then
  installed_version="$(marker "$to/AGENTS.md")"
fi

# Resolve the base from the source checkout's history when none was given: the newest
# commit whose plugin.json carries the installed version is the last state of that
# release, which is what a repo installed at the end of it holds. A repo installed
# mid-release merges against a slightly wrong base and shows that as conflicts rather
# than guessing; --base pins the exact one when known.
stage="$(mktemp -d "${TMPDIR:-/tmp}/ratchet-upgrade.XXXXXX")" || die "could not create a staging directory"
# The staging directory outlives the script only in report mode, where it is the
# product: the proposals a human reads before saying yes. In apply mode, and on any
# error or interruption, it goes with the process.
keep_stage=0
trap '[ "$keep_stage" -eq 1 ] || rm -rf "$stage"' EXIT
base_note=""
if [ -z "$base" ] && [ -n "$installed_version" ]; then
  if src_top="$(git -C "$from" rev-parse --show-toplevel 2>/dev/null)"; then
    src_top="$(cd "$src_top" && pwd -P)"
    prefix="${from#"$src_top"/}"
    [ "$prefix" = "$from" ] && prefix=""
    manifest="${prefix:+$prefix/}.claude-plugin/plugin.json"
    found=""
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      if git -C "$src_top" show "$c:$manifest" 2>/dev/null | grep -q "\"version\": *\"$installed_version\""; then
        found="$c"; break
      fi
    done <<LIST
$(git -C "$src_top" rev-list HEAD -- "$manifest" 2>/dev/null)
LIST
    if [ -n "$found" ]; then
      mkdir -p "$stage/.base"
      if git -C "$src_top" archive "$found" ${prefix:+"$prefix"} | tar -x -C "$stage/.base" 2>/dev/null; then
        base="$stage/.base${prefix:+/$prefix}"
        base_note="base: $installed_version from $(git -C "$src_top" rev-parse --short "$found") in $src_top"
      fi
    fi
    [ -n "$base" ] || base_note="base: no commit in $src_top has plugin.json at $installed_version; pass --base"
  else
    base_note="base: $from is not inside a git checkout, so history cannot supply one; pass --base"
  fi
elif [ -z "$base" ]; then
  base_note="base: installed version unknown (no ratchet-version marker in $to/AGENTS.md); pass --installed-version or --base"
else
  base_note="base: $base"
fi

printf 'FROM  %s (ratchet-version %s)\n' "$from" "$new_version"
printf 'TO    %s (ratchet-version %s)\n' "$to" "${installed_version:-unknown}"
printf 'INFO  %s\n' "$base_note"
if [ "$apply_all" -eq 1 ] || [ "${#apply[@]}" -gt 0 ]; then
  printf 'STAGE %s (removed on exit)\n' "$stage"
else
  printf 'STAGE %s (kept for inspection; remove it when done)\n' "$stage"
fi

# linked_parent <destination relative to $to> — any directory on the way is a symlink.
linked_parent() {
  local dir rest="$1" walked="$to"
  while [ "$rest" != "${rest#*/}" ]; do
    dir="${rest%%/*}"; rest="${rest#*/}"; walked="$walked/$dir"
    [ -L "$walked" ] && return 0
  done
  return 1
}

wants() {   # wants <rel> — is this path in the apply set?
  local p
  [ "$apply_all" -eq 1 ] && return 0
  for p in "${apply[@]+"${apply[@]}"}"; do [ "$p" = "$1" ] && return 0; done
  return 1
}

refused=0
applied=0
requested=0

# write_file <source> <destination relative to $to> — the one place anything is written.
# A temp file beside the destination, then one rename: a reader never sees a half-written
# file, and rename does not follow a symlink that appeared at the destination meanwhile.
write_file() {
  local src="$1" rel="$2" dest="$to/$2" tmp
  mkdir -p "$(dirname "$dest")" || { printf 'REFUSE %s (cannot create its directory)\n' "$rel"; refused=$((refused + 1)); return 1; }
  tmp="$(mktemp "$(dirname "$dest")/.ratchet-upgrade.XXXXXX")" || { printf 'REFUSE %s (cannot stage a write)\n' "$rel"; refused=$((refused + 1)); return 1; }
  cp "$src" "$tmp" || { rm -f "$tmp"; printf 'REFUSE %s (copy failed)\n' "$rel"; refused=$((refused + 1)); return 1; }
  if [ -e "$dest" ]; then [ -x "$dest" ] && chmod +x "$tmp"; else [ -x "$src" ] && chmod +x "$tmp"; fi
  mv -f "$tmp" "$dest" || { rm -f "$tmp"; printf 'REFUSE %s (move failed)\n' "$rel"; refused=$((refused + 1)); return 1; }
  return 0
}

# consider <source file> <destination relative to $to> <kind: core|memory|tree> [<installed tree root>]
consider() {
  local src="$1" rel="$2" kind="$3" treeroot="${4:-}" dest="$to/$2" status proposal n
  if [ -L "$dest" ] || linked_parent "$rel"; then
    status="SKIP"; printf 'SKIP      %s (symlink)\n' "$rel"
  elif [ ! -e "$dest" ]; then
    if [ "$kind" = "tree" ] && [ -n "$treeroot" ] && [ -d "$to/$treeroot" ] && [ ! -L "$to/$treeroot" ]; then
      status="NEW"; printf 'NEW       %s\n' "$rel"
    else
      status="ABSENT"; printf 'ABSENT    %s (not installed; install.sh adds it)\n' "$rel"
    fi
  elif [ "$kind" = "memory" ]; then
    status="MEMORY"; printf 'MEMORY    %s (live project memory, never written)\n' "$rel"
  elif cmp -s "$src" "$dest"; then
    status="SAME"; printf 'SAME      %s\n' "$rel"
  elif [ -n "$base" ] && [ -f "$base/${src#"$from"/}" ]; then
    proposal="$stage/$rel"; mkdir -p "$(dirname "$proposal")"
    git merge-file -p -L "installed" -L "ratchet ${installed_version:-base}" -L "ratchet $new_version" \
      "$dest" "$base/${src#"$from"/}" "$src" > "$proposal" 2>/dev/null
    n=$?
    if [ "$n" -eq 0 ] && cmp -s "$proposal" "$dest"; then
      status="CURRENT"; printf 'CURRENT   %s (installed edits are already on this release)\n' "$rel"
    elif [ "$n" -eq 0 ]; then
      status="MERGE"; printf 'MERGE     %s (%s hunks; proposal staged)\n' "$rel" "$(diff -u "$dest" "$proposal" | grep -c '^@@')"
    elif [ "$n" -ge 255 ]; then
      status="NOBASE"; printf 'NOBASE    %s (merge-file failed; diff only)\n' "$rel"
    else
      status="CONFLICT"; printf 'CONFLICT  %s (%s conflicts; resolve by hand from the staged proposal)\n' "$rel" "$n"
    fi
  else
    status="NOBASE"; printf 'NOBASE    %s (%s changed lines; no base to merge against)\n' "$rel" "$(diff "$dest" "$src" | grep -c '^[<>]')"
  fi

  # --apply-all takes what can be applied and passes over the rest in silence; a path
  # named with --apply is a request, and a request that cannot be met is a refusal.
  if [ "$apply_all" -eq 1 ]; then
    case "$status" in MERGE|NEW) ;; *) return 0 ;; esac
  else
    wants "$rel" || return 0
  fi
  requested=$((requested + 1))
  case "$status" in
    MERGE)        write_file "$proposal" "$rel" && { printf 'UPGRADED  %s\n' "$rel"; applied=$((applied + 1)); } ;;
    NEW)          write_file "$src" "$rel" && { printf 'ADDED     %s\n' "$rel"; applied=$((applied + 1)); } ;;
    SAME|CURRENT) ;;
    *)            printf 'REFUSE    %s (%s)\n' "$rel" "$status"; refused=$((refused + 1)) ;;
  esac
}

consider "$from/AGENTS.md" "AGENTS.md" core
consider "$from/CLAUDE.md" "CLAUDE.md" core
consider "$from/CODEX.md" "CODEX.md" core
consider "$from/STATE.md" ".ratchet/STATE.md" memory
consider "$from/DECISIONS.md" ".ratchet/DECISIONS.md" memory
for dir in hooks:.claude/hooks skills:.agents/skills; do
  srcdir="$from/${dir%%:*}"; destdir="${dir#*:}"
  [ -d "$srcdir" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    consider "$f" "$destdir/${f#"$srcdir"/}" tree "$destdir"
  done <<LIST
$(find "$srcdir" -type f | sort)
LIST
done

if [ "$apply_all" -eq 1 ] || [ "${#apply[@]}" -gt 0 ]; then
  printf '\n%s applied, %s refused\n' "$applied" "$refused"
  [ "$refused" -eq 0 ] || exit 1
  exit 0
fi
keep_stage=1
exit 0
