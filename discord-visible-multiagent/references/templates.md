# Cross-Channel Templates (v5)

Canonical source: `/home/ubuntu/.openclaw/shared/artifacts/discord-visible-multiagent/references/templates.md`

Use this file only for the most common visible text shapes around the current operator surface.
If you need helper selection, read `operator-cheat-sheet.md` or `helper-routing.md` instead.
If you need exact runtime send-shape rules, read `runtime-send-contracts.md`.
If you need executor result / notify / return semantics, read `executor-return-contract.md`.

## 0) Preferred operator entrypoints
For current execution, prefer these helpers:
- `hq-formal-collab-gate.sh`
- `hq-visible-dispatch-run.sh`
- `hq-handoff-send-plan.sh`
- `hq-followup-close-helper.sh`
- `executor-ownership-gate.sh`

## 1) Visible `[R1]` dispatch template

```text
## [R1] 任务派单

**任务ID**：<TASK-ID>
**任务目标**：<描述>
**基线材料**：<路径列表>
**产出要求**：<具体要求>
**回报要求**：完成后先在 thread 落地结果，再显式通知 HQ

---
```

## 2) Executor current-round instruction template

```text
## 当前轮执行指令（仅执行 R<n>）

**任务ID**：<TASK-ID>
**轮次**：R<n>
**任务目标**：<描述>
**基线材料**：<路径列表>
**产出要求**：<具体要求>

要求：
1. 只执行当前轮，不预写后续轮次；
2. 先在目标 thread 落地本轮结果；
3. 再显式通知 HQ：本轮已完成，请读取 thread 结果并决定下一轮。
```

## 3) Executor result post template

```text
## [R<n>] 执行结果

**任务ID**：<TASK-ID>
**状态**：完成 / 部分完成 / 阻塞
**执行说明**：<executor> 已按当前轮要求完成，并由 <executor> 本人通过标准受控路径在 thread 现场留痕。

<关键产出>

---
```

## 4) Executor notify templates

### Success notify
```text
[<TASK-ID>][R<n>] 本轮已完成，请读取 thread 现场结果并决定下一轮。
```

Executor runtime send note:
- current formal notify transport is a thread-visible executor-owned post in the tracked task thread
- HQ reads that notify from the same task thread
- executor must not post notify to the executor main channel or `#hq-command`
- after successful thread notify, executor final session reply must be exactly `NO_REPLY` to avoid duplicate main-channel delivery
- `hq_message_id` is a review / validation anchor, not a channel target

### Blocked notify
```text
[<TASK-ID>][R<n>] BLOCKED: <short-blocker>
reason: <最直接失败原因>
evidence: <最关键错误证据>
```

Rules:
- `pending confirmation` 不是发给 HQ 的正式回执
- 发给 HQ 的正式回执只保留：success notify / blocked with `reason` + `evidence`

## 5) HQ next-round / challenge template

```text
## [R<n+1>] 质量审核反馈

**任务ID**：<TASK-ID>

**具体质疑**
<缺口 / 问题>

**修改建议**
<具体修改要求>

**输出合同重审**
- <未满足项 1>
- <未满足项 2>

---
```

## 6) HQ acceptance / close templates

### Acceptance
```text
[TASK-ID] <TASK-ID>
[审核结果]：✅ 通过
[最终轮次]：R<n>
[产出物]：<列出产出物路径>
[结论]：<简短总结>
```

### BLOCKED / REVIEW / FAILED
```text
[TASK-ID] <TASK-ID>
[审核结果]：⚠️ BLOCKED / REVIEW / FAILED
[当前轮次]：R<n>
[当前进展]：<brief status>
[阻塞/审查原因]：<reason>
[建议下一步]：<next action>
```

### R15 capped close
```text
[TASK-ID] <TASK-ID>
[审核结果]：⚠️ CAPPED
[最终轮次]：R15 / R15
[当前进展]：<brief status>
[未达标准]：<what was not achieved>
[建议]：<人工介入 | 重新派单 | 拆分任务>
```

## 7) Minimal helper examples
These are convenience examples only.
For authoritative helper sequencing, use:
- `references/operator-cheat-sheet.md`
- `references/helper-routing.md`

### Formal task gate
```bash
./skills/discord-visible-multiagent/scripts/hq-formal-collab-gate.sh \
  --title "<任务标题>" \
  --slug "<slug>" \
  --target-channel-id "<目标执行频道ID>" \
  --executor-agent "<executor_agent>" \
  --executor-session-key "<executor_session_key>" \
  --task-goal "<任务目标>" \
  --baseline "<路径列表>" \
  --output-contract "<产出要求>"
```

### Handoff send-plan
```bash
./skills/discord-visible-multiagent/scripts/hq-handoff-send-plan.sh \
  --task-id "<TASK-ID>" \
  --format tool_call
```

### HQ follow-up helper: advance
```bash
./skills/discord-visible-multiagent/scripts/hq-followup-close-helper.sh \
  --task-id "<TASK-ID>" \
  --decision advance \
  --actor paimon-chief \
  --summary "<修改要求>" \
  --challenge "<具体质疑>" \
  --next-round <n+1> \
  --notify-agent "<executor_agent>" \
  --notify-thread-id "<thread_id>" \
  --notify-round "<n>" \
  --notify-text "[<TASK-ID>][R<n>] 本轮已完成，请读取 thread 现场结果并决定下一轮。"
```

### HQ follow-up helper: accept
```bash
./skills/discord-visible-multiagent/scripts/hq-followup-close-helper.sh \
  --task-id "<TASK-ID>" \
  --decision accept \
  --actor paimon-chief \
  --summary "<验收结论>" \
  --notify-agent "<executor_agent>" \
  --notify-thread-id "<thread_id>" \
  --notify-round "<n>" \
  --notify-text "[<TASK-ID>][R<n>] 本轮已完成，请读取 thread 现场结果并决定下一轮。"
```

## 8) Executor-owned Discord send examples
These are actor/provenance examples only, not the machine-level authority for formal `sessions_send` shapes.
For exact runtime send-shape rules, use `references/runtime-send-contracts.md`.

- 夜兰
```bash
openclaw message send --channel discord --account yelan --target channel:<thread_id> --message "..."
```

- 艾尔海森
```bash
openclaw message send --channel discord --account alhaitham --target channel:<thread_id> --message "..."
```

Rules:
- 由对应 executor 自己执行发送动作
- HQ 或其他 executor 不得代发
- 验收时不仅看消息是否进 thread，也要看 Discord 现场 author 是否符合目标执行者身份（当该工作流要求身份可见时）

## 9) Runtime-send + writeback reminder

```text
真实发送之后，不要只停留在“消息已经发出”。
如果该动作属于 task-state 跟踪链路，必须继续写回 DB：
- hq_sync → record-runtime-send.sh
- executor_reminder → record-runtime-send.sh
- dispatch anchors/state → update-task-status.sh / 对应写回链
```

Additional hard rule:
- 对动态 thread / Discord 文本，禁止直接把含反引号或命令替换风险的内容裸拼进 shell 命令。
- 应使用安全转义、stdin、临时文件或等价安全输入方式，避免 runtime-visible 文本被 shell 污染。
