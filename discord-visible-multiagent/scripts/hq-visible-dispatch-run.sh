#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STATE_DIR="$WORKSPACE_ROOT/shared/task/state"
DB_PATH="${TASK_DB_PATH:-$STATE_DIR/tasks.db}"
UPDATE_STATUS="$STATE_DIR/update-task-status.sh"

usage() {
  cat <<'EOF'
Usage:
  hq-visible-dispatch-run.sh --gate-json-file <path>
  hq-visible-dispatch-run.sh --task-id <TASK-ID> --target-channel <channel:id> --thread-name <name> --thread-starter-message <text> --r1-message <text> [--task-goal <text>] [--baseline <text>] [--output-contract <text>] [--round-instruction <text>] [--round-result-contract <text>] [--round-result-body <text>] [--executor-handoff-message <text>] [--next-check-minutes 5] [--result-payload-json <json>]

Purpose:
  Execute the visible dispatch phase for a formal collaboration task:
  1. create thread
  2. post visible [R1]
  3. write back ACTIVE + thread_id + hq_message_id

Rules:
  - This helper performs the real Discord sends for HQ-visible dispatch.
  - Executor handoff must still happen later through the formal handoff path.
  - This helper must not send executor handoff.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

extract_last_json() {
  python3 -c 'import sys
text = sys.stdin.read()
start = text.rfind("\n{")
if start == -1:
    start = text.find("{")
else:
    start += 1
if start == -1:
    raise SystemExit("No JSON object found in command output")
print(text[start:].strip())'
}

TASK_ID=""
TARGET_CHANNEL=""
THREAD_NAME=""
THREAD_STARTER_MESSAGE=""
R1_MESSAGE=""
TASK_GOAL=""
BASELINE=""
OUTPUT_CONTRACT=""
ROUND_INSTRUCTION=""
ROUND_RESULT_CONTRACT=""
ROUND_RESULT_BODY=""
EXECUTOR_HANDOFF_MESSAGE=""
NEXT_CHECK_MINUTES="5"
RESULT_PAYLOAD_JSON=""
GATE_JSON_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --gate-json-file) GATE_JSON_FILE="$2"; shift 2 ;;
    --task-id) TASK_ID="$2"; shift 2 ;;
    --target-channel) TARGET_CHANNEL="$2"; shift 2 ;;
    --thread-name) THREAD_NAME="$2"; shift 2 ;;
    --thread-starter-message) THREAD_STARTER_MESSAGE="$2"; shift 2 ;;
    --r1-message) R1_MESSAGE="$2"; shift 2 ;;
    --task-goal) TASK_GOAL="$2"; shift 2 ;;
    --baseline) BASELINE="$2"; shift 2 ;;
    --output-contract) OUTPUT_CONTRACT="$2"; shift 2 ;;
    --round-instruction) ROUND_INSTRUCTION="$2"; shift 2 ;;
    --round-result-contract) ROUND_RESULT_CONTRACT="$2"; shift 2 ;;
    --round-result-body) ROUND_RESULT_BODY="$2"; shift 2 ;;
    --executor-handoff-message) EXECUTOR_HANDOFF_MESSAGE="$2"; shift 2 ;;
    --next-check-minutes) NEXT_CHECK_MINUTES="$2"; shift 2 ;;
    --result-payload-json) RESULT_PAYLOAD_JSON="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

require_cmd python3
require_cmd sqlite3
require_cmd openclaw
require_cmd "$UPDATE_STATUS"

if [[ -n "$GATE_JSON_FILE" ]]; then
  [[ -f "$GATE_JSON_FILE" ]] || { echo "Gate JSON file not found: $GATE_JSON_FILE" >&2; exit 1; }
  eval "$(python3 - <<'PY' "$GATE_JSON_FILE"
import json, shlex, sys
path = sys.argv[1]
obj = json.load(open(path))
task = obj.get('task') or {}
vp = obj.get('visible_dispatch_payload') or {}
wb = obj.get('post_visible_dispatch_writeback_required') or {}
result_payload = {
  'task': task,
  'visible_contract': obj.get('visible_contract') or {},
  'visible_dispatch_payload': vp,
  'post_visible_dispatch_writeback_required': wb,
}
result = {
  'TASK_ID': task.get('task_id',''),
  'TARGET_CHANNEL': vp.get('target_channel',''),
  'THREAD_NAME': vp.get('thread_name',''),
  'THREAD_STARTER_MESSAGE': vp.get('thread_starter_message',''),
  'R1_MESSAGE': vp.get('r1_message',''),
  'NEXT_CHECK_MINUTES': str(wb.get('next_check_minutes',5)),
  'RESULT_PAYLOAD_JSON': json.dumps(result_payload, ensure_ascii=False),
}
for k,v in result.items():
  print(f"{k}={shlex.quote(v)}")
