#!/usr/bin/env bash
# Tests for upgrade.sh. Run from a Ratchet checkout:
#   drop-in/skills/ratchet-upgrade/scripts/test-upgrade.sh
#
# The script's promises: report mode writes nothing in the repo; a filled slot survives
# a merge; live memory is never touched; a conflict is shown and refused, never guessed;
# a second run changes nothing. Each case below sets up an old release, installs it,
# fills slots the way an owner would, and upgrades to the current drop-in.

set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
upgrade="$here/upgrade.sh"
dropin="$(cd "$here/../../.." && pwd -P)"
install="$dropin/skills/ratchet-init/scripts/install.sh"

pass=0; fail=0
sandbox="$(mktemp -d "${TMPDIR:-/tmp}/test-upgrade.XXXXXX")"; sandbox="$(cd "$sandbox" && pwd -P)"
trap 'rm -rf "$sandbox"' EXIT
export TMPDIR="$sandbox"   # staging directories land here and go with the sandbox

[ -f "$dropin/AGENTS.md" ] && [ -x "$install" ] || { echo "SKIP: run this from a Ratchet checkout"; exit 0; }

ok() { pass=$((pass + 1)); }
no() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }
snapshot() {
  (cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -print | sort | while IFS= read -r f; do
    if [ -L "$f" ]; then printf 'L %s -> %s\n' "$f" "$(readlink "$f")"
    else x=-; [ -x "$f" ] && x=x; printf 'F %s %s %s\n' "$f" "$x" "$(cksum <"$f")"; fi
  done)
}
new_repo() { repo="$sandbox/repo.$((pass + fail))"; mkdir -p "$repo" && git -C "$repo" init -q . ; }
status_of() { printf '%s\n' "$1" | awk -v p="$2" '$2 == p { print $1; exit }'; }
stage_of() { printf '%s\n' "$1" | sed -n 's/^STAGE //p'; }
# replace <file> <sed expression> — in-place edit without GNU-only flags
replace() { local t; t="$(mktemp)"; sed "$2" "$1" > "$t" && cat "$t" > "$1"; rm -f "$t"; }

new_version="$(sed -n 's/.*ratchet-version: *\([0-9][0-9.]*\).*/\1/p' "$dropin/AGENTS.md" | head -n 1)"
[ -n "$new_version" ] && ok || no "the drop-in's AGENTS.md carries no ratchet-version marker"

# An "old release": the current drop-in with the markers stripped (releases before 1.2
# had none), the enforcement table removed from AGENTS.md, one hook comment reworded,
# the ratchet-pickup skill absent, and plugin.json at 1.1.0.
old="$sandbox/old"; cp -R "$dropin" "$old"
for f in AGENTS.md CLAUDE.md CODEX.md hooks/check-on-stop.sh hooks/guard-destructive.sh hooks/lint-edited-file.sh hooks/lib-payload.sh; do
  replace "$old/$f" '/ratchet-version:/d'
done
t="$(mktemp)"; awk '/^## What enforces these rules/{skip=1} /^## Delegation and model tiers/{skip=0} !skip' "$old/AGENTS.md" > "$t" && cat "$t" > "$old/AGENTS.md"; rm -f "$t"
replace "$old/AGENTS.md" 's/^Require explicit human approval before:$/Require explicit human approval before doing any of:/'
replace "$old/hooks/check-on-stop.sh" 's/^MAX_BLOCKS=3$/MAX_BLOCKS=3  # consecutive blocks per session/'
rm -rf "$old/skills/ratchet-pickup"
replace "$old/.claude-plugin/plugin.json" "s/\"version\": \"$new_version\"/\"version\": \"1.1.0\"/"
grep -q '## What enforces' "$old/AGENTS.md" && no "old release still has the enforcement table" || ok

# install_old_and_fill — a repo set up from the old release, with slots filled.
install_old_and_fill() {
  "$install" --from "$old" --to "$repo" --claude >/dev/null 2>&1 || no "install of the old release failed"
  replace "$repo/AGENTS.md" 's/^- Run everything: `make check` <!-- FILL-ME -->$/- Run everything: `npm test`/'
  replace "$repo/.claude/hooks/check-on-stop.sh" 's/^CHECKS=.*/CHECKS=("make verify")/'
  printf '# Ratchet Project State\n\n## Objective\nShip the widget\n\n## Last handoff\n- Updated: 2026-10-27\n' > "$repo/.ratchet/STATE.md"
  grep -q 'npm test' "$repo/AGENTS.md" && grep -q 'make verify' "$repo/.claude/hooks/check-on-stop.sh" || no "slot filling did not take"
}

