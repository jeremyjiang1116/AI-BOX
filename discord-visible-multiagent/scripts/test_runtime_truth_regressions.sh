#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$(mktemp -d)"
ROOT="$OUT_DIR/workspace"
DB="$ROOT/shared/task/state/tasks.db"
SKILL_DIR="$ROOT/skills/discord-visible-multiagent"
export TASK_DB_PATH="$DB"
export OPENCLAW_WORKSPACE_ROOT="$ROOT"
export OPENCLAW_AGENTS_ROOT="$ROOT/agents"
trap 'rm -rf "$OUT_DIR"' EXIT

READY="$SKILL_DIR/scripts/hq-collab-handoff-ready.sh"
HANDOFF_HELPER="$SKILL_DIR/scripts/hq-executor-handoff-helper.sh"
SEND_PLAN="$SKILL_DIR/scripts/hq-handoff-send-plan.sh"
FOLLOWUP="$SKILL_DIR/scripts/hq-followup-close-helper.sh"
OWNERSHIP="$SKILL_DIR/scripts/executor-ownership-gate.sh"
REASSIGN="$SKILL_DIR/scripts/hq-reassign-executor.sh"
VERIFY="$SKILL_DIR/scripts/hq-thread-evidence-verify.sh"

MISSING_TASK="DOES-NOT-EXIST"
NEW_TASK="TASK-TEST-NEW"
ACTIVE_TASK="TASK-TEST-ACTIVE"
DONE_TASK="TASK-TEST-DONE"
BLOCKED_TASK="TASK-TEST-BLOCKED"
TEMP_TASK="TASK-TEST-RUNTIME-TRUTH-REGRESSION"

mkdir -p "$ROOT/skills" "$ROOT/shared/task/state" "$ROOT/agents/alhaitham-coder/sessions" "$ROOT/agents/yelan-research/sessions"
ln -s "$SOURCE_SKILL_DIR" "$SKILL_DIR"
cat > "$ROOT/agents/alhaitham-coder/sessions/sessions.json" <<'JSON'
{
  "agent:alhaitham-coder:discord:channel:666666666666666666": {
    "origin": {"accountId": "alhaitham"},
    "deliveryContext": {"accountId": "alhaitham"},
    "lastAccountId": "alhaitham"
  }
}
JSON
cat > "$ROOT/agents/yelan-research/sessions/sessions.json" <<'JSON'
{
  "agent:yelan-research:discord:channel:555555555555555555": {
    "origin": {"accountId": "yelan"},
    "deliveryContext": {"accountId": "yelan"},
    "lastAccountId": "yelan"
  }
}
JSON
cat > "$ROOT/shared/task/state/update-task-status.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TASK_ID="${1:?task_id}"
STATUS="${2:?status}"
ACTOR="${3:-}"
SUMMARY="${4:-}"
NEXT_CHECK_MINUTES="${5:-}"
RESULT_SUMMARY="${8:-$SUMMARY}"
RESULT_PAYLOAD_JSON="${9:-}"
python3 - "$TASK_DB_PATH" "$TASK_ID" "$STATUS" "$ACTOR" "$SUMMARY" "$NEXT_CHECK_MINUTES" "$RESULT_SUMMARY" "$RESULT_PAYLOAD_JSON" <<'PY'
import sqlite3, sys
db, task_id, status, actor, summary, next_check, result_summary, result_payload_json = sys.argv[1:9]
conn=sqlite3.connect(db)
cur=conn.cursor()
cur.execute("UPDATE tasks SET status=?, result_summary=?, result_payload_json=COALESCE(NULLIF(?, ''), result_payload_json), updated_at=datetime('now') WHERE task_id=?", (status, result_summary, result_payload_json, task_id))
cur.execute("INSERT INTO task_events (task_id,event_type,actor,summary,payload_json,created_at) VALUES (?,?,?,?,?,datetime('now'))", (task_id, 'status_updated', actor, summary, '{}'))
conn.commit()
PY
EOF
chmod +x "$ROOT/shared/task/state/update-task-status.sh"
cat > "$ROOT/shared/task/state/record-runtime-send.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TASK_ID=""; KIND=""; ACTOR=""; SUMMARY=""; PAYLOAD_JSON=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --payload-json) PAYLOAD_JSON="$2"; shift 2 ;;
    *) shift ;;
  esac
