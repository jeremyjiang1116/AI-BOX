# Runtime Send Contracts (workspace authority)

Canonical collaboration law remains:
- `/home/ubuntu/.openclaw/shared/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md`

This file is **not** the collaboration law layer.
This file is the **workspace runtime execution contract** for actual send shapes on this machine.

Executor return protocol authority:
- `references/executor-return-contract.md`

## Priority
If text conflicts:
1. canonical shared workflow defines role / round / visibility law
2. `skills/discord-visible-multiagent/SKILL.md` defines the workspace execution gate
3. **this file defines the exact runtime send shape that is allowed on this machine**
4. mirrors/docs must follow these rules, not compete with them

## Formal handoff and executor reminder: exact `sessions_send` contract

### Verified current runtime shape
For formal executor handoff and executor reminder on the current OpenClaw runtime surface, the only verified working shape is:
- `sessionKey = <exact executor_session_key>`
- `label = " "` (a single ASCII space)
- `message = <helper-produced payload>`

This is a runtime-specific boundary behavior, not a free-form selector choice.

### What this means
- `label` is **not** a second semantic selector in this contract
- `label` must not contain task names, notes, comments, tags, IDs, or session identifiers
- the single-space label is a **required runtime placeholder** for the currently verified handoff/reminder path
- when exact `executor_session_key` is available, no alternative selector form is authorized for formal handoff/reminder

### Allowed shape
```json
{
  "tool": "sessions_send",
  "arguments": {
    "agentId": "<executor-agent>",
    "sessionKey": "<exact executor_session_key>",
    "label": " ",
    "message": "<helper-produced payload>",
    "timeoutSeconds": 120
  }
}
```

### Forbidden shapes
These are workflow violations for formal handoff/reminder on this machine:
- `sessionKey` + any non-whitespace `label`
- label-only targeting when exact `executor_session_key` is already known
- hand-typed label text such as task names, `formal-handoff-r1`, `TASK-...`, `.` or notes
- ad hoc retries with multiple selector combinations at send time
- bypassing helper-produced send plans for formal handoff/reminder

### Required execution rule
For formal handoff/reminder, runtime must use:
1. `hq-executor-handoff-helper.sh` or `executor-reminder-helper.sh` for payload generation
2. `hq-handoff-send-plan.sh` for the exact runtime send shape when handoff is involved
3. the generated send arguments **without manual modification**

If this exact shape fails again in the future, classify it as a new runtime/tooling boundary issue and stop to re-verify.
Do not improvise alternate selector combinations during a live formal workflow.

## Executor-owned Discord thread sends: exact actor rule
For executor-owned thread messages:
- the assigned executor must send the message themselves
- the send must use the executor's bound Discord account
- one executor must not send on behalf of another executor
- HQ must not substitute for executor-owned sends

This file does not define the full executor return sequence.
That sequence is defined in `references/executor-return-contract.md`:
ownership gate → thread result first → short internal confirmation → thread-visible HQ notify.

## Mirror discipline
Any workflow mirror or helper-routing document that discusses runtime send shapes must either:
- quote this file exactly, or
- point here instead of restating the rule from memory
