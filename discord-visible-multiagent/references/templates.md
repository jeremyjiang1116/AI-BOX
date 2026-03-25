# Cross-Channel Templates (v3)

## 1) HQ Thread Creation Command

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

## 2) HQ → Executor Dispatch Template (R1 and follow-up)

```text
## [R<n>] 任务派单

**任务ID**：<id>
**任务目标**：<描述>
**基线材料**：<路径列表>
**产出要求**：<具体要求>
**回报要求**：完成后在 thread 回报，并通知 HQ

---
```

## 3) HQ Quality Challenge / Revision Request

```text
## [R<n>+1] 质量审核反馈

**任务ID**：<id>

**具体质疑**
<specific quality gap or missing evidence>

**修改建议**
<specific revision request>

**输出合同重审**
- <remaining unmet criterion 1>
- <remaining unmet criterion 2>

---
```

## 4) HQ Acceptance Signal

```text
## <任务ID> 验收确认

**审核结果**：✅ 通过
**最终轮次**：R<n>
**产出物**：<列出产出物路径>
**结论**：<简短总结>

---
```

## 5) HQ Capped Close (R15)

```text
## <任务ID> 强制收口（达到 R15 上限）

**审核结果**：⚠️ CAPPED
**最终轮次**：R15 / R15
**当前进展**：<brief status>
**未达标准**：<what was not achieved>
**建议**：<人工介入 / 重新派单 / 拆分任务>

---
```

## 6) Executor Result Post Template

```text
## [R<n>] <子任务阶段> 结果

**任务ID**：<id>
**产出物**：<路径或内容>
**状态**：完成 / 部分完成 / 阻塞

<key output>

---
```

## 7) ⚠️ 如何在 Thread 中发帖（必须按此格式！）

> 你的 Discord session 绑定到父频道上下文，不会自动看见 thread 里的内容。收到任务后，必须用以下命令显式发到 thread：

```bash
openclaw message send \
  --account <你的账号> \
  --channel discord \
  --target "<THREAD-ID>" \
  --message "## [R<轮次>] <子任务阶段> 结果

**任务ID**：<TASK-ID>
**产出物**：<路径或内容>
**状态**：完成 / 部分完成 / 阻塞

<具体产出内容>

---" \
  --json
```

**注意**：
- `--target` 后面直接跟 thread ID，不要加任何前缀（如 `thread:`）
- 示例：`--target "1485916657636610048"`
- `--account` 填写你的角色账号（alhaitham 用 `alhaitham`，yelan 用 `yelan`）

## 8) Executor → HQ Notification Template

```text
[<任务ID>][R<n>] <brief status>

产出：<path or brief result>

<optional: one-line summary>
```

## 9) HQ Round Advance Check清单

```
- [ ] 当前是第 R<n> 轮
- [ ] R<n> < 15
- [ ] 上一轮结果已在 thread 可见
- [ ] HQ 已收到显式通知
- [ ] 我已读取上一轮真实结果
- [ ] 下一轮指令已先公开发在 thread（含 [R<n>+1] 标记）
- [ ] 再把同一轮指令交给执行角色
```

## 10) HQ Final Report to #hq-command

```text
## <任务ID> 完成汇报

**状态**：✅ DONE / ⚠️ REVIEW / ❌ FAILED / ⚠️ CAPPED
**执行角色**：<角色名>
**总轮次**：R<n>
**产出**：<产出路径>
**简要结论**：<1-2句话>

---
```

## 11) Thread说明 (sessions_send Fallback)

```text
⚠️ 未收到 thread 中的执行角色消息，但已通过 sessions_send 收到结果。

实际结果：<result>

可以继续任务。
```
