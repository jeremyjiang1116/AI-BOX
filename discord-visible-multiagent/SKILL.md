---
name: discord-visible-multiagent
description: Coordinate visible multi-agent collaboration across Discord channels in OpenClaw, including formal HQ dispatch, executor-channel multi-turn execution (15-round hard cap), task-id-first tracking, payload-first runtime-send, and send-after-writeback discipline. Use when the user asks to hand off work from HQ to an execution channel, open a Discord thread for a tracked task, continue the next round in an existing thread, review or accept executor output, scan due tasks, generate HQ sync/reminder actions, or design/audit a visible cross-agent workflow. Typical trigger phrasings include “派给夜兰/艾尔海森”, “开个 thread 跑这个任务”, “继续这个 thread 的下一轮”, “给 executor 发 reminder”, “给 HQ 发 sync”, or “审一下这个多 agent 协同 skill / workflow”. Do not use when the request is mainly about Discord permissions, low-level OpenClaw routing internals, bot/plugin development, or single-agent solo execution.
---

# discord-visible-multiagent (workspace skill)

This workspace skill is the **formal execution entry** for Discord visible multi-agent collaboration in this workspace.

## Canonical basis
- Workflow canonical source: `<OPENCLAW_SHARED>/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md`
- Skill source artifacts: `<OPENCLAW_SHARED>/artifacts/discord-visible-multiagent/`
- Workspace workflow mirror: `docs/workflows/discord-true-multiround-workflow.md`

Treat the canonical shared workflow as the top rule source.
Treat this skill as the **primary execution entry and consolidation layer** for this workspace.
This workspace skill is the execution-layer entry that adds the **current machine's verified task-state/runtime integration rules**.

## Source-of-truth split
Use this split strictly to avoid drift, conflict, and duplication:

### 1. Canonical shared workflow = collaboration law
The canonical shared workflow defines:
- the true multi-round collaboration model
- HQ/executor role boundaries
- round governance
- visible-thread-first rules
- acceptance / cap / close behavior

If a collaboration rule is already defined there, do not redefine it differently elsewhere.

### 2. This skill = execution gate for this workspace
This skill defines:
- when the workflow must trigger
- what helper chain must be used on this machine
- what runtime-send/writeback boundaries are real
- what hard gates are required before executor handoff
- how to route common HQ operations without re-deriving the process each time

For day-to-day execution in this workspace, prefer this skill as the direct operating entry.

### 3. docs/workflows = supporting implementation notes
`docs/workflows/` is supporting detail only.
Use it for:
- helper-specific SOPs
- implementation notes
- runtime supplements
- machine-verified operational details

Docs must not compete with the skill.
If doc text and skill text conflict, fix the doc or fix the skill so they match again.

## Bundled scripts ownership
For this workspace, the maintained collaboration workflow scripts live under this skill's `scripts/` directory.
Use the role guides and helper-routing references for the detailed helper map.

## What this skill now governs
This skill is not only about thread/round etiquette anymore. It governs the combined workflow at the execution-gate level:

1. **skill-first**: hit this skill before running cross-agent Discord collaboration
2. **task-id-first**: formal tasks must be created in SQLite before visible dispatch
3. **visible-dispatch-first**: thread + visible `[R1]` must exist before executor handoff
4. **payload-first**: local helpers generate payload / intent / DB state, not fake full automation
5. **runtime-send**: real Discord send / `sessions_send` are performed by the current runtime/session
6. **writeback-required**: after real send, DB must be updated so the state layer remains truthful

Detailed helper selection and step-by-step variants belong in the references files.

## Collaboration-first classification
When a request may involve named executors, cross-session coordination, HQ tracking, visible collaboration, or multi-role handoff, classify it as a collaboration task first.

If the task has both:
- a content-layer attribute (research/search, coding, debugging, etc.), and
- a formal collaboration attribute,

then this skill is the correct top-level entry gate. Content-layer skills may still be used, but only after the collaboration path has been chosen correctly.

## Quick route first
Pick the lightest correct path before reading everything.

Before choosing a content-layer route, do one classification check first:
- Is this actually a multi-role / HQ-tracked / cross-session task?
- Is a named executor being asked to take the work?
- Does the task need visible coordination, sync-back, or acceptance?

