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
  hq-reassign-executor.sh \
    --task-id <TASK-ID> \
    --new-executor-agent <AGENT> \
    --new-executor-session-key <SESSION_KEY> \
    --new-hq-message-id <MESSAGE_ID> \
    [--round <ROUND>] \
    [--expected-old-executor <AGENT>] \
    [--actor <ACTOR>] \
    [--summary <SUMMARY>] \
    [--dry-run]

Purpose:
  Safely reassign the current formal collaboration round to a different executor
  after HQ has posted the new round's visible thread instruction.

What it does:
  - verifies task state and visible anchors
  - verifies the new executor session binding
  - backs up the SQLite DB before writeback
  - updates executor_agent / executor_session_key / hq_message_id / optional round
  - preserves result_payload_json and appends executor_reassignment provenance
  - inserts a task_event documenting the reassignment

This helper does NOT send the handoff. Run hq-executor-handoff-helper.sh and
hq-handoff-send-plan.sh after reassignment.
EOF
}

TASK_ID=""
NEW_EXECUTOR_AGENT=""
NEW_EXECUTOR_SESSION_KEY=""
NEW_HQ_MESSAGE_ID=""
SET_ROUND=""
EXPECTED_OLD_EXECUTOR=""
ACTOR="paimon-chief"
SUMMARY=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    --new-executor-agent|--executor-agent) NEW_EXECUTOR_AGENT="$2"; shift 2 ;;
    --new-executor-session-key|--executor-session-key) NEW_EXECUTOR_SESSION_KEY="$2"; shift 2 ;;
    --new-hq-message-id|--hq-message-id) NEW_HQ_MESSAGE_ID="$2"; shift 2 ;;
    --round|--set-round) SET_ROUND="$2"; shift 2 ;;
    --expected-old-executor) EXPECTED_OLD_EXECUTOR="$2"; shift 2 ;;
    --actor) ACTOR="$2"; shift 2 ;;
    --summary) SUMMARY="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for v in TASK_ID NEW_EXECUTOR_AGENT NEW_EXECUTOR_SESSION_KEY NEW_HQ_MESSAGE_ID; do
  [[ -n "${!v}" ]] || { echo "Missing required arg: $v" >&2; usage; exit 1; }
done
command -v python3 >/dev/null 2>&1 || { echo "Missing required command: python3" >&2; exit 1; }

SUMMARY="${SUMMARY:-HQ reassigned executor for current formal collaboration round}"

TASK_ID="$TASK_ID" \
NEW_EXECUTOR_AGENT="$NEW_EXECUTOR_AGENT" \
NEW_EXECUTOR_SESSION_KEY="$NEW_EXECUTOR_SESSION_KEY" \
NEW_HQ_MESSAGE_ID="$NEW_HQ_MESSAGE_ID" \
SET_ROUND="$SET_ROUND" \
EXPECTED_OLD_EXECUTOR="$EXPECTED_OLD_EXECUTOR" \
ACTOR="$ACTOR" \
SUMMARY="$SUMMARY" \
DRY_RUN="$DRY_RUN" \
DB_PATH="$DB_PATH" \
TZ_NAME="$TZ_NAME" \
python3 - <<'PY'
import json
import os
import shutil
import sqlite3
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

TASK_ID = os.environ['TASK_ID']
NEW_EXECUTOR_AGENT = os.environ['NEW_EXECUTOR_AGENT']
NEW_EXECUTOR_SESSION_KEY = os.environ['NEW_EXECUTOR_SESSION_KEY']
NEW_HQ_MESSAGE_ID = os.environ['NEW_HQ_MESSAGE_ID']
SET_ROUND_RAW = os.environ.get('SET_ROUND', '')
EXPECTED_OLD_EXECUTOR = os.environ.get('EXPECTED_OLD_EXECUTOR', '')
ACTOR = os.environ['ACTOR']
SUMMARY = os.environ['SUMMARY']
DRY_RUN = os.environ.get('DRY_RUN') == '1'
DB_PATH = Path(os.environ['DB_PATH'])
TZ_NAME = os.environ.get('TZ_NAME', 'Asia/Shanghai')

