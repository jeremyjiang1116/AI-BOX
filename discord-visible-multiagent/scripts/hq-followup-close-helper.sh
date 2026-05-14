#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="${OPENCLAW_WORKSPACE_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
STATE_DIR="$WORKSPACE_ROOT/shared/task/state"
DB_PATH="${TASK_DB_PATH:-$STATE_DIR/tasks.db}"
TZ_NAME="${TASK_TZ:-Asia/Shanghai}"

usage() {
  cat <<'EOF'
Usage:
  hq-followup-close-helper.sh \
    --task-id <TASK-ID> \
    --decision <advance|accept|blocked|review|failed|capped> \
    --actor <ACTOR> \
    --summary <SUMMARY> \
    [--notify-agent <EXECUTOR_AGENT>] \
    [--notify-thread-id <THREAD_ID>] \
    [--notify-round <ROUND_NO>] \
    [--notify-text <TEXT>] \
    [--next-round <N>] \
    [--challenge <TEXT>] \
    [--close-status <DONE|BLOCKED|REVIEW|FAILED|CLOSED>] \
    [--result-summary <TEXT>] \
    [--result-payload-json <JSON>] \
    [--next-check-minutes <MINUTES>]

Purpose:
  Generate a truthful HQ follow-up / close payload from current task-state and,
  when requested, write back the chosen decision to SQLite.

Decisions:
  - advance : prepare next-round HQ instruction draft, increment current_round, keep task ACTIVE
  - accept  : prepare close draft, default close status DONE
  - blocked : prepare blocked draft, set status BLOCKED
  - review  : prepare review draft, set status REVIEW
  - failed  : prepare failed draft, set status FAILED
  - capped  : prepare R15 capped-close draft, default close status REVIEW

Notes:
  - This helper does NOT perform real Discord sends.
  - It writes DB state so the task-state layer remains truthful.
  - For advance, --next-round is required and must be current_round + 1 and <= 15.
  - For advance/accept/blocked/review/failed, notify closure validation is mandatory.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

TASK_ID=""
DECISION=""
ACTOR=""
SUMMARY=""
NEXT_ROUND=""
CHALLENGE=""
CLOSE_STATUS=""
RESULT_SUMMARY=""
RESULT_PAYLOAD_JSON=""
NEXT_CHECK_MINUTES=""
NOTIFY_AGENT=""
NOTIFY_THREAD_ID=""
NOTIFY_ROUND=""
NOTIFY_TEXT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    --decision) DECISION="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --next-round) NEXT_ROUND="$2"; shift 2 ;;
    --challenge) CHALLENGE="$2"; shift 2 ;;
    --close-status) CLOSE_STATUS="$2"; shift 2 ;;
    --result-summary) RESULT_SUMMARY="$2"; shift 2 ;;
    --result-payload-json) RESULT_PAYLOAD_JSON="$2"; shift 2 ;;
    --next-check-minutes) NEXT_CHECK_MINUTES="$2"; shift 2 ;;
    --notify-agent) NOTIFY_AGENT="$2"; shift 2 ;;
    --notify-thread-id) NOTIFY_THREAD_ID="$2"; shift 2 ;;
    --notify-round) NOTIFY_ROUND="$2"; shift 2 ;;
    --notify-text) NOTIFY_TEXT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for v in TASK_ID DECISION ACTOR SUMMARY; do
  [[ -n "${!v}" ]] || { echo "Missing required arg: $v" >&2; usage; exit 1; }
done

case "$DECISION" in
  advance|accept|blocked|review|failed|capped) ;;
  *) echo "Unsupported --decision: $DECISION" >&2; exit 1 ;;
esac

require_cmd sqlite3
require_cmd python3
require_cmd "$STATE_DIR/update-task-status.sh"

needs_notify_gate=0
case "$DECISION" in
  advance|accept|blocked|review|failed) needs_notify_gate=1 ;;
  capped) needs_notify_gate=0 ;;
esac

if [[ "$needs_notify_gate" == "1" ]]; then
  for v in NOTIFY_AGENT NOTIFY_THREAD_ID NOTIFY_ROUND NOTIFY_TEXT; do
    [[ -n "${!v}" ]] || { echo "Missing required notify arg for decision $DECISION: $v" >&2; usage; exit 1; }
  done
fi

escaped_task_id="$(printf "%s" "$TASK_ID" | sed "s/'/''/g")"
row="$(sqlite3 -json "$DB_PATH" "SELECT task_id, title, status, phase, hq_channel, hq_message_id, thread_id, thread_name, executor_agent, executor_session_key, current_round, priority, result_summary, result_payload_json FROM tasks WHERE task_id = '$escaped_task_id';")"
[[ -n "$row" ]] || row='[]'

