# Required Anti-Patterns (v4 — Must Avoid)

Canonical source: `$HOME/.openclaw/shared/artifacts/discord-visible-multiagent/references/anti-patterns.md`
Workspace supplements:
- `docs/workflows/task-state-discord-integration.md`
- `docs/workflows/task-state-mvp-v1.md`
- `docs/workflows/runtime-send-writeback.md`

## Workflow Gate Failures
1. **Skip the skill-first gate** for formal Discord multi-agent collaboration.
2. **Classify a formal multi-role task by content type first** (search/coding/debug) instead of first deciding whether it must enter the collaboration workflow.
3. **Skip task creation** for a formal tracked task before visible dispatch.
4. **Skip visible dispatch** and hand off to executor first.
5. **Treat payload generation as real execution** — helper output is not the same as real send.
6. **Treat docs/workflows helper docs as a second source of truth** instead of following the skill + canonical workflow.

## Thread & Round Governance
7. **Skip thread subject** or use the wrong format.
8. **Omit `[R<n>]` round tag** on visible thread instructions/results.
9. **Allow R16 or higher** — R15 hard cap is absolute unless the user explicitly changes it in advance.
10. **Let executor increment rounds independently** — HQ is sole authority on round counter.
11. **Forget to increment or miscount rounds** — round errors break the cap mechanism.

## Dispatch & Handoff Errors
12. **Dispatch vague tasks** without `task_id`, objective, constraints, or output contract.
13. **Send to executor before thread + visible `[R1]` are ready**.
14. **Fail to write back `thread_id` / `hq_message_id` / ACTIVE** after real dispatch.
15. **Bypass the formal handoff gate** by constructing executor handoff ad hoc instead of using readiness-checked helper flow.
16. **Assume cross-channel implicit memory** is automatically shared.
17. **Mix unrelated tasks in one thread** without clear `task_id` separation.

## Review & Acceptance Errors
18. **Treat executor "完成" as closing signal** — only HQ acceptance closes the task.
19. **Accept output without verifying** goal attainment and output-contract compliance.
20. **Advance to next round without reading actual previous-round result**.
21. **Skip quality challenge** when output is substandard.
22. **Let the task enter a black hole with no HQ-visible sync-back**.

## Runtime Boundary Errors
23. **Assume shell helpers are the authoritative real-send layer**.
24. **Assume helper-generated reply/target hints guarantee direct-send capability**.
25. **Pretend HQ sync is fully automated** when it is actually runtime-send + writeback.
26. **Pretend executor reminder is complete without actual `sessions_send`**.
27. **Send real messages but do not write them back to DB**.
28. **Prefer a stale abstract state ladder over the live SQLite-backed task-state flow**.

## sessions_send / Delivery Errors
29. **Treat `sessions_send` timeout as delivery failure** — verify actual delivery.
30. **Treat internal notify as a substitute for visible thread result**.
31. **Block task progress forever waiting for perfect thread visibility** when fallback logic is available.

## Shell Safety Errors
32. **Use backticks around dynamic values** in shell commands.
33. **Assume dynamic IDs/values are safe to interpolate without care**.

## Reporting Errors
34. **Dump raw process logs** to HQ instead of distilled status.
35. **Fail to preserve traceability** (`task_id`, round, executor, visible anchor, HQ decision).
36. **Report progress based on prompt/config text only** instead of actual observed behavior.
