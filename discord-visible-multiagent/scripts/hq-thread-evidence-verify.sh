#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DB_PATH="${TASK_DB_PATH:-$WORKSPACE_ROOT/shared/task/state/tasks.db}"

usage() {
  cat <<'EOF'
Usage:
  hq-thread-evidence-verify.sh \
    --task-id <TASK-ID> \
    --result-message-id <MESSAGE_ID> \
    --notify-message-id <MESSAGE_ID> \
    [--executor-agent <AGENT>] \
    [--executor-account <ACCOUNT>] \
    [--round <ROUND>] \
    [--thread-json-file <PATH> | --read-live] \
    [--read-limit <N>]

Purpose:
  Verify thread-visible executor evidence before HQ accepts, advances, or closes.

Checks:
  - task exists and has thread_id / executor / current_round anchors
  - result and notify messages exist in the target thread
  - result and notify are authored by the expected executor identity/account
  - result appears before notify when comparable timestamps are available
  - notify text matches the formal success or BLOCKED notify shape

Input modes:
  --thread-json-file reads a saved `openclaw message read --json` payload.
  --read-live reads Discord directly via `openclaw message read` using the executor
  account (or the bound account discovered from sessions metadata).
EOF
}

TASK_ID=""
RESULT_MESSAGE_ID=""
NOTIFY_MESSAGE_ID=""
EXECUTOR_AGENT=""
EXECUTOR_ACCOUNT=""
ROUND=""
THREAD_JSON_FILE=""
READ_LIVE=0
READ_LIMIT="50"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task-id) TASK_ID="$2"; shift 2 ;;
    --result-message-id) RESULT_MESSAGE_ID="$2"; shift 2 ;;
    --notify-message-id) NOTIFY_MESSAGE_ID="$2"; shift 2 ;;
    --executor-agent) EXECUTOR_AGENT="$2"; shift 2 ;;
    --executor-account) EXECUTOR_ACCOUNT="$2"; shift 2 ;;
    --round) ROUND="$2"; shift 2 ;;
    --thread-json-file) THREAD_JSON_FILE="$2"; shift 2 ;;
    --read-live) READ_LIVE=1; shift ;;
    --read-limit) READ_LIMIT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

for v in TASK_ID RESULT_MESSAGE_ID NOTIFY_MESSAGE_ID; do
  [[ -n "${!v}" ]] || { echo "Missing required arg: $v" >&2; usage; exit 1; }
done
if [[ -n "$THREAD_JSON_FILE" && "$READ_LIVE" == "1" ]]; then
  echo "Use either --thread-json-file or --read-live, not both" >&2
  exit 1
