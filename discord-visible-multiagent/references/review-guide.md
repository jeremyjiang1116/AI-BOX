# Review Guide (v3 — Flexible End-State)

## HQ Acceptance Decision Points
When executor delivers output (or hits R15 cap), HQ must decide:

### Accept
- Task goal is demonstrably met.
- Evidence is concrete and traceable.
- Output matches stated output contract.
- Risks are identified and bounded.
→ Reply with `验收通过` and close.

### Challenge + Revise
- Output is incomplete, unconvincing, or off-contract.
- Specific quality gap identified.
→ Reply with specific质疑 + 修改要求, then `[R+1]`, loop back.

### Forced Close (R15 Cap)
- Round counter hits 15 without acceptable output.
→ Post CAPPED close with reason and recommendation.

## Flexibility Rule
Do not force one final response template. Adapt structure to task type and risk level. The only mandatory signals are:
- TASK-ID
- Final round used
- Acceptance or challenge or capped decision

## Minimal Acceptance Signal
```
[TASK-ID] <id>
[审核结果]：✅ 通过
[最终轮次]：R<n>
[产出物]：<path>
[结论]：<brief>
```

## Minimal Challenge Signal
```
[TASK-ID] <id>
[轮次]：[R<n>+1]
[审核结果]：❌ 需要修改

[具体质疑]
<what is missing or wrong>

[修改建议]
<specific revision>
```

## R15 Capped Close
```
[TASK-ID] <id>
[审核结果]：⚠️ CAPPED
[最终轮次]：R15 / R15
[当前进展]：<brief status>
[未达标准]：<unmet criteria>
[建议]：<人工介入 | 重新派单 | 拆分任务>
```

## R12 Crisis Warning (Executor)
When reaching R12 without closure, executor should proactively flag:
```
[R<n>]
⚠️ 已达第 <n> 轮，剩余 <15-n> 轮。
当前状态：<brief status>
预计能否在 R15 前完成：<Yes/No/不确定>
```

## HQ Round Advance Checklist
Before sending next round, confirm ALL:
- [ ] Current round is R<n>
- [ ] R<n> < 15
- [ ] Previous round result visible in thread
- [ ] HQ received explicit notification from executor
- [ ] HQ has read actual previous round result
- [ ] Next round instruction posted in thread (with [R<n>+1])
- [ ] Same round instruction sent to executor via sessions_send
