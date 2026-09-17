#!/usr/bin/env bash
# Regression tests for install.sh. Run: .agents/skills/ratchet-init/scripts/test-install.sh
#
# The installer's one promise is that it never damages what is already in the repo,
# so most cases here pre-populate a destination and assert it survives byte-for-byte.

set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
install="$here/install.sh"
dropin="$(cd "$here/../../.." && pwd)"   # drop-in/ when run from the Ratchet repo

pass=0
fail=0
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/test-install.XXXXXX")"
trap 'rm -rf "$sandbox"' EXIT

[ -f "$dropin/AGENTS.md" ] || { echo "SKIP: run this from a Ratchet checkout (needs drop-in/AGENTS.md as the install source)"; exit 0; }

ok() { pass=$((pass + 1)); }
no() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }
# snapshot <repo> — one line per file (POSIX cksum of its bytes, plus its executable bit)
# and per symlink (its target, not what it points at). No tool outside POSIX, and no
# silenced errors: a snapshot that cannot be taken must not compare equal to another.
snapshot() {
  (cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | sort | while IFS= read -r f; do
    if [ -L "$f" ]; then printf 'L %s -> %s\n' "$f" "$(readlink "$f")"
    else x=-; [ -x "$f" ] && x=x; printf 'F %s %s %s\n' "$f" "$x" "$(cksum <"$f")"; fi
  done)
}
new_repo() { repo="$sandbox/repo.$((pass + fail))"; mkdir -p "$repo" && git -C "$repo" init -q . ; }

echo "== fresh repo, both adapters =="
new_repo
out="$("$install" --from "$dropin" --to "$repo" --claude --codex 2>&1)"; code=$?
[ "$code" -eq 0 ] && ok || no "fresh install exited $code: $out"
for f in AGENTS.md CLAUDE.md CODEX.md .ratchet/STATE.md .ratchet/DECISIONS.md \
         .agents/skills/ratchet-done/SKILL.md .agents/skills/ratchet-bugfix/scripts/rrr.sh \
         .claude/hooks/guard-destructive.sh .claude/hooks/test-hooks.sh; do
  [ -f "$repo/$f" ] && ok || no "missing after install: $f"
done
[ -L "$repo/.claude/skills" ] && [ -f "$repo/.claude/skills/ratchet-done/SKILL.md" ] && ok || no ".claude/skills does not resolve to the installed skills"
[ -x "$repo/.agents/skills/ratchet-bugfix/scripts/rrr.sh" ] && [ -x "$repo/.claude/hooks/guard-destructive.sh" ] && ok || no "scripts lost their executable bit"
"$repo/.claude/skills/ratchet-bugfix/scripts/test-rrr.sh" >/dev/null 2>&1 && ok || no "installed rrr suite fails when run through .claude/skills"
(cd "$repo" && .claude/hooks/test-hooks.sh >/dev/null 2>&1) && ok || no "installed hooks suite fails"
[ ! -e "$repo/.claude/settings.json" ] && ok || no "installer wrote .claude/settings.json; merging is the caller's job"

echo "== second run changes nothing =="
before="$(snapshot "$repo")"
out="$("$install" --from "$dropin" --to "$repo" --claude --codex 2>&1)"
after="$(snapshot "$repo")"
[ "$(printf '%s\n' "$before" | wc -l)" -gt 10 ] && ok || no "snapshot is empty or tiny, so the idempotency check below would prove nothing"
[ "$before" = "$after" ] && ok || no "second run modified the repo"
printf '%s' "$out" | grep -q "^0 added" && ok || no "second run reported additions: $(printf '%s' "$out" | tail -2)"

echo "== without adapter flags, only the model-agnostic core =="
new_repo
"$install" --from "$dropin" --to "$repo" >/dev/null 2>&1
[ -f "$repo/AGENTS.md" ] && [ -d "$repo/.agents/skills" ] && [ ! -e "$repo/CLAUDE.md" ] && [ ! -e "$repo/CODEX.md" ] && [ ! -e "$repo/.claude" ] && ok || no "core-only install added tool-specific files"