done
sqlite3 "$TASK_DB_PATH" "INSERT INTO task_events (task_id,event_type,actor,summary,payload_json,created_at) VALUES ('$(printf "%s" "$TASK_ID" | sed "s/'/''/g")','$(printf "%s" "$KIND" | sed "s/'/''/g")','$(printf "%s" "$ACTOR" | sed "s/'/''/g")','$(printf "%s" "$SUMMARY" | sed "s/'/''/g")','$(printf "%s" "$PAYLOAD_JSON" | sed "s/'/''/g")',datetime('now'));"
EOF
chmod +x "$ROOT/shared/task/state/record-runtime-send.sh"

python3 - <<'PY' "$DB"
import json, sqlite3, sys
from pathlib import Path
p=Path(sys.argv[1])
p.parent.mkdir(parents=True, exist_ok=True)
conn=sqlite3.connect(p)
cur=conn.cursor()
cur.execute('''CREATE TABLE tasks (
  task_id TEXT PRIMARY KEY, title TEXT, slug TEXT, status TEXT, phase TEXT, hq_channel TEXT,
  hq_message_id TEXT, thread_id TEXT, thread_name TEXT, executor_agent TEXT, executor_session_key TEXT,
  current_round INTEGER, priority TEXT, created_at TEXT, updated_at TEXT, next_check_at TEXT,
  result_summary TEXT, result_payload_json TEXT
)''')
cur.execute('''CREATE TABLE task_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT, task_id TEXT, event_type TEXT, actor TEXT, summary TEXT, payload_json TEXT, created_at TEXT
)''')
visible_contract={
  'round': 1,
  'task_goal': 'fixture goal',
  'baseline': 'fixture baseline',
  'output_contract': 'fixture output contract',
  'round_instruction': 'fixture round instruction',
  'round_result_contract': 'fixture result contract',
  'round_result_body': 'fixture result body',
  'visible_r1_message': 'fixture visible r1',
  'executor_handoff_message': 'fixture executor handoff',
}
payload=json.dumps({'visible_contract': visible_contract}, ensure_ascii=False)
def ins(task_id, status, thread_id, hq_message_id, executor_agent='alhaitham-coder', executor_session_key='agent:alhaitham-coder:discord:channel:666666666666666666', current_round=1, result_payload_json=payload):
    cur.execute('INSERT INTO tasks VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)', (
        task_id, f'{task_id} title', task_id.lower(), status, 'test', 'channel:000000000000000000',
        hq_message_id, thread_id, 'fixture-thread', executor_agent, executor_session_key, current_round, 'normal',
        '2026-01-01T00:00:00+0800', '2026-01-01T00:00:00+0800', None, 'fixture summary', result_payload_json
    ))
ins('TASK-TEST-NEW','NEW',None,None)
ins('TASK-TEST-ACTIVE','ACTIVE','222222222222222222','222222222222222223')
ins('TASK-TEST-DONE','DONE','111111111111111111','111111111111111112')
ins('TASK-TEST-BLOCKED','BLOCKED','444444444444444444','444444444444444445','yelan-research','agent:yelan-research:discord:channel:555555555555555555')
ins('TASK-TEST-REASSIGN-SOURCE','ACTIVE','222222222222222222','222222222222222223','yelan-research','agent:yelan-research:discord:channel:555555555555555555',2)
conn.commit()
PY

jq_get() {
  python3 -c 'import json,sys; obj=json.load(sys.stdin); path=sys.argv[1].split("."); cur=obj
for part in path:
    if part.isdigit(): cur=cur[int(part)]
    else: cur=cur.get(part)
print(cur if cur is not None else "")' "$1"
}

