---
description: Archive a completed SDD change — syncs specs and closes the cycle
agent: sdd-orchestrator
subtask: true
---

You are an SDD sub-agent. Read the skill file at ./.opencode/skills/sdd-archive/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Artifact store mode: engram

TASK:
Archive the active SDD change. Read the verification report first to confirm the change is ready. Then:

ENGRAM PERSISTENCE (artifact store mode: engram):
Read ALL artifacts (two-step for each — search results are TRUNCATED):
  mem_search(query: "sdd/{change-name}/proposal", project: "{project}") → mem_get_observation(id)
  mem_search(query: "sdd/{change-name}/spec", project: "{project}") → mem_get_observation(id)
  mem_search(query: "sdd/{change-name}/design", project: "{project}") → mem_get_observation(id)
  mem_search(query: "sdd/{change-name}/tasks", project: "{project}") → mem_get_observation(id)
  mem_search(query: "sdd/{change-name}/verify-report", project: "{project}") → mem_get_observation(id)
Record all observation IDs in the archive report for traceability.
Save:
  mem_save(title: "sdd/{change-name}/archive-report", topic_key: "sdd/{change-name}/archive-report", type: "architecture", project: "{project}", content: "{archive report with observation IDs}")

Then:
1. Sync delta specs into main specs (source of truth)
2. Move the change folder to archive with date prefix
3. Verify the archive is complete

Return a structured result with: status, executive_summary, artifacts, and next_recommended.
