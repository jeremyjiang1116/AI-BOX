# Review Guide (v4 — Acceptance + Runtime Truth)

Canonical source: `/home/ubuntu/.openclaw/shared/artifacts/discord-visible-multiagent/references/review-guide.md`
Workspace supplements:
- `docs/workflows/task-state-mvp-v1.md`
- `docs/workflows/runtime-send-writeback.md`

## HQ Acceptance Decision Points
When executor delivers output, HQ must choose one of the following truthful outcomes.
Use this guide together with `scripts/hq-followup-close-helper.sh` after executor notify has arrived and HQ is reviewing the real current-round result.

### Accept
Use only when all are true:
- task goal is demonstrably met
- evidence is concrete and traceable
- output matches the stated output contract
- visible/result chain is sufficiently trustworthy for this task
- remaining risks are identified and bounded

→ Accept, close, and sync back visibly.

### Challenge + Revise
Use when any of the following is true:
- output is incomplete or off-contract
- evidence is weak
- visible/result chain is missing a necessary verification step
- result exists but does not yet justify acceptance

→ Raise a specific challenge, increment round correctly, and continue.

### Mark BLOCKED / REVIEW / FAILED
Use when:
- the task cannot safely progress
- missing prerequisite/context/tooling blocks reliable continuation
- HQ needs explicit review instead of pretending closure
- the workflow truthfully is not DONE

### Forced Close (R15 Cap)
At R15 without acceptable closure:
- do not open R16
- close as capped / forced-close path
- sync current progress, unmet criteria, and recommendation back to HQ

## HQ Review Principles
- Executor completion is never acceptance by itself.
- Internal notify is not the same as visible result.
- If the workflow claims a real send happened, verify it through runtime evidence or DB writeback where applicable.
- Prefer live task-state truth over stale abstract state stories.
- If a key verification link is missing, state that it is missing; do not collapse uncertainty into acceptance.

## Mandatory Review Checks Before Acceptance
- [ ] `task_id` is clear
- [ ] final round is clear
- [ ] embedded notify-closure checks have passed for the triggering executor notify
- [ ] output contract is met
- [ ] evidence is concrete enough
- [ ] HQ has actually reviewed the relevant artifact/result
- [ ] if runtime send/writeback matters for this task, the action history is truthful enough
- [ ] final visible sync/close message will not misrepresent the actual state
- [ ] for executor-owned Discord sends, the visible Discord author matches the intended executor identity when that identity is part of the workflow requirement
- [ ] for executor-owned Discord sends, the command/account binding matches the executor, for example 夜兰 → `--account yelan`, 艾尔海森 → `--account alhaitham`
- [ ] if the executor ended in `BLOCKED`, the notify includes both `reason` and `evidence`

## Minimal Acceptance Signal
```text
[TASK-ID] <id>
[审核结果]：✅ 通过
[最终轮次]：R<n>
[产出物]：<path>
[结论]：<brief>
```

## Minimal Challenge Signal
```text
[TASK-ID] <id>
[轮次]：R<n+1>
[审核结果]：❌ 需要修改

[具体质疑]
<what is missing or wrong>

[修改建议]
<specific revision>
```

## BLOCKED / REVIEW / FAILED Signal
```text
[TASK-ID] <id>
[审核结果]：⚠️ BLOCKED / REVIEW / FAILED
[当前轮次]：R<n>
[当前进展]：<brief status>
[阻塞/审查原因]：<reason>
[建议下一步]：<next action>
```

## R15 Capped Close
```text
[TASK-ID] <id>
[审核结果]：⚠️ CAPPED
[最终轮次]：R15 / R15
[当前进展]：<brief status>
[未达标准]：<unmet criteria>
[建议]：<人工介入 | 重新派单 | 拆分任务>
```

## Round Advance Checklist
Before sending next round, confirm all:
- [ ] embedded notify-closure checks have passed
- [ ] current round is R<n>
- [ ] R<n> < 15
- [ ] previous-round result is visible in thread
- [ ] HQ received explicit notify
- [ ] HQ has read actual previous-round result
- [ ] next-round instruction is ready and grounded in that result
- [ ] next visible sync/dispatch will remain truthful
- [ ] if executor-owned Discord identity matters, the previous-round result was sent under the correct executor-bound account
- [ ] no `pending confirmation` pseudo-status leaked into HQ as if it were a formal round result

## Runtime Truth Checklist
Use this especially when the task-state layer is involved:
- [ ] am I describing payload generation as if it were real sending?
- [ ] am I claiming success without runtime evidence?
- [ ] did I forget required writeback after real send?
- [ ] am I relying on stale helper assumptions instead of the current machine boundary?

If any answer is yes, do not present closure as complete.
