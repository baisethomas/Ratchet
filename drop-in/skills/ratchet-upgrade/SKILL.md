---
name: ratchet-upgrade
description: Bring a repository's installed Ratchet drop-ins (the contract, adapters, hooks, and skills) up to a newer release without losing the owner's filled-in answers. Use when the Ratchet plugin or checkout is newer than what a repo was set up with, or when the owner asks to update Ratchet in a repo.
disable-model-invocation: true
---

# Ratchet upgrade — newer release, same answers

Run on request only. `ratchet-init` never overwrites, so a repo keeps the release it was installed from until this runs. The plugin half (skills and the guard in Claude Code) updates with `/plugin marketplace update ratchet` then `/plugin update ratchet@ratchet`; this skill handles the per-repo half.

The script does the mechanical part: it compares every installed file with the new release and, where it can, replays the owner's edits onto the new template as a three-way merge. The judgment — which proposals land, how conflicts resolve — is yours, and every write waits for the owner's yes.

## 1. Find the source, the target, and the installed version

- **Source:** a complete Ratchet `drop-in/` at the new release. From the plugin, that is the plugin root (three levels above this file). Otherwise a Ratchet checkout's `drop-in/`.
- **Target:** the repo root. Confirm `AGENTS.md` and `.ratchet/` exist; if not, this is an install, not an upgrade: use `ratchet-init`.
- **Installed version:** `grep ratchet-version AGENTS.md` in the target. Releases before 1.2.0 carry no marker; tell them apart by content: an `AGENTS.md` with a "What enforces these rules" section is 1.1.0, one without is 1.0.0. Pass that as `--installed-version` once; the marker travels from then on.

**Done when:** you can name the source path, the new version, and the installed version.

## 2. Run the report

```
<source>/skills/ratchet-upgrade/scripts/upgrade.sh --from <source> --to <repo root> [--installed-version X.Y.Z]
```

It writes nothing in the repo. Read the `INFO base:` line first: without a base there is no merge, only a diff. The base comes from the source checkout's history by version; if the source is not a git checkout, or the owner installed from a specific commit, pass `--base <drop-in at that version>`.

Then read each status line. `SAME`, `MEMORY`, `ABSENT`, and `SKIP` need nothing. `NEW` is a file the release added (a new skill, a new script). `MERGE` has a clean proposal in the staging directory. `CONFLICT` has a proposal with markers. `NOBASE` has no proposal.

**Done when:** every file has a status and you know which ones carry a proposal.

## 3. Show the owner each proposal, then get a yes per file

- For each `MERGE`: `diff -u <repo>/<path> <stage>/<path>`. Check that every slot the owner filled (the check command, the high-risk modules, `CHECKS` in the stop hook, the model table) survived unchanged, and that the new release's sections are present. If a filled slot came back as `FILL-ME`, the base was wrong: stop and find the right one rather than apply.
- For each `CONFLICT`: open the staged proposal, resolve the markers by hand with the owner's edits kept and the release's change applied, and show the result as a diff. Never apply a file that still contains conflict markers.
- For each `NOBASE`: show `diff -u` and merge by hand, or find a base and re-run.
- `.ratchet/STATE.md` and `.ratchet/DECISIONS.md` are never touched; they are live memory, not templates.
- Rewording `AGENTS.md` is orchestrator-tier work under the contract: the owner sees that diff before it lands, every time.

**Done when:** the owner has said yes to a named list of paths.

## 4. Apply only what was approved

```
<source>/skills/ratchet-upgrade/scripts/upgrade.sh --from <source> --to <repo root> [--installed-version X.Y.Z] --apply <path> [--apply <path> ...]
```

The script recomputes each merge and writes only `MERGE` and `NEW` results. A path named with `--apply` in any other state is refused with exit 1. `--apply-all` takes every `MERGE` and `NEW`, passes over files with nothing to apply, and reports each `CONFLICT` and `NOBASE` as `LEFT` with exit 1, since the repo is not on the new release until those are merged by hand. Hand-resolved conflicts are written by you, as ordinary edits, after the owner has seen them. A second run must report `SAME` or `CURRENT` for everything applied.

**Done when:** the paths the owner approved are upgraded, a re-run shows them `SAME`, and `git status` shows only those files changed.

## 5. Prove the upgraded install still works

- Claude Code: run `.claude/hooks/test-hooks.sh`; it stages its own copy of the stop hook, so a filled `CHECKS` line does not break it.
- Run the repo's check command from `AGENTS.md` → Repo specifics.
- If skills were upgraded: run `.agents/skills/ratchet-bugfix/scripts/test-rrr.sh` and `.agents/skills/ratchet-handoff/scripts/test-runlog.sh`.

**Done when:** the suites you ran are green, or the report says exactly which is not and why.

## 6. Report

Which files were upgraded, from which version to which, what was refused or left for a later pass and why, and the suites that ran. Then `ratchet-done`.
