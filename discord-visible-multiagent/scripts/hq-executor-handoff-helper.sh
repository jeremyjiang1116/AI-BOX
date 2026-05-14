#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STATE_DIR="$WORKSPACE_ROOT/shared/task/state"
DB_PATH="${TASK_DB_PATH:-$STATE_DIR/tasks.db}"
READY_HELPER="$SCRIPT_DIR/hq-collab-handoff-ready.sh"

usage() {
  cat <<'EOF'
Usage:
  hq-executor-handoff-helper.sh --task-id <TASK-ID>

Purpose:
  Produce the formal executor handoff payload only when the task has passed
  the collaboration readiness gate.

Rules:
  - If readiness check fails, this helper exits non-zero.
  - If readiness check passes, this helper returns the executor session key,
    handoff message, and visible anchors.

This helper does NOT deliver the message itself.
EOF
}

TASK_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$TASK_ID" ]] || { echo "Missing --task-id" >&2; usage; exit 1; }
command -v sqlite3 >/dev/null 2>&1 || { echo "Missing required command: sqlite3" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Missing required command: python3" >&2; exit 1; }
command -v "$READY_HELPER" >/dev/null 2>&1 || { echo "Missing required helper: $READY_HELPER" >&2; exit 1; }

if ! ready_json="$($READY_HELPER --task-id "$TASK_ID")"; then
  echo "$ready_json"
  exit 3
fi
[[ -n "$ready_json" ]] || ready_json='[]'

escaped_task_id="$(printf "%s" "$TASK_ID" | sed "s/'/''/g")"
row="$(sqlite3 -json "$DB_PATH" "SELECT task_id, executor_agent, executor_session_key, thread_id, hq_message_id, current_round, result_summary, result_payload_json FROM tasks WHERE task_id = '$escaped_task_id';")"
[[ -n "$row" ]] || row='[]'

READY_JSON="$ready_json" ROW_JSON="$row" python3 -c '
import json, os, sys
from pathlib import Path
ready = json.loads(os.environ["READY_JSON"])
rows = json.loads(os.environ["ROW_JSON"])
if not rows:
    print(json.dumps({"task_id": None, "error": "task_not_found"}, ensure_ascii=False, indent=2))
    sys.exit(4)
row = rows[0]
task_id = row["task_id"]
executor_agent = row.get("executor_agent") or ""
round_no = row.get("current_round") or 1
result_summary = row.get("result_summary") or ""
result_payload_json = row.get("result_payload_json") or ""
thread_id = row.get("thread_id")
hq_message_id = row.get("hq_message_id")

visible_contract = None
if result_payload_json:
    try:
        payload = json.loads(result_payload_json)
        if isinstance(payload, dict):
            visible_contract = payload.get("visible_contract")
    except Exception:
        visible_contract = None

if not isinstance(visible_contract, dict):
    print(json.dumps({
        "task_id": task_id,
        "handoff_allowed": False,
        "error": "visible_contract_missing",
        "evidence": "result_payload_json.visible_contract not found"
    }, ensure_ascii=False, indent=2))
    sys.exit(6)

visible_output_contract = visible_contract.get("output_contract") or ""
visible_round_instruction = visible_contract.get("round_instruction") or ""
visible_round_result_contract = visible_contract.get("round_result_contract") or ""
visible_round_result_body = visible_contract.get("round_result_body") or ""
visible_r1_message = visible_contract.get("visible_r1_message") or ""
executor_handoff_message = visible_contract.get("executor_handoff_message") or ""
if not visible_output_contract or not visible_round_instruction or not visible_round_result_contract or not visible_round_result_body or not visible_r1_message or not executor_handoff_message:
    print(json.dumps({
        "task_id": task_id,
        "handoff_allowed": False,
        "error": "visible_contract_incomplete",
        "evidence": {
            "has_output_contract": bool(visible_output_contract),
            "has_round_instruction": bool(visible_round_instruction),
            "has_round_result_contract": bool(visible_round_result_contract),
            "has_round_result_body": bool(visible_round_result_body),
            "has_visible_r1_message": bool(visible_r1_message),
            "has_executor_handoff_message": bool(executor_handoff_message),
        }
    }, ensure_ascii=False, indent=2))
    sys.exit(6)

sessions_root = Path(os.environ.get("OPENCLAW_AGENTS_ROOT", str(Path.home() / ".openclaw/agents")))
sessions_path = sessions_root / executor_agent / "sessions/sessions.json"
executor_account = ""
account_evidence = []
if sessions_path.exists():
    try:
        sessions_obj = json.loads(sessions_path.read_text())
        candidates = []
        for session_key, meta in sessions_obj.items():
            if not isinstance(meta, dict):
                continue
            origin = meta.get("origin") or {}
            delivery = meta.get("deliveryContext") or {}
            for label, value in [
                ("origin.accountId", origin.get("accountId")),
                ("deliveryContext.accountId", delivery.get("accountId")),
                ("lastAccountId", meta.get("lastAccountId")),
            ]:
                if value:
                    candidates.append((label, value, session_key))
        values = [v for _, v, _ in candidates]
        uniq = sorted(set(values))
        if len(uniq) == 1:
            executor_account = uniq[0]
            account_evidence = [
                {"source": label, "value": value, "sessionKey": session_key}
                for label, value, session_key in candidates if value == executor_account
            ]
        elif len(uniq) > 1:
            print(json.dumps({
                "task_id": task_id,
                "handoff_allowed": False,
                "error": "executor_account_binding_ambiguous",
                "executor_agent": executor_agent,
                "candidate_accounts": uniq,
                "evidence": [
                    {"source": label, "value": value, "sessionKey": session_key}
                    for label, value, session_key in candidates
                ]
            }, ensure_ascii=False, indent=2))
            sys.exit(5)
    except Exception as e:
        print(json.dumps({
            "task_id": task_id,
            "handoff_allowed": False,
            "error": "executor_sessions_parse_failed",
            "executor_agent": executor_agent,
            "evidence": str(e),
            "sessions_path": str(sessions_path),
        }, ensure_ascii=False, indent=2))
        sys.exit(5)

if not executor_account:
    print(json.dumps({
        "task_id": task_id,
        "handoff_allowed": False,
        "error": "executor_account_binding_missing",
        "executor_agent": executor_agent,
        "evidence": {
            "sessions_path": str(sessions_path),
            "exists": sessions_path.exists(),
        }
    }, ensure_ascii=False, indent=2))
    sys.exit(5)

blocked_notify_body = f"[{task_id}][R{round_no}] BLOCKED: cannot_post_to_thread"
blocked_reason_example = "reason: <最直接失败原因>"
blocked_evidence_example = "evidence: <最关键错误证据>"
hq_notify_body = f"[{task_id}][R{round_no}] 本轮已完成，请读取 thread 现场结果并决定下一轮。"
dynamic_send_cmd = f"openclaw message send --channel discord --account {executor_account} --target channel:{thread_id} --message \\\"<FINAL_RESULT>\\\""
hq_notify_transport = "thread_visible_executor_notify"
hq_notify_send_cmd = f"openclaw message send --channel discord --account {executor_account} --target channel:{thread_id} --message \"{hq_notify_body}\""
hq_notify_delivery_note = "由 executor 使用绑定 Discord account 把固定 notify 文本发到同一个任务 thread；HQ 再读取 thread 现场结果和 notify。"
message = f"""## 当前轮执行指令（正式 handoff）

**任务ID**：{task_id}
**轮次**：R{round_no}
**执行锚点**：thread_id={thread_id} / hq_message_id={hq_message_id}
**你当前绑定的 Discord account**：`{executor_account}`

以下合同必须与 thread 中当前轮公开指令保持一致，你不得自行改写：

```text
{executor_handoff_message}
```

### 合同一致性说明
- 你在 thread 中实际落地的本轮结果，必须满足 thread 公开任务单已经说明的 output contract
- 不得额外引入 thread 中未公开的隐藏要求
- 若你发现 HQ handoff 与 thread 公开任务单不一致，应立即 BLOCKED 回 HQ，不要猜测执行

### Step 0：执行前自检
先确认你能识别目标 thread_id，并且知道结果必须发到 `thread_id={thread_id}`，不是主频道。
同时确认你本轮所有 Discord outbound/read/thread 操作都必须使用你自己的绑定 account：`{executor_account}`。
若无法确认，立即回 HQ：
```text
{blocked_notify_body}
{blocked_reason_example}
{blocked_evidence_example}
```

### Step 1：由你本人完成本轮执行，并把结果发到目标 thread
这一步必须由当前执行者本人完成，HQ 或其他角色不得代发。
允许使用本 workflow 明示的 **sanctioned assisted-post / standard send path**。

本轮执行说明（你需要做的事）：

```text
{visible_round_instruction}
```

本轮结果形态约束（你最终发到 thread 的内容必须满足这个约束）：

```text
{visible_round_result_contract}
```

本轮 thread 落地内容（当前公开的结果正文占位）：

```text
{visible_round_result_body}
```

发送要求：
- 若本轮结果是动态值，你必须先完成本轮选择/计算，再把最终结果发到 thread；
- 不要把任务说明文本原样发出去；
- 最终发送内容必须满足“结果形态约束”；
- 若你当前会话缺少 native/direct post 能力，你仍可使用下方由 HQ/skill 明示的 sanctioned assisted-post / standard send path；
- 只要实际发送动作由你本人完成，且使用的是本 handoff 明示路径，该发送就属于本 workflow 认可的合法执行。

本轮经 HQ/skill 明示批准的标准发送路径如下（把 <FINAL_RESULT> 替换为你本轮实际算出的最终结果）：

```bash
{dynamic_send_cmd}
```

这条命令在本轮中属于 **sanctioned assisted-post / standard send path**，不是未授权旁路。
你不得自创其他 shell/CLI/provider messaging 旁路，但可以使用上面这条被明确批准的路径完成 thread 落地。

### Step 1.5：短时确认（executor 内部处理，不上浮为 HQ 正式回执）
执行发送命令后，由你自己在当前轮内完成一个短、有限的确认流程，例如短时 poll 命令结果或短时检查 thread 是否出现消息。
确认相关的 Discord read/thread 操作同样必须使用你自己的绑定 account：`{executor_account}`。
在这个内部确认阶段：
- 不要把 `pending confirmation` 发给 HQ
- 不要因为“当前还没看到成功回执”就立刻宣布 BLOCKED
- 如果你无法解析或确认你自己的绑定 account，就直接 BLOCKED，不要猜其他 account

只有两种正式回执允许发给 HQ：
1. **确认成功** → 使用同一任务 thread 发送固定 notify：`{hq_notify_body}`
2. **确认失败** → 发下面的 BLOCKED 终态：
```text
{blocked_notify_body}
{blocked_reason_example}
{blocked_evidence_example}
```

### Step 2：再显式通知 HQ
只有在你已经确认 thread 发帖成功后，才通知 HQ。
当前工作区对 HQ notify 的标准路径是 **thread-visible executor notify**：
- 你必须把下面的固定 notify 文本发到同一个任务 thread：`thread_id={thread_id}`；
- 发送必须使用你的绑定 account：`{executor_account}`；
- HQ 从同一任务 thread 读取这条完成通知；
- 禁止把 notify 发到 executor 主频道或 `#hq-command`；
- `hq_message_id={hq_message_id}` 是 HQ 审核/校验锚点，不是 Discord channel target。

正式 notify 发送命令如下：

```bash
{hq_notify_send_cmd}
```

正式 notify 文本必须是：

```text
{hq_notify_body}
```

发送成功后，当前 executor 会话的最终回复必须只输出：

```text
NO_REPLY
```

这样可以避免 runtime 把同一条任务 notify 再投递到 executor 主频道。HQ 的推进依据是 thread 中可见的结果与 notify，不是 executor 会话最终文本。

### 强约束
1. 只执行当前轮，不预写后续轮次；
2. 没有 thread 现场结果，禁止回“已完成”；
3. 发送动作必须由当前执行者本人完成，禁止 HQ 或其他角色代发；
4. 只允许使用本 handoff 明示的标准受控路径，不允许自创其他 shell/CLI 旁路；
5. 不要伪造发送主体，不要把别人的发送说成是你自己完成；
6. `pending confirmation` 只是你内部短暂状态，不是发给 HQ 的正式回执；
7. `BLOCKED` 必须带 `reason` 和 `evidence`，不能只回空壳 BLOCKED；
8. 不要猜测 `--account`，所有 Discord 相关动作必须使用你当前绑定的 account：`{executor_account}`；
9. 若使用上方 HQ/skill 明示的 sanctioned assisted-post / standard send path，不要把它误判成“未验证可用的一等 direct post 才能执行”的阻塞理由；
10. 成功把 result 与 notify 都发入 thread 后，最终会话回复必须是 `NO_REPLY`，不得把 notify 再回到 executor 主频道。"""

out = {
    "task_id": task_id,
    "handoff_allowed": True,
    "executor_session_key": row.get("executor_session_key"),
    "visible_anchors": {
        "thread_id": thread_id,
        "hq_message_id": hq_message_id,
    },
    "visible_contract": visible_contract,
    "executor_handoff_message": message,
    "state_snapshot": {
        "current_round": round_no,
        "result_summary": result_summary or None,
        "result_payload_json": result_payload_json or None,
    },
    "executor_binding": {
        "agent_id": executor_agent,
        "account_id": executor_account,
        "evidence": account_evidence,
        "source": str(sessions_path),
    },
    "executor_preflight": {
        "ownership_gate_helper": "skills/discord-visible-multiagent/scripts/executor-ownership-gate.sh",
        "required_args": {
            "task_id": task_id,
            "executor_agent": executor_agent,
            "executor_account": executor_account,
            "thread_id": str(thread_id),
        },
        "purpose": "block cross-task thread sends, wrong executor identity, and wrong bound account before executor-owned thread result posting"
    },
    "sessions_send_target": {
        "sessionKey": row.get("executor_session_key")
    },
    "executor_templates": {
        "thread_result_body": visible_round_result_body,
        "hq_notify_body": hq_notify_body,
        "blocked_notify_body": blocked_notify_body,
        "blocked_reason_example": blocked_reason_example,
        "blocked_evidence_example": blocked_evidence_example,
        "thread_post_mode": "executor_owned_standard_path",
        "standard_send_command": dynamic_send_cmd,
        "hq_notify_transport": hq_notify_transport,
        "hq_notify_delivery_note": hq_notify_delivery_note,
        "hq_notify_command": hq_notify_send_cmd,
        "sanctioned_assisted_post": True,
    },
}
print(json.dumps(out, ensure_ascii=False, indent=2))
'
