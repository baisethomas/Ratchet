# Ratchet

A model-agnostic operating framework for reliable AI-assisted software development.

Ratchet treats the repository, not the conversation, as the durable source of truth. It gives coding agents a consistent operating contract, compressed project state, durable decision history, verification gates, and clear escalation rules so a fresh agent can continue work without relying on chat history.

## What problem it solves

AI coding workflows often fail for reasons that are not purely model-capability problems: context disappears between sessions, decisions are forgotten, verification is inconsistent, and the human becomes the synchronization layer. Ratchet separates those failure modes into explicit operating layers.

## The three layers

1. **Behavior**: `AGENTS.md` defines the model-agnostic operating contract for the repository.
2. **State**: `.ratchet/STATE.md` and `.ratchet/DECISIONS.md` preserve the minimum project context and durable decisions a fresh agent cannot infer from code alone.
3. **Verification**: hooks, tests, adversarial review, and completion audits prove work instead of relying on model confidence.

## Included components

- Model-agnostic `AGENTS.md` contract
- Thin Claude Code and Codex adapters, with model routing by blast radius
- Branch/workstream state handoffs
- Durable decision ledger with an autonomy ladder
- Verification and destructive-command hooks
- Six skills agents load on their own: completion gate, test-first bug fixing with a script that proves the test can fail, hostile review, handoff, tighten-after-failure, and a never-overwrite installer
- Adversarial review prompts
- Completion audit checklist
- Graduation rules for moving repeated workflows into pipelines
- Tested Python pipeline example

## Design principle

The human should stay at the product and architecture layer. Routine implementation choices, project-memory maintenance, and verification should be handled by the agent system when they are within authorized scope. High-impact or irreversible decisions still escalate.

Ratchet deliberately avoids becoming a second synchronization system beside Git. Git remains the integration mechanism.

## Start here

For the full operating model, installation sequence, invariants, and rationale, see [`PLAYBOOK.md`](PLAYBOOK.md).

The previous detailed README has been preserved at [`docs/technical-readme.md`](docs/technical-readme.md).

The reusable files live in [`drop-in/`](drop-in/).

## Credits

Several ideas in the skills are adapted from Matt Pocock's [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). [`drop-in/skills/CREDITS.md`](drop-in/skills/CREDITS.md) lists each one and where it came from.