PY
)"
fi

for v in TASK_ID TARGET_CHANNEL THREAD_NAME THREAD_STARTER_MESSAGE R1_MESSAGE; do
  [[ -n "${!v}" ]] || { echo "Missing required arg: $v" >&2; usage; exit 1; }
done

if [[ -z "$GATE_JSON_FILE" && -z "$RESULT_PAYLOAD_JSON" ]]; then
  for v in TASK_GOAL OUTPUT_CONTRACT ROUND_INSTRUCTION ROUND_RESULT_CONTRACT ROUND_RESULT_BODY EXECUTOR_HANDOFF_MESSAGE; do
    [[ -n "${!v}" ]] || { echo "Missing required arg for manual mode: $v" >&2; usage; exit 1; }
  done
fi

if [[ -z "$RESULT_PAYLOAD_JSON" ]]; then
  escaped_task_id="$(printf "%s" "$TASK_ID" | sed "s/'/''/g")"
  RESULT_PAYLOAD_JSON="$(TASK_ID="$TASK_ID" TARGET_CHANNEL="$TARGET_CHANNEL" THREAD_NAME="$THREAD_NAME" THREAD_STARTER_MESSAGE="$THREAD_STARTER_MESSAGE" R1_MESSAGE="$R1_MESSAGE" TASK_GOAL="$TASK_GOAL" BASELINE="$BASELINE" OUTPUT_CONTRACT="$OUTPUT_CONTRACT" ROUND_INSTRUCTION="$ROUND_INSTRUCTION" ROUND_RESULT_CONTRACT="$ROUND_RESULT_CONTRACT" ROUND_RESULT_BODY="$ROUND_RESULT_BODY" EXECUTOR_HANDOFF_MESSAGE="$EXECUTOR_HANDOFF_MESSAGE" NEXT_CHECK_MINUTES="$NEXT_CHECK_MINUTES" sqlite3 -json "$DB_PATH" "SELECT task_id, title, slug, status, phase, hq_channel, thread_name, executor_agent, executor_session_key, current_round, priority, created_at, updated_at, next_check_at FROM tasks WHERE task_id = '$escaped_task_id';" | python3 -c 'import json, os, sys
rows = json.load(sys.stdin)
if not rows:
    raise SystemExit("task_not_found")
task = rows[0]
payload = {
    "task": task,
    "visible_contract": {
        "round": 1,
        "task_goal": os.environ["TASK_GOAL"],
        "baseline": os.environ["BASELINE"],
        "output_contract": os.environ["OUTPUT_CONTRACT"],
        "round_instruction": os.environ["ROUND_INSTRUCTION"],
        "round_result_contract": os.environ["ROUND_RESULT_CONTRACT"],
        "round_result_body": os.environ["ROUND_RESULT_BODY"],
        "visible_r1_message": os.environ["R1_MESSAGE"],
        "executor_handoff_message": os.environ["EXECUTOR_HANDOFF_MESSAGE"]
    },
    "visible_dispatch_payload": {
        "target_channel": os.environ["TARGET_CHANNEL"],
        "thread_name": os.environ["THREAD_NAME"],
        "thread_starter_message": os.environ["THREAD_STARTER_MESSAGE"],
        "r1_message": os.environ["R1_MESSAGE"]
    },
    "post_visible_dispatch_writeback_required": {
        "task_id": os.environ["TASK_ID"],
        "status": "ACTIVE",
        "next_check_minutes": int(os.environ["NEXT_CHECK_MINUTES"])
    }
}
print(json.dumps(payload, ensure_ascii=False))')"
fi

THREAD_CREATE_OUTPUT_RAW="$(openclaw message thread create \
  --channel discord \
  --account default \
  --target "$TARGET_CHANNEL" \
  --thread-name "$THREAD_NAME" \
  --message "$THREAD_STARTER_MESSAGE" \
  --json 2>&1)"
