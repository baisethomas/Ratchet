# Ratchet — The Operator Playbook

[![GitHub Repo](https://img.shields.io/badge/GitHub-baisethomas%2FRatchet-181717?logo=github&logoColor=white)](https://github.com/baisethomas/Ratchet)

Everything needed to run the craft — with any model — as drop-in files. Nothing here requires the strongest model; that's the point.

**Why "Ratchet":** the mechanism that only turns one way. The model's ceiling is fixed; the system's isn't. Every failure that escapes produces one permanent addition to the process — a rule, a hook, a test, an escalation gate — and the system never slips backward.

## What's in the box

| File | What it is | Where it goes |
|---|---|---|
| `PLAYBOOK.md` | The full manual: chat craft, code craft, and the compensation layer | Read it once; keep it as the reference |
| `drop-in/CLAUDE.md` | Repo working-rules template (checkpoints, verification, hard stops, reporting format) | Repo root of every project. Fill the `FILL-ME` sections |
| `drop-in/claude-ai-project-instructions.md` | ~180-word epistemics core | Claude.ai → Project → Custom instructions (or Settings → Preferences for account-wide) |
| `drop-in/api-system-prompt.txt` | Reliability rules + optional second-pass reviewer prompt | Appended to the system prompt of any API-powered app (summarizer, grant assistant, etc.) |
| `drop-in/review-prompts.md` | 8 copy-paste prompts: adversarial review, re-derivation, fresh-context adversary, decomposition assist, hostile diff review, reproduce-revert-restore, honest summary, plan-first leash | Keep open in a tab; paste as needed |
| `drop-in/claude-code-hooks-settings.json` | Post-edit lint hook, stop-hook test gate, destructive-command guard | Merge into `.claude/settings.json` in the repo; replace placeholder commands with yours |
| `drop-in/done-audit-checklist.md` | The two-minute human audit for every "done," plus the ratchet rule | Print or pin next to wherever you review completions |

## Install order (30 minutes total)

1. **Claude.ai (2 min):** paste `claude-ai-project-instructions.md` into your main Project's custom instructions.
2. **Each active repo (10 min):** copy `CLAUDE.md` to the root, fill the FILL-ME sections — especially the single check command and the hard-stop paths.
3. **Hooks (10 min):** merge `claude-code-hooks-settings.json` into `.claude/settings.json`, swap in your real lint/test commands, extend the destructive-command pattern for your stack. Verify hook syntax against current Claude Code docs — shapes occasionally change between releases.
4. **API apps (5 min):** append `api-system-prompt.txt` to each app's system prompt. For the grant-writing app, wire the optional second-pass reviewer as a second API call on final outputs.
5. **You (3 min):** read `done-audit-checklist.md` once; use it on the next three completions until it's reflex.

## The one rule that maintains all the others

When a failure gets through, don't just fix the output — add exactly one permanent thing to the system (a CLAUDE.md line, a hook, a test, an escalation rule). Capability is what you have; process is what you keep.
