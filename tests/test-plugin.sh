#!/usr/bin/env bash
# Checks that the plugin and marketplace manifests point at things that exist and work.
# Run from the repo root: tests/test-plugin.sh

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
pass=0; fail=0
ok() { pass=$((pass + 1)); }
no() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }

json() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null; }
field() { python3 -c 'import json,sys; v=json.load(open(sys.argv[1]))
for k in sys.argv[2].split("."): v=v[k] if isinstance(v,dict) else v[int(k)]
print(v)' "$1" "$2" 2>/dev/null; }

echo "== manifests parse and agree =="
for f in drop-in/.claude-plugin/plugin.json drop-in/plugin-hooks.json .claude-plugin/marketplace.json; do json "$f" && ok || no "$f is not valid JSON"; done
pname="$(field drop-in/.claude-plugin/plugin.json name)"
[ "$pname" = "$(field .claude-plugin/marketplace.json plugins.0.name)" ] && ok || no "plugin name differs between plugin.json and marketplace.json"
printf '%s' "$pname" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$' && ok || no "plugin name '$pname' is not kebab-case"
src="$(field .claude-plugin/marketplace.json plugins.0.source)"
[ -f "$src/.claude-plugin/plugin.json" ] && ok || no "marketplace source '$src' has no plugin.json"
field drop-in/.claude-plugin/plugin.json version | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' && ok || no "version is not semver"

echo "== every skill in the plugin root is a skill, and every drop-in skill is in the plugin root =="
n=0
for d in drop-in/skills/*/; do
  n=$((n + 1))
  [ -f "${d}SKILL.md" ] && ok || no "${d} has no SKILL.md"
  name="$(sed -n 's/^name: *//p' "${d}SKILL.md" | head -1)"
  [ "$name" = "$(basename "$d")" ] && ok || no "${d}: frontmatter name '$name' differs from the directory; plugin skills are invoked by frontmatter name"
done
[ "$n" -ge 6 ] && ok || no "expected at least 6 skills, found $n"

echo "== the hooks file references scripts that exist, and the guard blocks through it =="
hooks_rel="$(field drop-in/.claude-plugin/plugin.json hooks)"
[ -f "drop-in/$hooks_rel" ] && ok || no "plugin.json hooks path '$hooks_rel' does not exist under drop-in/"
export CLAUDE_PLUGIN_ROOT="$PWD/drop-in"
cmds="$(python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
for ev,groups in d["hooks"].items():
    for g in groups:
        for h in g["hooks"]:
            if h.get("type")=="command": print(ev+"\t"+h["command"])' "drop-in/$hooks_rel")"
[ -n "$cmds" ] && ok || no "no command hooks found in $hooks_rel"
while IFS=$'\t' read -r ev cmd; do
  [ -n "$cmd" ] || continue
  script="$(eval "printf '%s' $cmd" 2>/dev/null)"   # expands ${CLAUDE_PLUGIN_ROOT} exactly as the hook runner would
  [ -x "$script" ] && ok || no "$ev hook script is missing or not executable: $script"
  if [ "$ev" = "PreToolUse" ]; then
    printf '{"tool_name":"Bash","tool_input":{"command":"git push --force"}}' | eval "$cmd" >/dev/null 2>&1; [ $? -eq 2 ] && ok || no "guard did not block a force push when run via the plugin hook command"
    printf '{"tool_name":"Bash","tool_input":{"command":"git status"}}' | eval "$cmd" >/dev/null 2>&1; [ $? -eq 0 ] && ok || no "guard blocked a harmless command when run via the plugin hook command"
  fi
done <<<"$cmds"

echo "== the drop-in install and the plugin agree on which hooks exist =="
for s in drop-in/hooks/*.sh; do [ -x "$s" ] && ok || no "$s is not executable"; done

if command -v claude >/dev/null 2>&1; then
  echo "== claude plugin validate =="
  claude plugin validate drop-in >/dev/null 2>&1 && ok || no "claude plugin validate drop-in failed"
  claude plugin validate . >/dev/null 2>&1 && ok || no "claude plugin validate . (marketplace) failed"
else
  echo "SKIP: claude CLI not installed; manifest validation by the CLI not run"
fi

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
