# Ratchet — The Operator Playbook

[![GitHub Repo](https://img.shields.io/badge/GitHub-baisethomas%2FRatchet-181717?logo=github&logoColor=white)](https://github.com/baisethomas/Ratchet)

Everything needed to run the craft — with any model — as drop-in files. Nothing here requires the strongest model; that's the point.

**Why "Ratchet":** the mechanism that only turns one way. The model's ceiling is fixed; the system's isn't. Every failure that escapes produces one permanent addition to the process — a rule, a hook, a test, an escalation gate — and the system never slips backward.

Ratchet treats the repository as the durable source of truth. Conversation history is disposable; project state and accepted decisions are not. A fresh agent should be able to enter the repo, recover the current objective and constraints, do verifiable work, maintain project memory, and leave a clean handoff for the next agent without replaying prior chats or making the human act as the synchronization layer.

## What's in the box

| File | What it is | Where it goes |
|---|---|---|
| `PLAYBOOK.md` | The full manual: chat craft, code craft, project memory, and the compensation layer | Read it once; keep it as the reference |
| `drop-in/AGENTS.md` | Canonical, model-agnostic repo operating contract | Copy to the repo root of every project. Fill the `FILL-ME` sections |
| `drop-in/CLAUDE.md` | Thin Claude Code adapter that points to `AGENTS.md` and adds Claude-specific behavior only | Copy to the repo root when using Claude Code |
| `drop-in/STATE.md` | Mutable semantic handoff: objective, current phase, active work, blockers, verification, risks, and next actions | Copy to `.ratchet/STATE.md`; agents maintain it automatically |
| `drop-in/DECISIONS.md` | Durable decision ledger with an autonomy ladder for low, medium, and high-impact choices | Copy to `.ratchet/DECISIONS.md`; agents maintain it, escalating only high-impact decisions |
| `drop-in/claude-ai-project-instructions.md` | ~180-word epistemics core | Claude.ai → Project → Custom instructions (or Settings → Preferences for account-wide) |
| `drop-in/api-system-prompt.txt` | Reliability rules + optional second-pass reviewer prompt | Appended to the system prompt of any API-powered app |
| `drop-in/review-prompts.md` | 8 copy-paste prompts: adversarial review, re-derivation, fresh-context adversary, decomposition assist, hostile diff review, reproduce-revert-restore, honest summary, plan-first leash | Keep open in a tab; paste as needed |
| `drop-in/claude-code-hooks-settings.json` | Post-edit lint hook, stop-hook test gate, destructive-command guard | Merge into `.claude/settings.json` in the repo; copy `drop-in/hooks/` alongside it |
| `drop-in/hooks/` | The three hooks as tested scripts, plus `test-hooks.sh` (34 regression cases) | Copy to `.claude/hooks/`, `chmod +x`, fill the `CHECKS` array in `check-on-stop.sh`, then run `test-hooks.sh` |
| `drop-in/done-audit-checklist.md` | The two-minute human audit for every "done," plus the ratchet rule | Print or pin next to wherever you review completions |
| `drop-in/graduation-rule.md` | When a recurring workflow graduates from prompts to a pipeline — nodes, conditional edges, loop caps, and when NOT to graduate | Read once; apply when a workflow has run ~3+ times with the same shape |
| `drop-in/pipeline-skeleton.py` | A graduated workflow in plain Python: draft → review → conditional revise loop (capped) → done/escalate | Copy into the app's repo; prove the gate can fail before trusting it |
| `drop-in/test_pipeline_skeleton.py` | 15 cases for the review gate — conflicting, qualified, non-final, and empty verdicts must all reach a human | Copy alongside the skeleton; run it after changing the gate |

## The three layers

Ratchet separates three failure classes instead of asking model capability to cover all of them:

1. **Behavior** — `AGENTS.md` is the canonical operating contract. Tool-specific adapters such as `CLAUDE.md` point to it instead of duplicating universal rules.
2. **State** — `.ratchet/STATE.md` and `.ratchet/DECISIONS.md` tell a fresh agent what the project currently knows and why durable choices were made. Agents own maintaining both.
3. **Verification** — hooks, tests, adversarial review, and the done audit prove the work instead of trusting the model's confidence.

`STATE.md` is deliberately small and mutable. `DECISIONS.md` is durable and append-oriented. Neither is a transcript store. The goal is semantic continuity with minimal context and token cost.

## Decision autonomy

Ratchet is designed to keep the human at the big-picture layer:

- **Low impact:** routine implementation choices stay in code unless their rationale would otherwise be lost.
- **Medium impact:** durable, reversible choices within authorized scope are decided and recorded by the agent, then surfaced in the completion summary.
- **High impact:** architecture replacement, destructive migrations, major dependency/platform changes, public/shared contract changes, security-sensitive policy changes, or material product-scope changes require explicit human approval before acceptance or execution.

The agent, not the human, is responsible for deciding when project memory should be updated.

## Install order (35 minutes total)

1. **Every active repo (15 min):** copy `AGENTS.md` to the root and fill the FILL-ME sections. Create `.ratchet/`, copy `STATE.md` and `DECISIONS.md` into it, then initialize them from the project's actual current state and already-settled decisions. Keep only context a fresh agent cannot safely infer from the repo itself.
2. **Claude Code (1 min, if used):** copy `CLAUDE.md` to the repo root. It should remain a thin adapter that points back to `AGENTS.md`.
3. **Hooks (10 min):** copy `drop-in/hooks/` to `.claude/hooks/` and `chmod +x` the scripts, merge `claude-code-hooks-settings.json` into `.claude/settings.json`, fill the `CHECKS` array in `check-on-stop.sh` with your real commands, and extend the destructive-command patterns for your stack. **Then run `.claude/hooks/test-hooks.sh` — a hook that silently does nothing looks exactly like a hook that works.** Verify shapes against [the current hooks docs](https://code.claude.com/docs/en/hooks); they occasionally change between releases.
4. **Claude.ai (2 min, optional):** paste `claude-ai-project-instructions.md` into your main Project's custom instructions.
5. **API apps (5 min):** append `api-system-prompt.txt` to each app's system prompt. For any app producing final deliverables, wire the optional second-pass reviewer as a second API call.
6. **You (3 min):** read `done-audit-checklist.md` once so you know the escalation boundaries. After that, agents should handle routine state and decision maintenance themselves.
7. **Later, as needed:** when any workflow has run ~3+ times with the same shape, apply `graduation-rule.md` — promote it to a pipeline using `pipeline-skeleton.py` as the starting point.

## Handoff rule

For nontrivial work, the session is not complete until `.ratchet/STATE.md` is accurate enough for a fresh agent to continue without the conversation transcript. Agents update current state automatically as meaningful state changes and always before handoff. Agents also record medium-impact durable decisions automatically. Only high-impact decisions escalate to the human.

## The one rule that maintains all the others

When a failure gets through, don't just fix the output — add exactly one permanent thing to the system. If the failure was behavioral, add a rule, hook, test, or escalation gate. If the failure was lost project knowledge, add the missing state, constraint, or decision. Capability is what you have; process and project memory are what you keep.