THREAD_CREATE_OUTPUT="$(printf '%s' "$THREAD_CREATE_OUTPUT_RAW" | extract_last_json)"

THREAD_REPLY_OUTPUT_RAW="$(THREAD_CREATE_OUTPUT="$THREAD_CREATE_OUTPUT" R1_MESSAGE="$R1_MESSAGE" python3 - <<'PY'
import json, os, subprocess, sys
create = json.loads(os.environ['THREAD_CREATE_OUTPUT'])
thread_id = str(create['payload']['thread']['id'] if 'payload' in create and isinstance(create['payload'], dict) else create['thread']['id'])
r1 = os.environ['R1_MESSAGE']
proc = subprocess.run([
  'openclaw','message','thread','reply',
  '--channel','discord',
  '--account','default',
  '--target',thread_id,
  '--message',r1,
  '--json'
], capture_output=True, text=True)
if proc.returncode != 0:
  sys.stderr.write(proc.stderr or proc.stdout)
  sys.exit(proc.returncode)
print(proc.stdout)
PY
)"
THREAD_REPLY_OUTPUT="$(printf '%s' "$THREAD_REPLY_OUTPUT_RAW" | extract_last_json)"

WRITEBACK_JSON="$(THREAD_CREATE_OUTPUT="$THREAD_CREATE_OUTPUT" THREAD_REPLY_OUTPUT="$THREAD_REPLY_OUTPUT" python3 - <<'PY'
import json, os
create = json.loads(os.environ['THREAD_CREATE_OUTPUT'])
reply = json.loads(os.environ['THREAD_REPLY_OUTPUT'])
thread = create.get('payload', {}).get('thread') if isinstance(create.get('payload'), dict) else None
if thread is None:
  thread = create['thread']
thread_id = str(thread['id'])
message_id = None
if isinstance(reply, dict):
  if 'payload' in reply and isinstance(reply['payload'], dict):
    result = reply['payload'].get('result') or {}
    message_id = result.get('messageId')
  if message_id is None and 'result' in reply and isinstance(reply['result'], dict):
    message_id = reply['result'].get('messageId')
print(json.dumps({'thread_id': thread_id, 'hq_message_id': str(message_id) if message_id is not None else ''}, ensure_ascii=False))
PY
)"

THREAD_ID="$(printf '%s' "$WRITEBACK_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["thread_id"])')"
HQ_MESSAGE_ID="$(printf '%s' "$WRITEBACK_JSON" | python3 -c 'import json,sys; print(json.load(sys.stdin)["hq_message_id"])')"

"$UPDATE_STATUS" \
  "$TASK_ID" \
  "ACTIVE" \
  "paimon-chief" \
  "Visible dispatch completed by hq-visible-dispatch-run" \
  "$NEXT_CHECK_MINUTES" \
  "$THREAD_ID" \
  "$HQ_MESSAGE_ID" \
  "visible_dispatch_completed" \
  "$RESULT_PAYLOAD_JSON" >/dev/null

THREAD_CREATE_OUTPUT="$THREAD_CREATE_OUTPUT" THREAD_REPLY_OUTPUT="$THREAD_REPLY_OUTPUT" TASK_ID="$TASK_ID" TARGET_CHANNEL="$TARGET_CHANNEL" python3 - <<'PY'
import json, os
create = json.loads(os.environ['THREAD_CREATE_OUTPUT'])
reply = json.loads(os.environ['THREAD_REPLY_OUTPUT'])
thread = create.get('payload', {}).get('thread') if isinstance(create.get('payload'), dict) else None
if thread is None:
  thread = create.get('thread')
out = {
  'task_id': os.environ['TASK_ID'],
  'target_channel': os.environ['TARGET_CHANNEL'],
  'status': 'ACTIVE',
  'thread': thread,
  'r1_reply': reply,
  'writeback': {
    'status': 'ACTIVE',
    'thread_id': str(thread['id']),
    'hq_message_id': (
      str(((reply.get('payload') or {}).get('result') or {}).get('messageId'))
      if ((reply.get('payload') or {}).get('result') or {}).get('messageId') is not None
      else str((reply.get('result') or {}).get('messageId'))
    )
  },
  'next_action': 'Run handoff readiness check, then formal executor handoff'
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY
