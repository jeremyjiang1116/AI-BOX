---
name: memory-keeper
description: Govern durable memory layers for this workspace. Use when the user wants to remember something, place a long-term rule in the correct file, revise or merge existing memory, clean up or refactor AGENTS/MEMORY/USER/SOUL, audit a long-term file for duplication or staleness, stage a draft-first replacement of a memory layer, capture a durable lesson, or decide which long-term layer should own new information. This skill reads the relevant files first, checks ownership and overlap, proposes exact wording or a structural refresh plan in the target file’s house style, and asks for approval before high-impact long-term changes.
---

# Memory Keeper

Use this skill when the task is not merely to "write something down," but to decide **whether it belongs in long-term memory, which layer should own it, how it should be phrased, how to keep long-term files clean over time, and how to avoid polluting the wrong file**.

This skill is the default entry for durable-memory governance in this workspace.

## What this skill governs

This skill governs durable-memory decisions across:
- `USER.md`
- `SOUL.md`
- `AGENTS.md`
- `MEMORY.md`
- `.learnings/*`
- `memory/YYYY-MM-DD.md`
- `SESSION-STATE.md`
- skill/docs escalation when a repeatable workflow should be formalized outside memory files

It is for:
- memory classification;
- target-file selection;
- exact wording proposal;
- redundancy / merge / placement analysis;
- approval-first long-term writing;
- staged cleanup of long-term files;
- structural refresh of `AGENTS.md`, `MEMORY.md`, `USER.md`, or `SOUL.md`;
- keep / merge / delete / move audits;
- draft-first replacement workflows;
- backup / mapping-review discipline for major refreshes.

It is **not** for blindly appending a note because the user said “remember this.”

## Trigger conditions

Use this skill when the user says things like:
- “remember this”
- “write this into memory”
- “put this in AGENTS”
- “add this to MEMORY”
- “write this to USER / SOUL”
- “make this a long-term rule”
- “solidify this”
- “we should always do it this way”
- “capture this lesson”
- “this should become permanent”

Also use it when the user does **not** explicitly say “remember,” but the conversation is clearly producing:
- a long-term workflow rule;
- a recurring review standard;
- a stable routing rule;
- a durable user preference;
- a reusable collaboration convention;
- a lasting lesson from a mistake or incident;
- a file-ownership or memory-layering decision;
- a signal that a long-term file has become messy, stale, duplicated, bloated, or poorly layered.

## Core goal

Maintain a **clean, durable, correctly layered memory system** for this workspace.

For small tasks, produce the **smallest correct durable-memory change** in the **right file**, with the **right wording**, after checking the existing file first and before making long-term writes.

For larger maintenance tasks, produce the correct **audit → draft → approval → replacement** workflow so that long-term files become cleaner, more current, and easier to maintain over time.

## Default execution chain

When in doubt, follow this default chain:
1. classify durability and information type;
2. choose the most likely owning layer and neighboring candidate layers;
3. read the target file/section and any needed neighboring files;
4. check overlap, duplication, merge-vs-append, and section placement;
5. decide whether this is an incremental update or a structural refresh;
6. draft exact wording or a refresh plan in the file’s house style;
7. ask for approval before long-term changes;
8. only then write, report, and clean up obsolete draft artifacts if needed.

## Working modes

### Mode 1 — incremental update
Use when the task is a small or medium durable-memory change such as:
- adding a new rule;
- revising an existing rule;
- merging overlapping wording;
- capturing a durable lesson;
- placing a stable preference in the right layer.

Default process:
1. classify the information;
2. inspect the likely target file and section;
3. check for overlap, duplication, and better placement;
4. draft exact wording in the file’s house style;
5. ask for approval;
6. then write and report.

### Mode 2 — structural refresh
Use when the task is to clean up, modernize, de-duplicate, or re-layer a long-term file.

Typical triggers:
- “this file is getting messy”
- “clean up MEMORY.md”
- “refactor AGENTS.md”
- “audit what should stay vs move”
- “this long-term file has stale or duplicated rules”

