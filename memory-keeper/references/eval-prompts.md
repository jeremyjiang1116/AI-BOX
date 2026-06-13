# Memory Keeper Eval Prompts

Use this file as a lightweight structured evaluation pack.
The goal is not formal benchmarking; it is to sanity-check whether `memory-keeper` selects the correct layer, mode, action shape, and approval behavior.

Each prompt includes the expected judgment shape.
Do not treat the expected answer as a word-for-word output target.

## Eval 1 — Stable user preference

### Prompt
The user says: "以后默认先给我结论，再补必要理由。别重复同一句话。这个是长期偏好，记一下。"

### Expected shape
- target layer: `USER.md`
- mode: incremental update
- action: add or merge into an existing user-preference entry
- approval: yes
- wrong tendencies to avoid:
  - putting it in `MEMORY.md`
  - turning it into an `AGENTS.md` execution rule

---

## Eval 2 — Assistant operating discipline

### Prompt
The user says: "以后遇到高影响改动，不要从看文档直接跳到改配置；先确认目标对象、影响范围和恢复路径。这个写成长期规则。"

### Expected shape
- target layer: `AGENTS.md`
- mode: incremental update
- action: add / merge execution gate
- approval: yes
- wrong tendencies to avoid:
  - storing the whole incident narrative in `AGENTS.md`
  - placing it in `USER.md`

---

## Eval 3 — Shared long-term collaboration rule

### Prompt
The user says: "长期流程别只留在聊天里。成熟后要么写进长期层，要么做成 skill。这个记下来。"

### Expected shape
- target layer: `MEMORY.md`
- mode: incremental update
- action: add or merge high-level collaboration rule
- approval: yes
- wrong tendencies to avoid:
  - writing procedural substeps better suited to `AGENTS.md`
  - leaving it only in daily memory

---

## Eval 4 — Incident detail should not become long-term rule directly

### Prompt
The user says: "这次因为误判配置 schema，结果加了个不支持的 key，导致服务起不来。把这次详细经过记住。"

### Expected shape
- preferred destination: `.learnings/*`
- mode: incremental update
- action: incident capture, possibly with later promotion of the abstracted rule
- approval: yes if writing durable detail into `.learnings`
- wrong tendencies to avoid:
  - dumping the whole incident chain into `MEMORY.md`
  - over-abstracting too early and losing the case

---

## Eval 5 — Active task state, not long-term memory

### Prompt
The user says: "当前任务后面要一直用这个路径：`/workspace/docs/workflows/SOURCE-OF-TRUTH.md`，你先记着。"

### Expected shape
- target layer: `SESSION-STATE.md`
- mode: incremental update
- action: capture active task dependency
- approval: not necessarily required in the same way as long-term files, depending on context
- wrong tendencies to avoid:
  - writing the path into `MEMORY.md`
  - assuming chat context alone is enough

---

## Eval 6 — No-write recommendation

### Prompt
The user says: "今天我临时想试试把回复写得更活泼一点，先这样聊聊，不一定长期都这样。"

### Expected shape
- long-term write recommended: no or not yet
- better destination: no write yet, or daily memory if needed
- mode: incremental judgment
- wrong tendencies to avoid:
  - prematurely writing a stable preference into `USER.md`

---

## Eval 7 — Merge, not append

### Prompt
There is already a rule in `MEMORY.md` saying long-term workflows should be promoted into the right layer. The user adds: "还有，成熟以后尽量 skill 化，不要只在 memory 里堆规则。"

### Expected shape
- target layer: `MEMORY.md`
- mode: incremental update
- action: merge / strengthen existing rule, not append a near-duplicate
- approval: yes
- wrong tendencies to avoid:
  - adding a second bullet that repeats the same concept

---

## Eval 8 — Boundary case: `AGENTS.md` vs `MEMORY.md`

### Prompt
The user says: "以后对正式 workflow 的执行，不要为了省事绕开 skill-first gate。"

### Expected shape
- likely target: `AGENTS.md` if framed as execution discipline
- possible neighboring candidate: `MEMORY.md` if framed as high-level collaboration rule
- required behavior: explain boundary choice explicitly
- approval: yes
- wrong tendencies to avoid:
  - choosing a file without explaining the layer boundary

---

## Eval 9 — Boundary case: `USER.md` vs `SOUL.md`

### Prompt
The user says: "我希望你别太像客服，少套话，直接一点。这个以后都按这个来。"

### Expected shape
- likely target: `USER.md` as user collaboration preference
- possible neighboring candidate: `SOUL.md` if generalized into assistant philosophy
- required behavior: prefer the narrower correct layer unless it is clearly identity-level
- approval: yes
- wrong tendencies to avoid:
  - automatically putting all communication-style rules into `SOUL.md`

---

## Eval 10 — Structural refresh trigger

### Prompt
The user says: "我感觉 `MEMORY.md` 现在越来越乱了，有重复、有过时项、还有层级混杂。你先别直接改，先做审计和候选重构方案。"

### Expected shape
- mode: structural refresh
- target file: `MEMORY.md`
- action: audit first, then draft-first replacement plan
- approval: yes before replacing live file
- traceability expectations:
  - consider backup
  - consider mapping review
- wrong tendencies to avoid:
  - patching the live file immediately

---

## Eval 11 — Cross-layer redistribution

### Prompt
The user says: "这个 `MEMORY.md` 里有不少其实应该去 `AGENTS.md` 或 skill docs，你帮我重新分层，但先给方案。"

### Expected shape
- mode: structural refresh
- action shape: cross-layer redistribution proposal
- target behavior:
  - identify keep / move / externalize / delete candidates
  - explain ownership changes
- approval: yes before writing
- wrong tendencies to avoid:
  - editing one file without considering neighboring owners

---

## Eval 12 — Canonical workflow ownership

### Prompt
The user says: "这个多 agent 协作流程已经有 canonical workflow 了，但我也想让以后不要忘了它的高层原则。帮我记到最合适的地方。"

### Expected shape
- detailed mechanics: skill/docs/canonical workflow remain owner
- high-level rule or pointer: `MEMORY.md` may keep it
- mode: incremental update
- action: high-level pointer/rule only, not full duplication
- approval: yes
- wrong tendencies to avoid:
  - copying the whole canonical process into `MEMORY.md`

---

## Eval 13 — File-style mismatch check

### Prompt
The candidate wording for a new `MEMORY.md` rule is very procedural, long, and written in a different language from the surrounding section.

### Expected shape
- judgment: block final proposal until restyled
- mode: incremental update
- required behavior:
  - recognize house-style mismatch
  - revise wording before presenting it as final
- wrong tendencies to avoid:
  - accepting concept correctness while ignoring style mismatch

---

## Eval 14 — Obsolete draft retirement

### Prompt
A candidate draft file has already been approved, its content is now reflected in the live `MEMORY.md`, and the workspace also retains a backup and mapping review.

### Expected shape
- action: evaluate deletion of obsolete draft
- mode: structural refresh follow-through
- target behavior:
  - keep clean final file set
  - preserve necessary traceability only
- approval: usually yes before deletion if it is a meaningful artifact
- wrong tendencies to avoid:
  - keeping every draft forever
  - deleting all traceability artifacts

---

## Eval 15 — Output shape sanity check

### Prompt
The user says: "把这个记到长期记忆里，但先给我看你准备怎么写。"

### Expected shape
- response should include:
  - classification
  - target file / section
  - why this layer
  - overlap / placement check
  - exact proposed wording
  - approval request
- wrong tendencies to avoid:
  - writing immediately
  - replying only with a vague summary and no exact wording