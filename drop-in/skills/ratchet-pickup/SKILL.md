---
name: ratchet-pickup
description: Resume a branch from .ratchet/STATE.md without redoing the prior agent's work and without trusting its self-report. Use when starting a session on a branch that has project memory, taking over another agent's or model's in-flight work, or continuing after context was compacted or cleared.
---

# Ratchet pickup — read the trail, verify the claims, redo nothing

`AGENTS.md` sets the rules: read project memory before planning, trust verified repository reality over stale state, and never accept a "done" on trust. This is the read side of `ratchet-handoff`. It adds no rules; if it ever disagrees with `AGENTS.md`, `AGENTS.md` wins.

Two failures this prevents. **Redoing the trail:** a "let me verify everything from scratch" pass treats an authoritative handoff as noise and spends the session re-deriving it. **Trusting the trail:** a prior agent's "tests green" is a self-report, and a self-report is not proof. The trail says where to look; git and the check command say what is true.

## 1. Read the trail before anything else

- Read `AGENTS.md`, then `.ratchet/STATE.md`, then `.ratchet/DECISIONS.md`. If a run log exists (`.ratchet/run.tsv`, written by `ratchet-handoff`'s `runlog.sh`), read its last rows; a `start` row marks where an earlier run began.
- The prior session's transcript, if one is reachable, is not the trail. `STATE.md` is. Open a transcript only to resolve a specific gap the state file names, and keep what you learn out of the state file unless a fresh agent would need it.
- No `STATE.md` → this is not a pickup. Reconstruct from `git log`, `git diff <base>...HEAD`, and open PRs, then write `STATE.md` with `ratchet-handoff` before planning anything.

**Done when:** you can say in two sentences what the prior agent was driving toward and where it says it stopped.

## 2. Establish what is true now

Run these; do not recall them:

```
git status --short
git branch --show-current
git log --oneline -10
git merge-base --is-ancestor <last-known-good-commit> HEAD && echo reachable
```

- If the known-good commit is not reachable, the branch was rebased, squashed, or reset since the handoff. The claim "known green at that commit" covers a patch, not a hash: find the same patch with `git show <commit> | git patch-id --stable` against the reflog and the current branch. If the patch is there unchanged, the claim survives; if it changed or cannot be found, the claim is void and "Verification status" is stale.
- Run the check command from `AGENTS.md` → Repo specifics once. This is not redoing the prior work; "Verification status" described a different moment than now.
- Uncommitted files in `git status` that `STATE.md` does not mention are a finding. Do not stash, revert, or commit them until you know what they are.

**Done when:** you can name the branch, HEAD, whether the known-good commit still describes the code, and the check command's current result.

## 3. Verify each inherited claim against the real artifact

Go through `STATE.md` line by line and mark each claim **holds**, **stale**, or **cannot check**:

- Each "Working on" line's tag, against git and the forge: `[merged #N]` — the PR is merged and its commits are on the base; `[open PR #N]` — the PR exists, is open, and its head is this branch; `[in flight <branch>]` — the branch exists and has commits beyond the base; `[verified, uncommitted]` — the files are in `git status` and the check command passes now; `[reverted #N]` — the revert is on the branch; `[planned, not started]` — nothing to check. A line with no tag is not done; check it and tag it.
- "Verification status": a prior pass is a self-report. If step 2's run disagrees, reality wins and the line is stale.
- "Blocked": test whether each blocker still holds with one cheap check (the service is up, the dependency landed, the owner answered).
- "Completed" and `DECISIONS.md`: spot-check that what they describe is in the code, with a grep or a file read each, not a re-implementation.

Verify claims, not labor. Do not re-run the prior reproduction, re-apply a completed migration, or rewrite finished code to see whether you would have done it the same way. If a claim cannot be checked from here, say so and carry it as ASSUMED, never upgrade it to holds.

**Done when:** every claim in `STATE.md` carries one of the three marks.

## 4. Repair state, then name the resume point

- Fix every **stale** line in `STATE.md` so it describes the code and tests as they are now. Replace; do not append a note saying the old line was wrong.
- If an accepted `DECISIONS.md` entry conflicts with repository reality, stop and report the conflict. `AGENTS.md` forbids choosing silently.
- Name the resume point: the first "Next" item that is startable now, or the first stale claim that must be resolved before any "Next" item can start.

**Done when:** `STATE.md` is true now and the first action is named and startable.

## 5. Route and report

- Continue with the skill the resume point calls for (`ratchet-bugfix` for a bug, `ratchet-review` before accepting inherited high-risk work, `ratchet-done` when the inherited work turns out to be finished). The pickup ends here; the routed skill owns the rest.
- Tell the owner: where the prior agent stopped, which claims held and which were stale, what you redid (ideally nothing), whether inherited uncommitted work is now committed, and the resume point.

Any step you skipped stays in that report as `skip: <reason>`.

<sub>Treating the prior trail as authoritative input while verifying its claims against the real artifact, the status-tag vocabulary, and the `git patch-id` check for a verdict that outlived a rebase are adapted from the `session-pickup` and `shipping` playbooks and the `recall` skill in Lauren Tan's [pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT). See `../CREDITS.md`.</sub>
