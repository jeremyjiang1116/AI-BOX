# Executor Return Contract (v1) — Single Formal Return Method

This is the workspace authority for how an assigned executor returns a current-round result to HQ in Discord visible multi-agent collaboration.

Canonical collaboration law:
- `<OPENCLAW_SHARED>/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md`

Runtime send-shape authority:
- `references/runtime-send-contracts.md`

This file collapses the previous confusion into one rule:

> There is exactly one formal executor return protocol. Different send transports are implementation details, not different workflows.

## 1. The only valid logical return sequence

For every executor-owned round result, the sequence is:

1. **Confirm anchors**
   - `task_id`
   - round `R<n>`
   - `thread_id`
   - `hq_message_id`
   - assigned `executor_agent`
   - executor-bound Discord `account`
   - current-round visible output contract

2. **Run executor ownership gate before any result post**
   ```bash
   skills/discord-visible-multiagent/scripts/executor-ownership-gate.sh \
     --task-id <TASK-ID> \
     --executor-agent <executor_agent> \
     --executor-account <executor_account> \
     --thread-id <thread_id>
   ```

3. **Post the current-round result in the task thread first**
   - The sender must be the assigned executor.
   - The Discord account must be the executor's bound account.
   - The target must be the tracked `thread_id`.
   - The result must satisfy the visible current-round output contract.
   - The send path must be the sanctioned standard path provided by the handoff / skill.

4. **Do a short internal confirmation**
   - Confirm command success and, when practical, that the thread-visible result exists.
   - This is internal only.
   - Do not send `pending confirmation` to HQ.

5. **Notify HQ only after the thread result is confirmed**
   - The current workspace notify transport is an executor-owned **thread-visible notify** posted to the tracked task thread.
   - The executor must use the same `thread_id` and executor-bound Discord account used for the result post.
   - Do not send notify to the executor main channel or `#hq-command`.
   - `sessions_send` is only the formal handoff transport; it is not the visible notify surface.
   - After successful thread notify, the executor session final reply must be exactly `NO_REPLY` to prevent duplicate delivery into the executor main channel.
   - `hq_message_id` remains a review / validation anchor; do not treat it as a Discord channel target.

   Success notify:
   ```text
   [<TASK-ID>][R<n>] 本轮已完成，请读取 thread 现场结果并决定下一轮。
   ```

   Blocked notify:
   ```text
   [<TASK-ID>][R<n>] BLOCKED: <short-blocker>
   reason: <最直接失败原因>
   evidence: <最关键错误证据>
   ```

6. **HQ reviews, not accepts blindly**
   HQ must then use the real thread result plus the notify anchors to choose exactly one:
   - accept
   - advance to next round
   - BLOCKED
   - REVIEW
   - FAILED
   - capped close at R15

   HQ follow-up / close must go through:
   ```bash
   skills/discord-visible-multiagent/scripts/hq-followup-close-helper.sh
   ```

## 2. The executable method by role

### HQ opens and hands off the round

Use the standard HQ chain:

```text
hq-formal-collab-gate.sh
→ hq-visible-dispatch-run.sh
→ hq-collab-handoff-ready.sh
→ hq-executor-handoff-helper.sh
→ hq-handoff-send-plan.sh
→ runtime sessions_send exactly as planned
→ record-runtime-send.sh --kind executor_handoff
```

Rules:
- HQ sends formal handoff to the executor with the helper-produced `sessions_send` plan only.
- HQ does not handcraft `sessions_send` selector combinations.
- HQ does not send executor-owned thread results in place of the executor.

### Executor returns the round

Use the standard executor chain:

```text
receive handoff
→ confirm anchors
→ executor-ownership-gate.sh
→ executor-owned result post to thread
→ short internal confirmation
→ thread-visible executor notify with fixed text
→ final executor session reply `NO_REPLY`
```

Rules:
- The thread result comes before HQ notify.
- The thread result is an executor-owned Discord send.
- The HQ notify is executor-owned and thread-visible: the executor posts the fixed notify text to the same tracked task thread, and HQ reads it from there. The executor session final reply is `NO_REPLY`, not the notify text.
- If the executor cannot post to the thread, the executor sends a blocked notify with `reason` and `evidence`; the executor must not send success notify.

### HQ reviews after notify

Use:

```text
read/verify thread result
→ hq-followup-close-helper.sh with notify args
→ send next-round / close / blocked / review / failed text as appropriate
→ write back real sends when applicable
```

Rules:
- Executor notify is necessary but never sufficient.
- HQ must verify thread reality before acceptance or next round.
- No R16 unless the user explicitly changes the cap in advance.

## 3. Transport mapping: one protocol, multiple implementation paths

These are implementation paths, not separate formal workflows.

### A. HQ → executor handoff / reminder

Formal path:
- `sessions_send`
- exact helper-produced shape from `hq-handoff-send-plan.sh`
- governed by `runtime-send-contracts.md`

This is not an executor return path.

### B. executor → task thread result

Formal path:
- executor-owned Discord send to `thread_id`
- using the executor-bound account
- using only a sanctioned standard path from the handoff / skill

Allowed standard paths may include:
- native/direct post path, when available
- `openclaw message send`
- `openclaw message thread reply` when appropriate
- a sanctioned assisted-post path explicitly provided in formal handoff

### C. executor → HQ completion notify

Formal path:
- executor-owned Discord send of the fixed notify text to the tracked `thread_id`
- use the executor-bound account and the same sanctioned send path family as result posting
- HQ reads that notify from the same task thread
- do not post notify to the executor main channel or `#hq-command`
- use `hq_message_id` only as a review / validation anchor, never as a channel target

Current standard notify text is fixed to the success / blocked shapes in section 1.

### D. Legacy / compatibility paths

Paths such as `openclaw agent --deliver` may explain older successful samples, but they are not the preferred formal return contract for new tracked tasks.

For new formal tracked tasks, use this contract unless a future skill update explicitly replaces it.

## 4. Hard invalid states

These are workflow violations:

- HQ posts an executor-owned result and presents it as executor output.
- One executor posts in place of another executor.
- The result is posted to the wrong thread.
- The result uses the wrong Discord account.
- Executor sends success notify before a thread result exists and is confirmed.
- Executor sends `pending confirmation` as a formal HQ update.
- Executor sends BLOCKED without `reason` and `evidence`.
- HQ advances or accepts without the notify anchors passing helper validation.
- HQ treats different transports as separate acceptable protocols during live execution.
- Anyone improvises send paths at runtime instead of using the helper / handoff-sanctioned path.

## 5. Minimal success checklist

Executor side:
- [ ] anchors confirmed
- [ ] ownership gate passed
- [ ] result posted to tracked thread by assigned executor account
- [ ] short internal confirmation completed
- [ ] thread-visible HQ notify posted with exact success shape
- [ ] final executor session reply was `NO_REPLY`, so no task notify leaked to executor main channel

HQ side:
- [ ] notify `task_id`, round, executor, and thread anchors match task state
- [ ] thread result is visible and read
- [ ] output contract is met or gaps are identified
- [ ] `hq-followup-close-helper.sh` used for accept / advance / blocked / review / failed
- [ ] real sends are written back when task-state tracking requires it
