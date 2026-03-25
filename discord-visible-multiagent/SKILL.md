---
name: discord-visible-multiagent
description: Coordinate visible multi-agent collaboration across Discord channels in OpenClaw, including HQ dispatch, executor-channel multi-turn execution (15-round hard cap), thread-based naming, per-message round labeling, HQ quality acceptance, and sessions_send fallback. Use when the user asks to run or design cross-channel workflows, handoff tasks from HQ to execution channels, continue follow-ups in-channel over multiple turns, or report distilled outcomes back to HQ. Do not use when the request is about underlying OpenClaw routing, Discord permissions, or single-agent solo tasks.
---

# discord-visible-multiagent (v3)

## Core Objective
Implement a practical, reviewable collaboration workflow for Discord + OpenClaw where:
- HQ channel handles command, routing, round governance, and quality acceptance.
- Executor channels handle focused delivery with multi-turn continuity.
- Cross-channel coordination is explicit, visible, and traceable.
- Thread naming, round labels, and sessions_send fallback are first-class concerns.

## v3 Naming Conventions

### Thread subject format
```
<任务ID>-<任务名>-<子任务阶段>
```
Examples:
- `SKILL-001-正式Skill产出-草案阶段`
- `TASK-LOGO-品牌重塑-初稿交付`
- `TASK-OSS-开源方案-技术评估`

Round number (R1/R2...) is NOT pre-determined; it emerges dynamically in the interaction.

### Per-message round label
Every thread message must carry a round tag:
```
[R1] [R2] [R3] ... [R15]
```
- HQ assigns round on each dispatch; executor echoes it back.
- HQ is the sole authority on round counter; executor must not self-increment.

## Operating Rules (v3)
- Treat each Discord channel session as context-local.
- Continue follow-ups in the same execution channel.
- **15 rounds hard cap**: R15 is the absolute maximum. R16 is forbidden.
- Thread visibility is **Best Effort**; use sessions_send result as fallback on anomaly.
- Keep REVIEW flexible; adapt to task type and risk level.
- Do not create scripts (references-only scope).

## Round Policy (v3)
- Default max rounds: **R15**
- **Hard cap**: after R15, executor MUST close; no R16 under any circumstances.
- User override examples:
  - "本任务上限 8 轮" → R8 cap
  - "允许 20 轮深挖" → R20 cap (requires explicit approval)
- Apply user-provided limit as highest priority.

## HQ Quality Acceptance (v3) — Core Responsibility
**Executor saying "完成" is NOT a closing condition.**

HQ must:
1. Verify task goal was actually achieved.
2. Verify output quality meets the stated output contract.
3. If insufficient: raise specific question + revision request, then `[R+1]`.
4. Loop until HQ formally accepts.

Acceptance signals:
- Goal met? Evidence present?
- Output matches output contract?
- Risks identified and bounded?
- Only HQ `验收通过` = valid close. "完成" from executor ≠ acceptance.

## sessions_send Fallback (v3)
Thread visibility via thread subject update = Best Effort.
If thread subject update fails or is unavailable:
1. Use sessions_send result as continuation context.
2. Carry TASK-ID + round tag in message body.
3. Post thread说明: `⚠️ 未收到 thread 中的执行角色消息，但已通过 sessions_send 收到结果...`
4. Proceed with task; do not block on thread naming.

## Real Multi-Round Collaboration (v3) — Core Distinction
This is NOT scripted relay. Each round is generated live by HQ based on actual thread results.

### Formal chain
1. HQ creates thread (name: `任务ID-任务名-子任务阶段`)
2. HQ posts `[R1]` dispatch in thread (public)
3. HQ sends current-round instruction to executor via sessions_send
4. Executor delivers current-round result in thread
5. Executor notifies HQ explicitly
6. HQ reads actual thread result
7. HQ generates next-round instruction based on real result
8. HQ posts `[R<n+1>]` in thread (public)
9. HQ sends current-round to executor
10. Loop until DONE / CAPPED / BLOCKED / FAILED

### Three hard prerequisites before next round
HQ may only advance to next round when ALL THREE are true:
- Previous round result is visible in thread
- HQ has received executor's explicit notification
- HQ has read the actual result and generated a new instruction

## Workflow (v3)

### Phase 0: Receive Task
- Read task content.
- Determine dispatch target (if not user-specified):
  - Analyze task type and difficulty
  - Choose appropriate executor
  - Identify target channel ID

