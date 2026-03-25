# AI-BOX

Private repository for AI workflows, skills, and collaboration assets.

## Included

- `discord-visible-multiagent/` — OpenClaw skill for visible Discord multi-agent collaboration workflows.

---

# discord-visible-multiagent

A practical OpenClaw skill for running **visible, reviewable, multi-agent collaboration** across Discord channels and threads.

It is designed for workflows where:
- HQ dispatches work from a command channel
- execution happens in a dedicated executor channel/thread
- each round is visible and traceable
- HQ performs real acceptance, not just relay
- `sessions_send` can be used as a fallback when thread visibility is imperfect

## What problem it solves

This skill standardizes a messy real-world pattern:

1. A user gives HQ a task
2. HQ dispatches it to an executor channel
3. The executor works in a Discord thread over multiple rounds
4. HQ reviews actual outputs round by round
5. HQ either accepts, requests revision, or force-closes at the cap
6. HQ reports the distilled result back to the command channel

Without a shared workflow, these tasks often fail because of:
- hidden context
- missing round control
- executor saying “done” without quality acceptance
- thread visibility glitches
- weak sync-back to HQ

This skill makes that process explicit.

## Core guarantees

- **Visible thread workflow**: HQ and executor leave reviewable traces in Discord threads
- **Round governance**: every message carries `[R<n>]`
- **HQ-only round authority**: executor must not self-increment
- **Quality acceptance**: executor completion does **not** equal acceptance
- **Fallback path**: when thread visibility fails, continue via `sessions_send`
- **Hard cap**: default maximum is 15 rounds unless explicitly overridden

## Directory structure

```text
discord-visible-multiagent/
├── SKILL.md
└── references/
    ├── workflow.md
    ├── templates.md
    ├── boundaries.md
    ├── anti-patterns.md
    └── review-guide.md
```

## Files

### `SKILL.md`
The main entry point. Defines when to use the skill, its operating model, constraints, round policy, acceptance logic, and overall workflow.

### `references/workflow.md`
The full end-to-end process, including:
- dispatch flow
- provenance checks
- thread/result confirmation
- fallback logic
- HQ acceptance loop
- capped close behavior

### `references/templates.md`
Reusable command and message templates for:
- thread creation
- HQ dispatch
- executor result posts
- HQ revision requests
- HQ acceptance signals
- fallback notices
- final reports

### `references/boundaries.md`
Defines the scope and non-goals of the workflow so the skill is not misused.

### `references/anti-patterns.md`
A checklist of things that must not happen, including:
- missing `[R<n>]` labels
- allowing R16+
- treating executor “完成” as closure
- skipping HQ acceptance
- advancing without reading real thread results
- assuming implicit cross-channel memory

### `references/review-guide.md`
A concise HQ review guide for deciding:
- accept
- challenge + revise
- capped close

## Recommended usage scenarios

Use this skill when you need:
- HQ → executor channel dispatch
- multi-round collaboration in a Discord thread
- explicit task IDs and round tags
- visible review and acceptance
- a repeatable pattern for multi-agent execution

Do **not** use it for:
- single-agent solo work
- basic Discord permission debugging
- underlying OpenClaw routing/plugin bugs
- workflows that do not need visible round governance

## Quick start

### Step 1: Create a thread in the executor channel

```bash
openclaw message thread create \
  --account default \
  --channel discord \
  --target "channel:<目标执行频道ID>" \
  --thread-name "<任务ID>-<任务名>-<子任务阶段>" \
  --auto-archive-min 10080 \
  --message "HQ 派单：<任务描述>" \
  --json
```

### Step 2: Post the first round in the thread

```text
## [R1] 任务派单

**任务ID**：SKILL-001
**任务目标**：更新 skill 的 README 和使用示例
**基线材料**：shared/artifacts/discord-visible-multiagent/
**产出要求**：修改 README，并补充 quick start 与 examples
**回报要求**：完成后在 thread 回报，并通知 HQ
```

### Step 3: Send the same round to the executor

Via `sessions_send`, send only the **current round**. Do not pre-write future rounds.

### Step 4: Executor posts result in thread

```text
## [R1] README 增强结果

**任务ID**：SKILL-001
**产出物**：shared/artifacts/discord-visible-multiagent/README.md
**状态**：完成

已补充：用途说明、目录结构、快速开始、使用示例。
```

### Step 5: HQ reviews and decides

HQ must choose one of:
- accept
- challenge + revise
- capped close
- blocked/failed

Executor saying “完成” is **not enough**.

---

## Example workflows

## Example A — Skill drafting task

**Scenario**:
HQ asks `alhaitham-coder` to update a skill draft in an executor channel thread.

**Flow**:
1. HQ creates thread `SKILL-001-正式Skill产出-草案阶段`
2. HQ posts `[R1]` dispatch
3. HQ sends the current round to Alhaitham
4. Alhaitham posts the draft result in thread
5. Alhaitham notifies HQ
6. HQ reads the actual result and requests revision if needed
7. On acceptance, HQ posts acceptance and reports back to command channel

## Example B — Research task with fallback

**Scenario**:
Executor finishes work, but the thread result is not visible due to routing/thread binding inconsistency.

**Flow**:
1. Executor sends `sessions_send` completion notice
2. HQ attempts to read thread multiple times
3. Thread still does not show fresh executor output
4. HQ posts fallback notice in thread:

```text
⚠️ 未收到 thread 中的执行角色消息，但已通过 sessions_send 收到结果。

实际结果：已完成模型对比与风险分析，产出路径为 shared/artifacts/TASK-042-report.md

可以继续任务。
```

5. HQ continues the workflow instead of blocking forever

## Example C — Quality challenge loop

**Scenario**:
Executor delivered an artifact, but it does not satisfy the output contract.

**HQ response**:

```text
## [R2] 质量审核反馈

**任务ID**：TASK-042

**具体质疑**
缺少对 fallback 风险的分析，且未解释为什么选择该 provider。

**修改建议**
补充风险对比、失败路径，以及 provider 选择理由。

**输出合同重审**
- provider 选择依据
- fallback 风险说明
- 最终推荐结论
```

Then the executor revises in `[R2]`, and HQ reviews again.

## Example D — Forced close at cap

If the workflow reaches the round cap:

```text
## TASK-042 强制收口（达到 R15 上限）

**审核结果**：⚠️ CAPPED
**最终轮次**：R15 / R15
**当前进展**：已完成大部分分析，但最终方案仍存在争议
**未达标准**：尚未形成可执行的一致结论
**建议**：人工介入 / 拆分任务后重新派单
```

## Key operating rules

1. **Every thread message must include `[R<n>]`**
2. **HQ is the only round authority**
3. **Do not move to next round without reading actual result**
4. **Do not treat executor completion as acceptance**
5. **Do not allow R16 unless the cap was explicitly redefined before execution**
6. **Do not rely on implicit cross-channel memory**
7. **Use `sessions_send` fallback when thread visibility is anomalous**

## Best practices

- Always include a clear `TASK-ID`
- Keep the thread subject stable and structured
- Put the current-round objective in writing
- Make revision requests specific and testable
- Distill outcomes before syncing back to HQ
- Treat visibility as a feature, not a guarantee

## Next improvements

Suggested next steps for this repository:
- add a dedicated `README.md` inside `discord-visible-multiagent/`
- add a Chinese quickstart variant
- add sample task transcripts
- add a real checklist for HQ acceptance reviews
- later evaluate whether scripts are worth introducing beyond the current references-only scope
