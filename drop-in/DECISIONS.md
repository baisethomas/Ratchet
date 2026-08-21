# Ratchet Decision Ledger

<!--
DROP-IN: copy this file to `.ratchet/DECISIONS.md` in the target repository.
This is durable project memory: decisions that future agents should not reopen accidentally.

Unlike STATE.md, this file is append-oriented. The agent owns maintaining it. Record durable choices when their rationale would otherwise be lost and future work would be constrained by them.

SAFETY: Never record secrets, credentials, access tokens, personal/customer data, or sensitive security/incident details. Use sanitized references to the approved protected system instead.

CONCURRENCY: Re-read this file immediately before writing. Preserve decisions added elsewhere, append rather than overwrite, and resolve conflicts explicitly. Never silently drop another branch's accepted or proposed decision.

Autonomy rule:
- Low-impact implementation choices usually stay in code and do not need an entry.
- Medium-impact durable choices may be decided and recorded by the agent, then surfaced in the completion summary.
- High-impact choices require explicit human approval before they are accepted or executed.

Do not record routine implementation choices that are obvious from the code. Do not silently rewrite prior rationale.
-->

## Decision format

### D001 — FILL-ME: short decision title

- **Status:** accepted | proposed | superseded
- **Impact:** low | medium | high
- **Date:** YYYY-MM-DD
- **Decision:** FILL-ME
- **Why:** FILL-ME
- **Rejected / alternatives:** FILL-ME
- **Consequences:** FILL-ME
- **Revisit when:** FILL-ME
- **Approved by:** agent | human name/role

---

## Decisions

<!--
Append durable decisions below.
Medium-impact decisions can be accepted autonomously by the agent when they are reversible and within authorized scope.
High-impact decisions remain proposed until a human approves them.
If an accepted decision changes, mark the old entry superseded and add a new decision that references it.
-->
