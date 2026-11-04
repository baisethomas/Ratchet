# Brief: Make guard-destructive.sh fail closed

**Project:** Ratchet
**Created:** 2026-11-04
**Status:** open

## Task

Ternary blocked the Ratchet install in loomlogic-agent-environment (PR #4, check run 126902264285) with a blocking finding: `drop-in/hooks/guard-destructive.sh` fails OPEN when the payload_field helper (`drop-in/hooks/lib-payload.sh`) exits unexpectedly or the payload can't be parsed, so a destructive command can get through. Fix this upstream so the guard fails CLOSED (blocks the command, with a clear message) on any unexpected helper exit or unparseable payload, while normal allowed commands still pass. Also confirm whether `install.sh` keeps the exec bit on `skills/ratchet-upgrade/scripts/upgrade.sh` when it copies files into a target repo (Ternary flagged a missing exec bit downstream; the bit is set upstream as 100755), and fix the installer if it doesn't. Bump the Ratchet version the way the repo normally does, so `ratchet-upgrade` can re-sync installed repos.

## Complete means

- [ ] Exercising `guard-destructive.sh` with (1) a malformed or empty payload and (2) a forced non-zero or unexpected exit from the payload_field helper BLOCKS, i.e. exits with the hook's deny code. Show the before (fails open) and after (blocks).
- [ ] A known destructive command is still blocked, and a normal benign command is still allowed.
- [ ] `drop-in/hooks/test-hooks.sh` has new regression cases for both fail-open paths, and the full hook test suite passes.
- [ ] RRR is proven for the fail-open fix: revert the fix, the new test fails; restore it, the test passes (`RRR: PROVEN` line in the PR body).
- [ ] Installing into a scratch repo with `install.sh` leaves `upgrade.sh` executable (shown with `ls -l` or `git ls-files -s`), or the installer is fixed so it does.
- [ ] The existing test suites (`test-rrr.sh`, `test-upgrade.sh`, and any other repo tests or CI) pass.

## Evidence required

- The test output (before and after) for the new hook cases, and the full test-hooks.sh run.
- The RRR output.
- The scratch-install exec-bit proof.
- The diff, and the version-bump line.
- Ternary's check result on the work PR.

## Ratchet repos

If the repo has `.ratchet/`, follow its AGENTS.md:
- Update `.ratchet/STATE.md`: tag the PR `[open PR #N]` and update Last handoff.
- Append medium-impact decisions to `.ratchet/DECISIONS.md` (append only; supersede, never edit).
- Write the PR body in five sections: What changed / Shape & why / Verification (split RAN / READ / ASSUMED / INCONCLUSIVE; ASSUMED never empty) / Residue / Handoff.
- Bug fixes include the `RRR: PROVEN` line from rrr.sh.
- Any skipped step is written as `skip: <reason>`.
- The Verifier will fail PRs missing these.

## Reserved for the operator

- merge
- deploy
- send / publish
- cutting or announcing a Ratchet release
- re-syncing the downstream installs (granted-ai #63 and loomlogic-agent-environment #4 are handled after this merges, by a separate instruction)

## Original intake

> Fix the hook upstream in Ratchet with a brief, then re-sync the installs

(Baise, 2026-11-04 2:23 PM PT, choosing between: fix upstream in Ratchet, patch locally in each install, or ship the installs as is.)

## Notes from the CoS

This blocks the Ratchet installs on granted-ai (#63) and loomlogic-agent-environment (#4), which are both on hold. Ternary's other two notes on loomlogic #4 were a false "files not in diff" warning and the exec-bit suggestion covered above. Fix only what's listed; don't refactor the other hooks.