If yes, enter this skill first even if another content-layer skill also matches.

### Role-first routes
- **HQ opening / dispatching / handing off / reviewing / closing** → read `references/operator-cheat-sheet.md` first, then `references/hq-workflow.md` if needed
- **Executor receiving formal handoff / posting result / notifying HQ** → read `references/operator-cheat-sheet.md` first, then `references/executor-return-contract.md`, then `references/executor-workflow.md` if needed

### Operator surface rule
Prefer the smallest possible operator surface:
- HQ primary entrypoints should stay concentrated in `hq-formal-collab-gate.sh`, `hq-visible-dispatch-run.sh`, `hq-handoff-send-plan.sh`, and `hq-followup-close-helper.sh`
- executor primary preflight should stay concentrated in `executor-ownership-gate.sh`
- internal validation should be embedded in those helpers when possible instead of spawning extra standalone scripts

### Task-shape routes
- **New formal tracked task** → read `references/operator-cheat-sheet.md`, then `references/hq-workflow.md` only if needed
- **Existing thread / next-round advance / acceptance** → read `references/operator-cheat-sheet.md`, then `references/review-guide.md` only if needed
- **Due-task / HQ sync / executor reminder** → read `references/helper-routing.md`, then `references/runtime-send-contracts.md`, then `references/hq-workflow.md`
- **Workflow design / audit / modernization** → read `references/workflow.md`, then `references/hq-workflow.md`, then `references/executor-workflow.md`, then `references/runtime-send-contracts.md`, then `references/anti-patterns.md`

## Load order
If no narrower route above is obvious, default to:
1. `references/operator-cheat-sheet.md`
2. the relevant role guide (`references/hq-workflow.md` or `references/executor-workflow.md`)
3. `references/executor-return-contract.md` when executor result / notify / return semantics are involved
4. `references/runtime-send-contracts.md` and `references/helper-routing.md` as needed
5. other references only when the task shape truly requires them

### Runtime truth regression checks
When you change helper behavior, task-state gates, notify validation, send-plan validation, ownership rules, or visible-contract payload construction, run the maintained regression checks documented in `references/helper-routing.md`.
Run them serially, not in parallel. They share the same SQLite task-state store and parallel runs can produce lock-noise false negatives.

## Core operating rules
- HQ is the sole authority for dispatch, round counter, acceptance, and final close.
- Executor completion is **not** acceptance; HQ must personally verify quality.
- Use explicit thread naming and `[R<n>]` round labels on every visible thread instruction/result.
- Enforce the hard round cap. Never allow R16 unless the user explicitly changes the cap in advance.
- Do not assume implicit cross-channel memory.
- Keep HQ sync-back visible and distilled.
- If a real task is being coordinated, preserve task-state truth: `task_id`, `thread_id`, `hq_message_id`, round, executor, current status.
- For each round, the thread-visible HQ instruction is the authoritative contract anchor. Formal handoff may restate or operationalize that round, but must not tighten, narrow, or secretly specialize the output contract, acceptance criteria, or executor-visible requirements.
- Formal handoff must not introduce any executor-visible requirement that is absent from the thread-visible current-round instruction.
- For dynamic Discord/thread text, do not use shell-inline backticks or unsafe command substitution. Use safe escaping or file/stdin-based input so runtime-visible content cannot be corrupted by the shell.
- There is exactly one formal executor return protocol: executor confirms anchors, passes ownership gate, posts the current-round result in the task thread first, performs short internal confirmation, then posts the fixed HQ notify shape into the same task thread using the executor-bound account, and returns `NO_REPLY` as the executor session final text. Do not send executor notify to the executor main channel or `#hq-command`; `sessions_send` is only the formal handoff transport, not the visible notify surface. Treat transport variants as implementation details, not alternate workflows; use `references/executor-return-contract.md` as the authority.

## Mandatory execution model (new hard rule)
For this workspace, the correct execution model is:

> **payload-first + runtime-send + writeback**

Meaning:
- shell/helpers are responsible for SQLite state, task registration, payload generation, draft generation, and runtime intent generation;
- the current assistant/runtime session is responsible for real sending;
- after any real send, the action must be written back to `tasks.db` when applicable.

