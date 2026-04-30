#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  test_handoff_runtime_contract.sh [TASK-ID]

Purpose:
  Non-destructive regression check for formal handoff send-plan contract.

Behavior:
  - clones the source task into a temporary task record
  - normalizes that temporary task to ACTIVE for contract testing
  - validates positive and negative send-plan behavior
  - removes the temporary task on exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STATE_DIR="${TASK_STATE_DIR:-$WORKSPACE_ROOT/shared/task/state}"
SKILL_DIR="${DISCORD_VISIBLE_MULTIAGENT_SKILL_DIR:-$SCRIPT_DIR/..}"
DB="${TASK_DB_PATH:-$STATE_DIR/tasks.db}"
HANDOFF_HELPER="$SKILL_DIR/scripts/hq-executor-handoff-helper.sh"
SEND_PLAN="$SKILL_DIR/scripts/hq-handoff-send-plan.sh"
VALIDATOR="$SKILL_DIR/scripts/validate_handoff_send_plan.py"
REMINDER="$STATE_DIR/executor-reminder-helper.sh"

SOURCE_TASK_ID="${1:-TASK-20260423-002}"
TASK_ID="TASK-TEST-HANDOFF-CONTRACT"
cleanup() {
  sqlite3 "$DB" "delete from tasks where task_id='${TASK_ID}';" >/dev/null 2>&1 || true
}
trap cleanup EXIT

python3 - <<'PY' "$DB" "$SOURCE_TASK_ID" "$TASK_ID"
import sqlite3, sys
p, source_task_id, task_id = sys.argv[1:4]
conn = sqlite3.connect(p)
conn.row_factory = sqlite3.Row
cur = conn.cursor()
cur.execute("SELECT * FROM tasks WHERE task_id=?", (source_task_id,))
row = cur.fetchone()
if not row:
    raise SystemExit(f"source task not found: {source_task_id}")
cols = [r[1] for r in cur.execute('PRAGMA table_info(tasks)').fetchall()]
data = {c: row[c] for c in cols}
data['task_id'] = task_id
data['status'] = 'ACTIVE'
cur.execute("DELETE FROM tasks WHERE task_id=?", (task_id,))
cur.execute(f"INSERT INTO tasks ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})", [data[c] for c in cols])
conn.commit()
conn.close()
PY

printf '\n== executor notify transport contract ==\n'
bash "$HANDOFF_HELPER" --task-id "$TASK_ID" > /tmp/handoff-helper.json
python3 - <<'PY' /tmp/handoff-helper.json "$TASK_ID"
import json, sys
path, task_id = sys.argv[1:3]
obj = json.load(open(path))
templates = obj.get('executor_templates') or {}
message = obj.get('executor_handoff_message') or ''
expected_notify = f'[{task_id}][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。'

assert obj.get('handoff_allowed') is True
assert templates.get('hq_notify_body') == expected_notify
assert templates.get('hq_notify_transport') == 'thread_visible_executor_notify'
notify_cmd = templates.get('hq_notify_command') or ''
assert templates.get('standard_send_command', '').split('--target channel:', 1)[1].split()[0] in notify_cmd
assert '--account alhaitham' in notify_cmd
assert 'thread-visible executor notify' in message
assert 'HQ 从同一任务 thread 读取这条完成通知' in message
assert '禁止把 notify 发到 executor 主频道或 `#hq-command`' in message
assert 'NO_REPLY' in message
assert '--target channel:<HQ_CHANNEL_ID>' not in message
assert '--reply-to' not in message
print(json.dumps({'ok': True, 'notify_transport': templates.get('hq_notify_transport')}, ensure_ascii=False))
PY

printf '\n== handoff send plan (exec_json) ==\n'
bash "$SEND_PLAN" --task-id "$TASK_ID" --format exec_json > /tmp/handoff-plan.json
cat /tmp/handoff-plan.json | sed -n '1,80p'

printf '\n== validator positive ==\n'
python3 "$VALIDATOR" < /tmp/handoff-plan.json

printf '\n== validator negative (bad label) ==\n'
python3 - <<'PY' /tmp/handoff-plan.json > /tmp/handoff-bad.json
import json, sys
obj=json.load(open(sys.argv[1]))
obj['label']='BAD-LABEL'
print(json.dumps(obj))
PY
if python3 "$VALIDATOR" < /tmp/handoff-bad.json; then
  echo 'ERROR: negative case unexpectedly passed'
  exit 1
else
  echo 'negative case correctly rejected'
fi

printf '\n== handoff send plan with embedded validation ==\n'
bash "$SEND_PLAN" --task-id "$TASK_ID" --format json > /tmp/handoff-preflight.json
cat /tmp/handoff-preflight.json | sed -n '1,120p'

printf '\n== reminder helper contract ==\n'
bash "$REMINDER" --task-id "$TASK_ID" --mode command | sed -n '1,120p'

printf '\nAll minimal handoff contract regression checks passed.\n'
