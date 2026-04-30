# HQ Workflow (v1) — Discord Visible Multi-Agent HQ Path

Canonical collaboration law:
- `/home/ubuntu/.openclaw/shared/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md`

Workspace execution gate:
- `/home/ubuntu/.openclaw/workspace/skills/discord-visible-multiagent/SKILL.md`

Runtime send contract authority:
- `/home/ubuntu/.openclaw/workspace/skills/discord-visible-multiagent/references/runtime-send-contracts.md`

Single executor return contract:
- `/home/ubuntu/.openclaw/workspace/skills/discord-visible-multiagent/references/executor-return-contract.md`

This file is HQ-only.
It defines what **HQ / paimon-chief** must do, and what HQ must never delegate, fake, or silently skip.

## 0. HQ role boundary
HQ owns:
- task classification into formal collaboration
- task creation and visible dispatch
- writeback truth for dispatch and HQ-side sends
- formal executor handoff preparation and send-plan validation
- HQ sync / reminder / acceptance / next-round / close decisions
- round authority
- final review responsibility
- enforcing the single formal executor return protocol after handoff

HQ must not:
- send executor-owned thread results in place of the executor
- silently replace a missing executor result with HQ-authored text and pretend the workflow is intact
- treat executor notify as acceptance
- handcraft selector combinations during formal handoff/reminder

## 1. Phase A — classify and open the formal task
1. decide whether the request is a formal HQ-tracked collaboration task
2. choose executor/channel
3. create the tracked task before any visible dispatch

Preferred helper:
- `skills/discord-visible-multiagent/scripts/hq-formal-collab-gate.sh`

Minimum outputs HQ must preserve:
- `task_id`
- `thread_name`
- visible dispatch payload
- blocked handoff state before visible anchors exist

## 2. Phase B — visible dispatch
HQ/runtime must:
1. create the thread
2. post visible `[R1]`
3. write back:
   - `thread_id`
   - `hq_message_id`
   - `status=ACTIVE`

Required helper:
- `skills/discord-visible-multiagent/scripts/hq-visible-dispatch-run.sh`

HQ hard rule:
- never hand off to executor first and promise visible trace later

## 3. Phase C — formal handoff to executor
HQ must use this exact chain:
1. `hq-collab-handoff-ready.sh`
2. `hq-executor-handoff-helper.sh`
3. `hq-handoff-send-plan.sh --format tool_call` (or `exec_json` for validation path)
4. runtime performs the real `sessions_send`
5. after successful real send, write back:
   - `kind=executor_handoff`

### HQ handoff hard rules
- do not handcraft `sessions_send`
- do not improvise selector combinations
- `hq-handoff-send-plan.sh` now performs the exact send-shape validation internally
- if preflight evidence must be written back, use `hq-handoff-send-plan.sh --record-preflight`
- if the exact runtime send contract fails, stop and classify as runtime/tooling boundary
- do not report handoff as completed if only payload generation succeeded

## 4. Phase D — HQ reminder / sync
This is a follow-up side-path, not a substitute for review/acceptance logic.
The truthful order is:
1. detect the need for follow-up on a tracked task
2. choose HQ sync vs executor reminder
3. generate draft/intent only
4. perform the real runtime send
5. record send writeback

### Executor reminder
Use:
- `shared/task/state/executor-reminder-helper.sh`
- runtime send according to workspace runtime contract
- `record-runtime-send.sh --kind executor_reminder`

### HQ sync
Use:
- `shared/task/state/hq-sync-draft-helper.sh`
- HQ runtime sends visibly in HQ
- `record-runtime-send.sh --kind hq_sync`

## 5. Phase E — HQ receives executor notify
When HQ receives executor notify:
- notify is necessary, not sufficient
- HQ follow-up / acceptance must pass the notify-closure checks now embedded inside `skills/discord-visible-multiagent/scripts/hq-followup-close-helper.sh`
- then HQ must confirm the thread-visible result when required by the workflow
- HQ must not collapse uncertainty into “looks done”
- HQ must evaluate the executor return against `references/executor-return-contract.md`: thread result first, executor-owned sender/account, short internal confirmation, then fixed success/BLOCKED notify

If visible result is missing:
- treat as anomaly
- do not silently substitute an HQ send in place of executor-owned result

## 6. Phase F — HQ review / next-round / acceptance
HQ must choose one truthful state:
- accept
- challenge + next round
- BLOCKED
- REVIEW
- FAILED
- capped close at R15

### Before acceptance
HQ must verify:
- the embedded notify-closure checks passed for the executor notify that triggered this review step
- output contract met
- evidence concrete enough
- result chain trustworthy enough
- required runtime send / writeback truth exists where relevant

### Before next round
HQ must verify:
1. the embedded notify-closure checks passed
2. previous-round result visible in thread
3. HQ received explicit notify
4. HQ has read the real result
5. new thread-visible instruction fully exposes the new round contract
6. handoff stays contract-consistent with that visible instruction

## 7. Phase G — close / forced close / traveler-visible state
HQ must keep traveler-visible state synchronized.
No-result-yet is never an excuse for silence.

At R15 without closure:
- do not open R16
- stop thread-round continuation
- sync truthful status back immediately

## 8. HQ quick checklist
- [ ] formal task created before visible dispatch
- [ ] visible `[R1]` exists before handoff
- [ ] dispatch anchors written back
- [ ] handoff readiness passed
- [ ] handoff send-plan validation passed
- [ ] real handoff send performed using exact runtime contract
- [ ] `executor_handoff` writeback recorded
- [ ] executor notify verified against thread reality
- [ ] HQ review performed personally
- [ ] next-round / accept / blocked decision is truthful