created_at="$(TZ="$TZ_NAME" date +%Y-%m-%dT%H:%M:%S%z)"

ROW_JSON="$row" \
DECISION="$DECISION" \
TASK_ID="$TASK_ID" \
SUMMARY="$SUMMARY" \
ACTOR="$ACTOR" \
NEXT_ROUND="$NEXT_ROUND" \
CHALLENGE="$CHALLENGE" \
CLOSE_STATUS="$CLOSE_STATUS" \
RESULT_SUMMARY="$RESULT_SUMMARY" \
RESULT_PAYLOAD_JSON="$RESULT_PAYLOAD_JSON" \
CREATED_AT="$created_at" \
NEXT_CHECK_MINUTES="$NEXT_CHECK_MINUTES" \
NOTIFY_AGENT="$NOTIFY_AGENT" \
NOTIFY_THREAD_ID="$NOTIFY_THREAD_ID" \
NOTIFY_ROUND="$NOTIFY_ROUND" \
NOTIFY_TEXT="$NOTIFY_TEXT" \
python3 - <<'PY'
import json, os, re, sys
rows = json.loads(os.environ['ROW_JSON'])
if not rows:
    print(json.dumps({
        'task_id': None,
        'ok': False,
        'error': 'task_not_found'
    }, ensure_ascii=False, indent=2))
    sys.exit(2)
row = rows[0]
decision = os.environ['DECISION']
summary = os.environ['SUMMARY']
next_round_raw = os.environ.get('NEXT_ROUND', '')
challenge = os.environ.get('CHALLENGE', '')
close_status = os.environ.get('CLOSE_STATUS', '')
result_summary = os.environ.get('RESULT_SUMMARY', '')
result_payload_json = os.environ.get('RESULT_PAYLOAD_JSON', '')
notify_agent = os.environ.get('NOTIFY_AGENT', '')
notify_thread_id = os.environ.get('NOTIFY_THREAD_ID', '')
notify_round = os.environ.get('NOTIFY_ROUND', '')
notify_text = os.environ.get('NOTIFY_TEXT', '')

current_round = int(row.get('current_round') or 1)
status = row.get('status') or ''
thread_id = row.get('thread_id') or ''
hq_message_id = row.get('hq_message_id') or ''

blockers = []
if not thread_id:
    blockers.append('missing_thread_id')
if not hq_message_id:
    blockers.append('missing_hq_message_id')
if status not in ('ACTIVE', 'REVIEW', 'BLOCKED') and decision == 'advance':
    blockers.append('status_not_advancable')
if decision == 'accept' and status != 'ACTIVE':
    blockers.append('status_not_acceptable')

notify_gate_required = decision in ('advance', 'accept', 'blocked', 'review', 'failed')
notify_validation = None
if notify_gate_required:
    violations = []
    expected_task = row.get('task_id')
    expected_status = status
    expected_agent = row.get('executor_agent') or ''
    expected_thread = str(thread_id or '')
    expected_round = str(current_round)
    if expected_status not in ('ACTIVE', 'BLOCKED', 'REVIEW'):
        violations.append('status_not_reviewable')
    if notify_agent != expected_agent:
        violations.append('executor_agent_mismatch')
    if notify_thread_id != expected_thread:
        violations.append('thread_id_mismatch')
    if notify_round != expected_round:
        violations.append('round_mismatch')
    prefix_ok = False
    patterns = [
        rf'^\[{re.escape(expected_task)}\]\[R{re.escape(expected_round)}\]',
        rf'^\[{re.escape(expected_task)}\]\s*\[R{re.escape(expected_round)}\]',
    ]
    for pat in patterns:
        if re.search(pat, notify_text):
            prefix_ok = True
            break
    if not prefix_ok:
        violations.append('notify_prefix_mismatch')
    success_hint = '本轮已完成，请读取 thread 现场结果并决定下一轮。' in notify_text
    blocked_hint = 'BLOCKED:' in notify_text and 'reason:' in notify_text and 'evidence:' in notify_text
    if not (success_hint or blocked_hint):
        violations.append('notify_shape_unrecognized')
    notify_validation = {
        'ok': not violations,
        'notify_kind': 'success' if success_hint else ('blocked' if blocked_hint else None),
        'violations': violations,
    }
    if violations:
        blockers.extend([f'notify_gate:{v}' for v in violations])

next_status = None
next_check_minutes = os.environ.get('NEXT_CHECK_MINUTES', '')
event_type = None
thread_message = None
hq_sync = None
computed_next_round = None

