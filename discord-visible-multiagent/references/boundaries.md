# Skill Boundaries (v3)

## In Scope
- HQ → executor channel dispatch with v3 thread/round conventions
- Executor multi-turn with R15 hard cap
- HQ quality acceptance loop (executor "完成" ≠ acceptance)
- Explicit sessions_send fallback
- Visible, traceable cross-channel collaboration flow
- Round counter maintenance (HQ as sole authority)
- Provenance-based inter_session message handling

## Out of Scope
- Scripts/automation (references-only)
- Hidden implicit context sync across channels
- Forcing one rigid REVIEW final format
- Platform-level Discord permission/deployment design
- OpenClaw internal routing mechanisms

## v3-Specific Boundary Rules
- **R16 is absolutely forbidden.** R15 = forced close signal.
- Executor "完成" ≠ acceptance. HQ must formally accept.
- Thread subject update is best-effort; sessions_send fallback always valid.
- Round increment is HQ's sole responsibility; executor must echo round tag.
- Quality challenge + revision is a normal loop iteration, not a failure state.
- Three hard prerequisites before next round: thread visible + explicit notify + HQ read.
- Do not use backticks around dynamic values in shell commands (command injection risk).
- sessions_send timeout does NOT mean message failed; always verify actual delivery.

## Collaboration Boundary Rules
- Keep private/sensitive data out of broad channels unless explicitly approved.
- Share only task-relevant context during handoff.
- Preserve traceability: TASK-ID, round tag, thread subject, HQ acceptance signal.
