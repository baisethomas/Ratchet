# Brief: Fix the two upstream findings Ternary raised on loomlogic #4

**Project:** Ratchet
**Created:** 2026-11-04
**Status:** open

## Task

Ternary failed the downstream Ratchet install in loomlogic-agent-environment #4 (run 126987729099) because of two problems in Ratchet's own tooling. Fix both here, upstream, so every downstream install picks them up on the next re-sync. First, the CSV formula scrub in `runlog.sh` (around line 122) only checks the first byte, so a value whose leading whitespace or carriage return comes before `=`, `+`, `-`, `@` or `"` gets through unscrubbed. Second, the restore in `rrr.sh` (around line 140) resets only the exec bit, so a 0600 or 0640 file can come back as 0644, and the `fix_intact` check ignores non-exec mode drift, so it can still report PROVEN after a wrong restore. The restore should bring back the exact original mode, and `fix_intact` should fail on any mode drift.

## Complete means

- [ ] A test in Ratchet's suite feeds `runlog.sh` values with leading spaces, tabs and CR before each of `= + - @ "`. Every one is scrubbed, it fails on 11a02d0 and passes on the PR head.
- [ ] A test restores a 0600 file and a 0640 file through `rrr.sh`. Each comes back with its exact original mode, and the test fails on 11a02d0.
- [ ] A test changes a non-exec mode bit after the fix. `fix_intact` then reports the fix isn't intact (not PROVEN), and the test fails on 11a02d0.
- [ ] All existing test scripts pass on the PR head (test-hooks.sh, test-upgrade.sh, test-install.sh and the rest).
- [ ] The version is bumped as a patch (1.3.1) in plugin.json and wherever else 1.3.0 is declared, with a semver note in docs/technical-readme.md.
- [ ] The Ternary check on the PR is PASS, or NEUTRAL with a rebuttal to each note posted on the PR.

## Evidence required

- Test output on 11a02d0 (the new tests failing) and on the PR head (everything passing), pasted in the PR.
- `RRR: PROVEN` lines for both bug fixes.
- The diff touching only runlog.sh, rrr.sh, their tests, version strings and docs.

## Ratchet repos

This repo has no root `.ratchet/`. Write `skip: no root .ratchet/ in the Ratchet repo; decisions recorded in docs/technical-readme.md`, and record decisions in docs/technical-readme.md.
- Write the PR body in five sections: What changed / Shape & why / Verification (split RAN / READ / ASSUMED / INCONCLUSIVE; ASSUMED never empty) / Residue / Handoff.
- Bug fixes include the `RRR: PROVEN` line from rrr.sh.
- Any skipped step is written as `skip: <reason>`.
- The Verifier will fail PRs missing these.

## Reserved for the operator

- merge
- deploy
- send / publish
- tagging a release

## Original intake

> Fix both upstream with the Ratchet Builder, and brief Ternary to skip vendored Ratchet files in downstream repos

## Notes from the CoS

This unblocks granted-ai #63 and loomlogic #4. Once it merges, both re-sync to 1.3.1 in one pass. The findings came from Ternary's review of loomlogic #4 (evidence comment 6647186806 on loomlogic #3).