if decision == 'advance':
    if not next_round_raw:
        blockers.append('missing_next_round')
    else:
        try:
            computed_next_round = int(next_round_raw)
        except ValueError:
            blockers.append('invalid_next_round')
        else:
            if computed_next_round != current_round + 1:
                blockers.append('next_round_must_increment_by_one')
            if computed_next_round > 15:
                blockers.append('round_cap_exceeded')
    if not challenge:
        blockers.append('missing_challenge')
    next_status = 'ACTIVE'
    event_type = 'hq_followup_advance'
    if computed_next_round:
        thread_message = (
            f"## [R{computed_next_round}] 继续指令\n\n"
            f"**任务ID**：{row['task_id']}\n"
            f"**轮次**：R{computed_next_round}\n"
            f"**审核结果**：❌ 需要修改\n\n"
            f"**具体质疑**\n{challenge}\n\n"
            f"**修改要求**\n{summary}\n\n---"
        )
        hq_sync = (
            f"[TASK-ID] {row['task_id']}\n"
            f"[轮次推进]：R{current_round} -> R{computed_next_round}\n"
            f"[状态]：继续下一轮\n"
            f"[原因]：{summary}"
        )
elif decision == 'accept':
    next_status = close_status or 'DONE'
    event_type = 'hq_followup_accept'
    thread_message = (
        f"[TASK-ID] {row['task_id']}\n"
        f"[审核结果]：✅ 通过\n"
        f"[最终轮次]：R{current_round}\n"
        f"[结论]：{summary}"
    )
    hq_sync = thread_message
elif decision in ('blocked', 'review', 'failed'):
    mapping = {'blocked': 'BLOCKED', 'review': 'REVIEW', 'failed': 'FAILED'}
    next_status = close_status or mapping[decision]
    event_type = f'hq_followup_{decision}'
    thread_message = (
        f"[TASK-ID] {row['task_id']}\n"
        f"[审核结果]：⚠️ {next_status}\n"
        f"[当前轮次]：R{current_round}\n"
        f"[当前进展]：{summary}\n"
        f"[阻塞/审查原因]：{challenge or '待补充'}"
    )
    hq_sync = thread_message
elif decision == 'capped':
    if current_round != 15:
        blockers.append('capped_requires_r15')
    next_status = close_status or 'REVIEW'
    event_type = 'hq_followup_capped'
    thread_message = (
        f"[TASK-ID] {row['task_id']}\n"
        f"[审核结果]：⚠️ CAPPED\n"
        f"[最终轮次]：R15 / R15\n"
        f"[当前进展]：{summary}\n"
        f"[未达标准]：{challenge or '待补充'}"
    )
    hq_sync = thread_message

