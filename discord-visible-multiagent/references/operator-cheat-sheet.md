# Operator Cheat Sheet (v1)

Use this file when you already know the Discord visible multi-agent workflow applies and just need the smallest operator surface.

## HQ only: 4 primary entrypoints

### 1. Open a new formal tracked task
Use:
- `scripts/hq-formal-collab-gate.sh`

What it gives you:
- `task_id`
- dispatch payload
- blocked handoff state before visible dispatch exists

### 2. Execute visible dispatch
Use:
- `scripts/hq-visible-dispatch-run.sh`

What it does:
- create thread
- post visible `[R1]`
- write back `thread_id` / `hq_message_id` / `status=ACTIVE`

### 3. Prepare formal executor handoff
Use:
- `scripts/hq-collab-handoff-ready.sh`
- `scripts/hq-executor-handoff-helper.sh`
- `scripts/hq-handoff-send-plan.sh`

What it does:
- explicitly verifies that visible dispatch anchors now make handoff legal
- obtains the formal handoff payload after readiness passes
- validates the exact runtime send shape internally
- returns the only allowed `sessions_send` plan for formal handoff
- optional: `--record-preflight` for evidence writeback only

### 4. Review / advance / accept / close
Use:
- `scripts/hq-followup-close-helper.sh`
- `scripts/hq-thread-evidence-verify.sh` when result/notify message IDs are available and provenance must be checked
- `references/review-guide.md` when the decision is not obvious

Entry condition:
- HQ has already received the executor notify for the current round
- HQ is now choosing the truthful next state from the real visible result

What it does:
- generates the next-round / accept / blocked / review / failed / capped draft
- writes task-state changes back
- internally enforces notify-closure validation for `advance|accept|blocked|review|failed`

### Side path: switch executor for the next/current round
Use only after HQ has already posted the new visible current-round instruction in the task thread:
- `scripts/hq-reassign-executor.sh`

What it does:
- backs up `tasks.db`
- verifies the new executor session binding
- updates executor/session/HQ message anchor/optional round
- records `executor_reassigned` provenance

Then resume the normal handoff chain: helper payload → send plan → runtime `sessions_send` → `record-runtime-send.sh --kind executor_handoff`.

## Executor only: 1 primary ownership gate
Read first for return semantics:
- `references/executor-return-contract.md`

Use:
- `scripts/executor-ownership-gate.sh`

What it blocks:
- wrong task thread
- wrong executor identity
- wrong bound account
- non-`ACTIVE` task state

## Minimum HQ sequence
1. `hq-formal-collab-gate.sh`
2. `hq-visible-dispatch-run.sh`
3. `hq-collab-handoff-ready.sh`
4. `hq-executor-handoff-helper.sh`
5. `hq-handoff-send-plan.sh`
6. runtime performs `sessions_send`
7. `record-runtime-send.sh --kind executor_handoff`
8. later, optionally `hq-thread-evidence-verify.sh`, then `hq-followup-close-helper.sh`

## Minimum executor return sequence
1. receive formal handoff and confirm `task_id` / round / `thread_id` / `hq_message_id` / executor account
2. `executor-ownership-gate.sh`
3. executor posts the current-round result in the task thread using the sanctioned path
4. executor performs short internal confirmation
5. executor posts the fixed success or BLOCKED notify shape into the same task thread, then returns `NO_REPLY` as the session final text
6. HQ reviews via `hq-followup-close-helper.sh`

There is one formal return protocol. `sessions_send`, Discord send commands, and older `openclaw agent --deliver` samples are transports around that protocol, not competing workflows.

## Do not memorize these as top-level operator steps
These are internal or secondary details now:
- handoff payload generation internals
- send-shape validation internals
- notify-closure internal checks

Read the role workflow docs only when the edge case is not obvious.
