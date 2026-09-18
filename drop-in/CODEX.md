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
- Codex discovers repo skills in `.agents/skills/`, not `.claude/skills/`. Ratchet installs its skills there for that reason. If a workflow exists only under `.claude/skills/`, Codex will not load it on its own: read its `SKILL.md` directly when the task matches, and report the gap.
- Treat any conflict between this file and `AGENTS.md` as a configuration error. `AGENTS.md` wins; report the conflict.

## Model routing

Tiers, what each owns, and the routing rules are defined in `AGENTS.md` → Delegation and model tiers. Resolve the criteria below against the models currently available on the target host; do not pin model names in this adapter. The orchestrator's model is selected by the Codex host or the owner.

| Tier | Selection criteria |
|---|---|
| Orchestrate | **Host-selected; prefer the most capable available model for complex reasoning and cross-cutting decisions.** |
| Operate, high risk | **The most capable available coding and reasoning model.** |
| Operate, routine | **A balanced coding model suited to everyday implementation, with a good tradeoff between quality, latency, and cost.** |
| Git & docs | **A fast, economical model capable of bounded mechanical tasks.** |

### Resolve models at session start

1. Read the target host's current model catalog or exposed tool metadata, including capability descriptions and any availability restrictions. Respect explicit owner selections and constraints. Use only identifiers the host exposes as available to this session; a public announcement does not establish access.
2. Match available models to the tier criteria. Prefer the host's current recommended successor for a tier when its capabilities meet that tier's needs. Do not infer capability from version numbers, release dates, or names alone, and do not invent model identifiers or unsupported reasoning settings.
3. State the resolved tier-to-model mapping and its source before the first authorized delegation. Keep this mapping in session context rather than replacing these criteria with names in the repository. The orchestrator cannot switch its own model; report a mismatch between the preferred and active model without claiming to change it.
4. Keep the mapping stable during the session. Resolve it again in a new session, when the owner requests a refresh, or when the host reports that a selected model is unavailable. For substitutions, follow `AGENTS.md` and disclose the change.
5. If the host provides no reliable catalog or capability information, inherit the orchestrator's model where supported and disclose that current model selection could not be verified. If delegation or inheritance is unavailable, do the work in the current session under the single-model rules in `AGENTS.md`.

This is routing guidance, not an automatic model updater: it uses the models the host makes available and does not grant access to new releases, change the running session's model, or authorize delegation. The escalation, review-strength, verification, and hard-stop rules in `AGENTS.md` still apply.
