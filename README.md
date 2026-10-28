# Ratchet

[![HOL Guard Scanner](https://img.shields.io/badge/HOL%20Guard-passing-00a67e)](https://github.com/hashgraph-online/hol-guard)

An operating system for AI-assisted software work, in drop-in files, for any model.

Ratchet treats the repository, not the conversation, as the durable source of truth. A small contract that always loads, project memory the agents maintain themselves, procedures that load when the task matches, and checks that fire whether or not the model remembers them. One rule holds it together: every failure that escapes permanently tightens one of those layers, and the system never slips backward.

The bet is that a weaker model plus this system outperforms a stronger model working bare, because most of what goes wrong in agent work is process failure that capability was papering over.

## What problem it solves

Agent coding fails for reasons that are not model-capability problems. Context disappears between sessions. Decisions are forgotten and re-litigated. "Tests pass" means someone believed it. The human ends up as the synchronization layer, carrying state from one agent to the next. Ratchet names each of those failures and gives it a layer that owns it.

## The four layers

1. **Contract.** `AGENTS.md` is the model-agnostic operating contract: what must be read before any edit, how work is checkpointed, what counts as verification, which actions need a human, and how delegated work is routed by blast radius rather than by apparent size. A rule-to-enforcer table says, for every rule, which hook or script or skill step holds it, or admits that prose alone does. Prose-only rows are the next things to mechanize.
2. **Memory.** `.ratchet/STATE.md` is the current state of a branch, a dashboard rather than a diary, with every in-flight item tagged by its status. `.ratchet/DECISIONS.md` is the durable decision ledger with an autonomy ladder: low-impact choices stay in the code, medium-impact ones are recorded and surfaced, high-impact ones wait for a human. Git is the only synchronization mechanism; Ratchet never builds a second one beside it.
3. **Procedures.** Eight skills agents load on their own. The completion gate bins every claim as ran, read, assumed, or inconclusive and refuses to call inconclusive a pass. Bug fixing reproduces first, tests the shared premise after two failed fixes, and runs a script that reverts the fix to prove the test can fail. Hostile review reproduces every finding before acting on it and asks for the one fact a change is safe because of. Handoff writes memory, then commits only this session's own work. Pickup, the read side, verifies inherited claims against git instead of trusting or redoing them. Tighten turns an escaped failure into exactly one permanent fix at the lowest layer that can catch it. Init installs all of this without overwriting anything.
   Upgrade brings an older install forward: it replays the owner's filled-in answers onto the new release as a three-way merge, shows every proposal, and writes nothing without a yes.
4. **Mechanical enforcement.** Claude Code hooks that lint on every edit, run the check command before the agent is allowed to finish, refuse to finish while project memory still holds a template placeholder, and block destructive commands outright. A revert-and-restore script that proves a regression test bites. A run log for unattended work that refuses to write a row it cannot prove was written alone. None of this depends on the model remembering to do it.

## How a piece of work moves through it

An agent reads the contract and the memory, writes the definition of done as a checkable predicate before the first edit, and works in steps that each end with the repository known-good. Before claiming done it audits its own diff hunk by hunk, re-runs the checks, and reports what it ran, read, assumed, and could not decide. High-risk work needs a verdict from a context that did not write it. At the end of a session it rewrites the state file, records any durable decisions, and commits its own work so the handoff is real. The next agent, on any model, picks the branch up by checking the inherited claims against git and the check command, repairs whatever went stale, and continues. When something gets through all of that anyway, one layer gets one permanent addition, and the table in the contract records which.

## Included components

- Model-agnostic `AGENTS.md` contract with delegation tiers, hard stops, and the enforcement table
- Thin Claude Code and Codex adapters: model and effort per tier, and a fixed form for steps a tool cannot run
- `STATE.md` and `DECISIONS.md` templates
- Hooks: post-edit lint, stop gate with placeholder check, destructive-command guard, with their own test suite
- Eight skills: `ratchet-done`, `ratchet-bugfix` with `rrr.sh`, `ratchet-review`, `ratchet-handoff` with `runlog.sh`, `ratchet-pickup`, `ratchet-tighten`, `ratchet-init`, `ratchet-upgrade` with `upgrade.sh`
- Adversarial review prompts for chat and for diffs
- Completion audit checklist
- Graduation rule for promoting a repeated workflow into a pipeline, with a tested Python skeleton

## Design principles

- The human stays at the product and architecture layer. Routine choices, memory maintenance, and verification belong to the agent system within authorized scope; irreversible or high-impact choices escalate.
- A check beats a rule. When a failure has a fixed shape, it gets a hook, a test, or a script, never another sentence for the model to remember.
- The always-loaded contract stays small. Every line in it competes for the weakest model's attention, so a line that a check now enforces is deleted.
- Verification is tier-independent. The check command, the guards, and the self-test apply equally to every model, and a faster model gets a shorter leash, not a looser contract.
- Evidence over confidence. A test that was never seen failing is decoration; a review finding is a claim until it reproduces; a prior agent's "tests pass" is a self-report.

## What it is not

Ratchet is not a fleet orchestrator, a planning tool, or a generator of app-driving verification skills. Those exist elsewhere and were left out on purpose. It is the fixed part of the system: the part that is the same in every repository and gets stronger each time something slips through.

## Start here

For the full operating model, installation sequence, invariants, and rationale, see [`PLAYBOOK.md`](PLAYBOOK.md). The file-by-file reference is [`docs/technical-readme.md`](docs/technical-readme.md).

The reusable files live in [`drop-in/`](drop-in/). In Claude Code, `/plugin marketplace add baisethomas/Ratchet` then `/plugin install ratchet@ratchet` installs the skills and the destructive-command guard everywhere; `/ratchet:ratchet-init` then sets up each repo with the contract, the memory files, and the stop gate. Codex reads the same skills from `.agents/skills/` after init.

## Updating

Ratchet has two halves, and they update differently.

- **The plugin half** (the skills and the destructive-command guard) updates in Claude Code with `/plugin marketplace update ratchet` then `/plugin update ratchet@ratchet`. Claude Code leaves auto-update off for third-party marketplaces, so this is a deliberate step unless you enable it for the `ratchet` marketplace under `/plugin`.
- **The per-repo half** (`AGENTS.md`, the adapters, the hooks, and the skills copied into `.agents/skills/`) is never overwritten by the installer. Run `/ratchet:ratchet-upgrade` in the repo: it compares every installed file with the new release, replays your filled-in answers onto the new template as a three-way merge, shows each proposal, and writes only what you approve. Project memory in `.ratchet/` is never touched. Files carry a `ratchet-version` marker from 1.2.0 on; a repo set up from 1.0.0 or 1.1.0 tells the skill its version once.

## Credits

Ratchet's own ideas are the contract, the memory model, binning claims by how they were established, the revert-and-restore proof, verifying review findings before acting on them, and the ratchet rule itself. Several procedures adapt ideas from Matt Pocock's [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) and Lauren Tan's [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT). [`drop-in/skills/CREDITS.md`](drop-in/skills/CREDITS.md) lists each one and where it came from.
