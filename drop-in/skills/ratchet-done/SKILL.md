---
name: ratchet-done
description: Completion gate for coding work. Use before telling the user that nontrivial work is done, fixed, ready for review, or passing — even when the change feels obviously fine. Audits the real diff, re-runs the checks, bins claims as RAN / READ / ASSUMED, and writes the completion report.
---

# Ratchet done — the completion gate

`AGENTS.md` defines what "done" means: the reporting format and the self-test. This is the procedure for getting there honestly. It adds no rules; if it ever disagrees with `AGENTS.md`, `AGENTS.md` wins.

The failure this exists to catch: work that has only reached the stage where it *looks* done. Do the steps in order and do not draft the report until step 5 — a summary written first becomes the thing you defend.

## 1. Read the real diff

Run these; do not recall them:

```
git status --short
git diff HEAD            # plus `git diff <base>...HEAD` if you committed during the task
```

For every hunk, name the sentence of the request that requires it. Remove what you can't justify: reformatting, renames, debug output, commented-out code, stray files, a helper that duplicates an existing one. Untracked files count — either they belong to the change or they go.

If removing a hunk would break the change, it was justified; say why in the report. If the owner would be surprised to see a file in the list, say so first, not last.

## 2. Run the checks now

- Run the full check command from `AGENTS.md` → Repo specifics, after your final edit. A run from before the last edit is evidence about a different diff.
- Keep the actual output: the command, the counts, the exit status.
- If a check fails and you don't understand why, stop and report that. Do not edit a test, broaden a catch, or skip a check to get green.
- If a check cannot run here (credentials, services, hardware, production data), it goes in ASSUMED with the exact command the owner should run.
- A stop hook that ran the checks counts only if you saw its output. Outside Claude Code no hook runs — run them yourself.

## 3. Bin every claim

Write down each thing you believe is true about this change, then sort it:

- **RAN** — you executed it in this session and saw the result. Quote the command and the result.
- **READ** — you inspected code or docs but executed nothing. "The caller handles null" is READ until a test says so.
- **ASSUMED** — environment, versions, external services, data shape, behavior of code you didn't open, library signatures recalled from memory.

Two checks on the bins:

- **Promote what's cheap.** Anything in READ or ASSUMED that you could turn into RAN in under a minute — do it now instead of reporting it.
- **ASSUMED is never empty.** If it is, you haven't looked: which runtime version, which platform, which config, which inputs did you not try?

For a bug fix, the RAN bin must contain the `ratchet-bugfix` proof: the original failing reproduction and the `RRR: PROVEN` verdict line. Without it, say plainly that the regression test was never seen failing.

## 4. Hard stops and memory

- Re-read the hard-stop list in `AGENTS.md`. Did anything you did or are about to propose touch it — a migration, an external send, a destructive git operation, a public or shared contract? If it ran without approval, that is the first line of the report, not a footnote.
- Update `.ratchet/STATE.md` so a fresh agent could continue this branch without this conversation: replace stale state, don't append a diary.
- Record any medium-impact decision you made in `.ratchet/DECISIONS.md`. A high-impact decision is a proposal awaiting approval, not a record.
- No secrets, credentials, customer data, or transcript dumps in either file.

## 5. Write the report

Exactly these sections, in this order:

1. **What changed** — the behavior difference, first, in one or two sentences. Not a list of files.
2. **Shape & why** — files touched, the approach, and why this one if alternatives were live.
3. **Verification** — the three bins from step 3, kept separate. Never collapse them into "tested."
4. **Residue** — untested paths, follow-ups, things you noticed and deliberately left alone, and the one command the owner should run themselves.
5. **Handoff** — confirm `STATE.md` is current; list medium-impact decisions recorded and high-impact decisions awaiting approval.

## 6. Self-test

Answer the `AGENTS.md` "Self-test before every done" questions against what you actually did in steps 1–5. Any "no" means go back, not soften the wording. If something can't be resolved in this session, the report says "not done" and says why — a precise "not done" is a good outcome; a vague "done" is the failure.

## Wording

- "Tests pass" means you ran them after the last edit and saw them pass. Otherwise write what is true: "not run," "ran before the final edit," "ran only `<subset>`."
- "Should work," "looks correct," and "I believe" are READ or ASSUMED. Bin them; don't phrase around them.
- If something failed or was skipped, say so in the section where the owner would look for it.