fi
command -v sqlite3 >/dev/null 2>&1 || { echo "Missing required command: sqlite3" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Missing required command: python3" >&2; exit 1; }

escaped_task_id="$(printf "%s" "$TASK_ID" | sed "s/'/''/g")"
row="$(sqlite3 -json "$DB_PATH" "SELECT task_id,status,thread_id,executor_agent,executor_session_key,current_round FROM tasks WHERE task_id = '$escaped_task_id';")"
[[ -n "$row" ]] || row='[]'

resolved="$(ROW_JSON="$row" EXECUTOR_AGENT="$EXECUTOR_AGENT" EXECUTOR_ACCOUNT="$EXECUTOR_ACCOUNT" ROUND="$ROUND" python3 - <<'PY'
import json, os, sys
from pathlib import Path
rows = json.loads(os.environ['ROW_JSON'])
if not rows:
    print(json.dumps({'ok': False, 'error': 'task_not_found'}, ensure_ascii=False))
    sys.exit(2)
row = rows[0]
executor_agent = os.environ.get('EXECUTOR_AGENT') or row.get('executor_agent') or ''
executor_account = os.environ.get('EXECUTOR_ACCOUNT') or ''
round_raw = os.environ.get('ROUND') or str(row.get('current_round') or '')
if not row.get('thread_id'):
    print(json.dumps({'ok': False, 'error': 'missing_thread_id', 'task_id': row.get('task_id')}, ensure_ascii=False))
    sys.exit(3)
if not executor_agent:
    print(json.dumps({'ok': False, 'error': 'missing_executor_agent', 'task_id': row.get('task_id')}, ensure_ascii=False))
    sys.exit(3)
try:
    round_no = int(round_raw)
except Exception:
    print(json.dumps({'ok': False, 'error': 'invalid_round', 'round': round_raw}, ensure_ascii=False))
    sys.exit(3)
account_evidence = []
if not executor_account:
    sessions_root = Path(os.environ.get("OPENCLAW_AGENTS_ROOT", str(Path.home() / ".openclaw/agents")))
    sessions_path = sessions_root / executor_agent / "sessions/sessions.json"
    if sessions_path.exists():
        try:
            sessions = json.loads(sessions_path.read_text())
            candidates = []
            for session_key, meta in sessions.items():
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
                executor_account = uniq[0]
                account_evidence = [
                    {'source': label, 'value': value, 'sessionKey': session_key}
                    for label, value, session_key in candidates if value == executor_account
                ]
            elif len(uniq) > 1:
                print(json.dumps({'ok': False, 'error': 'executor_account_binding_ambiguous', 'candidate_accounts': uniq}, ensure_ascii=False))
                sys.exit(3)
        except Exception as e:
            print(json.dumps({'ok': False, 'error': 'executor_sessions_parse_failed', 'evidence': str(e)}, ensure_ascii=False))
            sys.exit(3)
if not executor_account:
    print(json.dumps({'ok': False, 'error': 'missing_executor_account', 'executor_agent': executor_agent}, ensure_ascii=False))
    sys.exit(3)
print(json.dumps({
    'ok': True,
    'task_id': row.get('task_id'),
    'status': row.get('status'),
    'thread_id': str(row.get('thread_id')),
    'executor_agent': executor_agent,
    'executor_account': executor_account,
    'current_round': round_no,
    'account_evidence': account_evidence,
}, ensure_ascii=False))
PY
)" || { printf '%s\n' "$resolved"; exit $?; }

thread_json=""
if [[ -n "$THREAD_JSON_FILE" ]]; then
  [[ -f "$THREAD_JSON_FILE" ]] || { echo "Thread JSON file not found: $THREAD_JSON_FILE" >&2; exit 1; }
  thread_json="$(cat "$THREAD_JSON_FILE")"
elif [[ "$READ_LIVE" == "1" ]]; then
  thread_id="$(printf '%s' "$resolved" | python3 -c 'import json,sys; print(json.load(sys.stdin)["thread_id"])')"
  account="$(printf '%s' "$resolved" | python3 -c 'import json,sys; print(json.load(sys.stdin)["executor_account"])')"
  thread_json="$(openclaw message read --channel discord --account "$account" --target "channel:$thread_id" --limit "$READ_LIMIT" --json)"
else
  echo "Missing evidence input: use --thread-json-file <PATH> or --read-live" >&2
  exit 1
fi

RESOLVED_JSON="$resolved" \
THREAD_JSON="$thread_json" \
RESULT_MESSAGE_ID="$RESULT_MESSAGE_ID" \
NOTIFY_MESSAGE_ID="$NOTIFY_MESSAGE_ID" \
python3 - <<'PY'
import json
import os
import re
import sys
from datetime import datetime

resolved = json.loads(os.environ['RESOLVED_JSON'])
raw = os.environ.get('THREAD_JSON') or ''
result_id = str(os.environ['RESULT_MESSAGE_ID'])
notify_id = str(os.environ['NOTIFY_MESSAGE_ID'])

try:
    data = json.loads(raw)
except Exception as e:
    print(json.dumps({'ok': False, 'task_id': resolved.get('task_id'), 'error': 'thread_json_parse_failed', 'evidence': str(e)}, ensure_ascii=False, indent=2))
    sys.exit(4)

messages = []

def walk(x):
    if isinstance(x, dict):
        if any(k in x for k in ('id', 'messageId', 'message_id')) and any(k in x for k in ('content', 'text', 'message', 'body')):
            messages.append(x)
        for v in x.values():
            walk(v)
    elif isinstance(x, list):
        for v in x:
            walk(v)
walk(data)

if not messages and isinstance(data, list):
    messages = [x for x in data if isinstance(x, dict)]

