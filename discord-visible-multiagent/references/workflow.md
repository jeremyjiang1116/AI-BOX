# Workflow (v3) — HQ ↔ Executor Channels

## End-to-End Flow

### Phase 0: Receive Task
- User dispatches in #hq-command.
- Read task content.
- Determine dispatch target (if not user-specified):
  - Analyze task type and difficulty → choose executor.
  - Identify target channel ID.

### Phase 1: Create Thread and Dispatch

**1.1 Create Thread**
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
Thread name format: `<任务ID>-<任务名>-<子任务阶段>`
Examples: `SKILL-001-正式Skill产出-草案阶段`, `TASK-LOGO-品牌重塑-初稿交付`

**1.2 Post `[R1]` in thread** (public dispatch)
```bash
openclaw message send \
  --account default \
  --channel discord \
  --target "<thread ID>" \
  --message "## [R1] 任务派单

**任务ID**：<任务ID>
**任务目标**：<描述>
**基线材料**：<路径列表>
**产出要求**：<具体要求>
**回报要求**：完成后在 thread 回报，并通知 HQ

---" \
  --json
```

**1.3 Send to executor via sessions_send**
```bash
openclaw sessions_send \
  --sessionKey "agent:<角色>-coder:discord:channel:<目标频道ID>" \
  --message "## [R1] 任务派单

**任务ID**：<任务ID>
**任务目标**：<描述>
**基线材料**：<路径列表>
**产出要求**：<具体要求>
**回报要求**：完成后在 thread 回报结果，并用 sessions_send 通知 HQ

---" \
  --json
```

### Phase 2: Executor Executes
1. Receive task via sessions_send.
2. Confirm in thread: `收到任务，开始执行。`
3. Execute task (read baseline materials, produce output).
4. Post result in thread (required, with `[Rx]` tag).
5. Notify HQ via sessions_send.

### Phase 3: Receive Completion Notification

**3.1 Check provenance**
```python
if message.provenance and message.provenance.kind == "inter_session":
    source_agent = extract_agent_from(message.provenance.sourceSessionKey)
    thread_id = extract_thread_id_from(message.content)
    # Must enter Phase 3.2
else:
    # Normal user message; process normally
```

**3.2 Thread result retrieval with fallback**
```python
thread_messages = openclaw message read \
  --channel discord \
  --target "<thread ID>" \
  --limit 10

if thread_messages contains executor's response:
    result = executor's response from thread
    go_to_phase_4()
else:
    # Thread anomaly: use sessions_send result as fallback
    result = message.content

    # Post说明 in thread
    openclaw message send \
      --account default \
      --channel discord \
      --target "<thread ID>" \
      --message "⚠️ 未收到 thread 中的执行角色消息，但已通过 sessions_send 收到结果。

实际结果：<result>

可以继续任务。" \
      --json

    go_to_phase_4()
```

Core principle: Thread visibility = **Best Effort**. sessions_send fallback always valid.

### Phase 4: HQ Acceptance Check

**4.1 Quality acceptance**
```python
if executor says "完成" / "DONE" / "已产出":
    artifact = get_artifact(executor.response)
    quality = review(artifact)  # Must personally verify

    if quality.is_acceptable():
        go_to_phase_5()  # Accept → close
    else:
        # Quality insufficient → raise specific issue + revision, round +1
        current_round += 1
        send_to_thread({
          "message": f"## [R{current_round}] 质量审核反馈\n\n问题：<具体问题>\n修改建议：<修改建议>\n\n请按要求修改后重新提交。"
        })
        # Loop: executor revises → re-review
```

**4.2 Round cap check**
```python
if current_round >= 15:
    # Hard cap hit → forced close, no R16
    go_to_phase_5(status="CAPPED", reason="达到15轮上限")
else:
    # Continue to next round
    continue
```

### Phase 5: Close

**5.1 Thread confirmation**
```bash
openclaw message send \
  --account default \
  --channel discord \
  --target "<thread ID>" \
  --message "## <任务ID> 验收确认

**审核结果**：✅ 通过 / ❌ 需要修改 / ⚠️ 阻塞
**最终轮次**：R<N>
**产出物**：<列出产出物路径>
**结论**：<简短总结>

---" \
  --json
```

**5.2 Report to HQ channel**
```bash
openclaw message send \
  --account default \
  --channel discord \
  --target "channel:1483658047443177512" \
  --message "## <任务ID> 完成汇报

**状态**：✅ DONE / ⚠️ REVIEW / ❌ FAILED / ⚠️ CAPPED
**执行角色**：<角色名>
**总轮次**：R<N>
**产出**：<产出路径>
**简要结论**：<1-2句话>

---" \
  --json
```

## Round Counter Rules
- Start: R1 (first dispatch)
- Increment: +1 per new instruction dispatch
- Authority: HQ is sole authority on round counter
- Check: `current_round < 15` before every dispatch
- R15 = last turn. No R16 ever.

## State Hints
- `NEW` → `DISPATCHED` → `IN_PROGRESS` → `DISTILLED` → `ACCEPTED` → `CLOSED`
- Branches: `BLOCKED`, `REROUTED`, `CAPPED`

## sessions_send Fallback
If thread subject cannot be set or updated:
1. Proceed using sessions_send as continuation mechanism.
2. Carry TASK-ID + round tag in message body.
3. Post thread说明: `⚠️ 未收到 thread 中的执行角色消息，但已通过 sessions_send 收到结果...`
4. Do not stall task waiting for thread confirmation.
