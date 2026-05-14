---
name: discord-visible-multiagent
description: Coordinate formal, visible multi-agent collaboration across Discord in OpenClaw. Use when the user asks to dispatch work to a named executor, open or continue a tracked task thread, review or accept executor output, scan due tasks, send HQ sync or executor reminders, continue the next round, or audit this workflow. This is the top-level gate for HQ-tracked cross-agent work; content-layer skills run only after this collaboration route is selected. Do not use for Discord permissions, low-level routing/plugin work, bot development, or single-agent solo tasks.
---

# discord-visible-multiagent


## Quick Decision Card

Use this skill when:
- a named executor is involved;
- Discord thread-visible collaboration is required;
- `task_id` / round / HQ acceptance must be tracked.

Minimum HQ path:
1. Run `scripts/hq-formal-collab-gate.sh`.
2. Create the visible `[R<n>]` thread anchor with `scripts/hq-visible-dispatch-run.sh`.
3. Check readiness with `scripts/hq-collab-handoff-ready.sh`.
4. Generate executor handoff with `scripts/hq-executor-handoff-helper.sh`.
5. Generate the validated runtime send plan with `scripts/hq-handoff-send-plan.sh`.
6. Execute the exact `sessions_send` plan and record `executor_handoff` only after the real send succeeds.
7. Executor posts the result in the task thread using the sanctioned path.
8. Executor posts the fixed same-thread notify.
9. HQ verifies thread evidence when needed, then accepts or continues with `scripts/hq-followup-close-helper.sh`.

Never:
- treat executor completion as HQ acceptance;
- skip the visible `[R<n>]` anchor;
- send as the wrong actor/account;
- allow R16+ without explicit user override;
- invent ad hoc Discord send paths;
- move notify to the executor main channel or `#hq-command`.

## Portable core rules

These rules are portable across OpenClaw workspaces:
- select this skill before content-layer execution for formal named-executor collaboration;
- preserve task anchors: `task_id`, thread/message anchors, executor, current round, status;
- HQ owns dispatch, review, acceptance, close, and round authority;
- executor owns executor-result posting and same-thread notify;
- helper-generated payloads and send plans are the source of truth for fragile send shapes.

## Workspace-specific assumptions

This published copy keeps the workflow portable, but some helpers assume a standard OpenClaw workspace layout unless overridden. See `references/workspace-specific.md` before adapting this skill to a different deployment.

Default assumptions include:
- `OPENCLAW_WORKSPACE_ROOT` defaults to the repository/workspace root inferred from `scripts/`;
- `TASK_DB_PATH` defaults to `$OPENCLAW_WORKSPACE_ROOT/shared/task/state/tasks.db`;
- task-state helper scripts live under `shared/task/state/`;
- executor session metadata lives under `OPENCLAW_AGENTS_ROOT` or `$HOME/.openclaw/agents`;
- local workflow mirrors such as `docs/workflows/` are supporting notes, not public portability requirements.

This skill is the **workspace execution gate** for formal Discord visible multi-agent collaboration.

Use it to keep HQ ↔ executor work visible, task-state-backed, round-bounded, and truthful. Keep detailed procedure in the reference files; keep this file small enough to be the first thing an operator can actually read.

## Authority map

1. **Canonical collaboration law**
   - In Jeremy/OpenClaw workspaces this is mirrored at `$HOME/.openclaw/shared/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md`.
   - Defines role boundaries, visible multi-round law, round cap, and close/acceptance behavior.
   - For portable installs, treat this `SKILL.md` plus `references/` as the packaged public contract.

2. **This `SKILL.md`**
   - Decides when the workflow triggers.
   - Defines the workspace-level execution gates and non-negotiable rules.
   - Routes operators to the right helper/reference without restating every detail.

3. **Reference docs under `references/`**
   - `operator-cheat-sheet.md` — smallest daily operator surface.
   - `helper-routing.md` — exact helper selection and regression checks.
   - `hq-workflow.md` — HQ responsibilities and decision path.
   - `executor-return-contract.md` — single formal executor return protocol.
   - `executor-workflow.md` — executor-side expansion.
   - `runtime-send-contracts.md` — exact current runtime send shapes.
   - `review-guide.md` — HQ review / accept / challenge / close criteria.
   - `templates.md` — visible message templates and examples.
   - `workflow.md`, `boundaries.md`, `anti-patterns.md`, `eval-prompts.md` — supporting context.

4. **Workspace workflow mirrors under `docs/workflows/`**
   - Jeremy/OpenClaw supporting implementation notes only. They must not compete with this skill or the canonical workflow.
   - See `references/workspace-specific.md` for portability boundaries.

If these layers conflict: trust the canonical workflow first, then this skill, then the specific runtime/reference authority. Fix the drifting document instead of inventing a new path.

## Trigger rule

Enter this skill before any content-layer skill when the request involves formal cross-agent collaboration, such as:

- “派给夜兰 / 艾尔海森 / executor”
- “开 thread 跑这个任务”
- “继续这个 thread 的下一轮”
- “审一下 executor 的结果 / accept / close”
- “给 executor 发 reminder”
- “给 HQ 发 sync / 查 due tasks”
- “审计 / 改进这个多 agent 协作 workflow / skill”

