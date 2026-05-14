# Workflow (v5) — Discord Visible Multi-Agent Overview

Canonical workflow source: `$HOME/.openclaw/shared/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md`
Workspace task-state supplements:
- `docs/workflows/task-state-discord-integration.md`
- `docs/workflows/task-state-mvp-v1.md`
- `docs/workflows/hq-dispatch-runtime-sop.md`
- `docs/workflows/hq-sync-runtime-sop.md`
- `docs/workflows/runtime-send-writeback.md`

This file is now the **overview / routing mirror**.
It is intentionally shorter than the role-specific guides.

Primary role-specific execution guides:
- `references/hq-workflow.md`
- `references/executor-workflow.md`

## 0. The only correct execution model in this workspace
For formal HQ ↔ executor collaboration, use:

> **skill-first + task-id-first + visible-dispatch-first + payload-first + runtime-send + writeback**

Any workflow that skips one of these gates is drift.

## 1. Role split
### HQ path
HQ owns:
- task creation and visible dispatch
- dispatch writeback
- formal executor handoff preparation
- handoff send-plan validation inside the main send-plan helper
- reminder / sync / acceptance / next-round / close decisions
- embedded notify-closure validation inside the followup helper before review / advance / acceptance
- round authority

Read:
- `references/hq-workflow.md`
- `references/helper-routing.md`
- `references/review-guide.md`

### Executor path
Executor owns:
- executing only the assigned current round
- landing result in the correct thread first
- passing ownership preflight before executor-owned thread posting
- using the executor's own bound account / sanctioned path
- explicit thread-visible HQ notify in the same task thread only after thread result confirmation
- keeping notify anchors truthful to task / round context
- truthful BLOCKED reporting with `reason` + `evidence`

Read:
- `references/executor-workflow.md`
- `references/templates.md`
- `references/boundaries.md`

## 2. Shared hard laws
- visible dispatch happens before formal handoff
- dispatch anchors must be written back promptly
- executor completion is not HQ acceptance
- next round requires visible result + explicit notify + HQ review
- HQ is sole authority for round increment
- R15 is the hard cap, R16 is forbidden
- runtime send shapes for formal handoff/reminder are machine contracts, not freehand choices

## 3. Runtime boundary
Helpers generate payload, draft, intent, and DB state.
Runtime/current session performs the real send.
After real send, writeback is required when applicable.

## 4. Fast routing map
- **I already know this workflow applies and just need the smallest operator surface** → `references/operator-cheat-sheet.md`
- **I am HQ and need to open / hand off / review / close** → `references/hq-workflow.md`
- **I am executor and need to act on a handoff** → `references/executor-workflow.md`
- **I need exact helper selection** → `references/helper-routing.md`
- **I need exact runtime send shape** → `references/runtime-send-contracts.md`
- **I need review / acceptance criteria** → `references/review-guide.md`
- **I need output / notify templates** → `references/templates.md`

## 5. Summary
This workspace workflow is a visible multi-agent collaboration workflow backed by SQLite task-state, executed through runtime send, and kept truthful by mandatory writeback.

The overview file is not the place for detailed role instructions anymore.
Use the HQ / executor role guides for actual execution behavior.
