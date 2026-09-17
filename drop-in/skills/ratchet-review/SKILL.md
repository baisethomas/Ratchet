---
name: ratchet-review
description: Hostile review of a diff by a fresh-context reviewer, with every finding verified before it is acted on. Use when the user asks to review a branch, PR, or diff, and before accepting high-risk work as done.
---

# Ratchet review — hostile diff review

`AGENTS.md` sets the rules: reviews go up a tier, and verification is evidence. This is the procedure. It adds no rules; if it ever disagrees with `AGENTS.md`, `AGENTS.md` wins.

The author of a diff is the worst-placed reader of it. The review happens in a context that never saw the reasoning, only the result.

## 1. Pin the comparison

- Decide what is being reviewed. **Everything since a base** (a branch, a PR, "since `main`"): the diff is `git diff <base>...HEAD`, where the base is what the user named, else the merge-base with the main branch. **One named commit** ("review `abc123`", "review the last commit"): the diff is `git diff <commit>^ <commit>` — comparing a commit with itself is empty, and `<commit>...HEAD` would review everything *after* it instead.
- Confirm every ref resolves (`git rev-parse <ref>`) and that the diff is non-empty. A bad ref fails here, not inside a reviewer.
- Write one sentence stating what the change was asked to do. The reviewer judges scope against that sentence, so get it from the request, the issue, or `.ratchet/STATE.md` — not from the diff.

**Done when:** you have a diff command that produces output, a commit list, and the one-sentence task.

## 2. Hand it to a fresh reviewer

Delegate to a subagent with no access to this conversation, on a model at least as strong as the one that wrote the diff (`AGENTS.md` → Delegation and model tiers). If delegation is not authorized or not available, stop and tell the owner to run step 3's brief in a new session; a self-review in the authoring context is not this skill.

Give the reviewer only: the diff command, the commit list, the task sentence, and the repo's check command.

## 3. The brief

> Review this diff as a hostile senior engineer. You did not write it. Do not defend it and do not fix it. Where a claim can be checked by running something cheap — the check command, a one-line probe, a test with a hostile input — run it and quote the output instead of reasoning about it.
>
> 1. HOSTILE INPUTS — for each changed function or script: empty input, null, unicode, a missing or unreadable file, a path outside the expected directory, a symlink, a concurrent second call, an interruption halfway.
> 2. SCOPE — every hunk not strictly required by the task sentence: debug output, reformatting, renames, duplicated helpers, behavior nobody asked for.
> 3. SWALLOWS — broadened catches, ignored errors and exit codes, suppressed type or lint errors, tests weakened or skipped to pass.
> 4. MEMORY-BASED API CALLS — any library or CLI call whose signature was not checked against the installed version.
> 5. TESTS THAT CANNOT FAIL — new tests whose expected value is computed the way the code computes it, or that would pass with the change reverted.
> 6. SIMPLICITY — is there a version of this change with half the diff? Sketch it in three lines.
>
> For each finding: file and line, what breaks, the input or sequence that breaks it, and whether you RAN it or READ it. Findings only, most severe first, under 500 words.

## 4. Verify before acting

A finding is a claim, and reviewers are confidently wrong as often as authors. For each one, most severe first:

- **Reproduce it** — as a failing test where the codebase allows (then `ratchet-bugfix`), otherwise as a command whose output shows the problem.
- **Reproduced:** fix it, or record it in the report's Residue if it is outside the task.
- **Not reproduced, or built on a false premise:** say so, with the evidence. Do not change code to satisfy a finding you could not make fail.
- **Real but out of scope** (it needs an adversary who already has the user's permissions, or a requirement nobody has): decline it and state the scope line in the code or docs, so the next reviewer sees it was a decision.

**Done when:** every finding is marked fixed, declined with a reason, or deferred to Residue — none silently dropped.

## 5. Stop rule

Re-review after fixes, but stop when a round produces only variations on something already declined. Report the remaining disagreement to the owner instead of patching past the scope line.

Finish with `ratchet-done`. Its verification section lists each finding and its outcome.

<sub>Pinning and validating the fixed point before spawning reviewers, and capping each reviewer's brief, are adapted from the `code-review` skill in [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). See `../CREDITS.md`.</sub>
