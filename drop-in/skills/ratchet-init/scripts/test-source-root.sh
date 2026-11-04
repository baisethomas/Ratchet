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

echo "== plugin layout: AGENTS.md sits beside skills/, three levels above SKILL.md =="
plugin="$sandbox/plugin"
mkdir -p "$plugin/skills/ratchet-init/scripts"
printf '# contract\n' > "$plugin/AGENTS.md"
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
mkdir -p "$co/drop-in/skills/ratchet-init/scripts"
mkdir -p "$co/.agents/skills/ratchet-init/scripts"
printf '# contract\n' > "$co/drop-in/AGENTS.md"
want="$co/drop-in"
got="$("$resolve" "$co/.agents/skills/ratchet-init/scripts" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then ok; else
  no "installed layout from scripts/: expected $want (exit 0), got ${got:-<empty>} (exit $code)"
fi
got="$("$resolve" "$co/.agents/skills/ratchet-init" 2>/dev/null)" && code=0 || code=$?
if [ "$code" -eq 0 ] && [ "$got" = "$want" ]; then ok; else
  no "installed layout from skill dir: expected $want (exit 0), got ${got:-<empty>} (exit $code)"
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

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
