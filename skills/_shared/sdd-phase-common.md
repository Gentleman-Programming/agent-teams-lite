# SDD Phase — Common Protocol

This file contains boilerplate that is **identical** across all SDD phase skills (explore, propose, spec, design, tasks, apply). Sub-agents should load this alongside their phase-specific SKILL.md.

---

## Skill Registry Loading

**Do this FIRST, before any other work.**

1. Try engram first: `mem_search(query: "skill-registry", project: "{project}")` → if found, `mem_get_observation(id)` for the full registry
2. If engram not available or not found: read `.atl/skill-registry.md` from the project root
3. If neither exists: proceed without skills (not an error)

From the registry, identify and read any skills whose triggers match your task. Also read any project convention files listed in the registry.

---

## Engram Upsert Note

When saving artifacts with `mem_save`, always set `topic_key` to the artifact's canonical key (e.g., `sdd/{change-name}/proposal`).

`topic_key` enables upserts — saving again updates, not duplicates.

---

## Return Envelope

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
