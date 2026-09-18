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
<source>/skills/ratchet-init/scripts/install.sh --from <source> --to <repo root> [--claude [--plugin]] [--codex]
```

`--to` must be the repo root. Pass `--claude` and `--codex` only for tools actually used here. Add `--plugin` when the Ratchet plugin is enabled in Claude Code (you are running from it if the source in step 1 was the plugin root): the skills already come from the plugin, and linking them again shows every skill twice in `/skills`. The guard script is still copied so `test-hooks.sh` can exercise it; it just must not be wired into `settings.json`, because the plugin already runs it. The installer echoes the resolved source as `FROM`; repeat it to the owner so they can see where the files came from. Read the `ADD` / `SKIP` / `LINK` lines. A `SKIP ... (exists)` is a file the repo already had: compare it with Ratchet's version and tell the owner what differs. The common case is an existing `CLAUDE.md` (any repo that has used Claude Code has one) and sometimes an existing `AGENTS.md`. Offer the owner the same three options every time, recommended first:

1. **Append** — add Ratchet's contract as a section at the end of the existing file, leaving the owner's rules untouched above it. Right for a short existing file that holds repo knowledge (commands, conventions).
2. **Sidecar** — write Ratchet's version as `AGENTS.ratchet.md` and add one line to the existing file: "Also read `AGENTS.ratchet.md`." Right when the existing file is long or owned by someone else.
3. **Skip** — leave both as they are and note in the report which Ratchet rules are therefore not in force. Right when the owner wants to read Ratchet's version first.

Never replace the existing file, and never create a competing `AGENTS.md` beside a `CLAUDE.md` that already acts as the contract. A `SKIP ... (parent is a symlink)` means a directory such as `.claude` or `.ratchet` points somewhere else (shared dotfiles, another checkout); the installer will not write through it, so ask the owner where those files should live. Never replace it yourself — an existing `AGENTS.md` is someone's contract.

**Done when:** the installer exited 0 and every `SKIP` has been explained.

## 3. Fill the slots from evidence

Open each installed file and resolve every `FILL-ME`. Propose values from what step 1 found, show them as a draft, and let the owner edit before writing:

- **Check command** (`AGENTS.md` → Repo specifics): the one command that lints, typechecks, and tests. Run it before proposing it — but for compiled and mobile stacks (Xcode, Gradle, Rust) a run is minutes and the first attempt usually fails on setup (a stale simulator name, a missing toolchain). Start it in the background as soon as you have a candidate and continue the survey while it runs; expect to iterate. If the repo has no such command, say so — that gap is the most valuable finding of the install, and creating one is a better first task than any rule.
- **High-risk and untested modules:** from churn (`git log --format= --name-only | sort | uniq -c | sort -rn | head`), from what writes data or handles money, auth, or concurrency, and from where tests are absent.
- **Public API / shared contracts, extra hard-stop paths, environment assumptions:** from the code and config, confirmed by the owner.
- **Delegation tiers:** the modules that must change together, the fragile generated files, the worst realistic loss.
- **Codex model routing:** preserve the capability-based criteria in `CODEX.md`; do not replace them with fixed model names. Follow its session-start resolution procedure using the target host's current catalog or exposed tool metadata, and report any fallback. For model slots in the adapter-less table, use host evidence where available; otherwise ask once, up front, alongside the tool question in step 1. If the owner defers, leave those slots `FILL-ME` and say so in the report as a decision, not a gap.
- **`.ratchet/STATE.md`:** write it from the branch's real current state, by hand, following the template's sections — objective, what is done, what is in flight, the check command's actual result, next actions. That is what `ratchet-handoff` would do; you do not need to invoke it mid-install. The stop gate will refuse to finish while any `FILL-ME` remains in it.

Leave a slot as `FILL-ME` rather than guess; list the ones left open.

## 4. Hooks (Claude Code only)

If you passed `--plugin`, wire only the stop gate and the lint hook, and say so: the guard script is on disk for the tests, but the plugin already runs it.

- Set `CHECKS` in `.claude/hooks/check-on-stop.sh` to the check command from step 3. `test-hooks.sh` stages its own copy with the npm defaults, so filling `CHECKS` does not break the suite.
- The lint hook as shipped runs ESLint and only on `.js`/`.ts` files. **In any other stack it exits 0 on every edit and looks like it is working.** Either adapt the file-extension case and the lint command to this repo's linter (`swiftlint lint --path`, `ruff check`, `gofmt -l`, `cargo clippy`, ...) or tell the owner plainly that the lint hook is a no-op here and leave the PostToolUse entry out of the settings merge. The `test-hooks.sh` lint cases only exercise the parser and project-dir paths, so an adapted hook still passes them.
- Merge the `hooks` block from `<source>/claude-code-hooks-settings.json` into `.claude/settings.json` — the `Stop` and `PostToolUse` entries, and the `PreToolUse` guard entry **only if the plugin is not enabled here**. If that file already has hooks, add Ratchet's entries beside them; do not replace the block. Drop the `_readme` and `_purpose` keys. Show the diff before writing.
- Extend the guard's patterns for this stack if the owner wants (`terraform apply`, `kubectl delete`, ...).

## 5. Prove it works

```
.claude/hooks/test-hooks.sh                              # if hooks were installed
.agents/skills/ratchet-bugfix/scripts/test-rrr.sh
```

A hook that silently does nothing looks exactly like a hook that works. `test-hooks.sh` pipes real payloads through the guard and asserts the blocks, so it is the proof that the guard bites. Do not type a payload containing a destructive command into a Bash call yourself: the guard matches command text, so it will block the `printf` that carries it. If you want one manual probe, write the payload to a file with the Write tool and run `.claude/hooks/guard-destructive.sh < payload.json; echo "exit $?"` — expect 2.

**Done when:** both suites pass in the target repo.

## 6. Report

What was added, what was skipped and how it differs, which slots are still open, the test results, and that nothing is committed — committing the install is the owner's call. Finish with `ratchet-done`.

<sub>The shape of this skill — explore, present, confirm drafts, then write; update in place and never create a competing file; verify a hook by piping it a payload — is adapted from `setup-matt-pocock-skills` and `git-guardrails-claude-code` in [mattpocock/skills](https://github.com/mattpocock/skills) (MIT). See `../CREDITS.md`.</sub>
