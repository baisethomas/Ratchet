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

What is Ratchet's own: binning claims as RAN / READ / ASSUMED, the completion gate, reverting a fix to prove its test can fail (`rrr.sh`), verifying review findings before acting on them, the stop rule for review loops, and installing skills where every tool looks.