Do **not** use this skill for:
- unrelated single-agent solo work;
- Discord platform permissions / bot deployment design;
- low-level OpenClaw routing/plugin implementation unless the visible collaboration workflow itself is being audited.

## Fast route

Pick the narrowest correct route; do not read the whole reference tree by default.

| Situation | Read / use first |
|---|---|
| HQ opening, dispatching, handing off, reviewing, or closing a formal task | `references/operator-cheat-sheet.md` |
| Need exact helper order or due-task / sync / reminder path | `references/helper-routing.md` |
| HQ decision is non-obvious | `references/hq-workflow.md`, then `references/review-guide.md` |
| Executor received a formal handoff | `references/executor-return-contract.md`, then `references/executor-workflow.md` if needed |
| Need exact `sessions_send` / runtime send shape | `references/runtime-send-contracts.md` |
| Need visible wording | `references/templates.md` |
| Auditing or redesigning the workflow | `references/workflow.md`, `references/boundaries.md`, `references/anti-patterns.md`, `references/eval-prompts.md` |

## Core execution model

Formal tracked collaboration in this workspace uses:

> **skill-first + task-id-first + visible-dispatch-first + payload-first + runtime-send + writeback**

Meaning:
- choose this collaboration route before content-layer execution;
- create/preserve a `task_id` before visible dispatch;
- create the task thread and visible `[R1]` dispatch before executor handoff;
- helpers generate payloads, drafts, intents, validations, and SQLite state;
- the current runtime/session performs real Discord sends and `sessions_send`;
- after a real send, write back the action when the task-state workflow requires it;
- preserve task-state anchors for real coordinated work: `task_id`, `thread_id`, `hq_message_id`, current round, executor, and status.

## Non-negotiable rules

- **HQ owns coordination**: task creation, visible dispatch, round authority, review, acceptance, and close.
- **Executor owns executor results**: HQ or another executor must not post executor-owned result text in the assigned executor's place.
- **Thread result comes before notify**: executor must land the current-round result in the tracked thread before sending the fixed HQ notify into the same task thread.
- **Notify is not acceptance**: HQ must read/verify the thread result before advance or acceptance.
- **`sessions_send` is not the visible notify surface**: use it for formal handoff transport only; executor notify belongs in the tracked thread.
- **Visible contract is authoritative**: formal handoff may operationalize the current round, but must not secretly narrow, change, or add executor-visible requirements absent from the thread-visible output contract.
- **No R16**: R15 is the hard cap unless the user explicitly changes the cap in advance.
- **No ad hoc send-shape improvisation**: formal handoff/reminder must use helper-produced runtime send plans and the exact current contract in `runtime-send-contracts.md`, including the verified `sessionKey` + whitespace `label` selector rule.
- **Correct actor and provenance matter**: use the assigned actor/session/account and preserve truthful provenance for native/direct vs sanctioned assisted/standard sends.
- **No shell text corruption**: do not wrap dynamic Discord/thread content in shell backticks or unsafe command substitution; prefer safe escaping or file/stdin input.
- **No black holes**: if a formal task stalls, sync truthful status instead of silently waiting.

## Standard operator surface

### HQ formal task chain

Use the helper chain documented in `references/operator-cheat-sheet.md` and `references/helper-routing.md`:

```text
hq-formal-collab-gate.sh
→ hq-visible-dispatch-run.sh
→ hq-collab-handoff-ready.sh
→ hq-executor-handoff-helper.sh
→ hq-handoff-send-plan.sh
→ runtime sessions_send exactly as planned
→ $OPENCLAW_WORKSPACE_ROOT/shared/task/state/record-runtime-send.sh --kind executor_handoff
→ hq-followup-close-helper.sh when reviewing/advancing/closing
```

Do not skip visible dispatch/writeback before handoff.
Do not handcraft `sessions_send` when the helper can produce the plan.

### Executor formal return chain

Use the single protocol in `references/executor-return-contract.md`:

```text
confirm anchors
→ executor-ownership-gate.sh
→ executor-owned result post to tracked thread
→ short internal confirmation
→ fixed thread-visible HQ notify
→ final executor session reply NO_REPLY
```

If the executor cannot safely post to the tracked thread, report `BLOCKED` with `reason` and `evidence`; do not send a success notify.

## Regression checks

When changing helper behavior, task-state gates, ownership/account binding, notify validation, send-plan validation, visible payload construction, or runtime send contracts, run these serially:

```bash
discord-visible-multiagent/scripts/test_runtime_truth_regressions.sh
discord-visible-multiagent/scripts/test_handoff_runtime_contract.sh
discord-visible-multiagent/scripts/test_visible_contract_integrity.sh
```

Run serially because they share the SQLite task-state store and parallel runs can create misleading lock failures.

## Maintenance rule

Keep `SKILL.md` as the entry gate. Put long examples, helper internals, templates, and edge-case expansions in `references/`. If a future incident adds a new rule, first decide whether it belongs here as a non-negotiable gate or in a narrower reference file.
