# Brief: rrr.sh must verify the fix every phase; upgrade must respect file mode

**Project:** Ratchet
**Created:** 2026-11-04
**Status:** open

## Task

When Ternary reviewed the re-synced Ratchet 1.2.1 install in loomlogic-agent-environment (PR #4, run 126938079426), it flagged two upstream problems in files that are byte-identical to Ratchet main 770fc5d. (1) Blocking: in `drop-in/skills/ratchet-bugfix/scripts/rrr.sh` (around line 221), `fix_intact` is only checked after phase 3. A test that edits the fix files during phase 1 or 2 can still produce a false `RRR: PROVEN`. Check the fix paths after every phase, and fail loudly with no PROVEN line when they've drifted. (2) Warning: in `drop-in/skills/ratchet-upgrade/scripts/upgrade.sh` (around line 220), files are compared by bytes only, so a change that touches only the mode (the exec bit) is reported as SAME, and merges keep the old mode. Include the file mode in the comparison and the apply step. Bump the version to 1.2.2 the way the repo normally does.

## Complete means

- [ ] rrr.sh checks that the fix is intact after every phase. New cases in `test-rrr.sh` show a test that alters a fix file in phase 1, and another in phase 2, each ends without `RRR: PROVEN` and exits non-zero. Existing rrr cases still pass.
- [ ] RRR is proven for change (1): with the fix reverted, the new cases fail; with it restored, they pass.
- [ ] upgrade.sh reports a mode-only difference as changed and applies the upstream mode. A new case in `test-upgrade.sh` covers an exec-bit-only change, both detection and apply. Existing upgrade cases still pass.
- [ ] RRR is proven for change (2) the same way.
- [ ] Every suite passes: test-rrr, test-upgrade, test-hooks, test-install, test-source-root, test-runlog, test-plugin, and CI.
- [ ] The version is bumped to 1.2.2.

## Evidence required

- Test output before and after for the new cases, and full runs of every suite.
- Both RRR outputs.
- The diff and the version-bump line.
- Ternary's result on the work PR.

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
- re-syncing the downstream installs (granted-ai #63 and loomlogic-agent-environment #4), which follows by a separate instruction after merge

## Original intake

> Write a new Ratchet brief for the rrr.sh and upgrade.sh fixes, then re-sync the installs

(Baise, 2026-11-04 3:38 PM PT)

## Notes from the CoS

This blocks the Ratchet installs in granted-ai #63 and loomlogic #4 a second time; the first round was fixed in Ratchet #20 (770fc5d). Fix only these two issues. If Ternary raises more upstream findings on this PR, list them under Residue rather than widening scope on your own.
