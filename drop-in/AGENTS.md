# AGENTS.md — Canonical Working Rules for This Repository

<!--
DROP-IN: place this file at the repo root.
This is Ratchet's model-agnostic operating contract. Any coding agent entering the repo should read this first.
Tool-specific files such as CLAUDE.md should point here rather than duplicate these rules.
-->

## Before any edit

- Read `.ratchet/STATE.md` and `.ratchet/DECISIONS.md` if they exist before planning.
- Read the files you'll change AND their call sites before forming a plan. The repo is context the user didn't type.
- For anything beyond a trivial change, state the plan before editing.
- Resolve three things first: what behavior changes (intent), what's allowed to change (blast radius), and what proves it's done (passing test, reproduced-then-fixed bug, green build, or other explicit check).

## Project memory

- Treat `.ratchet/STATE.md` as the current semantic handoff for the project.
- Treat `.ratchet/DECISIONS.md` as durable shared project memory.
- Do not replay or preserve chat transcripts as project memory. Store only context a fresh competent agent cannot safely infer from the repository.
- You may update `STATE.md` as work progresses.
- You may propose new decisions, but do not silently add, supersede, or remove accepted decisions without explicit human approval.
- If repository reality conflicts with state or decisions, stop and report the conflict instead of choosing one silently.

## Checkpoint discipline

- One conceptual change per step. Each step ends with the repo in a known-good state.
- Never batch edits across a failing state. Never stack a later step on an unverified earlier one.
- Do the riskiest or most informative step first so a fatal discovery happens early.

## Verification

- Never claim tests pass without running them.
- Reproduce a bug before fixing it whenever reproduction is possible.
- After writing a regression test, prove it can fail by reverting or disabling the fix, confirm failure, restore the fix, and confirm pass.
- Check installed-version APIs rather than relying on memory.
- If a test fails and the cause is not understood, stop and report. Do not hide, bypass, or reshape the test merely to produce green output.

## Scope law

- No drive-by changes: no unrelated reformatting, renames, cleanup, or debug output.
- Before summarizing, inspect the full diff and justify every hunk against the request.
- If one behavior change requires touching many files, call out the blast radius and reconsider whether the change is happening at the right layer.

## Hard stops

Require explicit human approval before:

- destructive database migrations or irreversible data changes
- force pushes, history rewrites, branch deletion, or destructive git operations
- deleting files or data outside the immediate task
- sending data to external systems when the task did not already authorize it
- changing public API surfaces or other shared contracts
- accepting, superseding, or removing durable decisions in `.ratchet/DECISIONS.md`
- anything listed as project-specific hard-stop territory below

## Reporting format

Every nontrivial completion summary should contain, in order:

1. **What changed** — the behavior, first.
2. **Shape & why** — files touched, approach chosen, and why if alternatives were live.
3. **Verification** — what was actually run/read/assumed. Never collapse these categories.
4. **Residue** — assumptions, untested paths, follow-ups, and deliberately untouched issues.
5. **Handoff** — confirm `.ratchet/STATE.md` reflects the current objective, completed work, blockers, verification status, and next action.

## Repo specifics

<!-- FILL-ME: repository-specific operating knowledge -->
- Run everything: `make check` <!-- FILL-ME -->
- Run tests only: <!-- FILL-ME -->
- Known untested / high-risk modules: <!-- FILL-ME -->
- Public API / shared contract surface: <!-- FILL-ME -->
- Environment assumptions worth stating: <!-- FILL-ME -->
- Additional hard-stop paths or operations: <!-- FILL-ME -->

## Self-test before every "done"

1. Did I run the available checks, or does the change merely read correct?
2. Does the diff contain only the intended change, and can I justify every hunk?
3. What did I assume about environment, versions, or project state, and did I state it?
4. For a bug fix, do I have evidence the regression test can fail without the fix?
5. Did anything irreversible, shared, or decision-level require human approval?
6. Could a fresh agent continue from `.ratchet/STATE.md` without this conversation?

Any "no" means the work is not done yet.
