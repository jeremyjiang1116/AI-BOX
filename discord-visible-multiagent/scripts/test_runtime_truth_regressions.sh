#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
DB="$ROOT/shared/task/state/tasks.db"
READY="$ROOT/skills/discord-visible-multiagent/scripts/hq-collab-handoff-ready.sh"
HANDOFF_HELPER="$ROOT/skills/discord-visible-multiagent/scripts/hq-executor-handoff-helper.sh"
SEND_PLAN="$ROOT/skills/discord-visible-multiagent/scripts/hq-handoff-send-plan.sh"
FOLLOWUP="$ROOT/skills/discord-visible-multiagent/scripts/hq-followup-close-helper.sh"
OWNERSHIP="$ROOT/skills/discord-visible-multiagent/scripts/executor-ownership-gate.sh"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

MISSING_TASK="DOES-NOT-EXIST"
ACTIVE_TASK="TASK-20260416-028"
DONE_TASK="TASK-20260423-002"
BLOCKED_TASK="TASK-20260423-001"
TEMP_TASK="TASK-TEST-RUNTIME-TRUTH-REGRESSION"

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
  local out="$TMPDIR/$name.json"
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
out="$(run_expect_fail_json ready_new 3 bash "$READY" --task-id TASK-20260416-027)"
assert_contains "$out" 'status_not_active'
assert_contains "$out" 'missing_thread_id'
assert_contains "$out" 'missing_hq_message_id'

out="$(run_expect_fail_json ownership_done 5 bash "$OWNERSHIP" --task-id "$DONE_TASK" --executor-agent alhaitham-coder --executor-account alhaitham --thread-id 1496727762495471777)"
assert_json_field "$out" "error" "task_not_active"
assert_json_field "$out" "status" "DONE"

printf '\n== notify gate mismatches ==\n'
out="$(run_expect_fail_json notify_agent_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify agent mismatch test' --notify-agent yelan-research --notify-thread-id 1494342422795386983 --notify-round 1 --notify-text '[TASK-20260416-028][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'notify_gate:executor_agent_mismatch'

out="$(run_expect_fail_json notify_thread_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify thread mismatch test' --notify-agent alhaitham-coder --notify-thread-id 999999999999999999 --notify-round 1 --notify-text '[TASK-20260416-028][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'notify_gate:thread_id_mismatch'

out="$(run_expect_fail_json notify_round_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify round mismatch test' --notify-agent alhaitham-coder --notify-thread-id 1494342422795386983 --notify-round 2 --notify-text '[TASK-20260416-028][R2] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'notify_gate:round_mismatch'
assert_contains "$out" 'notify_gate:notify_prefix_mismatch'

out="$(run_expect_fail_json notify_shape_mismatch 3 bash "$FOLLOWUP" --task-id "$ACTIVE_TASK" --decision accept --actor paimon-chief --summary 'notify shape mismatch test' --notify-agent alhaitham-coder --notify-thread-id 1494342422795386983 --notify-round 1 --notify-text '任务做完了，请看一下')"
assert_contains "$out" 'notify_gate:notify_shape_unrecognized'

printf '\n== ownership mismatches ==\n'
out="$(run_expect_fail_json ownership_account_mismatch 6 bash "$OWNERSHIP" --task-id "$ACTIVE_TASK" --executor-agent alhaitham-coder --executor-account yelan --thread-id 1494342422795386983)"
assert_contains "$out" 'executor_account_mismatch'

out="$(run_expect_fail_json ownership_agent_mismatch 6 bash "$OWNERSHIP" --task-id "$ACTIVE_TASK" --executor-agent yelan-research --executor-account alhaitham --thread-id 1494342422795386983)"
assert_contains "$out" 'executor_agent_mismatch'

out="$(run_expect_fail_json ownership_thread_mismatch 6 bash "$OWNERSHIP" --task-id "$ACTIVE_TASK" --executor-agent alhaitham-coder --executor-account alhaitham --thread-id 999999999999999999)"
assert_contains "$out" 'thread_id_mismatch'

printf '\n== blocked task must not accept ==\n'
out="$(run_expect_fail_json accept_blocked 3 bash "$FOLLOWUP" --task-id "$BLOCKED_TASK" --decision accept --actor paimon-chief --summary 'test accept on blocked task' --notify-agent yelan-research --notify-thread-id 1496723919145668719 --notify-round 1 --notify-text '[TASK-20260423-001][R1] BLOCKED: cannot_post_to_thread
reason: test
evidence: test')"
assert_contains "$out" 'status_not_acceptable'
assert_json_field "$out" "writeback.next_status" ""
assert_json_field "$out" "drafts.thread_message" ""

printf '\n== active without anchors ==\n'
python3 - <<'PY'
import sqlite3
p='/home/ubuntu/.openclaw/workspace/shared/task/state/tasks.db'
conn=sqlite3.connect(p)
conn.row_factory=sqlite3.Row
cur=conn.cursor()
cur.execute("SELECT * FROM tasks WHERE task_id='TASK-20260416-028'")
row=cur.fetchone()
cols=[r[1] for r in cur.execute('PRAGMA table_info(tasks)').fetchall()]
data={c: row[c] for c in cols}
data['task_id']='TASK-TEST-RUNTIME-TRUTH-REGRESSION'
data['thread_id']=None
data['hq_message_id']=None
data['status']='ACTIVE'
cur.execute("DELETE FROM tasks WHERE task_id=?", (data['task_id'],))
cur.execute(f"INSERT INTO tasks ({','.join(cols)}) VALUES ({','.join('?' for _ in cols)})", [data[c] for c in cols])
conn.commit()
conn.close()
PY
cleanup_temp() {
  sqlite3 "$DB" "DELETE FROM tasks WHERE task_id='$TEMP_TASK';" >/dev/null 2>&1 || true
}
trap 'cleanup_temp; rm -rf "$TMPDIR"' EXIT

out="$(run_expect_fail_json ready_missing_anchors 3 bash "$READY" --task-id "$TEMP_TASK")"
assert_contains "$out" 'missing_thread_id'
assert_contains "$out" 'missing_hq_message_id'

out="$(run_expect_fail_json accept_missing_anchors 3 bash "$FOLLOWUP" --task-id "$TEMP_TASK" --decision accept --actor paimon-chief --summary 'accept on active without anchors' --notify-agent alhaitham-coder --notify-thread-id 1494342422795386983 --notify-round 1 --notify-text '[TASK-TEST-RUNTIME-TRUTH-REGRESSION][R1] 本轮已完成，请读取 thread 现场结果并决定下一轮。')"
assert_contains "$out" 'missing_thread_id'
assert_contains "$out" 'missing_hq_message_id'
cleanup_temp

printf '\nAll runtime truth regression checks passed.\n'