### Phase 1: Create Thread and Dispatch
```bash
openclaw message thread create \
  --account default \
  --channel discord \
  --target "channel:<目标执行频道ID>" \
  --thread-name "<任务ID>-<任务名>-<子任务阶段>" \
  --message "HQ 派单：<任务描述>" \
  --json
```
Then post `[R1]` task dispatch in thread and sessions_send to executor.

### Phase 2: Executor Executes
- Receive task via sessions_send.
- Confirm receipt in thread.
- Execute task.
- Post result in thread (required).
- Notify HQ explicitly.

### Phase 3: Receive Completion
- Check provenance. If `kind == "inter_session"`, enter Phase 3.2.
- Attempt to read thread result.
- If thread has result → use it.
- If thread empty → use sessions_send result as fallback, post thread说明.

### Phase 4: HQ Acceptance Check
- If executor says "完成":
  - Review artifact quality (must personally verify)
  - Acceptable → Phase 5
  - Not acceptable → raise specific issue + revision, `[R+1]`, loop back
- Check round counter: `current_round >= 15` → forced close

### Phase 5: Close
- Post acceptance/rejection in thread.
- Report to HQ channel.

## Provenance Check (Required on inter_session messages)
```python
if message.provenance and message.provenance.kind == "inter_session":
    source_agent = extract_agent_from(message.provenance.sourceSessionKey)
    thread_id = extract_thread_id_from(message.content)
    # Must enter Phase 3.2 to confirm result
else:
    # Normal user message; process normally
```

## Round Counter Maintenance
- HQ must maintain round counter.
- Increment strictly: `R1 → R2 → R3...`
- Check `current_round < 15` before every dispatch.
- Never forget or miscount — round errors break the cap mechanism.

## Workflow Diagram
```
用户派单
    ↓
Phase 0: 接收任务，判断派发目标
    ↓
Phase 1.1: 创建 thread（名称格式: 任务ID-任务名-子任务阶段）
    ↓
Phase 1.2: HQ 在 thread 发 [R1] 任务派单
    ↓
Phase 1.3: sessions_send 给执行角色
    ↓
Phase 2: 执行角色执行
    ↓
Phase 3.1: 收到消息 → 检查 provenance
    ↓
    ├─ inter_session ─→ Phase 3.2 尝试获取 thread 结果
    │                   ├─ thread 有结果 → 使用 thread 结果
    │                   └─ thread 无结果 → sessions_send 兜底 + 发说明
    │                      ↓
    │                   Phase 4.1: 验收产出质量
    │                      ↓
    │                   ├─ 质量达标 → Phase 5 收口
    │                   └─ 质量不达标
    │                      轮次 +1
    │                      [R2] 质量审核反馈 → 执行角色修改
    │                      （循环直到达标）
    │
    ├─ 不是 inter_session ─→ 正常处理
    │
Phase 4.2: 检查轮次上限（>=15 强制收口）
    ↓
Phase 5: 收口：thread 确认 + 回 HQ 汇报
```

## State Machine
- `NEW` → `DISPATCHED` → `IN_PROGRESS` → `DISTILLED` → `ACCEPTED` → `CLOSED`
- Branches: `BLOCKED`, `REROUTED`, `CAPPED` (hit R15 without closure)

## What to Load from references/
- `references/workflow.md`: v3 end-to-end flow, state transitions, round governance.
- `references/templates.md`: HQ dispatch template, executor prompt, HQ report, HQ acceptance signal, thread creation commands.
- `references/boundaries.md`: scope, non-goals, handoff safety.
- `references/anti-patterns.md`: v3 anti-pattern checklist (updated).
- `references/review-guide.md`: HQ acceptance decision signals, capped close, R12 crisis warning.

## Output Contract
When triggered for execution, include:
- TASK-ID and thread subject
- Round label on every message: `[R<n>]`
- Round policy in use (default/override + hard cap status)
- Channel routing (HQ → executor → HQ)
- HQ acceptance decision (not just executor "完成")
- Distilled final deliverable for HQ routing

## Constraints
- Do not treat multi-channel as shared implicit memory.
- Do not skip HQ sync-back after executor completion.
- Do not force one fixed REVIEW template.
- Do not create scripts (references-only scope).
- **Do NOT allow R16. Hard cap is absolute.**
- Do not accept executor "完成" as final closing signal.
- Do not advance to next round without reading actual thread result.
- Do not use backticks around dynamic values in shell commands.
