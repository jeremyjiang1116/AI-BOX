# Eval Prompts (v1)

Use this file for lightweight smoke tests or comparison tests when refining the `discord-visible-multiagent` skill.

Goal: verify trigger quality, path selection, and negative boundaries.

## Expected-trigger prompts

### 1. New formal dispatch
Prompt:
> 帮我把这个任务正式派给夜兰，要求在 Discord 执行频道开 thread、先可见派单、然后再交给执行角色。

Expected:
- skill should trigger
- route to formal dispatch path
- mention task creation / task-id-first / visible `[R1]` / executor handoff / writeback

### 2. Continue an existing thread task
Prompt:
> 这个 thread 现在第 2 轮已经做完了，HQ 收到了通知，你继续按正式流程推进下一轮。

Expected:
- skill should trigger
- route to round-advance / review path
- enforce three prerequisites and round increment discipline

### 3. Due-task scan + HQ sync
Prompt:
> 你检查一下有哪些 formal task 到期了，帮我整理 HQ 应该发什么同步。

Expected:
- skill should trigger
- route to due-task checker + HQ sync draft path
- not pretend helper already sent the message

### 4. Executor reminder
Prompt:
> 给执行角色催一下 TASK-20260402-001 的进度，按现在 task-state 那套正式来。

Expected:
- skill should trigger
- route to executor reminder helper path
- mention executor session key resolution + runtime `sessions_send` + writeback

### 5. Workflow design / audit
Prompt:
> 我想把 Discord 多 agent 协同流程再审一遍，看看 formal task、visible dispatch、writeback 有没有缺漏。

Expected:
- skill should trigger
- route to workflow/design/audit mode
- inspect skill / workflow / references instead of jumping straight into helper execution

### 6. Runtime boundary question within workflow scope
Prompt:
> 现在这套 Discord 多 agent skill 里，为什么 dispatch helper 只负责 payload，不负责真实发送？

Expected:
- skill should trigger
- explain payload-first + runtime-send + writeback boundary clearly

## Expected-non-trigger prompts

### 7. Discord permission problem
Prompt:
> 为什么 yelan bot 在这个频道 Missing Access？

Expected:
- this skill should NOT be primary
- route to Discord permission / deployment / node-connect / platform troubleshooting instead

### 8. OpenClaw routing internals
Prompt:
> OpenClaw 的 sessions_send 在内部到底怎么路由？

Expected:
- this skill should NOT be primary
- route to OpenClaw internals / docs investigation instead

### 9. Single-agent solo task
Prompt:
> 你自己把这个 markdown 文件改一下，不需要派给别的 agent。

Expected:
- this skill should NOT be primary
- normal single-agent execution path

### 10. Bot/plugin development
Prompt:
> 帮我写一个 Discord bot，用来自动建 thread 和发消息。

Expected:
- this skill should NOT be primary
- route to coding / integration skill path instead

## Review questions after each smoke test
- Did the skill trigger when it should?
- Did it avoid triggering when it should not?
- Did it choose the right sub-path (dispatch / round-advance / due-task / audit)?
- Did it preserve payload-first + runtime-send + writeback truth?
- Did it avoid claiming a helper already completed a real send?
