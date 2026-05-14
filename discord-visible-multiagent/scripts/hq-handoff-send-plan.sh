#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HANDOFF_HELPER="$SCRIPT_DIR/hq-executor-handoff-helper.sh"
VALIDATOR="$SCRIPT_DIR/validate_handoff_send_plan.py"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
RECORD_SEND="$WORKSPACE_ROOT/shared/task/state/record-runtime-send.sh"

usage() {
  cat <<'EOF'
Usage:
  hq-handoff-send-plan.sh --task-id <TASK-ID> [--format json|tool_call|exec_json] [--actor <ACTOR>] [--record-preflight]

Purpose:
  Produce the only valid runtime send plan for a formal executor handoff.

Behavior:
  1. Reads the formal handoff payload from hq-executor-handoff-helper.sh
  2. Enforces selector-only planning rules
  3. Validates the exact runtime send shape internally
  4. Returns a runtime send plan, but does NOT perform the send
  5. Optional --record-preflight records only validation evidence, not a real handoff

Hard rules:
  - If executor_session_key is present, it is the only allowed selector
  - label is never emitted as a free-form note/tag field
  - Current runtime requires a whitespace-only label placeholder to avoid selector conflict
  - This helper exists to prevent ad hoc sessions_send parameter combinations

Formats:
  - json      : structured send plan + blocker template
  - tool_call : exact tool-call arguments for runtimes that require whitespace label placeholder
  - exec_json : exact JSON payload for validation / preflight / regression checks

Record-preflight:
  --record-preflight writes kind=executor_handoff_preflight. It must never be
  treated as proof that sessions_send already happened.
EOF
}

TASK_ID=""
FORMAT="json"
ACTOR="paimon-chief"
RECORD_PREFLIGHT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --record-preflight) RECORD_PREFLIGHT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

[[ -n "$TASK_ID" ]] || { echo "Missing --task-id" >&2; usage; exit 1; }
[[ "$FORMAT" == "json" || "$FORMAT" == "tool_call" || "$FORMAT" == "exec_json" ]] || { echo "Unsupported --format: $FORMAT" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Missing required command: python3" >&2; exit 1; }
command -v "$HANDOFF_HELPER" >/dev/null 2>&1 || { echo "Missing required helper: $HANDOFF_HELPER" >&2; exit 1; }

set +e
handoff_json="$($HANDOFF_HELPER --task-id "$TASK_ID" 2>&1)"
status=$?
set -e
if [[ $status -ne 0 ]]; then
  if [[ -n "$handoff_json" ]]; then
    printf '%s\n' "$handoff_json"
  else
    printf '%s\n' '{"task_id":null,"send_plan_allowed":false,"error":"handoff_helper_failed_without_output"}'
  fi
  exit $status
fi
[[ -n "$handoff_json" ]] || {
  printf '%s\n' '{"task_id":null,"send_plan_allowed":false,"error":"empty_handoff_helper_output"}'
  exit 7
}
exec_json="$(HANDOFF_JSON="$handoff_json" python3 -c 'import json, os, sys
obj = json.loads(os.environ["HANDOFF_JSON"])
if not obj.get("handoff_allowed"):
    print(json.dumps({
        "task_id": obj.get("task_id"),
        "send_plan_allowed": False,
        "error": obj.get("error") or "handoff_not_allowed",
        "evidence": obj
    }, ensure_ascii=False, indent=2))
    sys.exit(4)

session_key = obj.get("sessions_send_target", {}).get("sessionKey") or obj.get("executor_session_key") or ""
message = obj.get("executor_handoff_message") or ""
agent_id = obj.get("executor_session_key", "").split(":")[1] if obj.get("executor_session_key") else ""
if not session_key:
    print(json.dumps({
        "task_id": obj.get("task_id"),
        "send_plan_allowed": False,
        "error": "missing_executor_session_key",
        "evidence": "selector-only send requires exact executor_session_key"
    }, ensure_ascii=False, indent=2))
    sys.exit(5)
if not message:
    print(json.dumps({
        "task_id": obj.get("task_id"),
        "send_plan_allowed": False,
        "error": "missing_handoff_message"
    }, ensure_ascii=False, indent=2))
    sys.exit(6)

print(json.dumps({
    "agentId": agent_id,
    "label": " ",
    "sessionKey": session_key,
    "message": message,
    "timeoutSeconds": 120,
    "contract": {
        "selector_mode": "sessionKey_plus_whitespace_label",
        "label_must_equal": " ",
        "freeform_label_forbidden": True,
        "manual_shape_changes_forbidden": True,
    }
}, ensure_ascii=False))')"

validation_output="$(printf '%s' "$exec_json" | python3 "$VALIDATOR")"

if [[ "$RECORD_PREFLIGHT" == "1" ]]; then
  compact_payload="$(python3 - <<'PY' "$exec_json"
import json, sys
obj=json.loads(sys.argv[1])
print(json.dumps({
  "tool":"sessions_send",
  "agentId":obj.get("agentId"),
  "sessionKey":obj.get("sessionKey"),
  "label":obj.get("label"),
  "timeoutSeconds":obj.get("timeoutSeconds"),
  "contract":obj.get("contract", {}),
}, ensure_ascii=False))
PY
)"
  bash "$RECORD_SEND" \
    --task-id "$TASK_ID" \
    --kind executor_handoff_preflight \
    --actor "$ACTOR" \
    --summary "Formal handoff preflight passed; real sessions_send still required" \
    --payload-json "$compact_payload"
