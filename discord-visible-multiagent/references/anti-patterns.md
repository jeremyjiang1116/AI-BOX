# Required Anti-Patterns (v3 — Must Avoid)

## Thread & Round Naming
1. **Skip thread subject** or use wrong format — must follow `<任务ID>-<任务名>-<子任务阶段>`.
2. **Omit `[Rx]` round tag** on messages — round must be visible on every thread message.
3. **Allow R16 or higher** — R15 hard cap is absolute under all circumstances.

## Quality & Acceptance
4. **Treat executor "完成" as closing signal** — only HQ `验收通过` closes the task.
5. **Accept output without verifying** goal attainment and output contract compliance.
6. **Skip quality challenge** when output is substandard — must `[R+1]` with specific revision request.
7. **Advance to next round without reading actual thread result** — three prerequisites must all be met.

## Round Governance
8. **Let executor increment rounds independently** — HQ is sole authority on round counter.
9. **Exceed user-specified round cap** without escalation.
10. **Forget to increment or miscount rounds** — round errors break the cap mechanism.

## Dispatch & Context
11. **Dispatch vague tasks** without TASK-ID, objective, constraints, or output contract.
12. **Mix unrelated tasks in one thread** without TASK-ID separation.
13. **Assume cross-channel implicit memory** is shared automatically.
14. **Skip HQ sync-back** after executor completion or cap hit.

## sessions_send / Thread Fallback
15. **Block task progress waiting for thread subject confirmation** — use sessions_send fallback immediately.
16. **Treat sessions_send timeout as delivery failure** — timeout ≠ actual failure; verify delivery.
17. **Use backticks around dynamic values** in shell commands — risk of command injection.

## Thread Posting (v3 Specific)
18. **没有用显式 CLI 命令发 thread 消息**，只在 session 里写结果 — Discord session 不自动同步 thread 内容，必须用 `openclaw message send --target "<THREAD-ID>"` 显式发帖。
19. **Thread target 格式错误**（如加 `thread:` 前缀）— Discord target 直接用 thread ID，不加任何前缀。

## Anti-Patterns from v1/v2 Still Valid
20. **Dump full raw process logs** to HQ instead of distilled outcome.
21. **Expand scope to scripts/** in references-only version.
22. **Force one rigid REVIEW final format.**
23. **Treat "visible" as "automatically synchronized."**
24. **Treat HQ notification as thread result** — must read thread to confirm.
