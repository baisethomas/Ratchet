# Brief: Make Dependabot #15 merge-ready

**Project:** Ratchet
**Created:** 2026-11-02
**Status:** closed 2026-11-02. Outcome: recommend not merging until Ternary is fixed; #15 itself is clean. Verifier: all PASS except the main-run link, where the PR #14 run was accepted as a substitute by the operator.

## Task

Dependabot PR #15 bumps `hashgraph-online/ai-plugin-scanner-action` from 1.2.690 to 1.2.811 in
`.github/workflows/plugin-scan.yml`. Both `scan` checks pass, but the "Ternary review" check fails.
Find out why "Ternary review" fails and whether the bump causes it. Then either get #15 to all-green,
or recommend not merging it with a reason.

- #15: https://github.com/baisethomas/Ratchet/pull/15

## Complete means

- [ ] PR #15 has a comment stating either "ready to merge" or "recommend not merging: <reason>".
- [ ] If the outcome is ready to merge, every check on #15's latest head SHA passes, including "Ternary review".
- [ ] If "Ternary review" also fails on `main`, or fails for reasons unrelated to the bump, the comment says so and links a run on `main` that shows it.
- [ ] The comment lists any input, permission, or behavior changes between 1.2.690 and 1.2.811 that affect `plugin-scan.yml`, or says there are none.

## Evidence required

- A link to the failing "Ternary review" run, plus a one-line cause.
- A link to the passing run after any fix, at the head SHA.
- A link to a "Ternary review" run on `main`, to compare against.
- The upstream release or changelog entries that were checked.

## Reserved for the operator

- merge
- changing repository secrets, settings, or required checks
- disabling or removing any check
- send / publish

## Original intake

> Yes.

(In reply to the CoS: "do you want me to draft a Ratchet brief too?")

## Notes from the CoS

Small, but it's Ratchet's only open item, and a failing required check on a dependency bump hides
real breakage. Ratchet is the harness other projects (Tablet Notes) run on, so its CI should be trustworthy.
