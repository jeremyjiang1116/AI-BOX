# Helper Routing Quick Map (v2)

Use this file when the skill has already triggered and you need the fastest correct helper selection.

Primary role guides:
- Fastest operator surface: `references/operator-cheat-sheet.md`
- HQ behavior and decision authority: `references/hq-workflow.md`
- Single executor return protocol: `references/executor-return-contract.md`
- Executor behavior after handoff: `references/executor-workflow.md`

## New formal tracked task
Use when:
- HQ is creating a new tracked collaboration task
- you need `task_id`, `thread_name`, dispatch payload, executor handoff payload
- you want the formal collaboration gate, not just raw task creation

Helpers:
- `shared/task/state/create-task.sh` (direct task registration)
- `shared/task/state/hq-dispatch-helper.sh` (combined dispatch payload helper)
- `skills/discord-visible-multiagent/scripts/hq-formal-collab-gate.sh` (preferred formal entry gate)

Outputs to preserve:
- `task_id`
- `thread_name`
- dispatch payloads
- blocked handoff state
- post-send writeback requirements

## Dispatch anchors / state writeback
Use when:
- formal gate payload has been generated
- HQ wants the visible dispatch phase to be executed through a standard skill-owned path
- thread creation + visible `[R1]` + ACTIVE writeback should be done together

Helper:
- `skills/discord-visible-multiagent/scripts/hq-visible-dispatch-run.sh`

Outputs to preserve:
- `thread_id`
- `hq_message_id`
- `status = ACTIVE`
- full dispatch result JSON

## Handoff readiness check
Use when:
- visible dispatch has completed
- writeback should already exist
- HQ needs to know whether formal executor handoff is now legal

Helper:
- `skills/discord-visible-multiagent/scripts/hq-collab-handoff-ready.sh`

## Formal executor handoff payload
Use when:
- readiness must be enforced before any executor handoff
- HQ wants a handoff payload that is valid only after visible writeback
- HQ wants executor-side preflight requirements embedded into the handoff context

Helpers:
- `skills/discord-visible-multiagent/scripts/hq-executor-handoff-helper.sh`
- `skills/discord-visible-multiagent/scripts/hq-handoff-send-plan.sh`

Important:
- if readiness fails, the handoff path must fail too
- do not construct formal handoff ad hoc once these helpers exist
- for formal handoff, runtime must execute the exact helper-produced `sessions_send` shape, not a hand-typed variant
- current verified runtime send contract for formal handoff lives in `references/runtime-send-contracts.md`
- HQ must not improvise selector combinations during live handoff
- send-plan validation now happens inside `hq-handoff-send-plan.sh`
- if needed, use `hq-handoff-send-plan.sh --record-preflight` instead of a separate preflight helper
- after a real successful handoff send, record `executor_handoff` writeback via `shared/task/state/record-runtime-send.sh`
- handoff output now includes executor preflight metadata for `executor-ownership-gate.sh`
- the handoff now treats **executor-owned send** as the hard rule
- for Discord sends, the standard command must include the executor account binding, for example:
  - 夜兰: `openclaw message send --channel discord --account yelan --target channel:<thread_id> --message ...`
  - 艾尔海森: `openclaw message send --channel discord --account alhaitham --target channel:<thread_id> --message ...`
- HQ or another executor must not substitute for the assigned executor on executor-owned sends

## Mid-task executor reassignment
Use when:
- HQ has already posted the new current-round visible instruction in the tracked task thread
- the next round must switch to a different executor before formal handoff
- task-state must preserve backup, provenance, executor/session binding, and the new HQ message anchor

Helper:
- `skills/discord-visible-multiagent/scripts/hq-reassign-executor.sh`

Important:
- this helper does not post the visible instruction and does not send the handoff
- use it only after the new visible current-round instruction is already in the task thread
- it backs up `tasks.db`, verifies the new executor session binding, updates `executor_agent` / `executor_session_key` / `hq_message_id` / optional round, appends `executor_reassignment` provenance, and writes a `task_events.event_type=executor_reassigned` entry
- after reassignment, continue with the normal handoff chain: `hq-executor-handoff-helper.sh` → `hq-handoff-send-plan.sh` → runtime `sessions_send` → `record-runtime-send.sh --kind executor_handoff`
- do not use ad hoc SQLite edits for executor switches now that this helper exists