assert_json_field() {
  local file="$1"
  local path="$2"
  local expected="$3"
  local actual
  actual="$(jq_get "$path" < "$file")"
  if [[ "$actual" != "$expected" ]]; then
    echo "ASSERT FAILED: $file $path expected '$expected' got '$actual'" >&2
    exit 1
  fi
}

assert_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -q "$needle" "$file"; then
    echo "ASSERT FAILED: $file missing '$needle'" >&2
    cat "$file" >&2
    exit 1
  fi
}

run_expect_fail_json() {
  local name="$1"
  local expected_code="$2"
  shift 2
  local out="$OUT_DIR/$name.json"
  set +e
  "$@" >"$out"
  local code=$?
  set -e
  if [[ $code -ne $expected_code ]]; then
    echo "ASSERT FAILED: $name expected exit $expected_code got $code" >&2
    cat "$out" >&2
    exit 1
  fi
  echo "$out"
}

printf '\n== missing task blockers ==\n'
out="$(run_expect_fail_json ready_missing 2 bash "$READY" --task-id "$MISSING_TASK")"
assert_json_field "$out" "block_reason" "task_not_found"

out="$(run_expect_fail_json handoff_helper_missing 3 bash "$HANDOFF_HELPER" --task-id "$MISSING_TASK")"
assert_json_field "$out" "block_reason" "task_not_found"

out="$(run_expect_fail_json send_plan_missing 3 bash "$SEND_PLAN" --task-id "$MISSING_TASK" --format json)"
assert_json_field "$out" "block_reason" "task_not_found"

out="$(run_expect_fail_json followup_missing 2 bash "$FOLLOWUP" --task-id "$MISSING_TASK" --decision accept --actor paimon-chief --summary test --notify-agent x --notify-thread-id y --notify-round 1 --notify-text '[DOES-NOT-EXIST][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_json_field "$out" "error" "task_not_found"

out="$(run_expect_fail_json ownership_missing 4 bash "$OWNERSHIP" --task-id "$MISSING_TASK" --executor-agent x --executor-account y --thread-id z)"
assert_json_field "$out" "error" "task_not_found"

printf '\n== state blockers ==\n'
out="$(run_expect_fail_json ready_new 3 bash "$READY" --task-id "$NEW_TASK")"
assert_contains "$out" 'status_not_active'
assert_contains "$out" 'missing_thread_id'
assert_contains "$out" 'missing_hq_message_id'

out="$(run_expect_fail_json ownership_done 5 bash "$OWNERSHIP" --task-id "$DONE_TASK" --executor-agent alhaitham-coder --executor-account alhaitham --thread-id 111111111111111111)"
assert_json_field "$out" "error" "task_not_active"
assert_json_field "$out" "status" "DONE"

printf '\n== notify gate mismatches ==\n'
out="$(run_expect_fail_json notify_agent_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify agent mismatch test' --notify-agent yelan-research --notify-thread-id 222222222222222222 --notify-round 1 --notify-text '[TASK-TEST-ACTIVE][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'notify_gate:executor_agent_mismatch'

out="$(run_expect_fail_json notify_thread_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify thread mismatch test' --notify-agent alhaitham-coder --notify-thread-id 333333333333333333 --notify-round 1 --notify-text '[TASK-TEST-ACTIVE][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'notify_gate:thread_id_mismatch'

out="$(run_expect_fail_json notify_round_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify round mismatch test' --notify-agent alhaitham-coder --notify-thread-id 222222222222222222 --notify-round 2 --notify-text '[TASK-TEST-ACTIVE][R2] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'notify_gate:round_mismatch'
assert_contains "$out" 'notify_gate:notify_prefix_mismatch'

out="$(run_expect_fail_json notify_shape_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify shape mismatch test' --notify-agent alhaitham-coder --notify-thread-id 222222222222222222 --notify-round 1 --notify-text '任务做完了，请看一下')"
assert_contains "$out" 'notify_gate:notify_shape_unrecognized'

printf '\n== ownership mismatches ==\n'
out="$(run_expect_fail_json ownership_account_mismatch 6 bash "$OWNERSHIP" --task-id "$ACTIVE_TASK" --executor-agent alhaitham-coder --executor-account yelan --thread-id 222222222222222222)"
assert_contains "$out" 'executor_account_mismatch'