Do **not** revert to the old assumption that shell helpers or CLI snippets automatically own the whole dispatch/sync/reminder chain.

### G. Capability-gap fallback and provenance (hard rule)
If the executor session does **not** have native/direct ability to post into the target thread, do **not** let the executor invent its own `exec`, shell, or `openclaw` CLI bypass.
A fallback path is allowed only when HQ/skill explicitly provides a **single sanctioned assisted-post / standard send path** in the formal handoff.

#### Native/direct vs standard send path
In this workspace, `first-class / direct-post ability` remains a **descriptive distinction**, not the hard validity gate for workflow continuation.

Practical distinction:
- if you remove `exec`, shell, and CLI bypasses, and the executor can still directly post to the target thread, that is native/direct ability
- otherwise it is **not** native/direct ability; it is at most assisted/fallback or standard CLI/runtime posting

#### Hard validity gate
The real workflow gate is:
- the message is sent by the **correct actor** for that step, and
- the actor uses a workflow-recognized **standard send path**

That means:
- executor-result messages must be sent by the assigned executor
- HQ or another executor must not send in their place
- allowed standard send paths may include native/direct messaging paths, `openclaw message send`, and `openclaw message thread reply` when appropriate

#### Provenance rule
Do not collapse these into one bucket:
- **native/direct path** = executor independently posted in thread through a native messaging path
- **sanctioned assisted-post / standard CLI path** = executor lacks native/direct ability, but the send is still performed by the correct executor through a skill-recognized standard path

Instead when capability is missing:
- executor must either use the HQ-provided sanctioned assisted-post / standard send path, or explicitly report `BLOCKED: cannot_post_to_thread`
- HQ/runtime may perform the real thread send only where the workflow explicitly assigns that step to HQ rather than the executor
- provenance must remain visible/truthful:
  - keep executor text separate from HQ acceptance text
  - preserve provenance in task notes / status updates
  - do not pretend the executor used native/direct capability when they actually used a sanctioned assisted/standard path

This is now a workspace execution rule, not an optional convention.

### A. Dispatch setup + formal collaboration gate
Primary maintained entrypoints:
- `skills/discord-visible-multiagent/scripts/hq-formal-collab-gate.sh`
- `skills/discord-visible-multiagent/scripts/hq-visible-dispatch-run.sh`

Supporting state helpers remain under `shared/task/state/`.
Detailed helper selection and outputs are documented in `references/helper-routing.md`.

### B. Due-task scanning
Use the due-task helpers documented in `references/helper-routing.md`.
The skill-level rule is that due-task findings, reminder generation, and HQ sync all stay inside the task-state-backed workflow instead of ad hoc follow-up.

### C. HQ sync draft generation
HQ sync remains payload-first + runtime-send + writeback.
Use the helper-routing and role guides for the concrete helper chain.

### D. Executor reminder generation
Executor reminder generation remains part of the tracked task-state workflow.
Use the helper-routing reference for the maintained helper path and writeback rule.

### D.1 sessions_send selector hard gate (critical)
When a helper or DB record has already resolved an exact `executor_session_key`, that key becomes the only allowed logical selector for the runtime handoff/reminder send.

Hard rules:
- `label` is not a free-form note field, not a tracing tag, and not a comment slot
- do not pass both `sessionKey` and any non-whitespace `label`
- when exact `executor_session_key` is available, do not substitute it with label-based targeting
- do not invent placeholder labels like `formal-handoff-r1`
- do not copy the same session identifier into both fields
- for the current verified runtime send shape, the only allowed `label` value is a single whitespace placeholder: `" "`
- for formal handoff/reminder, do not handcraft `sessions_send`; use the helper-produced exact runtime shape only
- before any live formal handoff send, use `scripts/hq-handoff-send-plan.sh` as the single validated entrypoint
- after a real successful formal handoff send, write back `executor_handoff`

Required behavior:
- prefer the exact resolved selector path only
- prefer a helper-produced tool-call shape that uses `sessionKey` plus the verified whitespace-label placeholder
- if the current runtime/tool surface rejects that exact shape, stop and mark the step blocked as a runtime/tooling boundary issue
- do not "try a few combinations" interactively at send time
- treat `references/runtime-send-contracts.md` as the machine-level authority for exact send shapes

