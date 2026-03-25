# Example 01 — Skill Draft Review Loop

## Scenario
HQ wants `alhaitham-coder` to improve a skill draft in an executor channel. The process must be visible, multi-round, and quality-gated by HQ.

## Goal
Show the normal happy-path plus one quality challenge loop.

## Thread
```text
SKILL-001-正式Skill产出-草案阶段
```

## R1 — HQ dispatch
```text
## [R1] 任务派单

**任务ID**：SKILL-001
**任务目标**：基于现有基线材料，产出正式 skill 草案
**基线材料**：shared/tasks/SKILL-001-INPUT-TRUE-MULTIROUND.md
**产出要求**：输出完整 skill 草案，覆盖 workflow、templates、anti-patterns、review-guide
**回报要求**：完成后在 thread 回报，并通知 HQ
```

## R1 — Executor result
```text
## [R1] Skill 草案结果

**任务ID**：SKILL-001
**产出物**：shared/artifacts/discord-visible-multiagent/SKILL.md
**状态**：完成

已产出初版 skill 草案，包含 workflow、templates、boundaries、anti-patterns、review-guide 五部分。
```

## R1 — Executor notifies HQ
```text
[SKILL-001][R1] 已完成

产出：shared/artifacts/discord-visible-multiagent/SKILL.md
```

## HQ review result
HQ reads the actual artifact and decides quality is not yet sufficient.

## R2 — HQ quality challenge
```text
## [R2] 质量审核反馈

**任务ID**：SKILL-001

**具体质疑**
缺少对 sessions_send fallback 的清晰操作说明，且没有明确写出 HQ 验收职责。

**修改建议**
补上 fallback 规则、HQ 验收责任、R15 强制收口条件。

**输出合同重审**
- fallback continuation logic
- HQ acceptance duty
- round cap enforcement
```

## R2 — Executor revised result
```text
## [R2] Skill 修订结果

**任务ID**：SKILL-001
**产出物**：shared/artifacts/discord-visible-multiagent/SKILL.md
**状态**：完成

已补充 sessions_send fallback、HQ 验收职责、R15 强制收口逻辑。
```

## HQ acceptance
```text
## SKILL-001 验收确认

**审核结果**：✅ 通过
**最终轮次**：R2
**产出物**：shared/artifacts/discord-visible-multiagent/SKILL.md
**结论**：skill 草案已达到可继续沉淀与发布的标准。
```

## Why this example matters
- shows visible dispatch
- shows explicit HQ review authority
- shows executor completion ≠ acceptance
- shows a revision loop before closure
