# Skill Boundaries (v4)

Canonical source: `<OPENCLAW_SHARED>/artifacts/discord-visible-multiagent/references/boundaries.md`
Workspace supplements:
- `docs/workflows/task-state-discord-integration.md`
- `docs/workflows/task-state-mvp-v1.md`

## In Scope
- HQ → executor visible dispatch with thread/round conventions
- Executor multi-turn collaboration with R15 hard cap
- HQ quality acceptance loop (executor "完成" ≠ acceptance)
- Explicit `sessions_send` fallback and inter-session handling
- Visible, traceable cross-channel collaboration flow
- Round counter maintenance (HQ as sole authority)
- SQLite-backed task-state integration for formal tracked tasks
- payload generation / runtime-send / writeback discipline
- due-task scanning, HQ sync draft generation, executor reminder generation

## Out of Scope
- Discord platform deployment/permissions design
- OpenClaw internal routing implementation details
- unrelated single-agent solo task execution
- treating helper docs as independent workflow authorities

## Hard Boundary Rules
- **R16 is absolutely forbidden.** R15 = forced close signal.
- Executor "完成" ≠ acceptance. HQ must formally accept.
- Next round requires all three: thread-visible result + explicit notify + HQ review.
- Round increment is HQ's sole responsibility.
- Quality challenge + revision is a normal loop iteration, not a failure state.
- `sessions_send` timeout does **not** mean delivery failure; verify delivery.
- The abstract selector rule remains: do not use `sessionKey` together with any non-whitespace free-form `label`.
- For the current verified formal handoff/reminder runtime shape on this machine, see `runtime-send-contracts.md`; the machine-level exact working shape is `sessionKey + label=" "`.
- Prefer `sessionKey` when the exact executor session is already known; use `label` only when intentionally targeting by label resolution in non-formal paths.
- Every workflow send step must be performed by the correct actor for that step. In executor-owned paths, that means the assigned executor using the correct bound account.
- Do not use backticks around dynamic values in shell commands.
- Do not let tasks enter a black hole with no HQ-visible status.

## Current Machine Boundary Rules
- For this workspace, shell helpers are **not** the authoritative real-send layer.
- Helpers are responsible for:
  - DB task creation
  - payload/draft/intent generation
  - helper-side state logic
- Runtime/current session is responsible for:
  - real Discord-visible send
  - real `sessions_send`
- After real send, writeback is required when applicable.

## Task-State Boundary Rules
- Formal tracked tasks should be created in SQLite before visible dispatch.
- `task_id` must remain visible across DB, thread, HQ messages, executor handoff, and writeback.
- If real anchors exist (`thread_id`, `hq_message_id`), write them back promptly.
- Do not prefer an old abstract state model over the actual live `tasks.db` workflow.

## Collaboration Boundary Rules
- Keep private/sensitive data out of broad channels unless explicitly approved.
- Share only task-relevant context during handoff.
- Preserve traceability: `task_id`, round tag, thread subject, HQ decision, runtime send history.

## Role boundary reminders
### HQ
- owns task creation, visible dispatch, round authority, acceptance, and close decisions
- must not substitute for executor-owned result posting
- must not treat executor notify as acceptance

### Executor
- owns only the assigned current-round execution and its thread result posting
- must not prewrite future rounds
- must not post into another task's thread
- must not use another executor's bound account
- must not notify HQ before confirming thread result
