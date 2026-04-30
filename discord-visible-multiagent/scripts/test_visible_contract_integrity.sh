#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STATE_DIR="${TASK_STATE_DIR:-$WORKSPACE_ROOT/shared/task/state}"
DB="${TASK_DB_PATH:-$STATE_DIR/tasks.db}"
TMPDIR="$(mktemp -d)"
SOURCE_TASK="TASK-20260416-028"
TEST_TASK="TASK-TEST-VISIBLE-CONTRACT-001"

cleanup() {
  sqlite3 "$DB" "DELETE FROM tasks WHERE task_id='$TEST_TASK';" >/dev/null 2>&1 || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

python3 - <<'PY' "$DB" "$SOURCE_TASK" "$TEST_TASK"
import sqlite3, sys
p, source_task_id, test_task_id = sys.argv[1:4]
conn = sqlite3.connect(p)
conn.row_factory = sqlite3.Row
cur = conn.cursor()
cur.execute("SELECT * FROM tasks WHERE task_id=?", (source_task_id,))
row = cur.fetchone()
if not row:
    raise SystemExit(f"source task not found: {source_task_id}")
cols = [r[1] for r in cur.execute('PRAGMA table_info(tasks)').fetchall()]
data = {c: row[c] for c in cols}
data['task_id'] = test_task_id
data['status'] = 'NEW'
cur.execute("DELETE FROM tasks WHERE task_id=?", (test_task_id,))
cur.execute(f"INSERT INTO tasks ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})", [data[c] for c in cols])
conn.commit()
conn.close()
PY

printf '\n== manual payload construction integrity ==\n'
export TASK_ID="$TEST_TASK"
export TARGET_CHANNEL="channel:123"
export THREAD_NAME="thread-test"
export THREAD_STARTER_MESSAGE="starter-A"
export R1_MESSAGE="visible-r1-A"
export TASK_GOAL="goal-A"
export BASELINE="base-A"
export OUTPUT_CONTRACT="contract-A"
export ROUND_INSTRUCTION="instruction-A"
export ROUND_RESULT_CONTRACT="result-contract-A"
export ROUND_RESULT_BODY="result-body-A"
export EXECUTOR_HANDOFF_MESSAGE="handoff-A"
export NEXT_CHECK_MINUTES="5"
RESULT_PAYLOAD_JSON="$(sqlite3 -json "$DB" "SELECT task_id, title, slug, status, phase, hq_channel, thread_name, executor_agent, executor_session_key, current_round, priority, created_at, updated_at, next_check_at FROM tasks WHERE task_id = '$TEST_TASK';" | python3 -c 'import json, os, sys
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

python3 - <<'PY' "$RESULT_PAYLOAD_JSON"
import json, sys
payload = json.loads(sys.argv[1])
vc = payload['visible_contract']
assert vc['task_goal'] == 'goal-A'
assert vc['baseline'] == 'base-A'
assert vc['output_contract'] == 'contract-A'
assert vc['round_instruction'] == 'instruction-A'
assert vc['round_result_contract'] == 'result-contract-A'
assert vc['round_result_body'] == 'result-body-A'
assert vc['visible_r1_message'] == 'visible-r1-A'
assert vc['executor_handoff_message'] == 'handoff-A'
assert vc['round_result_contract'] != vc['visible_r1_message']
assert vc['executor_handoff_message'] != vc['visible_r1_message']
print(json.dumps({'ok': True}, ensure_ascii=False))
PY

printf '\nVisible contract integrity checks passed.\n'