echo "== report mode classifies every file and writes nothing in the repo =="
new_repo; install_old_and_fill
before="$(snapshot "$repo")"
out="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" 2>&1)"; code=$?
[ "$code" -eq 0 ] && ok || no "report exited $code: $out"
[ "$(snapshot "$repo")" = "$before" ] && ok || no "report mode changed the repo"
[ "$(status_of "$out" AGENTS.md)" = MERGE ] && ok || no "AGENTS.md should be MERGE, got: $(status_of "$out" AGENTS.md)"
[ "$(status_of "$out" .claude/hooks/check-on-stop.sh)" = MERGE ] && ok || no "check-on-stop.sh should be MERGE"
[ "$(status_of "$out" .ratchet/STATE.md)" = MEMORY ] && ok || no "STATE.md should be MEMORY"
[ "$(status_of "$out" .ratchet/DECISIONS.md)" = MEMORY ] && ok || no "DECISIONS.md should be MEMORY"
[ "$(status_of "$out" .agents/skills/ratchet-pickup/SKILL.md)" = NEW ] && ok || no "a skill new in the release should be NEW"
[ "$(status_of "$out" .agents/skills/ratchet-done/SKILL.md)" = SAME ] && ok || no "an unchanged skill should be SAME"
[ "$(status_of "$out" CODEX.md)" = ABSENT ] && ok || no "an adapter never installed should be ABSENT"
printf '%s' "$out" | grep -q "^INFO  base: $old" && ok || no "the report should name the base it used"
stage="$(stage_of "$out")"
[ -d "$stage" ] && ok || no "no staging directory was named"
grep -q 'npm test' "$stage/AGENTS.md" && ok || no "the AGENTS.md proposal lost the filled check command"
grep -q '^## What enforces these rules' "$stage/AGENTS.md" && ok || no "the AGENTS.md proposal lacks the new section"
grep -q "ratchet-version: $new_version" "$stage/AGENTS.md" && ok || no "the AGENTS.md proposal lacks the new marker"
grep -q 'CHECKS=("make verify")' "$stage/.claude/hooks/check-on-stop.sh" && ok || no "the hook proposal lost the filled CHECKS line"
grep -q 'FILL-ME' "$stage/.claude/hooks/check-on-stop.sh" && ok || no "the hook proposal lost the template's own FILL-ME comment (base mismatch?)"

echo "== apply writes only what was asked, keeps slots, never touches memory =="
state_before="$(cksum < "$repo/.ratchet/STATE.md")"
out="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" --apply AGENTS.md --apply .claude/hooks/check-on-stop.sh --apply .agents/skills/ratchet-pickup/SKILL.md 2>&1)"; code=$?
[ "$code" -eq 0 ] && ok || no "apply exited $code: $out"
printf '%s' "$out" | grep -q '^UPGRADED  AGENTS.md' && printf '%s' "$out" | grep -q '^ADDED     .agents/skills/ratchet-pickup/SKILL.md' && ok || no "apply did not report what it wrote"
grep -q 'npm test' "$repo/AGENTS.md" && grep -q '^## What enforces these rules' "$repo/AGENTS.md" && grep -q "ratchet-version: $new_version" "$repo/AGENTS.md" && ok || no "upgraded AGENTS.md lost a slot, a section, or the marker"
grep -q 'CHECKS=("make verify")' "$repo/.claude/hooks/check-on-stop.sh" && [ -x "$repo/.claude/hooks/check-on-stop.sh" ] && ok || no "upgraded hook lost CHECKS or its executable bit"
[ -f "$repo/.agents/skills/ratchet-pickup/SKILL.md" ] && ok || no "new skill was not added"
[ "$(cksum < "$repo/.ratchet/STATE.md")" = "$state_before" ] && ok || no "STATE.md changed during apply"
[ ! -f "$repo/.agents/skills/ratchet-pickup/SKILL.md" ] || grep -q 'ratchet-version' "$repo/CLAUDE.md" && no "CLAUDE.md was written although it was not in the apply list" || ok
[ -z "$(find "$repo" -name '.ratchet-upgrade.*' -print)" ] && ok || no "a temp file was left beside a destination"

echo "== the installed hook still passes its own suite after the upgrade =="
(cd "$repo" && .claude/hooks/test-hooks.sh >/dev/null 2>&1); hooks_rc=$?
# The hooks suite has two known failures when run as root (see the PR body for 1.1);
# accept either a clean pass or exactly that baseline.
if [ "$hooks_rc" -eq 0 ]; then ok
else
  n="$(cd "$repo" && .claude/hooks/test-hooks.sh 2>&1 | grep -c '^FAIL')"
  base_n="$(cd "$dropin/hooks" && ./test-hooks.sh 2>&1 | grep -c '^FAIL')"
  [ "$n" -eq "$base_n" ] && ok || no "upgraded hooks suite has $n failures; the drop-in's own suite has $base_n"
