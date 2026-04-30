# Executor Workflow (v1) — Discord Visible Multi-Agent Executor Path

Canonical collaboration law:
- `<OPENCLAW_SHARED>/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md`

Workspace execution gate:
- `<WORKSPACE>/skills/discord-visible-multiagent/SKILL.md`

Single formal return contract:
- `references/executor-return-contract.md`

This file is executor-only.
It defines what the assigned executor must do after formal handoff, and what is forbidden.

For the exact current-round return sequence, treat `references/executor-return-contract.md` as the authority. This file expands the executor-side behavior behind that contract.

## 0. Executor role boundary
Executor owns:
- executing only the assigned current round
- landing the current-round result in the correct thread
- using only the executor's own bound account for executor-owned sends
- explicitly notifying HQ after thread result is confirmed
- truthfully reporting BLOCKED with `reason` and `evidence`

Executor must not:
- prewrite later rounds
- post into the wrong task thread
- notify HQ before the thread result is actually confirmed
- let HQ or another executor send executor-owned result text in their place
- use ad hoc shell/CLI/provider bypasses not explicitly sanctioned in the handoff
- change the visible contract on their own

## 1. Phase A — receive formal handoff
When formal handoff arrives, executor must first confirm:
- `task_id`
- round number
- `thread_id`
- bound Discord account
- current-round output contract

If any of these cannot be safely confirmed:
- report BLOCKED to HQ
- include both `reason` and `evidence`

## 2. Phase B — execute only the current round
Executor must:
1. execute only the assigned round
2. not prewrite later rounds
3. keep output consistent with the thread-visible contract

If the handoff and visible thread instruction conflict:
- do not guess
- do not self-rewrite the contract
- report BLOCKED to HQ

## 3. Phase C — thread result first
Before any HQ notify, executor must first land the result in the target thread.

### Mandatory ownership preflight
Before any executor-owned thread result posting, run:
- `skills/discord-visible-multiagent/scripts/executor-ownership-gate.sh --task-id <TASK-ID> --executor-agent <executor_agent> --executor-account <executor_account> --thread-id <thread_id>`

This gate must reject:
- cross-task thread posting
- wrong executor identity
- wrong executor-bound account
- non-`ACTIVE` task state

If this gate fails:
- do not post
- report BLOCKED truthfully

### Validity gate
The result message is valid only when:
- the assigned executor sends it
- the executor uses their own bound account
- the correct task thread is targeted
- the send uses a workflow-recognized standard path

Allowed standard send paths may include:
- native/direct messaging path
- `openclaw message send`
- `openclaw message thread reply` when explicitly appropriate
- sanctioned assisted-post / standard send path explicitly provided in the formal handoff

Forbidden:
- posting to a different task's thread
- using another executor's account
- having HQ substitute for executor-owned result posting
- self-invented bypasses not sanctioned in the handoff

## 4. Phase D — short internal confirmation
After sending the thread result, executor must do a short internal confirmation step.

Rules:
- `pending confirmation` is internal only
- it is not a formal HQ update
- if confirmation succeeds, proceed to HQ notify
- if confirmation fails, report BLOCKED with `reason` and `evidence`

## 5. Phase E — explicit notify to HQ
Only after thread result is confirmed, executor may notify HQ.

HQ notify runtime rule on the current workspace surface:
- notify is a **thread-visible executor-owned Discord send** to the tracked task thread
- notify uses the same `thread_id` and executor-bound account as the result post
- HQ reads that notify from the same task thread
- executor must not post notify to the executor main channel or `#hq-command`
- `sessions_send` is only the formal handoff transport, not the visible notify surface
- after successful thread notify, the executor session final reply must be exactly `NO_REPLY` so runtime does not also post the notify into the executor main channel
- `hq_message_id` is a review / validation anchor, not a channel target

The notify must stay anchor-consistent with the tracked task:
- correct `task_id`
- correct round number
- correct executor identity
- correct task thread context

These checks are now enforced indirectly because HQ follow-up / acceptance requires the notify inputs and validates them inside `hq-followup-close-helper.sh`.

### Allowed formal HQ notify outcomes
1. success notify
```text
[TASK-...][R<n>] 本轮已完成，请读取 thread 现场结果并决定下一轮。
```

2. blocked notify
```text
[TASK-...][R<n>] BLOCKED: cannot_post_to_thread
reason: <最直接失败原因>
evidence: <最关键错误证据>
```

Executor must not:
- send “已完成” before the thread result exists
- send empty-shell BLOCKED without `reason` + `evidence`
- use vague completion language that hides uncertainty

## 6. Executor identity and ownership rules
For executor-owned Discord sends:
- the visible Discord author should match the assigned executor identity when identity visibility matters
- the bound account must match the executor role
- one executor must not post for another executor

This means, for example:
- 夜兰 result sends must use `--account yelan`
- 艾尔海森 result sends must use `--account alhaitham`

## 7. Executor quick checklist
- [ ] I confirmed `task_id`, round, thread, and bound account
- [ ] I am executing only the current round
- [ ] My result matches the visible contract
- [ ] I posted the result to the correct thread first
- [ ] I used only my own bound account / sanctioned path
- [ ] I completed short confirmation internally
- [ ] My HQ notify uses the correct task / round anchors
- [ ] Only then did I post the fixed HQ notify text into the same task thread
- [ ] My final session reply is exactly `NO_REPLY` after successful thread notify
- [ ] If blocked, I included both `reason` and `evidence`