def mid(m):
    for k in ('id', 'messageId', 'message_id'):
        v = m.get(k)
        if v is not None:
            return str(v)
    return ''

def text(m):
    for k in ('content', 'text', 'message', 'body'):
        v = m.get(k)
        if isinstance(v, str):
            return v
    return ''

def author_values(m):
    vals = []
    for k in ('author', 'sender', 'from', 'user', 'member'):
        v = m.get(k)
        if isinstance(v, str):
            vals.append(v)
        elif isinstance(v, dict):
            for kk in ('name', 'username', 'label', 'displayName', 'globalName', 'id', 'accountId'):
                if v.get(kk) is not None:
                    vals.append(str(v.get(kk)))
    for k in ('authorName', 'author_name', 'senderName', 'sender_name', 'username', 'accountId', 'account_id'):
        if m.get(k) is not None:
            vals.append(str(m.get(k)))
    return vals

def timestamp(m):
    for k in ('timestamp', 'createdAt', 'created_at', 'time', 'date'):
        v = m.get(k)
        if v is not None:
            return str(v)
    return ''

def find(message_id):
    for idx, m in enumerate(messages):
        if mid(m) == message_id:
            return idx, m
    return None, None

result_idx, result_msg = find(result_id)
notify_idx, notify_msg = find(notify_id)
violations = []
if result_msg is None:
    violations.append('result_message_not_found')
if notify_msg is None:
    violations.append('notify_message_not_found')

expected_task = resolved['task_id']
expected_round = str(resolved['current_round'])
expected_agent = resolved['executor_agent']
expected_account = resolved['executor_account']

def author_ok(m):
    vals = author_values(m)
    needles = [expected_agent, expected_account]
    return any(n and any(n in v for v in vals) for n in needles), vals

result_author_vals = []
notify_author_vals = []
if result_msg is not None:
    ok, result_author_vals = author_ok(result_msg)
    if not ok:
        violations.append('result_author_mismatch')
if notify_msg is not None:
    ok, notify_author_vals = author_ok(notify_msg)
    if not ok:
        violations.append('notify_author_mismatch')
    notify_text = text(notify_msg)
    prefix_patterns = [
        rf'^\[{re.escape(expected_task)}\]\[R{re.escape(expected_round)}\]',
        rf'^\[{re.escape(expected_task)}\]\s*\[R{re.escape(expected_round)}\]',
    ]
    if not any(re.search(p, notify_text) for p in prefix_patterns):
        violations.append('notify_prefix_mismatch')
    success_hint = '本轮已完成，请读取 thread 现场结果并决定下一轮。' in notify_text
    blocked_hint = 'BLOCKED:' in notify_text and 'reason:' in notify_text and 'evidence:' in notify_text
    if not (success_hint or blocked_hint):
        violations.append('notify_shape_unrecognized')

order_evidence = {'mode': None, 'result': None, 'notify': None}
if result_msg is not None and notify_msg is not None:
    rt = timestamp(result_msg)
    nt = timestamp(notify_msg)
    if rt and nt:
        order_evidence = {'mode': 'timestamp', 'result': rt, 'notify': nt}
        if rt > nt:
            violations.append('result_after_notify')
    else:
        order_evidence = {'mode': 'array_index', 'result': result_idx, 'notify': notify_idx}
        # Discord reads can be newest-first or oldest-first depending on provider;
        # require only that the two IDs are distinct when no comparable timestamp exists.
        if result_id == notify_id:
            violations.append('result_notify_same_message')

out = {
    'ok': not violations,
    'task_id': expected_task,
    'thread_id': resolved.get('thread_id'),
    'round': int(expected_round),
    'executor_agent': expected_agent,
    'executor_account': expected_account,
    'result_message_id': result_id,
    'notify_message_id': notify_id,
    'violations': violations,
    'evidence': {
        'message_count_scanned': len(messages),
        'result_found': result_msg is not None,
        'notify_found': notify_msg is not None,
        'result_author_values': result_author_vals,
        'notify_author_values': notify_author_vals,
        'notify_text': text(notify_msg) if notify_msg is not None else None,
        'order': order_evidence,
    }
}
print(json.dumps(out, ensure_ascii=False, indent=2))
sys.exit(0 if not violations else 5)
PY