fi

echo "== a second run finds nothing to do and changes nothing =="
out="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" --apply-all 2>&1)"; code=$?
before="$(snapshot "$repo")"
out2="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" --apply-all 2>&1)"; code2=$?
[ "$code2" -eq 0 ] && [ "$(snapshot "$repo")" = "$before" ] && ok || no "second apply-all changed the repo or exited $code2"
printf '%s' "$out2" | grep -Eq '^(MERGE|NEW|CONFLICT|NOBASE)' && no "second run still proposes changes: $(printf '%s' "$out2" | grep -E '^(MERGE|NEW|CONFLICT|NOBASE)')" || ok
grep -q "ratchet-version: $new_version" "$repo/CLAUDE.md" && ok || no "apply-all did not bring CLAUDE.md to the new marker"
out3="$("$upgrade" --from "$dropin" --to "$repo" 2>&1)"
printf '%s' "$out3" | grep -q "^TO    $repo (ratchet-version $new_version)" && ok || no "after the upgrade the installed version should read from the marker without --installed-version"

echo "== a line both sides changed is a conflict: shown, staged with markers, refused =="
new_repo; install_old_and_fill
replace "$repo/AGENTS.md" 's/^Require explicit human approval before doing any of:$/Require explicit approval before doing any of:/'
out="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" 2>&1)"
[ "$(status_of "$out" AGENTS.md)" = CONFLICT ] && ok || no "both-sides edit should be CONFLICT, got: $(status_of "$out" AGENTS.md)"
stage="$(stage_of "$out")"
grep -q '^<<<<<<<' "$stage/AGENTS.md" && grep -q '^>>>>>>>' "$stage/AGENTS.md" && ok || no "staged conflict proposal lacks markers"
before="$(cksum < "$repo/AGENTS.md")"
out="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" --apply AGENTS.md 2>&1)"; code=$?
[ "$code" -eq 1 ] && printf '%s' "$out" | grep -q '^REFUSE    AGENTS.md (CONFLICT)' && ok || no "applying a conflict should be refused with exit 1 (got $code)"
[ "$(cksum < "$repo/AGENTS.md")" = "$before" ] && ok || no "a refused apply still wrote the file"

echo "== no base means no merge: diff only, apply refused =="
new_repo; install_old_and_fill
out="$("$upgrade" --from "$dropin" --to "$repo" 2>&1)"; code=$?
[ "$code" -eq 0 ] && [ "$(status_of "$out" AGENTS.md)" = NOBASE ] && ok || no "without a base and a version AGENTS.md should be NOBASE (exit $code): $(status_of "$out" AGENTS.md)"
printf '%s' "$out" | grep -q '^INFO  base: installed version unknown' && ok || no "the report should say why there is no base"
before="$(cksum < "$repo/AGENTS.md")"
"$upgrade" --from "$dropin" --to "$repo" --apply AGENTS.md >/dev/null 2>&1; [ $? -eq 1 ] && [ "$(cksum < "$repo/AGENTS.md")" = "$before" ] && ok || no "NOBASE apply should be refused and write nothing"

