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

The session that talks to the owner is the **orchestrator**. Its model is selected by the host or owner; it cannot switch itself. The table routes subagents only when the user has expressly authorized delegation — it does not itself grant that authority. Delegate only bounded work and own the result: re-run the checks or read the evidence directly; never accept a subagent's "done" on trust. `AGENTS.md` binds every tier equally; a faster model gets a shorter leash, not a looser contract.

Model availability varies by Codex host. Use the named model when available; otherwise use the strongest available model appropriate to the same tier and state the substitution.

| Tier | Model | Owns | Never |
|---|---|---|---|
| Orchestrate | **Host-selected; prefer <!-- FILL-ME: strongest model -->** | The conversation with the owner; plans and blast-radius calls; root-cause diagnosis of production symptoms; anything in hard-stop territory; cross-cutting changes spanning <!-- FILL-ME: the modules that must change together -->; medium/high-impact `DECISIONS.md` entries; arguing or accepting review findings; the final report. | Delegates a decision it should make itself. |
| Implement, high risk | **<!-- FILL-ME: strongest model -->** | Code in the high-risk modules listed in `AGENTS.md` → Repo specifics; anything that writes production data; concurrency changes; test-first bug fixes that must prove reproduce-revert-restore; migration proposals (never execution). | Merges, deploys, executes migrations, or hand-edits <!-- FILL-ME: generated/fragile files, e.g. lockfiles, .pbxproj -->. |
| Implement, routine | **<!-- FILL-ME: mid-tier model -->** | Code outside the high-risk modules that has a test suite; well-specified refactors within one file; new tests for described behavior; PR body drafts; docs wording changes. | Touches the high-risk modules, resolves merge conflicts, or changes a public API surface or shared contract. |
| Chores | **<!-- FILL-ME: fastest model -->** | Git mechanics with fully specified inputs; `.ratchet/STATE.md` refreshes; issue-tracker comments and link updates; typo and formatting fixes in docs; read-only lookups and greps; running a named check and reporting its output verbatim. | Edits code, resolves conflicts, writes `DECISIONS.md` entries, or interprets a failing test. |

Rules of thumb:

- **Route by blast radius, not by apparent size.** A one-line change in a high-risk module is high-risk work; a fifty-line new settings screen is routine.
- **Escalate on the second failure.** If a routine or chores task fails verification twice, or turns out to touch a hard stop, return it to the orchestrator or the next tier up with the failure attached. Never retry a weaker model into the same wall.
- **Reviews go up a tier.** A hostile diff review (`review-prompts.md` §5) uses a model at least as strong as the one that wrote the diff, in a fresh context.
- **Verification is tier-independent.** The check command, the hard stops, and the self-test apply to every model equally.
- **When unsure, use the strongest model.** The cost of a wrong cheap answer in this repo is <!-- FILL-ME: the worst realistic loss, e.g. lost user data -->, not a wasted token.