Default process:
1. read the whole target file or all relevant sections;
2. classify entries into keep / merge / delete / move / stale / externalize;
3. identify which content belongs in neighboring files or skill/docs;
4. produce an audit report;
5. produce a candidate replacement draft or replacement plan;
6. get approval;
7. back up the original file when the change is high-impact;
8. replace or restructure the live file;
9. keep a mapping/audit record when useful;
10. remove obsolete draft artifacts when the live file has absorbed them and traceability is still preserved.

## Non-negotiable rules

### 1. Classify before writing
Never treat “remember this” as automatic permission to append to `MEMORY.md`.

First decide:
- is this durable or temporary?
- is it a rule, preference, lesson, environment fact, active task detail, or raw event?
- which layer should own it?

### 2. Read before write
Before proposing any long-term edit, read the relevant target file section first.

If placement is unclear, read the candidate neighboring files too.
Do not draft from memory or from impression alone.

Minimum expectation:
- read the target section;
- read nearby entries that may overlap;
- if boundary is unclear, read the neighboring candidate file(s) before deciding.

### 3. Understand house style first
Before drafting, determine the target file’s:
- language;
- abstraction level;
- sentence style;
- section structure;
- information density;
- duplication tolerance.

If you do not yet understand the file’s house style, do not produce final proposed wording.

### 4. Necessity test before long-term writes
Before proposing a long-term write, ask:
- is this truly long-term?
- will it matter across tasks or over time?
- is it stable enough to be promoted now?
- is it actually a one-off incident or temporary state?
- does it belong in a long-term layer, or only in `.learnings`, daily memory, or `SESSION-STATE.md`?

Do not promote unstable or one-off material into durable memory just because it sounds important in the moment.

### 5. Prefer the narrowest correct layer
Do not dump everything into `MEMORY.md`.

Choose the narrowest correct owner:
- user preference / collaboration preference → `USER.md`
- assistant philosophy / identity / behavioral stance → `SOUL.md`
- execution rules / gates / operating discipline → `AGENTS.md`
- shared long-term rules / environment facts / durable collaboration conventions → `MEMORY.md`
- incident detail / correction case / failure postmortem → `.learnings/*`
- raw recent event / unstable note → `memory/YYYY-MM-DD.md`
- active task dependency → `SESSION-STATE.md`
- formal repeatable workflow → skill/docs/canonical workflow, with memory only keeping the high-level rule when needed

### 6. Prefer modify/merge over append
Default assumption: the correct change is often **not** “add one more bullet.”

Check whether the new material should instead:
- modify an existing rule;
- merge into an existing rule;
- replace an outdated rule;
- delete a stale rule;
- restructure a section.

Only add a brand-new entry when the content is genuinely new and non-overlapping.

### 7. Placement is part of the decision
Choosing the file is not enough.
You must also decide:
- which section should own the content;
- where inside that section it best fits;
- whether adjacent wording should be adjusted to avoid drift or duplication.

### 8. Respect canonical ownership
If a detailed workflow already has a canonical home in a skill, workflow doc, or source-of-truth document, do not copy the entire implementation detail into long-term memory files.

Instead:
- keep the detailed mechanics in the canonical layer;
- store only the high-level rule, durable lesson, or pointer in memory when needed.

### 9. Approval-first for long-term writes
For `AGENTS.md`, `MEMORY.md`, `USER.md`, and `SOUL.md`, default behavior is:
1. classify;
2. inspect target file;
3. propose exact wording;
4. ask for approval;
5. only then write.

Do not perform silent long-term writes unless the user explicitly asked for immediate application after seeing the wording strategy.

### 10. Audit before structural changes
If the task is not a small local addition but a structural change—such as cleanup, reorganization, consolidation, or de-duplication—do not patch the live file first.

Instead:
1. audit current content;
2. identify keep / merge / delete / move candidates;
3. produce a candidate draft or replacement plan;
4. get approval;
5. then apply changes.

