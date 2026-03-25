# discord-visible-multiagent

A reusable OpenClaw skill package for **visible Discord multi-agent collaboration**.

This directory contains the skill definition plus reference materials needed to run HQ-driven, thread-based, multi-round execution across Discord channels.

## What this skill is for

Use this skill when you want to run workflows like:
- HQ receives a task in a command channel
- HQ dispatches work to an executor channel
- execution continues inside a dedicated Discord thread
- each round is visible with `[R<n>]` markers
- HQ performs real review and acceptance
- fallback to `sessions_send` is allowed when thread visibility is imperfect

This is especially useful for:
- coding/research delegation
- multi-round review loops
- cross-channel execution with explicit sync-back
- workflows where “visible process” matters, but must not block progress forever

## Included files

```text
.
├── README.md
├── SKILL.md
└── references/
    ├── workflow.md
    ├── templates.md
    ├── boundaries.md
    ├── anti-patterns.md
    └── review-guide.md
```

## Reading order

If you are onboarding to this skill for the first time, use this order:

1. **`SKILL.md`**
   - When to use the skill
   - Core workflow rules
   - Round policy
   - Acceptance logic
   - Constraints

2. **`references/workflow.md`**
   - Full end-to-end operating flow
   - Dispatch → execution → fallback → review → close

3. **`references/templates.md`**
   - Copyable command/message templates
   - Thread creation
   - HQ dispatch
   - Executor posting
   - HQ review / close signals

4. **`references/anti-patterns.md`**
   - Things that must not happen
   - Useful as a review checklist

5. **`references/review-guide.md`**
   - HQ acceptance decision reference

## Core workflow summary

### 1. HQ dispatches the task
- Create a thread in the executor channel
- Use subject format:

```text
<任务ID>-<任务名>-<子任务阶段>
```

- Post a public `[R1]` dispatch inside the thread
- Send the same current-round instruction to the executor

### 2. Executor only does the current round
- No pre-writing future rounds
- Post actual results in thread
- Notify HQ explicitly after posting result

### 3. HQ reviews before advancing
HQ may only advance when all are true:
- previous result exists in thread **or** fallback path is used properly
- HQ received explicit completion notification
- HQ read the actual result and generated the next round

### 4. HQ owns acceptance
Executor saying “完成” is not enough.
HQ must verify:
- goal attainment
- output contract compliance
- evidence quality
- risk visibility

If quality is insufficient, HQ must issue a revision request and continue to `[R+1]`.

### 5. Hard round cap
- Default cap: **15 rounds**
- R16 is forbidden unless the cap was explicitly redefined beforehand
- At cap, HQ must force-close and sync back

## Minimal quick example

### Thread creation

```bash
openclaw message thread create \
  --account default \
  --channel discord \
  --target "channel:<目标执行频道ID>" \
  --thread-name "SKILL-001-正式Skill产出-草案阶段" \
  --auto-archive-min 10080 \
  --message "HQ 派单：更新 skill 文档" \
  --json
```

### HQ dispatch in thread

```text
## [R1] 任务派单

**任务ID**：SKILL-001
**任务目标**：增强 skill 的 README 与示例
**基线材料**：discord-visible-multiagent/
**产出要求**：补 README、quick start、示例
**回报要求**：完成后在 thread 回报，并通知 HQ
```

### Executor result post

```text
## [R1] README 增强结果

**任务ID**：SKILL-001
**产出物**：discord-visible-multiagent/README.md
**状态**：完成

已补充用途说明、目录结构、quick start 与使用示例。
```

### HQ acceptance

```text
## SKILL-001 验收确认

**审核结果**：✅ 通过
**最终轮次**：R1
**产出物**：discord-visible-multiagent/README.md
**结论**：README 已补齐，信息结构清晰，可继续下一步优化。
```

## Fallback rule

Thread visibility is **best effort**, not absolute.

If executor result is not visible in thread after repeated checks:
1. Use `sessions_send` result to continue
2. Post a fallback notice in the thread
3. Do not block the workflow forever waiting for perfect visibility

Example:

```text
⚠️ 未收到 thread 中的执行角色消息，但已通过 sessions_send 收到结果。

实际结果：README 已更新，增加 quick start 与 examples。

可以继续任务。
```

## Anti-pattern highlights

Do not:
- omit `[R<n>]` tags
- let executor self-increment rounds
- accept output without HQ review
- treat executor “完成” as final close
- allow R16+
- skip HQ sync-back
- assume cross-channel memory is automatic
- block forever waiting for thread perfectness

## Package status

Current package style:
- **references-only**
- no `scripts/`
- optimized for policy/workflow clarity first

## Examples

See `examples/` for concrete usage patterns:
- `examples/EXAMPLE-01-skill-draft-review.md` — normal visible multi-round draft + HQ revision loop
- `examples/EXAMPLE-02-thread-fallback.md` — thread visibility anomaly handled via `sessions_send` fallback

## Suggested next steps

Possible future upgrades:
- add Chinese/English dual README variants
- add more sample transcripts
- add decision trees for HQ acceptance
- add optional helper scripts after the workflow is fully stable