fi

FORMAT="$FORMAT" EXEC_JSON="$exec_json" VALIDATION_OUTPUT="$validation_output" TASK_ID="$TASK_ID" python3 -c 'import json, os, sys
fmt = os.environ["FORMAT"]
exec_obj = json.loads(os.environ["EXEC_JSON"])
validation = json.loads(os.environ["VALIDATION_OUTPUT"])
task_id = os.environ["TASK_ID"]

if fmt == "exec_json":
    print(json.dumps(exec_obj, ensure_ascii=False, indent=2))
    sys.exit(0)

if fmt == "tool_call":
    print(json.dumps({
        "tool": "sessions_send",
        "arguments": {
            "agentId": exec_obj.get("agentId"),
            "label": exec_obj.get("label"),
            "sessionKey": exec_obj.get("sessionKey"),
            "message": exec_obj.get("message"),
            "timeoutSeconds": exec_obj.get("timeoutSeconds")
        },
        "rules": {
            "label_mode": "whitespace_placeholder",
            "label_must_equal": " ",
            "sessionKey_must_be_present": True,
            "manual_shape_changes_forbidden": True,
            "fallback_if_runtime_rejects_whitespace_label": "BLOCKED_runtime_tooling_boundary"
        },
        "validation": validation
    }, ensure_ascii=False, indent=2))
    sys.exit(0)

out = {
    "task_id": task_id,
    "send_plan_allowed": True,
    "policy": {
        "selector_mode": "sessionKey_plus_whitespace_label",
        "label_allowed": True,
        "label_mode": "whitespace_placeholder_only",
        "label_must_equal": " ",
        "freeform_label_forbidden": True,
        "manual_shape_changes_forbidden": True,
        "fallback_if_runtime_conflicts": "BLOCKED_runtime_tooling_boundary"
    },
    "runtime_send_plan": {
        "tool": "sessions_send",
        "agentId": exec_obj.get("agentId"),
        "label": exec_obj.get("label"),
        "sessionKey": exec_obj.get("sessionKey"),
        "message": exec_obj.get("message"),
        "timeoutSeconds": exec_obj.get("timeoutSeconds")
    },
    "validation": validation,
    "blocked_template": {
        "status": "BLOCKED",
        "reason": "runtime_tooling_boundary",
        "evidence": "sessions_send rejected the required whitespace-label sessionKey send shape"
    }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
' 
