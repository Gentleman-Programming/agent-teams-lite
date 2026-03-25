# SDD Phase — Common Protocol

This file contains boilerplate that is **identical** across all SDD phase skills. Sub-agents MUST load this alongside their phase-specific SKILL.md and follow the sections referenced by their skill.

Executor boundary: every SDD phase agent is an EXECUTOR, not an orchestrator. Do the phase work yourself. Do NOT launch sub-agents, do NOT call `delegate`/`task`, and do NOT bounce work back to another agent unless the phase skill explicitly says to stop and report a blocker.

---

## A. Skill Loading

Every phase skill's "Step 1: Load Skills" follows this exact procedure:

1. Check if the orchestrator provided one or more `SKILL: Load` instructions in your launch prompt. If yes, load those exact skills.
2. If no skill path was provided, search for the skill registry yourself:
   a. Try: `mem_search(query: "skill-registry", project: "{project}")` — if found, `mem_get_observation(id)` for full content
   b. Fallback: read `.atl/skill-registry.md` if it exists
3. From the registry, load any skills whose triggers match your current task.
4. If no registry exists, proceed with your phase skill only.

NOTE: searching the registry is SKILL LOADING, not delegation. You are loading tools to do your own work — not handing off execution to another agent.

---

## B. Artifact Retrieval (Engram Mode)

When your phase reads artifacts from engram, follow this two-step pattern. **This is mandatory — there are no shortcuts.**

**CRITICAL: `mem_search` returns 300-char PREVIEWS, not full content. You MUST call `mem_get_observation(id)` for EVERY artifact. If you skip this, you will work with incomplete data and produce wrong output.**

### Step A — Search (get IDs only)

**Run all artifact searches in parallel** — call all `mem_search` calls simultaneously in a single response. Do NOT search sequentially.

```
mem_search(query: "sdd/{change-name}/{artifact-type}", project: "{project}") → save ID
```

Repeat for each artifact your phase requires (see your SKILL.md for the list).

### Step B — Retrieve Full Content (mandatory for each)

**Run all retrieval calls in parallel** — call all `mem_get_observation` calls simultaneously in a single response.

```
mem_get_observation(id: {saved_id}) → full content (REQUIRED)
```

**DO NOT use search previews as source material.**

---

## C. Artifact Persistence

Every phase that produces an artifact MUST persist it. **If you skip this step, the pipeline BREAKS — downstream phases will not find your output.**

### Engram mode

```
mem_save(
  title: "sdd/{change-name}/{artifact-type}",
  topic_key: "sdd/{change-name}/{artifact-type}",
  type: "architecture",
  project: "{project}",
  content: "{your full artifact markdown}"
)
```

`topic_key` enables upserts — saving again updates, not duplicates.

(See `skills/_shared/engram-convention.md` for full naming conventions.)

### OpenSpec mode

The file was already written during the phase's main step. No additional action needed.

### Hybrid mode

Do BOTH: write the file to the filesystem AND call `mem_save` as above.

### None mode

Return result inline only. Do not write any files or call `mem_save`.

---

## D. Return Envelope

Every phase MUST return a structured envelope to the orchestrator. Include ALL of these fields:

| Field | Description |
|-------|-------------|
| `status` | `success`, `partial`, or `blocked` |
| `executive_summary` | 1-3 sentence summary of what was done |
| `detailed_report` | (optional) Full phase output, or omit if already inline |
| `artifacts` | List of artifact keys/paths written |
| `next_recommended` | The next SDD phase to run, or "none" |
| `risks` | Risks discovered, or "None" |

Example:

```markdown
**Status**: success
**Summary**: Proposal created for `{change-name}`. Defined scope, approach, and rollback plan.
**Artifacts**: Engram `sdd/{change-name}/proposal` | `openspec/changes/{change-name}/proposal.md`
**Next**: sdd-spec or sdd-design
**Risks**: None
```
