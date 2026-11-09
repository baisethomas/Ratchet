# Ratchet — The Operator Playbook

[![GitHub Repo](https://img.shields.io/badge/GitHub-baisethomas%2FRatchet-181717?logo=github&logoColor=white)](https://github.com/baisethomas/Ratchet)

Everything needed to run the craft — with any model — as drop-in files. Nothing here requires the strongest model; that's the point.

**Why "Ratchet":** the mechanism that only turns one way. The model's ceiling is fixed; the system's isn't. Every failure that escapes produces one permanent addition to the process — a rule, a hook, a test, an escalation gate, or a durable project-memory update — and the system never slips backward.

Ratchet treats the repository as the durable source of truth. Conversation history is disposable. A fresh agent should be able to enter a branch/workstream, recover the current objective and constraints, do verifiable work, maintain project memory, and leave a clean handoff without replaying prior chats or making the human act as the synchronization layer.

## What's in the box

| File | What it is | Where it goes |
|---|---|---|
| `PLAYBOOK.md` | The full manual: chat craft, code craft, project memory, and the compensation layer | Read it once; keep it as the reference |
| `drop-in/AGENTS.md` | Canonical, model-agnostic repo operating contract, including the delegation tiers (what each tier owns and never does), routing rules, the single-model fallback, and an optional tier-to-model table for tools with no adapter | Copy to the repo root of every project. Fill the `FILL-ME` sections |
| `drop-in/CLAUDE.md` | Thin Claude Code adapter that points to `AGENTS.md` and adds Claude-specific behavior only, plus the tier-to-model table for Claude Code (Fable orchestrates, or Opus where Fable is unavailable; Opus and Sonnet operate; Haiku handles git and docs) | Copy to the repo root when using Claude Code |
| `drop-in/CODEX.md` | Thin Codex adapter: what changes without Claude Code's hooks, plus capability-based model routing resolved from the host's current catalog each session | Copy to the repo root when using Codex. No fixed model names to maintain |
| `drop-in/STATE.md` | Mutable branch/workstream handoff: objective, current phase, active work, blockers, verification, risks, and next actions | Copy to `.ratchet/STATE.md`; agents maintain it automatically |
| `drop-in/DECISIONS.md` | Durable decision ledger with an autonomy ladder for low, medium, and high-impact choices | Copy to `.ratchet/DECISIONS.md`; agents maintain it, escalating only high-impact decisions |
| `drop-in/claude-ai-project-instructions.md` | ~180-word epistemics core | Claude.ai → Project → Custom instructions (or Settings → Preferences for account-wide) |
| `drop-in/api-system-prompt.txt` | Reliability rules + optional second-pass reviewer prompt | Appended to the system prompt of any API-powered app |
| `drop-in/review-prompts.md` | Copy-paste prompts for adversarial review and verification | Keep available for manual/fresh-context review passes |
| `drop-in/claude-code-hooks-settings.json` | Post-edit lint hook (one linter per file type; a mapped type with no linter installed is reported, not skipped), stop-hook test gate (also refuses to finish while `.ratchet/` memory still says `FILL-ME`), destructive-command guard | Merge into `.claude/settings.json` in the repo; copy `drop-in/hooks/` alongside it |
| `drop-in/hooks/` | Tested verification/guard scripts. `guard-destructive.sh` also reads optional project-owned extra rules at `.ratchet/guard-destructive.rules` (see below) | Copy to `.claude/hooks/`, configure, and run `test-hooks.sh` |
| `drop-in/.claude-plugin/`, `drop-in/plugin-hooks.json`, `.claude-plugin/marketplace.json` | The same skills plus the destructive-command guard, packaged as a Claude Code plugin; the repo is its own marketplace. `tests/test-plugin.sh` checks the manifests point at real, working things | `/plugin marketplace add baisethomas/Ratchet`, then `/plugin install ratchet@ratchet`. Then `/ratchet:ratchet-init` in each repo for the parts that must live there (it passes `--plugin` to the installer so skills and the guard are not installed twice) |
| `drop-in/skills/` | Eight procedures agents load on their own when the task matches. `ratchet-done`: completion gate (diff audit, checks, RAN / READ / ASSUMED / INCONCLUSIVE, state refresh). `ratchet-bugfix`: reproduce, fix, then `rrr.sh` proves the test fails without the fix; after two fixes on one premise fail, the premise is tested before a third. `ratchet-review`: hostile review in a fresh context, every finding reproduced before it is acted on, with a stop rule. `ratchet-handoff`: commit dirty work as `wip:`, rewrite `STATE.md` with tagged in-flight lines, classify and record decisions; `runlog.sh` keeps an append-only run log for long runs. `ratchet-pickup`: the read side — verify each inherited claim against git and the check command, repair stale state, name the resume point, redo nothing. `ratchet-tighten`: turn an escaped failure into one permanent fix, a check before a rule, and keep the rule-to-enforcer table in `AGENTS.md` current. `ratchet-init`: install all of this into a repo with `install.sh`, which never overwrites (user-invoked only). `ratchet-upgrade`: bring an older install to the current release with `upgrade.sh`, a three-way merge that keeps the owner's filled slots, never touches `.ratchet/`, and writes only on `--apply` (user-invoked only). Rules stay in `AGENTS.md`; skills only carry the how. Ideas adapted from Matt Pocock's skills and Lauren Tan's pstack are listed in `drop-in/skills/CREDITS.md` | Run `drop-in/skills/ratchet-init/scripts/install.sh`, or copy to `.agents/skills/` and symlink `.claude/skills` to it. Then run `ratchet-bugfix/scripts/test-rrr.sh`, `ratchet-handoff/scripts/test-runlog.sh`, and `ratchet-upgrade/scripts/test-upgrade.sh` |
| `drop-in/done-audit-checklist.md` | Short acceptance audit for every nontrivial "done" | Use at final review, especially on high-risk work |
| `drop-in/graduation-rule.md` | When a recurring workflow graduates from prompts to a pipeline | Apply after a workflow repeats with the same shape |
| `drop-in/pipeline-skeleton.py` | Example graduated workflow | Use only when the workflow warrants orchestration |
| `drop-in/test_pipeline_skeleton.py` | Tests for the example review gate | Run after changing the pipeline gate |

## The three layers

Ratchet separates three failure classes instead of asking model capability to cover all of them:

1. **Behavior** — `AGENTS.md` is the canonical operating contract. Tool-specific adapters such as `CLAUDE.md` point to it instead of duplicating universal rules.
2. **State** — `.ratchet/STATE.md` and `.ratchet/DECISIONS.md` give a fresh agent the minimal non-inferable context needed to continue a branch/workstream and understand durable decisions.
3. **Verification** — hooks, tests, adversarial review, and the done audit prove the work instead of trusting the model's confidence.

`STATE.md` is deliberately small and mutable. `DECISIONS.md` is durable and append-oriented. Neither is a transcript store.

## Core invariants

Ratchet should remain simple enough to drop into any repository. The system is hardened around seven invariants:

1. A fresh agent does not depend on the previous model or conversation.
2. The human is not responsible for routine project-memory bookkeeping.
3. Project memory stays compressed and excludes facts already inferable from the repository.
4. Git remains the integration mechanism; Ratchet does not build a second live synchronization layer.
5. Durable accepted decisions are not silently lost or rewritten.
6. High-impact, shared-state, or irreversible operations cannot silently exceed the agent's authority.
7. Secrets, personal/customer data, and sensitive incident details never become committed project memory.

## State and Git

`STATE.md` describes the **current branch/workstream**, not a globally synchronized live project database. Two branches may legitimately have different state while they are doing different work.

That is intentional. Git already provides the integration mechanism:

```text
branch/workstream
      ↓
    work
      ↓
  STATE.md
      ↓
     PR
      ↓
 review/merge
      ↓
integration agent reconciles state
      ↓
clean post-integration STATE.md
```

Do not add filesystem locks, remote locks, journals, background daemons, or cross-clone synchronization merely to keep `STATE.md` globally current. At integration, reconcile incoming state against the resulting code and tests. Repository reality, once verified, wins over stale state.

`DECISIONS.md` is append-oriented. Parallel branches may add compatible decisions independently. Git merge semantics are sufficient for ordinary cases. If accepted decisions materially conflict, surface that conflict explicitly instead of auto-resolving it.

## Decision autonomy

Ratchet is designed to keep the human at the big-picture layer:

- **Low impact:** routine implementation choices stay in code unless their rationale would otherwise be lost.
- **Medium impact:** durable, reversible choices within authorized scope are decided and recorded by the agent, then surfaced in the completion summary.
- **High impact:** architecture replacement, destructive data changes, major dependency/platform changes, public/shared contract changes, security-sensitive policy changes, or material product-scope changes require explicit human approval before acceptance or execution.

Database migrations are treated separately as a hard stop when they may affect a shared environment, even if the proposed migration appears additive or reversible.

## Project-memory safety

By default, `.ratchet/STATE.md` and `.ratchet/DECISIONS.md` are intended to be committed so project memory travels with the repository. That means agents must treat them as repository-visible information: never store secrets, credentials, access tokens, personal/customer data, or sensitive security/incident details. Store sanitized references to the approved protected system instead.

If the project requires private memory, gitignore `.ratchet/` or use the project's approved private store. This trades away automatic cross-clone continuity unless that private store is available to every agent.

## Project-owned guard rules

A project can block extra commands in `guard-destructive.sh` without forking Ratchet files. Create this file in the **project**, not in Ratchet's `drop-in/`:

```text
.ratchet/guard-destructive.rules
```

**Why that path.** `.ratchet/` is already project-owned (`STATE.md`, `DECISIONS.md`, `run.tsv`). The rules file is not a Ratchet template: `install.sh` will not seed it and will `SKIP` that destination even if a source later ships a copy; `upgrade.sh` classifies it `MEMORY` and never writes it. The hook finds it from the project root (`CLAUDE_PROJECT_DIR`, else `git rev-parse --show-toplevel`, else `.`), so the same file is used whether the hook is running from `.claude/hooks`, from `${CLAUDE_PLUGIN_ROOT}/hooks`, or from any other copy.

**Syntax.** Line-oriented text.

- Blank lines are ignored.
- A line whose first non-whitespace character is `#` is a comment.
- Leading and trailing whitespace on each line is trimmed. A trailing CR is stripped, so CRLF files match the same as LF.
- Every remaining line is an unanchored POSIX ERE, matched with `grep -E --` against the same **normalized** command text the default rules use (quotes stripped, operators padded). `--` means a pattern may start with `-`. `drizzle-kit generate` therefore also matches `npx drizzle-kit generate`. To require a token boundary, write it in the pattern (`npm run db:push([[:space:]]|$)`).

**How it combines with the defaults.** Project patterns are **additive**. They cannot disable or weaken a default rule. Defaults run first, so `git push --force` and `drizzle-kit push` still block when the file is present. A matching project pattern is reported as `project rule '<pattern>'` in the BLOCKED message.

**Missing or empty.** No file, an empty file, or a file that is only comments and blank lines: defaults only.

**Malformed or unreadable.** Fail closed, same class as a missing `lib-payload.sh`: if the path exists but is not a readable regular file, if the file cannot be read after that probe succeeded, or if any pattern is not a valid POSIX ERE, every real command exits 2 with a BLOCKED line that names `.ratchet/guard-destructive.rules`. "Cannot verify" is not treated as "nothing to block". A missing trailing newline, an empty file, and a comment-only file are not read failures.

Example (blocks `npm run db:push` and `drizzle-kit generate`, including the `npx` form):

```
# Extra blocked commands for this project. Combined with Ratchet defaults.
npm run db:push
drizzle-kit generate
```

## Upgrade: bytes and permission bits

`upgrade.sh` treats an installed file as `SAME` only when both the bytes and the permission bits (`st_mode & 0777`) match the new release. Group/other drift that leaves the owner-exec bit unchanged (0755 vs 0711, 0644 vs 0600) is `MERGE` with `mode differs`, in report mode and in apply. Apply copies those nine bits onto the staged file; it does not `chmod +x`/`chmod -x` after `mktemp` (0600), which used to land hooks at 0711 and ordinary files at 0600. Setuid, setgid, and sticky are stripped, so a 4755 upstream lands as 755.

The bits are read with GNU `stat -c '%a'`, then BSD/macOS `stat -f '%OLp'`, then `python3`. Only a 3–4 digit octal string is trusted, so macOS `stat -c` (a different flag) cannot be mistaken for a mode. `chmod --reference` is not used.

This is a medium-impact product decision (D-20261105-0007-upgrade-full-mode-bits). The Ratchet checkout has no root `.ratchet/`, so it is recorded here rather than in live project memory: `skip: no root .ratchet/ in Ratchet repo`.

This is a medium-impact product decision (D-20261105-0040-semver-1-3-0-minor). Version 1.3.0 is a minor bump: the project rules file is a backward-compatible new feature (installs without it behave as before), and the mode-restore fix rides along in the same unreleased minor after 1.2.2 already shipped. The Ratchet checkout has no root `.ratchet/`, so it is recorded here rather than in live project memory: `skip: no root .ratchet/ in Ratchet repo`.

This is a medium-impact product decision (D-20261105-0060-semver-1-3-1-patch). Version 1.3.1 is a patch: `runlog.sh` formula scrub now looks at the first non-space character so leading spaces, tabs, and CR cannot smuggle `= + - @ "`; `rrr.sh` restore and `fix_intact` copy and compare permission bits (`st_mode & 0777`) rather than the owner-exec bit alone, so a 0600 or 0640 file comes back exact and any mode drift is not PROVEN. No new features and no breaking changes. The Ratchet checkout has no root `.ratchet/`, so it is recorded here rather than in live project memory: `skip: no root .ratchet/ in Ratchet repo`.

This is a medium-impact product decision (D-20261109-0070-semver-1-3-2-patch). Version 1.3.2 is a patch: `runlog.sh` formula scrub also treats listed Unicode whitespace/BOM as a leading prefix before `= + - @ "`; a leftover takeover mutex is reclaimed so a dead lock can still be taken over; a refused write does not leave an empty log; `rrr.sh` place/revert copies `st_mode & 0777` independent of umask and a mode-only change is a real fix; install preflight requires each present skill's scripts; the jq/node hook requirement is documented on the settings.json write path because that file cannot hold comments. No new features and no breaking changes. The Ratchet checkout has no root `.ratchet/`, so it is recorded here rather than in live project memory: `skip: no root .ratchet/ in Ratchet repo`.

This is a medium-impact product decision (D-20261105-0050-rules-read-fail-closed). A project-rules file that passes the `-f`/`-r` probe but cannot then be read is fail-closed (exit 2), the same class as an unreadable or malformed file. A bash `while read; do …; done < file || deny` cannot observe that failure. The hook slurps with `cat --` after the probe and denies if that read fails; empty, comment-only, and EOF-without-newline files still fall back to defaults. The Ratchet checkout has no root `.ratchet/`, so it is recorded here rather than in live project memory: `skip: no root .ratchet/ in Ratchet repo`.

## Install order

**Plugin route (Claude Code):** `/plugin marketplace add baisethomas/Ratchet`, then `/plugin install ratchet@ratchet`. That delivers the seven skills and the destructive-command guard to every project, and updates arrive with `/plugin marketplace update ratchet` instead of re-copying files. It does **not** deliver the contract, project memory, stop gate, or adapters — those are per-repo by design, so run `/ratchet:ratchet-init` in each repo once, and `/ratchet:ratchet-upgrade` in each repo when a newer release changes them (the installer never overwrites, so nothing else brings them forward). Claude Code leaves auto-update off for third-party marketplaces; enable it for `ratchet` under `/plugin` or update by hand. Codex has no plugin system; it reads the same skills from `.agents/skills/` after `ratchet-init`, and `ratchet-upgrade` refreshes that copy too.

**Shortcut:** `drop-in/skills/ratchet-init/scripts/install.sh --from <ratchet>/drop-in --to <repo> [--claude] [--codex]` does the copying in steps 1–4 and never overwrites an existing file, so it is safe to re-run. Filling the `FILL-ME` slots and merging the hooks block into `.claude/settings.json` are still yours; the `ratchet-init` skill walks an agent through both.

1. **Every active repo:** copy `AGENTS.md` to the root and fill the `FILL-ME` sections. Create `.ratchet/`, copy `STATE.md` and `DECISIONS.md` into it, then initialize them from the branch/workstream's actual current state and already-settled decisions.
2. **Claude Code, if used:** copy `CLAUDE.md` to the repo root. Keep it a thin adapter that points back to `AGENTS.md`.
   **Codex, if used:** copy `CODEX.md` to the repo root. Its routing criteria select from the models available on the host each session; preserve the criteria instead of pinning model names. Existing installations must adopt the updated adapter and init skill once; the installer does not overwrite existing files. The hooks below do not fire around Codex; the adapter says so and makes the checks explicit.
3. **Hooks:** copy `drop-in/hooks/` to `.claude/hooks/`, configure the real checks, and run `test-hooks.sh` before trusting them.
4. **Skills:** copy `drop-in/skills/` to `.agents/skills/`, then `ln -s ../.agents/skills .claude/skills` so both tools load one copy (Codex scans `.agents/skills/`, Claude Code scans `.claude/skills/`; if `.claude/skills/` already exists, symlink each skill folder into it instead). Run `.agents/skills/ratchet-bugfix/scripts/test-rrr.sh` before trusting the proof script. Skills hold procedures only — never move a rule or hard stop out of `AGENTS.md` into one, because a skill that fails to trigger must not be able to switch a rule off.
5. **Optional chat/API layers:** install the provided project/system instructions where useful.
6. **Later:** graduate repeated workflows to pipelines only when the shape has proven stable.

## Handoff rule

For nontrivial work, the session is not complete until `.ratchet/STATE.md` is accurate enough for a fresh agent to continue **that branch/workstream** without the conversation transcript. Agents update current state automatically as meaningful state changes and always before handoff. Agents also record medium-impact durable decisions automatically. Only high-impact decisions escalate to the human.

At merge/integration, the integrating agent reconciles branch state into one clean resulting state instead of trying to keep every branch synchronized in real time.

## Documentation sync rule

`AGENTS.md`, `PLAYBOOK.md`, README, and any checklist/template that enforces the same workflow must agree on the core invariants. A change to the operating model is incomplete until affected surfaces are aligned. Tool-specific adapters should never become alternate sources of truth.

## Credits

Several ideas in the skills were learned from Matt Pocock's [mattpocock/skills](https://github.com/mattpocock/skills) (MIT) and adapted to Ratchet's contract; `drop-in/skills/CREDITS.md` lists each one and where it came from. His skills cover how to plan and build; Ratchet's cover how to prove the work is done. They install side by side.

## The one rule that maintains all the others

When a failure gets through, don't just fix the output. Add exactly one permanent thing to the system at the correct layer. If the failure was behavioral, add a rule, hook, test, or escalation gate. If the failure was lost project knowledge, add the missing state or decision. If a proposed fix requires Ratchet to become a second distributed system beside Git, reconsider the abstraction first.

Capability is what you have; process and project memory are what you keep.
