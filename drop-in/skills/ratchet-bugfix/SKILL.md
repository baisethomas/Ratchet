---
name: ratchet-bugfix
description: Test-first bug fixing with mechanical proof that the regression test can fail. Use when fixing a bug, a regression, a failing or flaky test, a crash, or any "this is broken / used to work" report — before editing the code under suspicion.
---

# Ratchet bugfix — reproduce, fix, revert, restore

`AGENTS.md` sets the rule: reproduce before fixing, and prove the regression test can fail. This is the procedure. It adds no rules; if it ever disagrees with `AGENTS.md`, `AGENTS.md` wins.

A fix for an unreproduced bug is a guess wearing a diff. A regression test that was never seen failing is decoration.

## 1. Reproduce — before touching the suspect code

- Turn the report into one command that fails **because of the bug**. Prefer a new automated test in the repo's existing test framework; fall back to a script or a documented manual sequence only if a test is genuinely impractical.
- Run it. Keep the failing output. Confirm it fails on the reported symptom, not on a typo in your new test.
- Expected values come from an independent source — the report, the spec, a worked example. A test that computes its expectation the same way the code does will agree with the bug.
- Test where the bug actually happens. If the only place you can attach a test is too shallow to reproduce the failing chain (one caller when the bug needs two, a unit when it needs the pipeline), a green test there is false confidence. Say so: the missing seam is a finding for the report, not something to paper over.
- **If you cannot reproduce it, stop and report.** Say what you tried, what you observed, and what information would make it reproducible. Do not ship a speculative fix. If the owner explicitly asks for one anyway, label it as unverified in the completion report.

## 2. Diagnose to the cause

- Find why it fails, not just where. State the cause in one sentence before writing the fix. If you can't, you are about to patch a symptom.
- Check whether the same cause exists at sibling call sites. Report them; fix them only if they are inside the task's blast radius.

## 3. Fix at the right layer

- Smallest change that removes the cause. No drive-by cleanup in the same diff.
- If the fix sprawls across many files for one behavior, say so — it usually means the wrong layer.
- Keep the fix and the test in separate files where the codebase allows; step 4 depends on reverting one without the other.

## 4. Prove the test can fail

Run `scripts/rrr.sh` from this skill's directory (`.agents/skills/ratchet-bugfix/`), with the repo root as the working directory. List only the files that contain the fix — never the test file:

```
.agents/skills/ratchet-bugfix/scripts/rrr.sh --test '<command that runs the new test>' -- <fix file> [<fix file>...]
```

It runs the test with the fix (must pass), with the fix files put back to `HEAD` (must **fail**), and with the fix restored (must pass). Your fix is backed up first and restored on every exit path; git's index, stash, and branches are never touched. If the fix is already committed, add `--base <commit-before-the-fix>`.

Fix files must be regular files inside the repo, listed by relative path. The script refuses symlinks, directories, and anything that resolves outside the repository — list the real file instead. A fix that only changes the executable bit counts as a fix.

Then read the phase 2 output yourself. `RRR: PROVEN` only means the exit codes were right. The failure must be the bug's assertion — not an import error, a syntax error, or a missing file, which would mean you reverted something the test needs in order to run at all.

If the verdict is `NOT PROVEN`:

| Verdict says | What it means | Do |
|---|---|---|
| does not exercise the bug | The test passes without your fix | Rewrite the test until it fails for the right reason. Do not weaken the claim instead. |
| does not pass with the fix | The fix is incomplete or the test is wrong | Back to step 2 |
| no fix to revert | Wrong files listed, or the fix is already committed | Correct the file list or pass `--base` |
| changed the fix files | The test command rewrote or deleted a file it is supposed to be testing | Fix the test's setup or cleanup so it leaves the fix files alone, then run again |
| flaky or order-dependent | Green → red → red | The test leaks state. Fix the test before trusting it. |

When the script can't be used (fix and test share a file, a compiled artifact sits in between, a manual reproduction): do the same three runs by hand and paste all three outputs. Never substitute "I'm confident it would fail."

## 5. Full suite, then report

- Run the repo's full check command from `AGENTS.md` → Repo specifics. A fix that breaks a neighbor is not a fix.
- If anything fails and you don't understand why, stop and report. Do not edit another test to get green.
- Finish with `ratchet-done`. In its verification section include: the original failing reproduction, the `rrr.sh` verdict line, and the full-suite result.

<sub>Two test-quality points in step 1 — independent expected values, and a too-shallow seam being a finding — are adapted from the `tdd` and `diagnosing-bugs` skills in [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). See `../CREDITS.md`.</sub>
