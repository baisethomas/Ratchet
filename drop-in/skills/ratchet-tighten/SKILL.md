---
name: ratchet-tighten
description: Turn an escaped failure into one permanent fix at the right layer — a check, a hook, a test, a skill step, or a rule. Use when a mistake got past the process - a false "done", a bug found after review, a broken rule, a repeated correction from the user - or when the user asks for a retro.
---

# Ratchet tighten — every escaped failure adds one permanent thing

The playbook's one maintaining rule: when a failure gets through, do not just fix the output. Add exactly one permanent correction, at the layer where it will actually fire. This is the procedure.

Fixing the instance is a separate task and comes first. This skill starts once the instance is fixed or contained.

## 1. State the escape in one sentence

"X happened, and nothing stopped it until Y." Work from primary sources — the diff, the command output, the conversation, the review thread — not from memory of them. If you cannot say where in the process it *should* have been caught, keep reading until you can.

**Done when:** the sentence names the failure, the point it should have been caught, and the point it was.

## 2. Check it is not already covered

Read what exists before adding anything: the check command and CI, `.claude/hooks/`, the skills, `AGENTS.md`. A guard that exists but is unwired, silently broken, or never triggered is the finding — fix that instead of adding a second one.

## 3. Pick the layer — mechanical beats prose

Choose the **first** option that can catch this class of failure:

1. **A deterministic check** — a test, a lint rule, a hook, a CI job, an assertion in a script. If the failure has a fixed shape (a pattern, a command, a file location, a missing step a script could detect), it gets a check. Full stop. Do not write a rule for something a machine can refuse.
2. **A step in a procedure** — a line in the skill or review brief that runs at the moment the failure occurs (`ratchet-done`, `ratchet-bugfix`, `ratchet-review`). For judgement calls that only matter at one point in the work.
3. **A rule in `AGENTS.md`** — last, and only for judgement that must hold at all times. Every line there is loaded into every session of every model, including the weakest one, and competes with every other line for attention.
4. **Project memory** — if the cause was missing knowledge rather than missing discipline, it belongs in `.ratchet/STATE.md` or a `DECISIONS.md` entry, not in a rule.
5. **Authority** — if the failure was an action that should have needed a human, add it to the hard stops and, where a pattern exists, to the guard hook.

If the honest answer is "the design made this failure easy," say that to the owner before adding machinery. Ratchet should not grow guards around something that should be simplified.

## 4. Build it, and prove it bites

- Reproduce the original failure first, against the process as it was.
- Add the one correction.
- Show it now catches the failure: the test fails, the hook blocks, the check goes red. Then show it passes on the corrected state.
- For a check or script, remove the new guard once and confirm something fails without it. A guard that was never seen firing is decoration.
- For prose (options 2–3), proof is weaker: state that it is unverified until a later session shows it changing behavior.

**Done when:** you have output showing the new guard catching the original failure — or, for prose, an explicit note that it is untested.

## 5. Keep the system small

- **One** correction per escape. If you want to add three, you have not found the right layer.
- When adding a line to `AGENTS.md` or a skill, look for one to delete: a rule now enforced by a check, or a sentence the model already obeys by default. The test for a no-op is whether removing it changes behavior, not whether it sounds important.
- Rewording `AGENTS.md`, an adapter, or the hard stops is orchestrator-tier work and is shown to the owner as a diff before it lands.

## 6. Report

What escaped, the layer chosen and why not the one above it, the evidence it bites, and anything deleted. Then `ratchet-done`.

<sub>The ordering — a deterministic check before a review rule before a line in the always-loaded file — and the hunt for no-ops are adapted from the `retro` and `writing-for-agents` skills in [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). See `../CREDITS.md`.</sub>
