#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_DIR="$WORKSPACE_ROOT/shared/task/state"
DB_PATH="${TASK_DB_PATH:-$STATE_DIR/tasks.db}"

usage() {
  cat <<'EOF'
Usage:
  hq-collab-handoff-ready.sh --task-id <TASK-ID>

Checks whether a formal collaboration task is allowed to hand off work to the executor.

Required conditions:
- thread_id exists
- hq_message_id exists
- status = ACTIVE
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

escaped_task_id="$(printf "%s" "$TASK_ID" | sed "s/'/''/g")"
row="$(sqlite3 -json "$DB_PATH" "SELECT task_id, status, thread_id, hq_message_id, executor_session_key FROM tasks WHERE task_id = '$escaped_task_id';")"
[[ -n "$row" ]] || row='[]'

ROW_JSON="$row" python3 -c '
import json, os, sys
rows = json.loads(os.environ["ROW_JSON"])
if not rows:
    print(json.dumps({
        "task_id": None,
        "handoff_allowed": False,
        "block_reason": "task_not_found"
    }, ensure_ascii=False, indent=2))
    sys.exit(2)
row = rows[0]
status = row.get("status") or ""
thread_id = row.get("thread_id") or ""
hq_message_id = row.get("hq_message_id") or ""
missing = []
if status != "ACTIVE":
    missing.append("status_not_active")
if not thread_id:
    missing.append("missing_thread_id")
if not hq_message_id:
    missing.append("missing_hq_message_id")
out = {
    "task_id": row.get("task_id"),
    "status": status,
    "thread_id": thread_id or None,
    "hq_message_id": hq_message_id or None,
    "executor_session_key": row.get("executor_session_key"),
    "handoff_allowed": not missing,
    "blockers": missing,
}
print(json.dumps(out, ensure_ascii=False, indent=2))
sys.exit(0 if not missing else 3)
'