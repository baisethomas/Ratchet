# Brief: project-guard-rules

**Project:** Ratchet
**Created:** 2026-11-04
**Status:** open

## Task

Make Ratchet's guard-destructive hook (`drop-in/hooks/guard-destructive.sh`) also enforce extra blocked-command rules from a project-owned file. `upgrade.sh` (`drop-in/skills/ratchet-upgrade/scripts/upgrade.sh`) and any re-sync must never overwrite that file. Installers (`drop-in/skills/ratchet-init/scripts/install.sh`) also must not clobber it. This lets a project like granted-ai block `npm run db:push` and `drizzle-kit generate` without forking Ratchet files. Document the file format (its location, syntax, and how it combines with the defaults) in `README.md` or `docs/technical-readme.md`. Add tests and bump the version. This is a new feature, so pick the semver level and justify it in DECISIONS.

## Complete means

- [ ] A project rule file at the documented path causes `guard-destructive.sh` to block a matching command (exit 2 with a message naming the project rule), and `drop-in/hooks/test-hooks.sh` covers it
- [ ] `test-hooks.sh` shows the default rules still block with a project file present (e.g. `git push --force`, `drizzle-kit push`)
- [ ] `test-hooks.sh` shows a missing or empty project file falls back to the defaults. Behavior on a malformed or unreadable file is decided, documented, and tested; fail closed is consistent with 1.2.1
- [ ] `drop-in/skills/ratchet-upgrade/scripts/test-upgrade.sh` shows an upgrade (report and `--apply-all`) leaves the project rule file byte-for-byte unchanged
- [ ] `drop-in/skills/ratchet-init/scripts/test-install.sh` covers the preserve case: re-install/upgrade over an existing project rule file keeps it
- [ ] The file format is documented in `README.md` or `docs/technical-readme.md`
- [ ] The version is bumped in `drop-in/.claude-plugin/plugin.json` and the `ratchet-version` markers, with a DECISIONS entry justifying the semver level
- [ ] CI is green and the Ternary check is green on the PR head
- [ ] Rebased on whichever of this PR or Ratchet PR #21 (v1.2.2) lands first, with no version collision

## Evidence required

- CI run link and Ternary check link for the final PR head SHA
- A test output excerpt (pass/fail counts) from test-hooks.sh, test-upgrade.sh, test-install.sh, showing the four new cases
- The example project rule file used in tests (db:push / drizzle-kit generate)
- The five-section PR body below, with STATE.md and DECISIONS.md updated

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
- pay

## Original intake

> Add project-level guard rules to Ratchet upstream so granted-ai can block db:push without forking

## Notes from the CoS

Baise's earlier choice, verbatim: "Fix the hook upstream in Ratchet with a brief, then re-sync the installs". In granted-ai #63 (D-20261104-2156) a local fork added `npm run db:push` / `npx drizzle-kit generate` to the guard. The 1.2.1 re-sync (D-20261104-2326) dropped that fork, so db:push is unblocked again. Ratchet PR #21 (rrr-fix-intact-and-upgrade-mode, v1.2.2) is in flight and may touch upgrade.sh. Rebase on whatever lands first and coordinate the version number. Out of scope, noted only: after merge, the granted-ai #63 re-sync adds a project rule file restoring the db:push block.
