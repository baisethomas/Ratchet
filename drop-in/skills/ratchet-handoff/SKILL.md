---
name: ratchet-handoff
description: Refresh .ratchet/STATE.md and record durable decisions so a fresh agent can continue without this conversation. Use when ending a nontrivial session, switching models or tools, when context is about to be compacted or cleared, or when the user asks for a handoff.
---

# Ratchet handoff — leave the branch continuable

`AGENTS.md` sets the rules for project memory: what `STATE.md` and `DECISIONS.md` are, the autonomy ladder, and memory safety. This is the procedure. It adds no rules; if it ever disagrees with `AGENTS.md`, `AGENTS.md` wins.

The test for everything below: could a competent agent who has never seen this conversation pick up this branch tomorrow?

## 1. Establish what is true now

Run these; do not recall them:

```
git status --short
git log --oneline -5
git branch --show-current
```

Then run the check command from `AGENTS.md` → Repo specifics, or find the most recent run whose output you actually saw *after* the last edit. "Known green" means a command and a result.

**Done when:** you can name the branch, the last known-good commit, and the current result of the check command.

## 2. Rewrite STATE.md — replace, never append

If `.ratchet/STATE.md` does not exist, copy the template first (`ratchet-init` installs it). Then rewrite each section from step 1's facts:

- **Delete what is stale.** Finished items leave "Working on". History older than this workstream leaves "Completed". This file is a dashboard, not a diary.
- **Point, don't copy.** Anything already captured elsewhere — a commit, a PR, an issue, a spec, a decision entry — is referenced by hash, number, or path. Duplicated text goes stale; a pointer does not.
- **Keep only what cannot be inferred.** If a fresh agent could learn it from the code, the tests, or `git log`, it does not belong here. What belongs: why the obvious approach was rejected, which check is flaky and how, what is half-done and in which file.
- **"Next" is ordered and concrete** — the next three actions, each startable without asking anyone.
- **"Open risks / assumptions"** takes the ASSUMED bin from `ratchet-done`, if you ran it.
- Fill in "Last handoff": date, tool and model, branch, last known-good commit.

**Done when:** every section is current or says `None`, no `FILL-ME` remains, and nothing in it repeats what `git log` already says.

## 3. Decisions — classify before writing

For each choice made this session that will constrain future work, place it on the `AGENTS.md` ladder. A useful filter for whether it is worth an entry at all — it should be all three of: **hard to reverse**, **surprising to someone reading the code**, and **the result of a real trade-off** with a live alternative.

- Fails the filter → low impact. Leave it in the code.
- Passes, reversible, inside the task's authorized scope → medium. Append an `accepted` entry to `.ratchet/DECISIONS.md` using its format and ID scheme, including the rejected alternative.
- Passes, with large blast radius or difficult reversal → high. Append it as `proposed`, do not act on it, and put it in front of the owner.

Never edit or delete an existing entry. To change one, mark it `superseded` and append the replacement.

**Done when:** every medium decision has an entry, every high one is `proposed` and surfaced, and no prior rationale was rewritten.

## 4. Safety pass

Read both files once more for anything that must not be repository-visible: secrets, tokens, credentials, customer or personal data, sensitive incident detail, pasted transcripts. Replace each with a sanitized reference to where the protected information lives.

## 5. Say what you did

Tell the owner: that `STATE.md` is current for this branch, which decisions were recorded, which are awaiting approval, and — if the next session will use skills — which ones it should start with. If the branch has uncommitted work, say so; a handoff describing work that exists only in a working tree is fragile.

<sub>"Point, don't copy", the suggested-skills note, and the three-part decision filter are adapted from the `handoff` and `domain-modeling` skills in [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). See `../CREDITS.md`.</sub>
