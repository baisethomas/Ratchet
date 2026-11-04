#!/usr/bin/env bash
# Regression tests for source-root.sh. Run:
#   .agents/skills/ratchet-init/scripts/test-source-root.sh
#
# Two layouts must resolve to a real drop-in/plugin root. A tree with no
# source must fail (exit non-zero), never skip.

set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
resolve="$here/source-root.sh"

pass=0
fail=0
ok() { pass=$((pass + 1)); }
no() { fail=$((fail + 1)); printf 'FAIL: %s\n' "$1"; }

sandbox="$(mktemp -d "${TMPDIR:-/tmp}/test-source-root.XXXXXX")"
trap 'rm -rf "$sandbox"' EXIT

[ -x "$resolve" ] || { echo "FAIL: $resolve is missing or not executable"; exit 1; }

# stamp_dropin <dir> — the files that identify a Ratchet drop-in/plugin root,
# not merely AGENTS.md beside a skills/ directory.
stamp_dropin() {
  mkdir -p "$1/skills/ratchet-init/scripts" "$1/.claude-plugin"
  printf '# contract\n' > "$1/AGENTS.md"
  printf '# state\n' > "$1/STATE.md"
  printf '# decisions\n' > "$1/DECISIONS.md"
  printf '{"name": "ratchet"}\n' > "$1/.claude-plugin/plugin.json"
}

echo "== plugin layout: a Ratchet drop-in/plugin root, three levels above SKILL.md =="
plugin="$sandbox/plugin"
stamp_dropin "$plugin"
got="$("$resolve" "$plugin/skills/ratchet-init/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$plugin" ]; then ok; else
  no "plugin layout from scripts/: expected $plugin (exit 0), got ${got:-<empty>} (exit $code)"
fi
got="$("$resolve" "$plugin/skills/ratchet-init" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$plugin" ]; then ok; else
  no "plugin layout from skill dir: expected $plugin (exit 0), got ${got:-<empty>} (exit $code)"
fi

echo "== installed .agents/skills layout: four levels up is the repo; drop-in/ lives there =="
co="$sandbox/checkout"
stamp_dropin "$co/drop-in"
mkdir -p "$co/.agents/skills/ratchet-init/scripts"
want="$co/drop-in"
got="$("$resolve" "$co/.agents/skills/ratchet-init/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then ok; else
  no "installed layout from scripts/: expected $want (exit 0), got ${got:-<empty>} (exit $code)"
fi
got="$("$resolve" "$co/.agents/skills/ratchet-init" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then ok; else
  no "installed layout from skill dir: expected $want (exit 0), got ${got:-<empty>} (exit $code)"
fi

echo "== installed .claude/skills layout: same walk as .agents/skills =="
# install.sh links .claude/skills -> ../.agents/skills, or makes a real directory
# of per-skill links. Either way the walk must reach drop-in/, not stop in .claude.
mkdir -p "$co/.agents/skills/ratchet-init/scripts" "$co/.claude"
ln -s "../.agents/skills" "$co/.claude/skills"
got="$("$resolve" "$co/.claude/skills/ratchet-init/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then ok; else
  no ".claude/skills symlink from scripts/: expected $want (exit 0), got ${got:-<empty>} (exit $code)"
fi
got="$("$resolve" "$co/.claude/skills/ratchet-init" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then ok; else
  no ".claude/skills symlink from skill dir: expected $want (exit 0), got ${got:-<empty>} (exit $code)"
fi
cldir="$sandbox/claude-dir"
stamp_dropin "$cldir/drop-in"
mkdir -p "$cldir/.agents/skills/ratchet-init/scripts" "$cldir/.claude/skills"
ln -s "../../.agents/skills/ratchet-init" "$cldir/.claude/skills/ratchet-init"
got="$("$resolve" "$cldir/.claude/skills/ratchet-init/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$cldir/drop-in" ]; then ok; else
  no ".claude/skills per-skill link: expected $cldir/drop-in (exit 0), got ${got:-<empty>} (exit $code)"
fi