out="$(run_expect_fail_json ownership_agent_mismatch 6 bash "$OWNERSHIP" --task-id "$ACTIVE_TASK" --executor-agent yelan-research --executor-account alhaitham --thread-id 222222222222222222)"
assert_contains "$out" 'executor_agent_mismatch'

out="$(run_expect_fail_json ownership_thread_mismatch 6 bash "$OWNERSHIP" --task-id "$ACTIVE_TASK" --executor-agent alhaitham-coder --executor-account alhaitham --thread-id 333333333333333333)"
assert_contains "$out" 'thread_id_mismatch'

printf '\n== blocked task must not accept ==\n'
out="$(run_expect_fail_json accept_blocked 3 bash "$FOLLOWUP" --task-id "$BLOCKED_TASK" --decision accept --actor paimon-chief --summary 'test accept on blocked task' --notify-agent yelan-research --notify-thread-id 444444444444444444 --notify-round 1 --notify-text '[TASK-TEST-BLOCKED][R1] BLOCKED: cannot_post_to_thread
reason: test
evidence: test')"
assert_contains "$out" 'status_not_acceptable'
assert_json_field "$out" "writeback.next_status" ""
assert_json_field "$out" "drafts.thread_message" ""

printf '\n== active without anchors ==\n'
python3 - <<'PY' "$DB" "$ACTIVE_TASK" "$TEMP_TASK"
import sqlite3, sys
db, source, temp = sys.argv[1:4]
conn=sqlite3.connect(db)
conn.row_factory=sqlite3.Row
cur=conn.cursor()
cur.execute("SELECT * FROM tasks WHERE task_id=?", (source,))
row=cur.fetchone()
cols=[r[1] for r in cur.execute('PRAGMA table_info(tasks)').fetchall()]
data={c: row[c] for c in cols}
data['task_id']=temp
data['thread_id']=None
data['hq_message_id']=None
data['status']='ACTIVE'
cur.execute("DELETE FROM tasks WHERE task_id=?", (temp,))
cur.execute(f"INSERT INTO tasks ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})", [data[c] for c in cols])
conn.commit()
PY
cleanup_temp() {
  sqlite3 "$DB" "DELETE FROM tasks WHERE task_id='$TEMP_TASK';" >/dev/null 2>&1 || true
}

out="$(run_expect_fail_json ready_missing_anchors 3 bash "$READY" --task-id "$TEMP_TASK")"
assert_contains "$out" 'missing_thread_id'
assert_contains "$out" 'missing_hq_message_id'

out="$(run_expect_fail_json accept_missing_anchors 3 bash "$FOLLOWUP" --task-id "$TEMP_TASK" --decision accept --actor paimon-chief --summary 'accept on active without anchors' --notify-agent alhaitham-coder --notify-thread-id 222222222222222222 --notify-round 1 --notify-text '[TASK-TEST-RUNTIME-TRUTH-REGRESSION][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'missing_thread_id'
assert_contains "$out" 'missing_hq_message_id'
cleanup_temp

printf '\n== executor reassignment helper ==\n'
python3 - <<'PY' "$DB" "$TEMP_TASK"
import sqlite3, sys
db, temp = sys.argv[1:3]
conn=sqlite3.connect(db)
conn.row_factory=sqlite3.Row
cur=conn.cursor()
cur.execute("SELECT * FROM tasks WHERE task_id='TASK-TEST-REASSIGN-SOURCE'")
row=cur.fetchone()
cols=[r[1] for r in cur.execute('PRAGMA table_info(tasks)').fetchall()]
data={c: row[c] for c in cols}
data['task_id']=temp
cur.execute("DELETE FROM tasks WHERE task_id=?", (temp,))
cur.execute(f"INSERT INTO tasks ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})", [data[c] for c in cols])
conn.commit()
PY
out="$OUT_DIR/reassign.json"
bash "$REASSIGN" \
  --task-id "$TEMP_TASK" \
  --new-executor-agent alhaitham-coder \
  --new-executor-session-key agent:alhaitham-coder:discord:channel:666666666666666666 \
  --new-hq-message-id 777777777777777777 \
  --round 2 \
  --expected-old-executor yelan-research \
  --summary 'regression executor reassignment' >"$out"