### 11. Structural refresh is a first-class operation
This skill is not only for adding memory. It also governs:
- staged cleanup;
- de-duplication;
- re-layering;
- targeted section refreshes;
- whole-file refreshes of long-term memory files.

### 12. Preserve traceability for major refreshes
When a long-term file is being substantially refreshed, explicitly evaluate whether to keep:
- a backup of the original file;
- a mapping review / audit record;
- a candidate draft artifact before replacement.

Preserve enough traceability to explain what changed and why, but do not keep unnecessary parallel files forever.

### 13. Remove obsolete drafts after promotion
When a draft file has served its purpose and the approved content is already reflected in the live long-term file:
- evaluate whether the draft should be deleted;
- prefer a clean final file set;
- keep only the minimum useful traceability artifacts.

## File-by-file house style guide

### General language rule
Long-term memory files (`USER.md`, `MEMORY.md`, `AGENTS.md`, `SOUL.md`, `IDENTITY.md`) should follow the target workspace's existing language and house style. In Chinese-first workspaces, write Chinese by default. Keep exact English where precision matters: commands, code, paths, file names, config keys, tool names, model/provider names, protocol tokens, and quoted trigger phrases.

### `MEMORY.md`
Purpose:
- shared long-term collaboration rules;
- stable environment facts that affect future decisions;
- operational preferences that remain true over time;
- durable lessons worth keeping at a high level.

Style:
- follow the target workspace's existing language; use Chinese by default in Chinese-first workspaces;
- preserve exact English tokens for commands, paths, file names, tool names, skill names, identifiers, and phrases that must match runtime behavior;
- concise, high-signal bullets;
- higher-level than `AGENTS.md`;
- avoid implementation minutiae;
- avoid incident-detail timelines;
- avoid duplicating detailed canonical workflows.

Usually wrong for `MEMORY.md`:
- long execution procedures;
- detailed recovery sequences;
- one-off incident chains;
- highly volatile version-specific trivia unless it repeatedly affects decisions.

### `AGENTS.md`
Purpose:
- operating rules;
- execution gates;
- runtime discipline;
- sequencing, fallback, and verification behavior.

Style:
- can be more procedural and explicit than `MEMORY.md`;
- can include sections, numbered rules, and operational checklists;
- still avoid stuffing it with raw case-by-case logs.

Usually wrong for `AGENTS.md`:
- pure user-profile information;
- identity/philosophy statements better suited to `SOUL.md`;
- temporary task notes.

### `USER.md`
Purpose:
- stable user preferences;
- collaboration style;
- communication preferences;
- persistent constraints;
- durable working preferences.

Style:
- profile-like;
- compact;
- preference-focused;
- avoid overfitting one isolated incident into a permanent trait.

Usually wrong for `USER.md`:
- assistant execution rules;
- workflow mechanics;
- debugging procedures;
- implementation details.

### `SOUL.md`
Purpose:
- assistant identity;
- values;
- behavioral philosophy;
- interpersonal stance.

Style:
- principle-oriented;
- identity/behavioral rather than procedural;
- not a runbook.

Usually wrong for `SOUL.md`:
- channel routing rules;
- command-level procedures;
- operational debugging discipline.

### `.learnings/*`
Purpose:
- postmortems;
- correction cases;
- important failures;
- concrete lessons discovered through execution.

Style:
- can be more concrete and incident-specific;
- preserve what happened, why it matters, and what to do differently next time;
- not the final resting place for stable long-term rules.

If a lesson becomes broadly reusable, promote the stable part upward.

### `memory/YYYY-MM-DD.md`
Purpose:
- recent raw notes;
- daily happenings;
- observations not yet promoted;
- unstable or not-yet-distilled material.

### `SESSION-STATE.md`
Purpose:
- active task continuity only;
- minimal short-lived state needed to continue safely.

Do not use it as long-term storage.

## Default classification logic

### Put it in `USER.md` when it is:
- a stable user preference;
- a collaboration preference;
- a response-style preference;
- a recurring tolerance or intolerance;
- a durable constraint.