This is a hard workflow gate because repeated selector misuse creates false negatives that look like collaboration failures but are actually HQ-side calling errors.

### E. Runtime-send writeback
Real `hq_sync`, `executor_reminder`, and `executor_handoff` sends must be written back so state/history stays truthful.
Use the concrete writeback helper path documented in `references/helper-routing.md`.

### F. Handoff readiness + formal executor handoff
Maintained entrypoints:
- `skills/discord-visible-multiagent/scripts/hq-collab-handoff-ready.sh`
- `skills/discord-visible-multiagent/scripts/hq-executor-handoff-helper.sh`
- `skills/discord-visible-multiagent/scripts/hq-handoff-send-plan.sh`

Detailed helper sequencing and writeback steps are documented in `references/helper-routing.md`.

### G. HQ follow-up / close decision helper
Maintained entrypoint:
- `skills/discord-visible-multiagent/scripts/hq-followup-close-helper.sh`

Use the role guides and review guide for detailed acceptance / next-round / close behavior.

#### Core rule
The message for a given execution step must be sent by the **correct actor** for that step:
- executor-step result → sent by the assigned executor
- HQ dispatch / HQ next-round instruction / HQ acceptance → sent by HQ

HQ or another executor must **not** substitute for the assigned executor when the workflow expects the executor to send.

#### Allowed standard send paths
For executor thread delivery in this workspace, the standard allowed paths may include:
- workflow-recognized native messaging/direct-post paths, when available
- `openclaw message send`
- `openclaw message thread reply` when appropriate for the target surface

These are acceptable only when the send action is performed by the correct actor/session for that step.

#### What remains forbidden
The problem is no longer “CLI exists”, but “uncontrolled path / wrong sender / untraceable bypass”.
So the workflow must still forbid:
- ad hoc, self-invented shell/CLI bypasses not explicitly sanctioned by the skill/helper
- HQ sending a message that should have been sent by the executor
- one executor sending in place of another executor
- provenance-obscuring wording that falsely claims a different sender performed the action

#### Direct post vs standard CLI path
`direct-post` may still be used as a descriptive distinction, but it is **not** the hard gate for workflow validity.
The hard gate is:
- did the correct actor send the message, and
- did they use a skill-recognized standard path?

If yes, the workflow may continue.

This is now the workspace execution rule.

## Required execution sequence for formal tasks
### Dispatch
1. enter the formal collaboration gate first for tracked tasks
2. create task first and obtain `task_id` / `thread_name`
3. run `skills/discord-visible-multiagent/scripts/hq-visible-dispatch-run.sh` to create thread + post visible `[R1]` + write back `ACTIVE`
4. run handoff readiness check
5. only then obtain/send formal executor handoff payload
6. executor-round messages must be sent by the executor itself through a skill-recognized standard path; HQ may not substitute for the executor

### Next-round advance
Only continue when all three are true:
1. previous-round visible result exists in thread
2. HQ received explicit notify
3. HQ has read the real result and generated the next instruction from it

### Reminder / sync path
1. due-task checker identifies due task
2. helper generates sync/reminder payload
3. runtime performs real send
4. send action is written back

## State model guidance
Prefer the live `tasks.db` state model and maintained helper docs over stale abstract ladders.
Concrete state details remain available through the task-state references and helper docs.

## What belongs in the skill vs docs
### Skill = execution gate and primary workspace authority
Keep in the skill:
- collaboration hard rules
- current machine capability boundaries
- mandatory execution model
- authoritative helper-chain order for this workspace
- the hard gate that formal executor handoff is invalid before visible writeback

### References / docs = detailed supplement only
Use references and workflow docs for:
- detailed helper selection
- SOP expansion
- long examples and templates
- implementation notes

They expand the skill, but must not replace it as execution authority.

## Boundary note
This skill governs collaboration workflow plus the verified task-state/runtime execution boundary for this workspace.
It does **not** govern:
- Discord platform deployment/permissions
- low-level OpenClaw internals
- unrelated single-agent tasks

## Sync note
If drift is found:
1. trust the canonical shared workflow first
2. then trust this skill as the workspace execution gate
3. then update workspace docs so supplements match the maintained execution path