out = {
    'ok': not blockers,
    'task_id': row.get('task_id'),
    'decision': decision,
    'current_status': status,
    'current_round': current_round,
    'thread_id': thread_id or None,
    'hq_message_id': hq_message_id or None,
    'executor_session_key': row.get('executor_session_key'),
    'notify_gate_required': notify_gate_required,
    'notify_validation': notify_validation,
    'blockers': blockers,
    'writeback': {
        'next_status': None if blockers else next_status,
        'result_summary': result_summary or summary,
        'result_payload_json': result_payload_json or None,
        'next_round': computed_next_round,
        'next_check_minutes': next_check_minutes or None,
        'event_type': None if blockers else event_type,
    },
    'drafts': {
        'thread_message': None if blockers else thread_message,
        'hq_sync_message': None if blockers else hq_sync,
    }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
sys.exit(0 if not blockers else 3)
PY

json_out="$(ROW_JSON="$row" \
DECISION="$DECISION" \
TASK_ID="$TASK_ID" \
SUMMARY="$SUMMARY" \
ACTOR="$ACTOR" \
NEXT_ROUND="$NEXT_ROUND" \
CHALLENGE="$CHALLENGE" \
CLOSE_STATUS="$CLOSE_STATUS" \
RESULT_SUMMARY="$RESULT_SUMMARY" \
RESULT_PAYLOAD_JSON="$RESULT_PAYLOAD_JSON" \
CREATED_AT="$created_at" \
NEXT_CHECK_MINUTES="$NEXT_CHECK_MINUTES" \
NOTIFY_AGENT="$NOTIFY_AGENT" \
NOTIFY_THREAD_ID="$NOTIFY_THREAD_ID" \
NOTIFY_ROUND="$NOTIFY_ROUND" \
NOTIFY_TEXT="$NOTIFY_TEXT" \
python3 - <<'PY'
import json, os, re, sys
rows = json.loads(os.environ['ROW_JSON'])
if not rows:
    sys.exit(2)
row = rows[0]
decision = os.environ['DECISION']
summary = os.environ['SUMMARY']
next_round_raw = os.environ.get('NEXT_ROUND', '')
challenge = os.environ.get('CHALLENGE', '')
close_status = os.environ.get('CLOSE_STATUS', '')
result_summary = os.environ.get('RESULT_SUMMARY', '')
result_payload_json = os.environ.get('RESULT_PAYLOAD_JSON', '')
notify_agent = os.environ.get('NOTIFY_AGENT', '')
notify_thread_id = os.environ.get('NOTIFY_THREAD_ID', '')
notify_round = os.environ.get('NOTIFY_ROUND', '')
notify_text = os.environ.get('NOTIFY_TEXT', '')
current_round = int(row.get('current_round') or 1)
status = row.get('status') or ''
thread_id = row.get('thread_id') or ''
hq_message_id = row.get('hq_message_id') or ''
blockers = []
if not thread_id:
    blockers.append('missing_thread_id')
if not hq_message_id:
    blockers.append('missing_hq_message_id')
if status not in ('ACTIVE', 'REVIEW', 'BLOCKED') and decision == 'advance':
    blockers.append('status_not_advancable')
notify_gate_required = decision in ('advance', 'accept', 'blocked', 'review', 'failed')
if notify_gate_required:
    expected_task = row.get('task_id')
    expected_status = status
    expected_agent = row.get('executor_agent') or ''
    expected_thread = str(thread_id or '')
    expected_round = str(current_round)
    if expected_status not in ('ACTIVE', 'BLOCKED', 'REVIEW'):
        blockers.append('notify_gate:status_not_reviewable')
    if notify_agent != expected_agent:
        blockers.append('notify_gate:executor_agent_mismatch')
    if notify_thread_id != expected_thread:
        blockers.append('notify_gate:thread_id_mismatch')
    if notify_round != expected_round:
        blockers.append('notify_gate:round_mismatch')
    prefix_ok = False
    patterns = [
        rf'^\[{re.escape(expected_task)}\]\[R{re.escape(expected_round)}\]',
        rf'^\[{re.escape(expected_task)}\]\s*\[R{re.escape(expected_round)}\]',
    ]
    for pat in patterns:
        if re.search(pat, notify_text):
            prefix_ok = True
            break
    if not prefix_ok:
        blockers.append('notify_gate:notify_prefix_mismatch')
    success_hint = '本轮已完成，请读取 thread 现场结果并决定下一轮。' in notify_text
    blocked_hint = 'BLOCKED:' in notify_text and 'reason:' in notify_text and 'evidence:' in notify_text
    if not (success_hint or blocked_hint):
        blockers.append('notify_gate:notify_shape_unrecognized')
computed_next_round = None
next_status = None
if decision == 'advance':
    if not next_round_raw:
        blockers.append('missing_next_round')
    else:
        try:
            computed_next_round = int(next_round_raw)
        except ValueError:
            blockers.append('invalid_next_round')
        else:
            if computed_next_round != current_round + 1:
                blockers.append('next_round_must_increment_by_one')
            if computed_next_round > 15:
                blockers.append('round_cap_exceeded')
    if not challenge:
        blockers.append('missing_challenge')
    next_status = 'ACTIVE'
elif decision == 'accept':
    next_status = close_status or 'DONE'
elif decision in ('blocked', 'review', 'failed'):
    mapping = {'blocked': 'BLOCKED', 'review': 'REVIEW', 'failed': 'FAILED'}
    next_status = close_status or mapping[decision]
elif decision == 'capped':
    if current_round != 15:
        blockers.append('capped_requires_r15')
    next_status = close_status or 'REVIEW'
if blockers:
    sys.exit(3)
print(json.dumps({'next_status': next_status, 'next_round': computed_next_round, 'result_summary': result_summary or summary, 'result_payload_json': result_payload_json or ''}, ensure_ascii=False))
PY
)"

next_status="$(printf '%s' "$json_out" | python3 -c 'import json,sys; print(json.load(sys.stdin)["next_status"])')"
next_round_value="$(printf '%s' "$json_out" | python3 -c 'import json,sys; v=json.load(sys.stdin).get("next_round"); print("" if v is None else v)')"
final_result_summary="$(printf '%s' "$json_out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("result_summary", ""))')"
final_result_payload_json="$(printf '%s' "$json_out" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("result_payload_json", ""))')"

"$STATE_DIR/update-task-status.sh" "$TASK_ID" "$next_status" "$ACTOR" "$SUMMARY" "$NEXT_CHECK_MINUTES" "" "" "$final_result_summary" "$final_result_payload_json"

if [[ -n "$next_round_value" ]]; then
  escaped_task_id2="$(printf "%s" "$TASK_ID" | sed "s/'/''/g")"
  escaped_round="$(printf "%s" "$next_round_value" | sed "s/'/''/g")"
  updated_at="$(TZ="$TZ_NAME" date +%Y-%m-%dT%H:%M:%S%z)"
  sqlite3 "$DB_PATH" "UPDATE tasks SET current_round = '$escaped_round', updated_at = '$updated_at' WHERE task_id = '$escaped_task_id2';"
fi
