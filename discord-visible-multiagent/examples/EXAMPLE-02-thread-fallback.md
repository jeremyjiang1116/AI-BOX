# Example 02 — Thread Visibility Failure with sessions_send Fallback

## Scenario
Executor completed the task, but HQ cannot observe fresh executor output in the thread after repeated checks.

## Goal
Show how to continue safely without blocking the task forever.

## Thread
```text
TASK-042-Provider评估-结果整理
```

## R1 — HQ dispatch
```text
## [R1] 任务派单

**任务ID**：TASK-042
**任务目标**：评估当前可用 provider，并给出推荐方案
**基线材料**：provider 列表、当前配置、历史阻塞记录
**产出要求**：产出结论、风险、推荐方案
**回报要求**：完成后在 thread 回报，并通知 HQ
```

## Executor sends notification, but thread looks stale
```text
[TASK-042][R1] 已完成

产出：shared/artifacts/TASK-042-provider-report.md

结论：推荐继续使用当前中转的 gpt-5.4 作为默认方案。
```

## HQ fallback handling
HQ tries multiple times to read the thread but does not see a fresh executor message.

Instead of blocking, HQ posts a fallback notice:

```text
⚠️ 未收到 thread 中的执行角色消息，但已通过 sessions_send 收到结果。

实际结果：已完成 provider 评估，推荐继续使用当前中转的 gpt-5.4；产出路径为 shared/artifacts/TASK-042-provider-report.md

可以继续任务。
```

## HQ then reviews the actual artifact
HQ reads `shared/artifacts/TASK-042-provider-report.md` and chooses one of:
- accept
- challenge + revise
- blocked/failed
- capped close

## Example acceptance
```text
## TASK-042 验收确认

**审核结果**：✅ 通过
**最终轮次**：R1
**产出物**：shared/artifacts/TASK-042-provider-report.md
**结论**：provider 评估清晰，推荐方案与风险说明完整。
```

## Why this example matters
- shows thread visibility is best effort, not absolute
- shows sessions_send timeout/visibility anomaly does not automatically mean failure
- shows HQ must still review the artifact instead of blindly trusting the notification
