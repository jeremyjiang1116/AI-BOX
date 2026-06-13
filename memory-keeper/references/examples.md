# Memory Keeper Examples

Use these examples as pattern anchors, not rigid templates.
The goal is to improve layer selection, wording style, and cleanup judgment.

## Example 1 — User preference belongs in `USER.md`

### Situation
The user says they prefer concise answers, want direct conclusions first, and dislike repetitive wording.

### Correct target
- `USER.md`

### Why
This is a stable collaboration preference belonging to the user profile, not an assistant operating manual and not a shared environment fact.

### Good shape
- Default preference: concise answers with the conclusion first; avoid repetitive wording unless the user explicitly asks for expansion.

### Usually wrong
- Writing this into `MEMORY.md` as a general collaboration rule.
- Writing this into `AGENTS.md` as if it were a runtime sequencing rule.

---

## Example 2 — Execution gate belongs in `AGENTS.md`

### Situation
A recurring failure shows that high-impact changes should not jump from related research directly into write actions. The correct path is target confirmation, impact audit, and recovery-path thinking before modification.

### Correct target
- `AGENTS.md`

### Why
This is an execution gate and operating discipline rule. It affects how the assistant should act during risky tasks.

### Good shape
- High-impact changes must not jump from related research directly into write actions. Before modifying core configuration, key plugins, or memory infrastructure, confirm the exact target, audit likely impact, and understand the recovery path.

### Usually wrong
- Writing the full incident chain into `AGENTS.md`.
- Writing only the concrete failed command instead of the reusable rule.

---

## Example 3 — Shared high-level rule belongs in `MEMORY.md`

### Situation
The user and assistant form a durable cross-task rule that long-term workflows should not remain only in conversation and should be promoted into the correct long-term layer or skillized when mature.

### Correct target
- `MEMORY.md`

### Why
This is a shared long-term collaboration rule, not just a user preference and not just an execution procedure.

### Good shape
- Long-term workflows, routing rules, review standards, and decision frameworks must not remain only in chat context or daily memory; promote them into the proper long-term layer, and skillize them when they become repeatable.

### Usually wrong
- Writing procedural substeps better suited to `AGENTS.md`.
- Writing a one-off reminder in daily memory and stopping there.

---

## Example 4 — Identity / behavioral philosophy belongs in `SOUL.md`

### Situation
A stable principle is formed that the assistant should be genuinely helpful rather than performatively helpful, and should prioritize signal over filler.

### Correct target
- `SOUL.md`

### Why
This is identity and behavioral philosophy, not a narrow workflow rule.

### Good shape
- Be genuinely helpful, not performatively helpful.
- Prefer high information density over filler.

### Usually wrong
- Writing this into `USER.md` as if it were a user preference.
- Writing this into `AGENTS.md` as a command-level procedure.

---

## Example 5 — Incident detail belongs in `.learnings/*`

### Situation
A bad diagnosis leads to an unsupported config key being added, which breaks validation. The incident produces a reusable lesson and should be preserved as a case.

### Correct target
- `.learnings/*`

### Why
The detailed failure chain and correction path are incident material. The stable abstracted rule may later be promoted to `AGENTS.md` or `MEMORY.md`, but the case detail belongs in the learning layer.

### Good shape
- Record what happened, why it failed, what should have been checked first, and what to do differently next time.

### Usually wrong
- Dumping the full failure narrative into `MEMORY.md`.
- Losing the case detail by keeping only a very abstract rule.

---

## Example 6 — Active task dependency belongs in `SESSION-STATE.md`

### Situation
The user provides a specific path, version, URL, ID, or decision that later steps in the current task depend on.

### Correct target
- `SESSION-STATE.md`

### Why
This is active-task continuity, not long-term memory.

### Good shape
- Goal: ...
- Current state: ...
- Critical dependency: ...
- Next step: ...

### Usually wrong
- Writing volatile task details into `MEMORY.md`.
- Trusting chat context alone when the task is still ongoing.

---

## Example 7 — Repeatable workflow belongs in skill/docs, not only memory

### Situation
A Discord multi-agent collaboration workflow gains stable stages, round discipline, and source-of-truth docs.

### Correct target
- canonical workflow / skill / docs first
- possibly `MEMORY.md` for the high-level rule or pointer

### Why
The detailed mechanics are too procedural and canonical for a memory file. Memory should keep only the stable high-level rule or locator when useful.

### Good shape
- In `MEMORY.md`: a high-level rule that formal multi-agent collaboration must enter the canonical workflow first.
- In skill/docs: the detailed round, provenance, and acceptance mechanics.

### Usually wrong
- Copying the entire implementation procedure into `MEMORY.md`.
- Keeping the workflow only in chat or only in `.learnings`.

---

## Example 8 — Incremental update should merge, not append

### Situation
A new lesson is very close to an existing long-term rule and mainly sharpens or modernizes it.

### Correct action
- modify or merge the existing rule

### Why
Long-term files become noisy if every refinement becomes a new bullet.

### Good shape
- Update the existing rule to absorb the stronger wording.

### Usually wrong
- Appending a near-duplicate bullet directly below the original.

---

## Example 9 — Structural refresh needs audit before replacement

### Situation
`MEMORY.md` becomes dense, duplicated, partially stale, and mixes multiple abstraction levels.

### Correct action
- structural refresh mode

### Correct process
1. read the whole file;
2. classify entries into keep / merge / delete / move / stale / externalize;
3. produce an audit report;
4. produce a candidate draft;
5. get approval;
6. back up the original;
7. replace the live file;
8. keep a mapping review when useful;
9. remove obsolete drafts after promotion.

### Usually wrong
- Repeatedly patching the live file without first auditing structure.
- Replacing the file without a backup when the change is large.

---

## Example 10 — Keep only the right abstraction layer in `MEMORY.md`

### Situation
A detailed workflow already has canonical ownership in a skill and source-of-truth docs, but the high-level cross-task rule still matters in memory.

### Correct action
- keep the high-level rule or pointer in `MEMORY.md`
- keep the detailed mechanics in the canonical layer

### Why
This preserves long-term recall without bloating memory files with implementation detail.

### Good shape
- `MEMORY.md`: collaboration-first rule + pointer to canonical workflow.
- skill/docs: full execution mechanics.

### Usually wrong
- Either duplicating everything in both places,
- or deleting the memory-level rule entirely and leaving no high-level reminder.

---

## Example 11 — File-style mismatch should block drafting

### Situation
A proposed rule is about to be added to an English high-level file, but the wording is procedural, overly detailed, and written in a different language from the surrounding section.

### Correct action
- stop and restyle before proposing it as final wording

### Why
House-style mismatch is a real memory-quality problem. A correct concept with the wrong style still degrades the file.

### Usually wrong
- Treating content correctness as enough and ignoring file style.

---

## Example 12 — Approval-first for long-term edits

### Situation
A durable rule has been correctly classified and a good target file has been identified.

### Correct default behavior
- propose the exact wording first;
- explain why it belongs in that file and section;
- ask for approval;
- only then write.

### Why
The user should be able to shape the exact long-term wording before it becomes durable.

### Usually wrong
- Silently writing to `AGENTS.md`, `MEMORY.md`, `USER.md`, or `SOUL.md` before showing the proposed text.