echo "== plugin and installed layouts from ratchet-upgrade/scripts =="
# The same resolver, started from the sibling skill, must find the same roots.
up_plugin="$sandbox/up-plugin"
stamp_dropin "$up_plugin"
mkdir -p "$up_plugin/skills/ratchet-upgrade/scripts"
got="$("$resolve" "$up_plugin/skills/ratchet-upgrade/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$up_plugin" ]; then ok; else
  no "upgrade plugin layout: expected $up_plugin (exit 0), got ${got:-<empty>} (exit $code)"
fi
up_inst="$sandbox/up-checkout"
stamp_dropin "$up_inst/drop-in"
mkdir -p "$up_inst/.agents/skills/ratchet-upgrade/scripts"
got="$("$resolve" "$up_inst/.agents/skills/ratchet-upgrade/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$up_inst/drop-in" ]; then ok; else
  no "upgrade installed layout: expected $up_inst/drop-in (exit 0), got ${got:-<empty>} (exit $code)"
fi

echo "== installed layout under an unrelated AGENTS.md+skills/ repo is not a source =="
# Ternary: walking from .agents/skills reaches the target root. AGENTS.md plus
# a top-level skills/ directory is common and is not a Ratchet drop-in.
fp="$sandbox/falsepos"
mkdir -p "$fp/skills/unrelated" "$fp/.agents/skills/ratchet-init/scripts"
printf '# some other contract\n' > "$fp/AGENTS.md"
printf '# not ratchet\n' > "$fp/skills/unrelated/README.md"
got="$("$resolve" "$fp/.agents/skills/ratchet-init/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -ne 0 ]; then ok; else
  no "unrelated AGENTS.md+skills/: expected fail, got $got (exit $code)"
fi

echo "== no source in the tree: must FAIL, not skip =="
empty="$sandbox/empty/.agents/skills/ratchet-init/scripts"
mkdir -p "$empty"
out="$("$resolve" "$empty" 2>&1)" && code=0 || code=$?
if [ "$code" -eq 0 ]; then
  no "missing source: expected non-zero exit, got 0 (skip/success). output: $out"
else
  ok
fi
printf '%s' "$out" | grep -q '^SKIP' && no "missing source: printed SKIP (a silent pass) instead of failing" || ok

echo "== test-install.sh fails instead of skipping when the source isn't found =="
# The regression Ternary flagged: an installed copy used to print SKIP and
# exit 0 when ../../.. landed in .agents. Stage that layout with no drop-in.
inst="$sandbox/nosrc/.agents/skills/ratchet-init/scripts"
mkdir -p "$inst"
cp "$here/test-install.sh" "$here/source-root.sh" "$here/install.sh" "$inst/"
chmod +x "$inst"/*
out="$("$inst/test-install.sh" 2>&1)" && code=0 || code=$?
if [ "$code" -eq 0 ]; then
  no "test-install.sh missing source: expected non-zero, got 0. output: $out"
else
  ok
fi
printf '%s' "$out" | grep -q '^SKIP' && no "test-install.sh missing source: printed SKIP (silent pass)" || ok
printf '%s' "$out" | grep -q 'FAIL' && ok || no "test-install.sh missing source: should say FAIL, got: $out"

echo "== test-upgrade.sh fails instead of skipping when the source isn't found =="
up="$sandbox/noup/.agents/skills"
mkdir -p "$up/ratchet-upgrade/scripts" "$up/ratchet-init/scripts"
upgrade_src="$(cd "$here/../../ratchet-upgrade/scripts" && pwd)"
cp "$upgrade_src/test-upgrade.sh" "$upgrade_src/upgrade.sh" "$up/ratchet-upgrade/scripts/"
cp "$here/source-root.sh" "$up/ratchet-init/scripts/"
chmod +x "$up/ratchet-upgrade/scripts/"* "$up/ratchet-init/scripts/"*
out="$("$up/ratchet-upgrade/scripts/test-upgrade.sh" 2>&1)" && code=0 || code=$?
if [ "$code" -eq 0 ]; then
  no "test-upgrade.sh missing source: expected non-zero, got 0. output: $out"
else
  ok
fi
printf '%s' "$out" | grep -q '^SKIP' && no "test-upgrade.sh missing source: printed SKIP (silent pass)" || ok

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