assert_json_field "$out" "ok" "True"
assert_json_field "$out" "to.executor_agent" "alhaitham-coder"
assert_json_field "$out" "to.executor_session_key" "agent:alhaitham-coder:discord:channel:666666666666666666"
reassigned_agent="$(sqlite3 "$DB" "SELECT executor_agent FROM tasks WHERE task_id='$TEMP_TASK';")"
if [[ "$reassigned_agent" != "alhaitham-coder" ]]; then
  echo "ASSERT FAILED: reassigned agent not persisted" >&2
  cat "$out" >&2
  exit 1
fi
if ! sqlite3 "$DB" "SELECT result_payload_json FROM tasks WHERE task_id='$TEMP_TASK';" | grep -q 'executor_reassignment'; then
  echo "ASSERT FAILED: reassignment provenance missing from result_payload_json" >&2
  cat "$out" >&2
  exit 1
fi
cleanup_temp

printf '\n== thread evidence verifier fixtures ==\n'
python3 - <<'PY' "$DB" "$ACTIVE_TASK" "$TEMP_TASK"
import sqlite3, sys
db, source, temp = sys.argv[1:4]
conn=sqlite3.connect(db)
conn.row_factory=sqlite3.Row
cur=conn.cursor()
cur.execute("SELECT * FROM tasks WHERE task_id=?", (source,))
row=cur.fetchone()
cols=[r[1] for r in cur.execute('PRAGMA table_info(tasks)').fetchall()]
data={c: row[c] for c in cols}
data['task_id']=temp
data['status']='ACTIVE'
data['thread_id']='222222222222222222'
data['executor_agent']='alhaitham-coder'
data['executor_session_key']='agent:alhaitham-coder:discord:channel:666666666666666666'
data['current_round']=1
cur.execute("DELETE FROM tasks WHERE task_id=?", (temp,))
cur.execute(f"INSERT INTO tasks ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})", [data[c] for c in cols])
conn.commit()
PY
cat >"$OUT_DIR/thread-ok.json" <<'JSON'
{
  "messages": [
    {"id":"m-result","content":"## [R1] 执行结果\n**任务ID**：TASK-TEST-RUNTIME-TRUTH-REGRESSION\nPASS","author":{"username":"alhaitham","id":"bot-a"},"timestamp":"2026-05-14T04:00:00+08:00"},
    {"id":"m-notify","content":"[TASK-TEST-RUNTIME-TRUTH-REGRESSION][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。","author":{"username":"alhaitham","id":"bot-a"},"timestamp":"2026-05-14T04:01:00+08:00"}
  ]
}
JSON
out="$OUT_DIR/evidence-ok.json"
bash "$VERIFY" --task-id "$TEMP_TASK" --result-message-id m-result --notify-message-id m-notify --thread-json-file "$OUT_DIR/thread-ok.json" >"$out"
assert_json_field "$out" "ok" "True"
cat >"$OUT_DIR/thread-bad.json" <<'JSON'
{
  "messages": [
    {"id":"m-result","content":"result","author":{"username":"paimon-chief"},"timestamp":"2026-05-14T04:00:00+08:00"},
    {"id":"m-notify","content":"done","author":{"username":"paimon-chief"},"timestamp":"2026-05-14T03:59:00+08:00"}
  ]
}
JSON
out="$(run_expect_fail_json evidence_bad 5 bash "$VERIFY" --task-id "$TEMP_TASK" --result-message-id m-result --notify-message-id m-notify --thread-json-file "$OUT_DIR/thread-bad.json")"
assert_contains "$out" 'result_author_mismatch'
assert_contains "$out" 'notify_author_mismatch'
assert_contains "$out" 'notify_shape_unrecognized'
cleanup_temp

printf '\nAll runtime truth regression checks passed.\n'