### Put it in `SOUL.md` when it is:
- about who the assistant should be;
- how the assistant should relate to the user;
- a stable behavioral philosophy;
- an identity-level principle rather than a workflow rule.

### Put it in `AGENTS.md` when it is:
- an execution gate;
- an operational workflow rule;
- a verification or fallback discipline;
- a runtime sequencing rule;
- a tool-usage constraint;
- a “how to operate” rule.

### Put it in `MEMORY.md` when it is:
- a shared long-term rule between user and assistant;
- a durable collaboration convention;
- a stable environment fact worth retaining;
- a long-term architectural preference;
- a durable lesson that should remain high-level.

### Put it in `.learnings/*` when it is:
- a concrete incident;
- a correction case;
- a failed attempt worth preserving;
- a postmortem or reusable case study.

### Put it in a skill/docs when it is:
- a repeatable formal workflow;
- a source-of-truth operating procedure;
- detailed mechanics that will be referenced repeatedly;
- something too detailed or too canonical for memory files.

## Preflight checklist before drafting

Before proposing wording, explicitly check:
1. What is the correct layer?
2. What exact file should own it?
3. Which section should own it?
4. What existing entries overlap?
5. Is the best action add, modify, merge, replace, delete, or move?
6. Is the content already covered elsewhere?
7. If covered elsewhere, is a pointer enough?
8. Does the wording match the file’s actual style?
9. Is this stable enough for the chosen layer?
10. Does the user need to approve the exact wording first? (For long-term files, usually yes.)

## Default response template

When proposing a durable-memory change, default to this structure:

### Classification
- durable or temporary
- recommended layer
- target file
- target section
- change type

### Why this layer
- brief explanation of why this file is the correct owner
- brief explanation of why neighboring files are less correct

### Redundancy / placement check
- overlapping existing content
- whether merge/modify is better than append
- section placement decision

### Proposed wording
- exact proposed text
- optional shorter / stronger variant if useful

### Approval
- ask for explicit approval before writing long-term files

## Structural refresh patterns

### Pattern 1 — one-rule cleanup
Use when a single rule is present but weak, duplicated, outdated, or misplaced.

Typical action:
- revise it;
- merge it into a nearby rule;
- move it to the correct file;
- delete the stale version.

### Pattern 2 — section cleanup
Use when one section has drifted into duplication, stale wording, or poor layering.

Typical action:
- read the full section;
- identify keep / merge / delete / move candidates;
- propose a cleaned section draft before editing live content.

### Pattern 3 — whole-file refresh
Use when a long-term file has become messy enough that patching it line-by-line is no longer the cleanest path.

Typical action:
- audit the full file;
- classify entries;
- produce a candidate replacement draft;
- back up the original;
- replace only after approval.

### Pattern 4 — cross-layer redistribution
Use when a file contains material that belongs in other long-term layers or in skill/docs.

Typical action:
- identify content that should move to `USER.md`, `SOUL.md`, `AGENTS.md`, `.learnings`, daily memory, or skill/docs;
- keep only the right abstraction layer in the original file;
- move or rewrite with explicit rationale.

## Reference material

When helpful, read:
- `references/examples.md` for concrete pattern anchors covering layer selection, wording style, merge-vs-append decisions, and structural refresh behavior.
- `references/output-templates.md` for proposal/report templates covering incremental updates, file cleanup, whole-file refreshes, redistribution, no-write recommendations, and post-write reporting.
- `references/eval-prompts.md` for lightweight evaluation prompts covering target-layer judgment, boundary cases, no-write cases, structural refresh triggers, and approval-first response shape.

Use the examples, templates, and eval prompts to improve judgment and consistency, not as rigid copy-paste outputs.

## Final rule

The goal is not to “remember more.”
The goal is to maintain a **clean, durable, correctly layered memory system** that matches this workspace’s actual house style, keeps long-term files useful instead of bloated, and supports both precise incremental updates and staged structural refreshes over time.