## Standard formal dispatch chain (HQ-only, recommended)
Use this exact order for a new HQ-tracked formal collaboration task:

1. `skills/discord-visible-multiagent/scripts/hq-formal-collab-gate.sh`
   - create task + generate visible payload + return blocked handoff
2. `skills/discord-visible-multiagent/scripts/hq-visible-dispatch-run.sh`
   - create thread + post visible `[R1]` + write back `ACTIVE`
3. `skills/discord-visible-multiagent/scripts/hq-collab-handoff-ready.sh`
   - verify `status=ACTIVE` + `thread_id` + `hq_message_id`
4. `skills/discord-visible-multiagent/scripts/hq-executor-handoff-helper.sh`
   - generate formal executor handoff payload
5. `skills/discord-visible-multiagent/scripts/hq-handoff-send-plan.sh`
   - validate and output the only allowed real handoff send plan
6. runtime `sessions_send`
   - execute the exact helper-produced send plan only
   - for formal handoff on the current runtime surface, follow `references/runtime-send-contracts.md`
   - if preflight evidence must be written back, use `hq-handoff-send-plan.sh --record-preflight`
7. after real send success, record `executor_handoff` writeback

Do not skip or reorder these steps.
Do not handcraft thread create/reply commands when the standard runner is available.

## Due-task / sync / reminder side-path (HQ-only, recommended)
Use this order when a tracked task needs follow-up rather than a new round decision:

1. `shared/task/state/hq-due-task-checker.sh`
   - identify overdue `ACTIVE / BLOCKED / REVIEW` tasks and structured findings
2. choose the truthful follow-up path
   - HQ-visible sync if HQ/status trace is what matters now
   - executor reminder if the executor needs a targeted nudge
3. generate the draft/intent only
   - `shared/task/state/hq-sync-draft-helper.sh` for HQ sync
   - `shared/task/state/executor-reminder-helper.sh` for executor reminder
4. runtime performs the real send
   - do not describe helper draft generation as if the message was already sent
5. `shared/task/state/record-runtime-send.sh`
   - write back `hq_sync` or `executor_reminder` so task-state history remains truthful

Do not skip the final writeback after a real send.
Do not collapse “draft generated” into “send completed”.

## HQ follow-up / close helper
Use when:
- HQ has reviewed executor output and must choose next round vs accept vs BLOCKED/REVIEW/FAILED vs capped close
- you want task-state writeback to stay aligned with the chosen follow-up decision
- you need a draft for thread-visible next step / close text without hand-writing everything from scratch

Helper:
- `skills/discord-visible-multiagent/scripts/hq-followup-close-helper.sh`

Important:
- this helper does not perform real sends
- it is for decision draft + truthful SQLite writeback
- use `advance` only with `--next-round <current+1>` and a concrete `--challenge`
- use `capped` only at R15
- notify closure validation is now embedded as a hard requirement inside `hq-followup-close-helper.sh` for `advance|accept|blocked|review|failed`

## Thread evidence verification before HQ accepts / advances
Use when:
- HQ has result and notify message IDs and needs a concrete evidence check before accept / advance / close
- author/account provenance matters
- you need to prove result-before-notify and fixed notify shape from a saved or live thread read

Helper:
- `skills/discord-visible-multiagent/scripts/hq-thread-evidence-verify.sh`

Inputs:
- `--task-id <TASK-ID>`
- `--result-message-id <MESSAGE_ID>`
- `--notify-message-id <MESSAGE_ID>`
- one of `--thread-json-file <PATH>` or `--read-live`

Important:
- `--thread-json-file` is best for deterministic regression or archived evidence
- `--read-live` reads the tracked thread via the executor-bound account discovered from session metadata, unless `--executor-account` is provided
- failure exits non-zero and reports violations such as `result_author_mismatch`, `notify_author_mismatch`, `notify_prefix_mismatch`, `notify_shape_unrecognized`, or `result_after_notify`
- this verifier complements, but does not replace, HQ's content-quality review

