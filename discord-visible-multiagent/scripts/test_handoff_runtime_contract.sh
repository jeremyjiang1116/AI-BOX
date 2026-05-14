#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  test_handoff_runtime_contract.sh [TASK-ID]

Purpose:
  Non-destructive regression check for formal handoff send-plan contract.

Behavior:
  - creates a temporary fixture workspace and task database
  - normalizes the fixture task to ACTIVE for contract testing
  - validates positive and negative send-plan behavior
  - removes the temporary fixture workspace on exit
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$(mktemp -d)"
FIXTURE_ROOT="$OUT_DIR/workspace"
ROOT="$FIXTURE_ROOT"
DB="$ROOT/shared/task/state/tasks.db"
SKILL_DIR="$ROOT/skills/discord-visible-multiagent"
HANDOFF_HELPER="$SKILL_DIR/scripts/hq-executor-handoff-helper.sh"
SEND_PLAN="$SKILL_DIR/scripts/hq-handoff-send-plan.sh"
VALIDATOR="$SKILL_DIR/scripts/validate_handoff_send_plan.py"
REMINDER="$ROOT/shared/task/state/executor-reminder-helper.sh"
SOURCE_TASK_ID="${1:-${SOURCE_TASK:-TASK-TEST-SOURCE-001}}"
TASK_ID="${TEST_TASK:-TASK-TEST-HANDOFF-CONTRACT}"
export TASK_DB_PATH="$DB"
export OPENCLAW_WORKSPACE_ROOT="$ROOT"
export OPENCLAW_AGENTS_ROOT="$ROOT/agents"

cleanup() {
  rm -rf "$OUT_DIR"
}
trap cleanup EXIT

mkdir -p "$ROOT/skills" "$ROOT/shared/task/state" "$ROOT/agents/alhaitham-coder/sessions"
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
cat > "$REMINDER" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "executor reminder command fixture: $*"
EOF
chmod +x "$REMINDER"
cat > "$ROOT/shared/task/state/record-runtime-send.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
TASK_ID=""
KIND=""
ACTOR=""
SUMMARY=""
PAYLOAD_JSON=""
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

python3 - <<'PY' "$DB" "$SOURCE_TASK_ID" "$TASK_ID"
import json, sqlite3, sys
from pathlib import Path
p, source_task_id, task_id = sys.argv[1:4]
Path(p).parent.mkdir(parents=True, exist_ok=True)
conn = sqlite3.connect(p)
cur = conn.cursor()
cur.execute("""CREATE TABLE IF NOT EXISTS tasks (
  task_id TEXT PRIMARY KEY, title TEXT, slug TEXT, status TEXT, phase TEXT, hq_channel TEXT,
  thread_name TEXT, executor_agent TEXT, executor_session_key TEXT, current_round INTEGER, priority TEXT,
  created_at TEXT, updated_at TEXT, next_check_at TEXT, thread_id TEXT, hq_message_id TEXT,
  result_summary TEXT, result_payload_json TEXT
)""")
cur.execute("""CREATE TABLE IF NOT EXISTS task_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT, task_id TEXT, event_type TEXT, actor TEXT, summary TEXT, payload_json TEXT, created_at TEXT
)""")
visible_contract = {
  "round": 1,
  "task_goal": "fixture goal",
  "baseline": "fixture baseline",
  "output_contract": "fixture output contract",
  "round_instruction": "fixture round instruction",
  "round_result_contract": "fixture result contract",
  "round_result_body": "fixture result body",
  "visible_r1_message": "fixture visible r1",
  "executor_handoff_message": "fixture executor handoff",
}
cur.execute("DELETE FROM tasks WHERE task_id IN (?, ?)", (source_task_id, task_id))
row = (
  source_task_id, "Fixture source task", "fixture-source", "DONE", "test", "channel:000000000000000000",
  "fixture-thread", "alhaitham-coder", "agent:alhaitham-coder:discord:channel:666666666666666666",
  1, "normal", "2026-01-01T00:00:00+0800", "2026-01-01T00:00:00+0800", None,
  "222222222222222222", "222222222222222223", "fixture summary", json.dumps({"visible_contract": visible_contract}, ensure_ascii=False),
)
cur.execute("INSERT INTO tasks VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", row)
cur.execute("INSERT INTO tasks SELECT ?, title, slug, ?, phase, hq_channel, thread_name, executor_agent, executor_session_key, current_round, priority, created_at, updated_at, next_check_at, thread_id, hq_message_id, result_summary, result_payload_json FROM tasks WHERE task_id=?", (task_id, "ACTIVE", source_task_id))
conn.commit()
conn.close()
PY

printf '\n== executor notify transport contract ==\n'
bash "$HANDOFF_HELPER" --task-id "$TASK_ID" > "$OUT_DIR/handoff-helper.json"
python3 - <<'PY' "$OUT_DIR/handoff-helper.json" "$TASK_ID"
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
assert '--target channel:888888888888888888' not in message
assert '--reply-to' not in message
print(json.dumps({'ok': True, 'notify_transport': templates.get('hq_notify_transport')}, ensure_ascii=False))
PY

printf '\n== handoff send plan (exec_json) ==\n'
bash "$SEND_PLAN" --task-id "$TASK_ID" --format exec_json > "$OUT_DIR/handoff-plan.json"
cat "$OUT_DIR/handoff-plan.json" | sed -n '1,80p'

printf '\n== validator positive ==\n'
python3 "$VALIDATOR" < "$OUT_DIR/handoff-plan.json"

printf '\n== validator negative (bad label) ==\n'
python3 - <<'PY' "$OUT_DIR/handoff-plan.json" > "$OUT_DIR/handoff-bad.json"
import json, sys
obj=json.load(open(sys.argv[1]))
obj['label']='BAD-LABEL'
print(json.dumps(obj))
PY
if python3 "$VALIDATOR" < "$OUT_DIR/handoff-bad.json"; then
  echo 'ERROR: negative case unexpectedly passed'
  exit 1
else
  echo 'negative case correctly rejected'
fi

printf '
== handoff send plan with embedded validation ==
'
bash "$SEND_PLAN" --task-id "$TASK_ID" --format json > "$OUT_DIR/handoff-preflight.json"
cat "$OUT_DIR/handoff-preflight.json" | sed -n '1,120p'

printf '
== handoff preflight writeback uses non-send event kind ==
'
before_count="$(sqlite3 "$DB" "SELECT count(*) FROM task_events WHERE task_id='$TASK_ID' AND event_type='executor_handoff_preflight';")"
bash "$SEND_PLAN" --task-id "$TASK_ID" --format exec_json --record-preflight >"$OUT_DIR/handoff-preflight-recorded.json"
after_count="$(sqlite3 "$DB" "SELECT count(*) FROM task_events WHERE task_id='$TASK_ID' AND event_type='executor_handoff_preflight';")"
if [[ "$after_count" != "$((before_count + 1))" ]]; then
  echo "ERROR: expected executor_handoff_preflight count to increment from $before_count to $((before_count + 1)); got $after_count" >&2
  exit 1
fi
if sqlite3 "$DB" "SELECT event_type FROM task_events WHERE task_id='$TASK_ID' ORDER BY id DESC LIMIT 1;" | grep -qx 'executor_handoff'; then
  echo 'ERROR: preflight must not record executor_handoff' >&2
  exit 1
fi

printf '\n== reminder helper contract ==\n'
bash "$REMINDER" --task-id "$TASK_ID" --mode command | sed -n '1,120p'

printf '\nAll minimal handoff contract regression checks passed.\n'
