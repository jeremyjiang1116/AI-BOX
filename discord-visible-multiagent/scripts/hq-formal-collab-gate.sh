#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STATE_DIR="${TASK_STATE_DIR:-$WORKSPACE_ROOT/shared/task/state}"
DISPATCH_HELPER="$STATE_DIR/hq-dispatch-helper.sh"
DB_PATH="${TASK_DB_PATH:-$STATE_DIR/tasks.db}"

usage() {
  cat <<'EOF'
Usage:
  hq-formal-collab-gate.sh \
    --title "<任务标题>" \
    --slug "<slug>" \
    --target-channel-id "<执行频道ID>" \
    --executor-agent "<executor_agent>" \
    --executor-session-key "<sessionKey>" \
    --task-goal "<任务目标>" \
    --baseline "<路径列表>" \
    --output-contract "<产出要求>" \
    [--round-instruction "当前轮执行说明"] \
    [--round-result-contract "当前轮结果形态约束"] \
    [--round-result-body "当前轮实际落地内容"] \
    [--phase "执行阶段"] \
    [--priority normal] \
    [--hq-channel "channel:<HQ_CHANNEL_ID>"]

Purpose:
  Formal collaboration entry gate for HQ tasks.

Behavior:
  1. Create the task record and generate visible-dispatch payloads
  2. Return executor handoff text, but mark handoff as BLOCKED
  3. Handoff stays blocked until visible anchors are written back:
     - thread_id
     - hq_message_id
     - status=ACTIVE

This helper does NOT perform real Discord sends.
This helper does NOT allow executor handoff before visible anchors exist.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

json_get() {
  python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1], ""))' "$1"
}

TITLE=""
SLUG=""
TARGET_CHANNEL_ID=""
EXECUTOR_AGENT=""
EXECUTOR_SESSION_KEY=""
TASK_GOAL=""
BASELINE=""
OUTPUT_CONTRACT=""
ROUND_INSTRUCTION=""
ROUND_RESULT_CONTRACT=""
ROUND_RESULT_BODY=""
PHASE="执行阶段"
PRIORITY="normal"
HQ_CHANNEL="${OPENCLAW_HQ_CHANNEL:-channel:<HQ_CHANNEL_ID>}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --title) TITLE="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --target-channel-id) TARGET_CHANNEL_ID="$2"; shift 2 ;;
    --executor-agent) EXECUTOR_AGENT="$2"; shift 2 ;;
    --executor-session-key) EXECUTOR_SESSION_KEY="$2"; shift 2 ;;
    --task-goal) TASK_GOAL="$2"; shift 2 ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --output-contract) OUTPUT_CONTRACT="$2"; shift 2 ;;
    --round-instruction) ROUND_INSTRUCTION="$2"; shift 2 ;;
    --round-result-contract) ROUND_RESULT_CONTRACT="$2"; shift 2 ;;
    --round-result-body) ROUND_RESULT_BODY="$2"; shift 2 ;;
    --phase) PHASE="$2"; shift 2 ;;
    --priority) PRIORITY="$2"; shift 2 ;;
    --hq-channel) HQ_CHANNEL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for v in TITLE SLUG TARGET_CHANNEL_ID EXECUTOR_AGENT EXECUTOR_SESSION_KEY TASK_GOAL BASELINE OUTPUT_CONTRACT; do
  [[ -n "${!v}" ]] || { echo "Missing required arg: $v" >&2; usage; exit 1; }
done

if [[ "$HQ_CHANNEL" == *"<HQ_CHANNEL_ID>"* ]]; then
  echo "Missing --hq-channel or OPENCLAW_HQ_CHANNEL; default placeholder is not sendable" >&2
  usage
  exit 1
fi

require_cmd python3
require_cmd sqlite3
require_cmd "$DISPATCH_HELPER"

dispatch_args=(
  --title "$TITLE"
  --slug "$SLUG"
  --target-channel-id "$TARGET_CHANNEL_ID"
  --executor-agent "$EXECUTOR_AGENT"
  --executor-session-key "$EXECUTOR_SESSION_KEY"
  --task-goal "$TASK_GOAL"
  --baseline "$BASELINE"
  --output-contract "$OUTPUT_CONTRACT"
  --phase "$PHASE"
  --priority "$PRIORITY"
  --hq-channel "$HQ_CHANNEL"
)
if [[ -n "$ROUND_INSTRUCTION" ]]; then
  dispatch_args+=(--round-instruction "$ROUND_INSTRUCTION")
fi
if [[ -n "$ROUND_RESULT_CONTRACT" ]]; then
  dispatch_args+=(--round-result-contract "$ROUND_RESULT_CONTRACT")
fi
if [[ -n "$ROUND_RESULT_BODY" ]]; then
  dispatch_args+=(--round-result-body "$ROUND_RESULT_BODY")
fi

dispatch_json="$($DISPATCH_HELPER "${dispatch_args[@]}")"

GATE_INPUT_JSON="$dispatch_json" python3 -c '
import json, os
payload = json.loads(os.environ["GATE_INPUT_JSON"])
task = payload["task"]
intent = payload["dispatch_runtime_intent"]
writeback = payload["post_send_writeback_required"]
visible_contract = payload.get("visible_contract") or {}
out = {
  "task": task,
  "collaboration_gate": {
    "kind": "formal-collaboration-entry",
    "task_id": task["task_id"],
    "classification": "formal_multi_agent_collaboration",
    "visible_dispatch_required": True,
    "executor_handoff_allowed": False,
    "block_reason": "visible_dispatch_incomplete",
    "required_before_handoff": {
      "thread_id": None,
      "hq_message_id": None,
      "status_must_be": "ACTIVE"
    }
  },
  "visible_contract": visible_contract,
  "visible_dispatch_payload": {
    "target_channel": intent["target_channel"],
    "thread_name": intent["thread_name"],
    "thread_starter_message": intent["thread_starter_message"],
    "r1_message": intent["r1_message"]
  },
  "executor_handoff_payload": {
    "executor_session_key": intent["executor_session_key"],
    "message": intent["executor_message"],
    "allowed_now": False,
    "note": "Do not send until visible anchors are written back"
  },
  "post_visible_dispatch_writeback_required": writeback,
  "next_action": "Create thread + post visible [R1] + write back thread_id/hq_message_id/status=ACTIVE before executor handoff"
}
print(json.dumps(out, ensure_ascii=False, indent=2))
' 