## State model quick reference
Use when:
- you need the current practical task-state values without re-reading the longer integration docs
- you are checking whether helper output / DB state / HQ follow-up wording still matches the live workflow

Current practical states in use include at least:
- `NEW`
- `ACTIVE`
- `BLOCKED`
- `REVIEW`
- `DONE`
- `FAILED`
- `CLOSED` (when/if explicitly closed in the DB flow)

Authority note:
- prefer the live `tasks.db` behavior and maintained helpers over any stale abstract ladder
- use `docs/workflows/task-state-discord-integration.md` for broader integration context

## Runtime truth regression checks
Use when:
- helper behavior changed
- task-state gates changed
- notify validation changed
- ownership/account binding logic changed
- executor reassignment logic changed
- thread evidence verification changed
- handoff planning / send-shape validation changed
- visible-contract payload construction changed

Run:
- `skills/discord-visible-multiagent/scripts/test_runtime_truth_regressions.sh`
- `skills/discord-visible-multiagent/scripts/test_handoff_runtime_contract.sh`
- `skills/discord-visible-multiagent/scripts/test_visible_contract_integrity.sh`

`test_handoff_runtime_contract.sh` also guards the executor return notify transport:
- formal handoff must expose `hq_notify_transport=thread_visible_executor_notify`
- formal handoff must not generate an executor Discord command targeting `#hq-command`
- executor completion notify is the fixed thread-visible text posted in the tracked task thread

Run these serially, not in parallel. They all touch the shared SQLite task-state store, and parallel execution can create misleading `database is locked` failures.

These are the minimum non-destructive regression checks before treating the change as stable.

## Due-task scanning
Use when:
- HQ needs to find overdue tracked tasks
- you need structured findings for `ACTIVE / BLOCKED / REVIEW`

Helper:
- `shared/task/state/hq-due-task-checker.sh`

## HQ sync draft generation
Use when:
- a due task needs an HQ-visible sync draft
- you need reply-target hints or runtime-send intent

Helper:
- `shared/task/state/hq-sync-draft-helper.sh`

Important:
- helper generates draft/intent only
- current runtime/session performs the real send

## Executor reminder generation
Use when:
- HQ needs to remind an executor about a tracked task
- you need `executor_session_key` resolved from DB

Helper:
- `shared/task/state/executor-reminder-helper.sh`

Important:
- helper generates a safe `sessions_send` payload
- current runtime/session performs the real send

## Post-send writeback
Use when:
- HQ sync was actually sent
- executor reminder was actually sent
- task-state history must remain truthful

Helper:
- `shared/task/state/record-runtime-send.sh`

Typical kinds:
- `hq_sync`
- `executor_reminder`
- `executor_handoff`
- `executor_handoff_preflight` (evidence only; never proof that the real handoff was sent)

## Executor-side operational note
This helper map is mostly HQ-facing because the current maintained script chain is HQ-owned.

Executor should primarily read:
- `references/executor-return-contract.md`
- `references/executor-workflow.md`
- `references/templates.md`
- `references/boundaries.md`

Executor should not re-derive HQ helper order from this file.

## Quick route by intent
- **“正式派单”** → `hq-formal-collab-gate.sh`
- **“执行 visible dispatch（建 thread + 发 R1 + 回写 ACTIVE）”** → `hq-visible-dispatch-run.sh`
- **“检查现在能不能 handoff”** → `hq-collab-handoff-ready.sh`
- **“拿正式 handoff payload”** → `hq-executor-handoff-helper.sh`
- **“中途切换 executor”** → `hq-reassign-executor.sh` after the new visible instruction is already posted
- **“验 result/notify 是否真在 thread 且作者正确”** → `hq-thread-evidence-verify.sh`
- **“查哪些任务到期了”** → `hq-due-task-checker.sh`
- **“生成 HQ 同步草稿”** → `hq-sync-draft-helper.sh`
- **“催 executor”** → `executor-reminder-helper.sh`
- **“真实发完了，记回 DB”** → `record-runtime-send.sh`