echo "== the base is found in the source checkout's history by installed version =="
src="$sandbox/src"; mkdir -p "$src" && git -C "$src" init -q . && git -C "$src" config user.email t@t && git -C "$src" config user.name t
cp -R "$old" "$src/drop-in" && git -C "$src" add -A && git -C "$src" commit -q -m "release 1.1.0"
rm -rf "$src/drop-in" && cp -R "$dropin" "$src/drop-in" && git -C "$src" add -A && git -C "$src" commit -q -m "release $new_version"
new_repo; install_old_and_fill
out="$("$upgrade" --from "$src/drop-in" --to "$repo" --installed-version 1.1.0 2>&1)"; code=$?
[ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^INFO  base: 1.1.0 from ' && ok || no "history lookup did not find the 1.1.0 base: $(printf '%s' "$out" | grep '^INFO')"
[ "$(status_of "$out" AGENTS.md)" = MERGE ] && ok || no "with a history base AGENTS.md should be MERGE, got: $(status_of "$out" AGENTS.md)"
out="$("$upgrade" --from "$src/drop-in" --to "$repo" --installed-version 9.9.9 2>&1)"
printf '%s' "$out" | grep -q '^INFO  base: no commit in ' && [ "$(status_of "$out" AGENTS.md)" = NOBASE ] && ok || no "an unknown version should report no base and fall back to NOBASE"

echo "== a symlinked destination is never written through =="
new_repo; install_old_and_fill
echo precious > "$sandbox/outside.md"; rm "$repo/AGENTS.md"; ln -s "$sandbox/outside.md" "$repo/AGENTS.md"
out="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" --installed-version 1.1.0 --apply AGENTS.md 2>&1)"; code=$?
[ "$code" -eq 1 ] && [ "$(status_of "$out" AGENTS.md)" = SKIP ] && [ "$(cat "$sandbox/outside.md")" = precious ] && [ -L "$repo/AGENTS.md" ] && ok || no "wrote through a symlinked AGENTS.md (exit $code)"
mkdir -p "$sandbox/shared-hooks"; rm -rf "$repo/.claude/hooks"; ln -s "$sandbox/shared-hooks" "$repo/.claude/hooks"
out="$("$upgrade" --from "$dropin" --to "$repo" --base "$old" --installed-version 1.1.0 --apply-all 2>&1)"
[ -z "$(ls -A "$sandbox/shared-hooks")" ] && [ "$(status_of "$out" .claude/hooks/check-on-stop.sh)" = SKIP ] && ok || no "wrote through a symlinked hooks directory"

echo "== setup errors exit 2 =="
new_repo
"$upgrade" --to "$repo" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "missing --from should be a usage error"
"$upgrade" --from "$sandbox" --to "$repo" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "a source without AGENTS.md should be refused"
mkdir -p "$repo/sub"
"$upgrade" --from "$dropin" --to "$repo/sub" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "a subdirectory target should be refused"
"$upgrade" --from "$dropin" --to "$repo" --base "$sandbox" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "a base without AGENTS.md should be refused"

echo "== a real 1.0.0 install from this checkout's history upgrades with its slots intact =="
ratchet_top="$(git -C "$dropin" rev-parse --show-toplevel 2>/dev/null)"
old_commit=""
if [ -n "$ratchet_top" ]; then
  while IFS= read -r c; do
    git -C "$ratchet_top" show "$c:drop-in/.claude-plugin/plugin.json" 2>/dev/null | grep -q '"version": *"1.0.0"' && { old_commit="$c"; break; }
  done <<LIST
$(git -C "$ratchet_top" rev-list HEAD -- drop-in/.claude-plugin/plugin.json 2>/dev/null)
LIST
fi
if [ -n "$old_commit" ]; then
  mkdir -p "$sandbox/v100" && git -C "$ratchet_top" archive "$old_commit" drop-in | tar -x -C "$sandbox/v100"
  new_repo
  "$install" --from "$sandbox/v100/drop-in" --to "$repo" --claude >/dev/null 2>&1 || no "install from the 1.0.0 release failed"
  replace "$repo/AGENTS.md" 's/^- Run everything: `make check` <!-- FILL-ME -->$/- Run everything: `npm test`/'
  replace "$repo/.claude/hooks/check-on-stop.sh" 's/^CHECKS=.*/CHECKS=("make verify")/'
  out="$("$upgrade" --from "$dropin" --to "$repo" --installed-version 1.0.0 2>&1)"; code=$?
  [ "$code" -eq 0 ] && printf '%s' "$out" | grep -q '^INFO  base: 1.0.0 from ' && ok || no "history lookup did not find the 1.0.0 base: $(printf '%s' "$out" | grep '^INFO')"
  [ "$(status_of "$out" AGENTS.md)" = MERGE ] && ok || no "1.0.0 AGENTS.md with a filled slot should merge cleanly, got: $(status_of "$out" AGENTS.md)"
  [ "$(status_of "$out" .claude/hooks/check-on-stop.sh)" = MERGE ] && ok || no "1.0.0 stop hook with a filled CHECKS line should merge cleanly, got: $(status_of "$out" .claude/hooks/check-on-stop.sh)"
  stage="$(stage_of "$out")"
  grep -q 'npm test' "$stage/AGENTS.md" && grep -q 'CHECKS=("make verify")' "$stage/.claude/hooks/check-on-stop.sh" && ok || no "a 1.0.0 upgrade proposal lost a filled slot"
  grep -q '^## What enforces these rules' "$stage/AGENTS.md" && grep -q 'INCONCLUSIVE' "$stage/AGENTS.md" && ok || no "a 1.0.0 upgrade proposal lacks the 1.1 contract additions"
else
  echo "SKIP: no 1.0.0 release in this checkout's history; the real-history case was not run"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
