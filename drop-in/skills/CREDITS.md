# Credits

## Matt Pocock — [mattpocock/skills](https://github.com/mattpocock/skills)

MIT License, Copyright (c) 2026 Matt Pocock.

Several ideas in these skills were learned from that repository and adapted to Ratchet's contract. No text was copied; the procedures here are written for Ratchet and any mistakes in them are ours. If you want a broader set of engineering skills — planning, specs, tickets, TDD, domain modeling — install his alongside these. They do not overlap much: his cover how to plan and build, these cover how to prove the work is done.

| Ratchet skill | Idea adapted | From |
|---|---|---|
| `ratchet-bugfix` | Expected values must come from an independent source of truth, never computed the way the code computes them | `tdd` (the tautological-test anti-pattern) |
| `ratchet-bugfix` | A test at too shallow a seam gives false confidence; a missing seam is itself the finding | `diagnosing-bugs` |
| `ratchet-review` | Pin and validate the fixed point before spawning reviewers; cap each reviewer's brief; report scope creep as a finding | `code-review` |
| `ratchet-handoff` | Reference existing artifacts by path instead of duplicating them; tell the next session which skills to load | `handoff` |
| `ratchet-handoff` | The three-part test for recording a decision: hard to reverse, surprising, the result of a real trade-off | `domain-modeling` |
| `ratchet-tighten` | A mechanical violation gets a deterministic check before a written rule; keep the always-loaded file small | `retro` |
| `ratchet-tighten` | Hunt no-ops: an instruction the model already follows costs context and changes nothing | `writing-for-agents` |
| `ratchet-init` | Explore, present, confirm drafts, then write; edit the file that exists rather than creating a rival; verify a hook by piping it a payload | `setup-matt-pocock-skills`, `git-guardrails-claude-code` |
| all | A "Done when" completion criterion on each step; short descriptions of the form "what it is, then use when"; user-invoked skills marked so they are never triggered implicitly | `writing-for-agents`, repo conventions |

## Lauren Tan (poteto) — [pstack](https://github.com/cursor/plugins/tree/main/pstack)

MIT License, Copyright (c) 2026 Lauren Tan. Read through the standalone mirror [backnotprop/pstack](https://github.com/backnotprop/pstack), which carries harness-neutral rewrites of some skills.

Ideas adapted to Ratchet's contract; no text copied except `runlog.sh`, which is a rewrite of pstack's `show-me-your-work/scripts/log.sh` and keeps its formula-injection scrub.

| Ratchet piece | Idea adapted | From |
|---|---|---|
| `AGENTS.md` enforcement table, `ratchet-tighten` | A table pairing each rule with what enforces it; a repeat through an unenforced rule is promoted to a check in the same change; a rule is dropped once its mistake cannot happen; exceptions carry a reason, an expiry, and an approver | `correct` |
| `AGENTS.md`, `ratchet-done` | INCONCLUSIVE as a verdict distinct from assumed, which never counts as a pass | `principle-prove-it-works`, `figure-it-out`, `benchmark-checklist` |
| `AGENTS.md`, `ratchet-bugfix` | After two fixes on one premise fail, test the premise before a third; revert a guard whose hypothesis the evidence refuted | `principle-attack-the-premise`, the bug-fix playbook |
| `AGENTS.md` | The exit condition is a checkable predicate written before the first edit and never relaxed to declare victory | the autonomous-run playbook |
| `AGENTS.md`, `ratchet-done` | The author's own run is not the verdict for high-risk work; green CI and bot approvals are inputs | the shipping playbook |
| `AGENTS.md` | Every delegation is a brief with fixed fields, and a field you cannot fill means the unit is not scoped | the orchestrate playbook |
| `AGENTS.md` reporting, `ratchet-done` | A skipped step stays visible as `skip: <reason>` | `poteto-mode` |
| `ratchet-done` | Match the evidence to the change type; classify a CI failure (stale base, one fresh run, identical second failure is real) before any retry | the pstack guide, the babysit playbook |
| `ratchet-handoff` | Commit dirty work as one `wip:` commit before a pause; tag each in-flight line with a status; a line with no tag is not done | the pause-safely playbook, `recall` |
| `ratchet-pickup` | The prior trail is authoritative input, so verify its claims against the real artifact without redoing the work; check whether a known-good commit still describes the code with `git patch-id` after a rebase | the session-pickup and shipping playbooks |
| `runlog.sh` | An append-only decision log with an evidence pointer and a result state per row | `show-me-your-work` |
| `ratchet-review` | The one fact a change is safe because of, and a five-rung ladder for how well it is proven; a test that fails when only internals change is also a finding | `blast-radius`, `principle-test-behavior-not-implementation` |
| `ratchet-tighten` | A prose rule carries an example of the failure it prevents | `principle-encode-lessons-in-structure` |
| `ratchet-bugfix` | Failing test committed first, fix on top, so history replays the proof | `principle-sequence-verifiable-units` |
| `CLAUDE.md`, `CODEX.md` | Effort as a per-tier floor; a fixed one-line form for a step a harness cannot run | `setup-pstack`, `docs/harness/claude-code.md` |

What is Ratchet's own: binning claims as RAN / READ / ASSUMED, the completion gate, reverting a fix to prove its test can fail (`rrr.sh`), verifying review findings before acting on them, the stop rule for review loops, and installing skills where every tool looks.
