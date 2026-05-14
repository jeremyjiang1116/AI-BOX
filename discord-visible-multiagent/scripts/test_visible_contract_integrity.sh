#!/usr/bin/env bash
set -euo pipefail

ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TMPDIR="$(mktemp -d)"
DB="${TASK_DB_PATH:-$TMPDIR/workspace/shared/task/state/tasks.db}"
SOURCE_TASK="${SOURCE_TASK:-TASK-TEST-SOURCE-001}"
TEST_TASK="${TEST_TASK:-TASK-TEST-VISIBLE-CONTRACT-001}"

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

python3 - <<'PY' "$DB" "$SOURCE_TASK"
import json, sqlite3, sys
from pathlib import Path
p, source_task_id = sys.argv[1:3]
Path(p).parent.mkdir(parents=True, exist_ok=True)
conn = sqlite3.connect(p)
cur = conn.cursor()
cur.execute("""
CREATE TABLE IF NOT EXISTS tasks (
  task_id TEXT PRIMARY KEY,
  title TEXT,
  slug TEXT,
  status TEXT,
  phase TEXT,
  hq_channel TEXT,
  thread_name TEXT,
  executor_agent TEXT,
  executor_session_key TEXT,
  current_round INTEGER,
  priority TEXT,
  created_at TEXT,
  updated_at TEXT,
  next_check_at TEXT,
  thread_id TEXT,
  hq_message_id TEXT,
  result_summary TEXT,
  result_payload_json TEXT
)
""")
cur.execute("SELECT 1 FROM tasks WHERE task_id=?", (source_task_id,))
if cur.fetchone() is None:
    cur.execute(
        """INSERT INTO tasks (
          task_id,title,slug,status,phase,hq_channel,thread_name,executor_agent,executor_session_key,
          current_round,priority,created_at,updated_at,next_check_at,thread_id,hq_message_id,result_summary,result_payload_json
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (
          source_task_id, "Fixture source task", "fixture-source", "NEW", "test", "channel:000000000000000000",
          "fixture-thread", "alhaitham-coder", "agent:alhaitham-coder:discord:channel:666666666666666666",
          1, "normal", "2026-01-01T00:00:00+0800", "2026-01-01T00:00:00+0800", None,
          None, None, None, json.dumps({"fixture": True}, ensure_ascii=False),
        ),
    )
conn.commit()
conn.close()
PY

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
