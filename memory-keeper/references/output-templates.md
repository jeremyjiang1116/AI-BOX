# Memory Keeper Output Templates

Use these templates when proposing durable-memory changes.
Adjust wording to fit the task, but preserve the decision structure.

## Template A — incremental long-term update proposal

Use for:
- adding one new durable rule;
- revising one existing rule;
- merging one or a few overlapping rules;
- placing a stable preference in the correct file.

### Classification
- durable or temporary:
- recommended layer:
- target file:
- target section:
- change type: add / modify / merge / replace / delete / move

### Why this layer
- why this file is the correct owner:
- why nearby candidate files are less correct:

### Redundancy / placement check
- overlapping existing content:
- duplicate risk:
- better as merge/modify than append: yes / no
- placement decision:

### Proposed wording
- exact proposed text:

### Optional variant
- shorter / stronger version if useful:

### Approval
- ask for explicit approval before writing the long-term file.

---

## Template B — long-term update proposal with neighboring-file explanation

Use when the boundary is non-obvious and the user may reasonably ask why the content is not going into another long-term file.

### Classification
- content type:
- durability judgment:
- recommended target:

### File-choice reasoning
- why it belongs in `<target file>`:
- why it does not belong in `<neighbor file 1>`:
- why it does not belong in `<neighbor file 2>`:

### Existing overlap
- relevant nearby entries reviewed:
- action chosen: add / modify / merge / replace

### Proposed wording
- exact proposed text:

### Approval
- request approval before writing.

---

## Template C — section cleanup proposal

Use for:
- cleaning one section;
- de-duplicating a local cluster of rules;
- improving wording consistency inside a section.

### Scope
- target file:
- target section:
- reason cleanup is needed:

### Audit summary
- keep:
- merge:
- delete:
- move:
- stale / weak entries:

### Proposed section strategy
- what will stay:
- what will be rewritten:
- what will be removed:
- whether surrounding wording needs adjustment:

### Proposed replacement text
- exact replacement block or exact edits:

### Approval
- ask for approval before editing the live file.

---

## Template D — whole-file structural refresh proposal

Use for:
- `MEMORY.md` / `AGENTS.md` / `USER.md` / `SOUL.md` becoming messy, stale, duplicated, or poorly layered.

### Why refresh is needed
- symptoms:
- why incremental patching is no longer the cleanest path:

### Audit summary
- keep:
- merge:
- delete:
- move to other files:
- externalize to skill/docs:
- stale or obsolete content:

### Proposed file structure
- sections to keep:
- sections to add:
- sections to remove:
- main structural changes:

### Draft / replacement plan
- whether to create a candidate draft first:
- whether to back up the original file:
- whether to keep a mapping review:

### Approval
- ask for approval before replacing or restructuring the live file.

---

## Template E — cross-layer redistribution proposal

Use when material exists, but its current file ownership is wrong.

### Problem
- current file:
- why current ownership is wrong:

### Redistribution plan
- content staying in place:
- content moving to another long-term file:
- content moving to `.learnings`:
- content moving to skill/docs:
- content being deleted as stale:

### Why this improves layering
- brief explanation:

### Proposed wording / resulting changes
- exact text for each destination when needed:

### Approval
- ask for approval before applying the redistribution.

---

## Template F — post-write report for long-term edits

Use after the user has approved and the edit is complete.
This should match the workspace’s long-term notification discipline.

### File
- `<file path>`

### Change type
- add / modify / merge / replace / delete / move

### Exact content added or changed
- summarize concretely
- include the exact new rule or the exact class of structural change

### Why it belongs here
- explain why this file/layer is the correct long-term owner

### Commit
- `<commit id>`

---

## Template G — obsolete draft retirement proposal

Use when a candidate draft file has already served its purpose and the approved content is now reflected in the live file.

### Current file set
- live file:
- backup:
- mapping review / audit artifact:
- obsolete draft candidate:

### Recommendation
- keep:
- delete:

### Why
- explain why deleting the draft improves clarity without losing necessary traceability.

### Approval
- ask for approval before deleting the draft file if required.

---

## Template H — no-write recommendation

Use when the correct action is **not** to write to a long-term file.

### Judgment
- long-term write recommended: no

### Why not
- too temporary / too incident-specific / already covered / better suited elsewhere / insufficiently stable

### Better destination
- `.learnings` / daily memory / `SESSION-STATE.md` / skill/docs / no write yet

### Optional next step
- what should happen instead:

---

## Style notes for all templates

- Be explicit about layer choice.
- Be explicit about section choice.
- Prefer exact proposed wording over vague summaries when asking approval.
- If merge/modify is better than append, say so directly.
- If the best action is no long-term write, say that plainly instead of forcing a memory update.
- For structural refreshes, prefer audit summary + replacement plan over piecemeal patch language.
- For major refreshes, remember backup / mapping-review / obsolete-draft decisions as part of the proposal.