try:
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(TZ_NAME)
except Exception:
    tz = timezone(timedelta(hours=8))

def now_text():
    return datetime.now(tz).strftime('%Y-%m-%dT%H:%M:%S%z')

def fail(code, **payload):
    payload.setdefault('ok', False)
    payload.setdefault('task_id', TASK_ID)
    print(json.dumps(payload, ensure_ascii=False, indent=2))
    sys.exit(code)

if not DB_PATH.exists():
    fail(2, error='db_not_found', db_path=str(DB_PATH))

if f'agent:{NEW_EXECUTOR_AGENT}:' not in NEW_EXECUTOR_SESSION_KEY:
    fail(3, error='executor_session_key_agent_mismatch', new_executor_agent=NEW_EXECUTOR_AGENT, new_executor_session_key=NEW_EXECUTOR_SESSION_KEY)

set_round = None
if SET_ROUND_RAW:
    try:
        set_round = int(SET_ROUND_RAW)
    except ValueError:
        fail(3, error='invalid_round', value=SET_ROUND_RAW)
    if set_round < 1 or set_round > 15:
        fail(3, error='round_out_of_range', value=set_round)

sessions_root = Path(os.environ.get("OPENCLAW_AGENTS_ROOT", str(Path.home() / ".openclaw/agents")))
sessions_path = sessions_root / NEW_EXECUTOR_AGENT / "sessions/sessions.json"
if not sessions_path.exists():
    fail(4, error='executor_sessions_missing', executor_agent=NEW_EXECUTOR_AGENT, sessions_path=str(sessions_path))
try:
    sessions = json.loads(sessions_path.read_text())
except Exception as e:
    fail(4, error='executor_sessions_parse_failed', executor_agent=NEW_EXECUTOR_AGENT, sessions_path=str(sessions_path), evidence=str(e))
if NEW_EXECUTOR_SESSION_KEY not in sessions:
    fail(4, error='executor_session_key_not_found', executor_agent=NEW_EXECUTOR_AGENT, new_executor_session_key=NEW_EXECUTOR_SESSION_KEY, sessions_path=str(sessions_path))

meta = sessions.get(NEW_EXECUTOR_SESSION_KEY) or {}
account_candidates = []
for label, value in [
    ('origin.accountId', (meta.get('origin') or {}).get('accountId')),
    ('deliveryContext.accountId', (meta.get('deliveryContext') or {}).get('accountId')),
    ('lastAccountId', meta.get('lastAccountId')),
]:
    if value:
        account_candidates.append({'source': label, 'value': value, 'sessionKey': NEW_EXECUTOR_SESSION_KEY})
account_values = sorted({c['value'] for c in account_candidates})
if len(account_values) > 1:
    fail(4, error='executor_account_binding_ambiguous_for_session', executor_agent=NEW_EXECUTOR_AGENT, candidate_accounts=account_values, evidence=account_candidates)
executor_account = account_values[0] if account_values else None

conn = sqlite3.connect(str(DB_PATH))
conn.row_factory = sqlite3.Row
cur = conn.cursor()
cur.execute('SELECT * FROM tasks WHERE task_id=?', (TASK_ID,))
row = cur.fetchone()
if not row:
    fail(5, error='task_not_found')
rowd = dict(row)
status = rowd.get('status') or ''
if status in ('DONE', 'FAILED', 'CLOSED'):
    fail(6, error='task_already_terminal', status=status)
if status not in ('ACTIVE', 'BLOCKED', 'REVIEW'):
    fail(6, error='task_status_not_reassignable', status=status)
if not rowd.get('thread_id'):
    fail(6, error='missing_thread_id')
if not rowd.get('hq_message_id'):
    fail(6, error='missing_existing_hq_message_id')
if EXPECTED_OLD_EXECUTOR and rowd.get('executor_agent') != EXPECTED_OLD_EXECUTOR:
    fail(6, error='expected_old_executor_mismatch', expected_old_executor=EXPECTED_OLD_EXECUTOR, actual_old_executor=rowd.get('executor_agent'))

