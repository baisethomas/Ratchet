# CLAUDE.md — Claude Code Adapter

<!--
DROP-IN: place this file at the repo root alongside AGENTS.md.
Claude Code loads this automatically. Ratchet's canonical operating contract lives in AGENTS.md.
Keep this file Claude-specific so universal rules do not drift across tool adapters.
-->

## Canonical contract

Read and follow `AGENTS.md` before doing any repository work. If this file conflicts with `AGENTS.md`, `AGENTS.md` wins unless the human explicitly says otherwise.

## Claude Code specifics

- Use plan mode for nontrivial work when available.
- Respect configured Claude Code hooks and stop-hook failures. Do not bypass or disable them to manufacture a green result.
- Load `.ratchet/STATE.md` and `.ratchet/DECISIONS.md` as required by `AGENTS.md` before planning.
- When a hook, permission boundary, or environment limitation prevents verification, report the exact blocked check instead of inferring success.
- Do not add universal workflow rules here. Put model-agnostic operating rules in `AGENTS.md` so Codex, Cursor, Claude, and future agents share one contract.

## Claude-specific project notes

<!-- FILL-ME only when this repository has Claude Code-specific behavior, tooling, or limitations. -->
- FILL-ME or delete this section if none.
