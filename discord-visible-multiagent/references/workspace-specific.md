# Workspace-Specific Assumptions

Use this reference when adapting `discord-visible-multiagent` outside the original Jeremy/OpenClaw workspace.

## Portable core

The portable contract is:
- HQ creates and owns the tracked task lifecycle.
- HQ posts visible round anchors before executor handoff.
- Executor posts executor-owned results in the tracked thread.
- Executor sends a fixed same-thread notify after the result lands.
- HQ verifies visible evidence before advancing, accepting, or closing.
- Scripts should read task state from a SQLite database through `TASK_DB_PATH` or the default workspace layout.

## Default local layout

Helpers infer paths from the script location unless environment variables override them:

```text
OPENCLAW_WORKSPACE_ROOT=<repo-or-workspace-root>
TASK_DB_PATH=$OPENCLAW_WORKSPACE_ROOT/shared/task/state/tasks.db
OPENCLAW_AGENTS_ROOT=$HOME/.openclaw/agents
```

Task-state helper scripts are expected under:

```text
$OPENCLAW_WORKSPACE_ROOT/shared/task/state/
```

Examples:
- `create-task.sh`
- `hq-dispatch-helper.sh`
- `update-task-status.sh`
- `record-runtime-send.sh`
- `executor-reminder-helper.sh`
- `hq-sync-draft-helper.sh`
- `hq-due-task-checker.sh`

## Original workspace mirrors

The original workspace also has implementation notes under:

```text
docs/workflows/
$HOME/.openclaw/shared/tasks/TASK-TRUE-MULTIROUND-WORKFLOW.md
```

These are not required public files in this repository. Treat them as local mirrors/supporting notes; the packaged public contract lives in `SKILL.md` and `references/`.

## Portable test mode

Regression scripts create temporary fixture workspaces and synthetic task IDs by default. They should not require real Jeremy historical task IDs or the user's live `tasks.db`.

Use these environment variables only when intentionally testing against another layout:

```bash
TASK_DB_PATH=/path/to/tasks.db
OPENCLAW_WORKSPACE_ROOT=/path/to/workspace
OPENCLAW_AGENTS_ROOT=/path/to/agents
```
