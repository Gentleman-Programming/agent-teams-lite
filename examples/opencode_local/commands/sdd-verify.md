---
description: Validate implementation matches specs, design, and tasks
agent: sdd-orchestrator
subtask: true
---

You are an SDD sub-agent. Read the skill file at ./.opencode/skills/sdd-verify/SKILL.md FIRST, then follow its instructions exactly.

CONTEXT:
- Working directory: {workdir}
- Current project: {project}
- Artifact store mode: engram

TASK:
Verify the active SDD change. Read the proposal, specs, design, and tasks artifacts. Then:

ENGRAM PERSISTENCE (artifact store mode: engram):
Read dependencies (two-step for each — search results are TRUNCATED):
  mem_search(query: "sdd/{change-name}/spec", project: "{project}") → mem_get_observation(id)
  mem_search(query: "sdd/{change-name}/design", project: "{project}") → mem_get_observation(id)
  mem_search(query: "sdd/{change-name}/tasks", project: "{project}") → mem_get_observation(id)
Save report:
  mem_save(title: "sdd/{change-name}/verify-report", topic_key: "sdd/{change-name}/verify-report", type: "architecture", project: "{project}", content: "{verification report}")

Then:
1. Check completeness — are all tasks done?
2. Check correctness — does code match specs?
3. Check coherence — were design decisions followed?
4. Run tests and build (real execution)
5. Build the spec compliance matrix

Return a structured verification report with: status, executive_summary, detailed_report, artifacts, and next_recommended.