current_round = int(rowd.get('current_round') or 1)
new_round = set_round if set_round is not None else current_round
if new_round < current_round:
    fail(6, error='round_regression_forbidden', current_round=current_round, requested_round=new_round)
if new_round > 15:
    fail(6, error='round_cap_exceeded', requested_round=new_round)

payload = {}
raw_payload = rowd.get('result_payload_json') or ''
if raw_payload:
    try:
        parsed = json.loads(raw_payload)
        if isinstance(parsed, dict):
            payload = parsed
        else:
            payload = {'previous_result_payload_json': parsed}
    except Exception:
        payload = {'previous_result_payload_json_unparsed': raw_payload}

created_at = now_text()
backup_path = None
reassignment = {
    'type': 'executor_reassignment',
    'task_id': TASK_ID,
    'actor': ACTOR,
    'summary': SUMMARY,
    'created_at': created_at,
    'from': {
        'executor_agent': rowd.get('executor_agent'),
        'executor_session_key': rowd.get('executor_session_key'),
        'hq_message_id': rowd.get('hq_message_id'),
        'current_round': current_round,
    },
    'to': {
        'executor_agent': NEW_EXECUTOR_AGENT,
        'executor_session_key': NEW_EXECUTOR_SESSION_KEY,
        'executor_account': executor_account,
        'hq_message_id': NEW_HQ_MESSAGE_ID,
        'current_round': new_round,
    },
    'thread_id': rowd.get('thread_id'),
    'session_binding_evidence': account_candidates,
}
payload['executor_reassignment'] = reassignment
payload.setdefault('executor_reassignments', [])
if isinstance(payload['executor_reassignments'], list):
    payload['executor_reassignments'].append(reassignment)
else:
    payload['executor_reassignments'] = [reassignment]
new_payload_json = json.dumps(payload, ensure_ascii=False)
event_payload_json = json.dumps(reassignment, ensure_ascii=False)

if not DRY_RUN:
    backup_path = Path('/tmp') / f'{DB_PATH.name}.{TASK_ID}.before-executor-reassign.{datetime.now(tz).strftime("%Y%m%d-%H%M%S")}'
    shutil.copy2(DB_PATH, backup_path)
    reassignment['backup_path'] = str(backup_path)
    payload['executor_reassignment']['backup_path'] = str(backup_path)
    payload['executor_reassignments'][-1]['backup_path'] = str(backup_path)
    new_payload_json = json.dumps(payload, ensure_ascii=False)
    event_payload_json = json.dumps(reassignment, ensure_ascii=False)
    conn.execute('BEGIN IMMEDIATE')
    cur.execute(
        '''UPDATE tasks
           SET executor_agent=?, executor_session_key=?, hq_message_id=?, current_round=?, result_payload_json=?, updated_at=?
           WHERE task_id=?''',
        (NEW_EXECUTOR_AGENT, NEW_EXECUTOR_SESSION_KEY, NEW_HQ_MESSAGE_ID, new_round, new_payload_json, created_at, TASK_ID),
    )
    cur.execute(
        '''INSERT INTO task_events (task_id, event_type, actor, summary, payload_json, created_at)
           VALUES (?, ?, ?, ?, ?, ?)''',
        (TASK_ID, 'executor_reassigned', ACTOR, SUMMARY, event_payload_json, created_at),
    )
    conn.commit()

out = {
    'ok': True,
    'dry_run': DRY_RUN,
    'task_id': TASK_ID,
    'status': status,
    'thread_id': rowd.get('thread_id'),
    'backup_path': str(backup_path) if backup_path else None,
    'from': reassignment['from'],
    'to': reassignment['to'],
    'event_type': None if DRY_RUN else 'executor_reassigned',
    'next_required_steps': [
        'post/confirm the visible current-round instruction is already in the task thread',
        'run hq-executor-handoff-helper.sh --task-id <TASK-ID>',
        'run hq-handoff-send-plan.sh --task-id <TASK-ID> and execute the exact sessions_send plan',
        'record executor_handoff only after the real sessions_send succeeds',
    ],
}
print(json.dumps(out, ensure_ascii=False, indent=2))
PY
