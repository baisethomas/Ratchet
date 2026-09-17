---
name: ratchet-init
description: Install Ratchet into a repository - the AGENTS.md contract, project memory, skills, and optionally the Claude Code and Codex adapters and hooks - then fill in the repo-specific slots from what the repo actually contains.
disable-model-invocation: true
---

# Ratchet init — install into this repository

Run on request only. This writes files at the repo root; nothing here is done on the agent's own initiative.

The installer never overwrites. The judgement — what the check command is, which modules are high-risk, how hooks merge into existing settings — is yours, and every answer is shown to the owner before it is written.

## 1. Find the source and look at the target

- **Source:** a complete Ratchet `drop-in/` directory. If this skill is running from the Ratchet plugin, that is the plugin root itself — three levels above this file (`SKILL.md` → `ratchet-init/` → `skills/` → the root) — and it contains `AGENTS.md`, so use it. Otherwise (the skills were copied into a repo, so three levels up is the repo root and there is no drop-in `AGENTS.md` beside a `skills/` directory) ask for the path to a Ratchet checkout, or offer to clone `https://github.com/baisethomas/Ratchet` into a temporary directory; cloning is a network call, so wait for a yes.
- **Target:** read before proposing anything — which of `AGENTS.md`, `CLAUDE.md`, `CODEX.md`, `.ratchet/`, `.agents/skills/`, `.claude/skills/`, `.claude/hooks/`, `.claude/settings.json` already exist; the build and test tooling (`package.json` scripts, `Makefile`, `pyproject.toml`, CI workflows); which agent tools the owner uses here.

**Done when:** you can list what exists, what is missing, and which tools (Claude Code, Codex, other) are in play.

## 2. Propose, then install

Tell the owner what will be added and what will be skipped, and get a yes. Then:

```
<source>/skills/ratchet-init/scripts/install.sh --from <source> --to <repo root> [--claude] [--codex]
```

`--to` must be the repo root. Pass `--claude` and `--codex` only for tools actually used here. Read the `ADD` / `SKIP` / `LINK` lines. A `SKIP ... (exists)` is a file the repo already had: compare it with Ratchet's version and tell the owner what differs. A `SKIP ... (parent is a symlink)` means a directory such as `.claude` or `.ratchet` points somewhere else (shared dotfiles, another checkout); the installer will not write through it, so ask the owner where those files should live. Never replace it yourself — an existing `AGENTS.md` is someone's contract.

**Done when:** the installer exited 0 and every `SKIP` has been explained.

## 3. Fill the slots from evidence

Open each installed file and resolve every `FILL-ME`. Propose values from what step 1 found, show them as a draft, and let the owner edit before writing:

- **Check command** (`AGENTS.md` → Repo specifics): the one command that lints, typechecks, and tests. Run it before proposing it. If the repo has no such command, say so — that gap is the most valuable finding of the install, and creating one is a better first task than any rule.
- **High-risk and untested modules:** from churn (`git log --format= --name-only | sort | uniq -c | sort -rn | head`), from what writes data or handles money, auth, or concurrency, and from where tests are absent.
- **Public API / shared contracts, extra hard-stop paths, environment assumptions:** from the code and config, confirmed by the owner.
- **Delegation tiers:** the modules that must change together, the fragile generated files, the worst realistic loss. In `CODEX.md` or the adapter-less table, the models the owner actually has.
- **`.ratchet/STATE.md`:** initialise from the branch's real current state with `ratchet-handoff`, not from the template's placeholders.

Leave a slot as `FILL-ME` rather than guess; list the ones left open.

## 4. Hooks (Claude Code only)

If the Ratchet plugin is enabled here, the destructive-command guard already runs from the plugin; installing `.claude/hooks/guard-destructive.sh` as well would run it twice. Wire only the stop gate and the lint hook, and say so.

- Set `CHECKS` in `.claude/hooks/check-on-stop.sh` to the check command from step 3.
- Merge the `hooks` block from `<source>/claude-code-hooks-settings.json` into `.claude/settings.json` — the `Stop` and `PostToolUse` entries, and the `PreToolUse` guard entry **only if the plugin is not enabled here**. If that file already has hooks, add Ratchet's entries beside them; do not replace the block. Drop the `_readme` and `_purpose` keys. Show the diff before writing.
- Extend the guard's patterns for this stack if the owner wants (`terraform apply`, `kubectl delete`, ...).

## 5. Prove it works

```
.claude/hooks/test-hooks.sh                              # if hooks were installed
.agents/skills/ratchet-bugfix/scripts/test-rrr.sh
```

A hook that silently does nothing looks exactly like a hook that works. Then pipe one blocked command through the guard and confirm exit 2:

```
printf '{"tool_name":"Bash","tool_input":{"command":"git push --force"}}' | .claude/hooks/guard-destructive.sh; echo "exit $?"
```

**Done when:** both suites pass in the target repo and the guard returned exit 2.

## 6. Report

What was added, what was skipped and how it differs, which slots are still open, the test results, and that nothing is committed — committing the install is the owner's call. Finish with `ratchet-done`.

<sub>The shape of this skill — explore, present, confirm drafts, then write; update in place and never create a competing file; verify a hook by piping it a payload — is adapted from `setup-matt-pocock-skills` and `git-guardrails-claude-code` in [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). See `../CREDITS.md`.</sub>