echo "== existing files survive =="
new_repo
echo "my contract" >"$repo/AGENTS.md"
mkdir -p "$repo/.ratchet" "$repo/.claude/hooks" && echo "my state" >"$repo/.ratchet/STATE.md" && echo "my guard" >"$repo/.claude/hooks/guard-destructive.sh"
"$install" --from "$dropin" --to "$repo" --claude >/dev/null 2>&1
[ "$(cat "$repo/AGENTS.md")" = "my contract" ] && [ "$(cat "$repo/.ratchet/STATE.md")" = "my state" ] && [ "$(cat "$repo/.claude/hooks/guard-destructive.sh")" = "my guard" ] && ok || no "an existing file was overwritten"
[ -f "$repo/.ratchet/DECISIONS.md" ] && [ -f "$repo/.claude/hooks/lib-payload.sh" ] && ok || no "missing siblings were not filled in next to existing files"

echo "== an existing .claude/skills directory gains links, keeps its contents =="
new_repo
mkdir -p "$repo/.claude/skills/mine" && echo "mine" >"$repo/.claude/skills/mine/SKILL.md"
"$install" --from "$dropin" --to "$repo" --claude >/dev/null 2>&1
[ ! -L "$repo/.claude/skills" ] && [ "$(cat "$repo/.claude/skills/mine/SKILL.md")" = "mine" ] && ok || no "existing .claude/skills was replaced"
[ -L "$repo/.claude/skills/ratchet-done" ] && [ -f "$repo/.claude/skills/ratchet-done/SKILL.md" ] && ok || no "per-skill link missing or dangling"

echo "== a symlink at a destination is never written through =="
new_repo
echo precious >"$sandbox/outside.md" && ln -s "$sandbox/outside.md" "$repo/AGENTS.md"
"$install" --from "$dropin" --to "$repo" >/dev/null 2>&1
[ "$(cat "$sandbox/outside.md")" = precious ] && [ -L "$repo/AGENTS.md" ] && ok || no "wrote through a symlinked destination"
new_repo
ln -s nowhere "$repo/CLAUDE.md"
out="$("$install" --from "$dropin" --to "$repo" --claude 2>&1)"; code=$?
[ -L "$repo/CLAUDE.md" ] && [ ! -e "$repo/nowhere" ] && ok || no "wrote through a dangling symlink destination"
[ "$code" -eq 0 ] && printf '%s' "$out" | grep -q "^SKIP  CLAUDE.md" && ok || no "a dangling symlink destination should be a clean SKIP, got exit $code"
new_repo
mkdir -p "$sandbox/shared-ratchet" "$sandbox/shared-claude" && ln -s "$sandbox/shared-ratchet" "$repo/.ratchet" && ln -s "$sandbox/shared-claude" "$repo/.claude"
out="$("$install" --from "$dropin" --to "$repo" --claude 2>&1)"; code=$?
[ -z "$(ls -A "$sandbox/shared-ratchet")" ] && [ -z "$(ls -A "$sandbox/shared-claude")" ] && ok || no "wrote outside the repo through a symlinked parent directory"
[ "$code" -eq 0 ] && printf '%s' "$out" | grep -q "^SKIP  .ratchet/STATE.md (parent is a symlink)" && [ -f "$repo/AGENTS.md" ] && ok || no "a symlinked parent should be a reported SKIP while the rest installs, got exit $code"

echo "== setup errors exit 2 and write nothing =="
mkdir -p "$sandbox/plain"
"$install" --from "$dropin" --to "$sandbox/plain" >/dev/null 2>&1; [ $? -eq 2 ] && [ -z "$(ls -A "$sandbox/plain")" ] && ok || no "installed into a directory that is not a git repo"
new_repo
"$install" --from "$sandbox/plain" --to "$repo" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "accepted a source with no AGENTS.md"
"$install" --to "$repo" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "accepted a missing --from"
mkdir -p "$repo/pkg"
"$install" --from "$dropin" --to "$repo/pkg" >/dev/null 2>&1; [ $? -eq 2 ] && [ -z "$(ls -A "$repo/pkg")" ] && ok || no "installed into a subdirectory instead of the repo root"
"$install" --from "$dropin" --to "$dropin" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "accepted source == destination"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
