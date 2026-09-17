# CODEX.md — Codex Adapter

<!--
DROP-IN: place this file at the repo root when using Codex.
AGENTS.md is the canonical model-agnostic operating contract. Do not duplicate those rules here.
Codex auto-loads AGENTS.md, not this file: keep the "Tool adapters" line in AGENTS.md so it is read.
-->

Codex loads `AGENTS.md` automatically; its tool-adapter line points here. This file is the Codex-specific adapter, not a second operating contract.

## Codex specifics

- The hooks in `.claude/settings.json` are not installed around Codex tool calls. Treat the hard stops in `AGENTS.md` as policy even when no guard intercepts a command, and run the required checks explicitly rather than assuming a stop hook ran them.
- Codex task context and any harness-managed memory are not model-agnostic project memory. Durable, shareable state belongs in `.ratchet/` under the rules in `AGENTS.md`; sensitive private pointers do not.
- Use the repo skills in `.claude/skills/` when their workflow matches the task. The directory name is historical, not an instruction to ignore them outside Claude Code.
- Treat any conflict between this file and `AGENTS.md` as a configuration error. `AGENTS.md` wins; report the conflict.

## Model routing

Tiers, what each owns, and the routing rules are defined in `AGENTS.md` → Delegation and model tiers. This table only says which model fills each tier here. The orchestrator's model is selected by the Codex host or the owner. Model availability varies by host.

| Tier | Model |
|---|---|
| Orchestrate | **Host-selected; prefer <!-- FILL-ME: strongest model -->** |
| Operate, high risk | **<!-- FILL-ME: strongest model -->** |
| Operate, routine | **<!-- FILL-ME: mid-tier model -->** |
| Git & docs | **<!-- FILL-ME: fastest model -->** |
