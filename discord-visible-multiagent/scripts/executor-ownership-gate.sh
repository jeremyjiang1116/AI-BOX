#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_PATH="${TASK_DB_PATH:-$WORKSPACE_ROOT/shared/task/state/tasks.db}"

usage() {
  cat <<'EOF'
Usage:
  executor-ownership-gate.sh \
    --task-id <TASK-ID> \
    --executor-agent <EXECUTOR_AGENT> \
    --executor-account <EXECUTOR_ACCOUNT> \
    --thread-id <THREAD_ID>

Purpose:
  Hard gate executor-owned result posting before any live thread send.

Checks:
  - task exists and is ACTIVE
  - provided executor matches the task's assigned executor
  - provided thread matches the task's thread_id
  - provided account matches the executor's bound account discovered from sessions metadata

This helper does NOT send any message.
EOF
}

TASK_ID=""
EXECUTOR_AGENT=""
EXECUTOR_ACCOUNT=""
THREAD_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    --executor-agent) EXECUTOR_AGENT="$2"; shift 2 ;;
    --executor-account) EXECUTOR_ACCOUNT="$2"; shift 2 ;;
    --thread-id) THREAD_ID="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for v in TASK_ID EXECUTOR_AGENT EXECUTOR_ACCOUNT THREAD_ID; do
  [[ -n "${!v}" ]] || { echo "Missing required arg: $v" >&2; usage; exit 1; }
done
command -v sqlite3 >/dev/null 2>&1 || { echo "Missing required command: sqlite3" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Missing required command: python3" >&2; exit 1; }

escaped_task_id="$(printf "%s" "$TASK_ID" | sed "s/'/''/g")"
row="$(sqlite3 -json "$DB_PATH" "SELECT task_id,status,executor_agent,executor_session_key,thread_id,current_round FROM tasks WHERE task_id = '$escaped_task_id';")"
[[ -n "$row" ]] || row='[]'

ROW_JSON="$row" EXECUTOR_AGENT="$EXECUTOR_AGENT" EXECUTOR_ACCOUNT="$EXECUTOR_ACCOUNT" THREAD_ID="$THREAD_ID" python3 - <<'PY'
import json, os, sys
from pathlib import Path

rows = json.loads(os.environ['ROW_JSON'])
if not rows:
    print(json.dumps({
        'ok': False,
        'error': 'task_not_found'
    }, ensure_ascii=False, indent=2))
    sys.exit(4)

row = rows[0]
expected_agent = row.get('executor_agent')
expected_thread = str(row.get('thread_id') or '')
expected_status = row.get('status') or ''
provided_agent = os.environ['EXECUTOR_AGENT']
provided_account = os.environ['EXECUTOR_ACCOUNT']
provided_thread = os.environ['THREAD_ID']

if expected_status != 'ACTIVE':
    print(json.dumps({
        'ok': False,
        'task_id': row.get('task_id'),
        'error': 'task_not_active',
        'status': expected_status,
    }, ensure_ascii=False, indent=2))
    sys.exit(5)

errors = []
if provided_agent != expected_agent:
    errors.append('executor_agent_mismatch')
if provided_thread != expected_thread:
    errors.append('thread_id_mismatch')

sessions_root = Path(os.environ.get("OPENCLAW_AGENTS_ROOT", str(Path.home() / ".openclaw/agents")))
sessions_path = sessions_root / expected_agent / "sessions/sessions.json"
expected_account = ''
account_evidence = []
if sessions_path.exists():
    try:
        sessions_obj = json.loads(sessions_path.read_text())
        candidates = []
        for session_key, meta in sessions_obj.items():
            if not isinstance(meta, dict):
                continue
            origin = meta.get('origin') or {}
            delivery = meta.get('deliveryContext') or {}
            for label, value in [
                ('origin.accountId', origin.get('accountId')),
                ('deliveryContext.accountId', delivery.get('accountId')),
                ('lastAccountId', meta.get('lastAccountId')),
            ]:
                if value:
                    candidates.append((label, value, session_key))
        uniq = sorted(set(v for _, v, _ in candidates))
        if len(uniq) == 1:
            expected_account = uniq[0]
            account_evidence = [
                {'source': label, 'value': value, 'sessionKey': session_key}
                for label, value, session_key in candidates if value == expected_account
            ]
        elif len(uniq) > 1:
            errors.append('executor_account_binding_ambiguous')
            account_evidence = [
                {'source': label, 'value': value, 'sessionKey': session_key}
                for label, value, session_key in candidates
            ]
    except Exception as e:
        errors.append('executor_sessions_parse_failed')
        account_evidence = {'error': str(e), 'sessions_path': str(sessions_path)}
else:
    errors.append('executor_sessions_missing')
    account_evidence = {'sessions_path': str(sessions_path), 'exists': False}

if expected_account and provided_account != expected_account:
    errors.append('executor_account_mismatch')

if errors:
    print(json.dumps({
        'ok': False,
        'task_id': row.get('task_id'),
        'error': 'ownership_gate_failed',
        'violations': errors,
        'expected': {
            'executor_agent': expected_agent,
            'thread_id': expected_thread,
            'executor_account': expected_account or None,
            'status': expected_status,
        },
        'provided': {
            'executor_agent': provided_agent,
            'thread_id': provided_thread,
            'executor_account': provided_account,
        },
        'account_evidence': account_evidence,
    }, ensure_ascii=False, indent=2))
    sys.exit(6)

print(json.dumps({
    'ok': True,
    'task_id': row.get('task_id'),
    'executor_agent': expected_agent,
    'thread_id': expected_thread,
    'executor_account': expected_account,
    'current_round': row.get('current_round'),
    'status': expected_status,
}, ensure_ascii=False, indent=2))
PY
