---
name: sdd-ff
description: >
  Fast-forward all SDD planning phases — proposal through tasks.
  Trigger: When the user says "sdd ff <name>", "fast forward", or wants to run all planning phases in sequence.
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Purpose

You are an ORCHESTRATOR for fast-forwarding all SDD planning phases. You coordinate four phases in sequence — propose, spec, design, tasks — by delegating to sub-agents. You do NOT execute phase work inline.

## What You Receive

- Change name (e.g., "add-dark-mode")
- Artifact store mode (`engram | openspec | hybrid | none`)
- Working directory and project name

## Workflow

Run these sub-agents in sequence. Do NOT show intermediate results — present a combined summary after ALL phases complete.

### Step 1: Launch Proposal

Launch a sub-agent for `sdd-propose`:

```
Task(
  description: 'sdd-propose for {change-name}',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-propose/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|hybrid|none}

  TASK:
  Create a proposal for the change "{change-name}".

  Return structured output with: status, executive_summary, artifacts, next_recommended, risks.'
)
```

If status is `blocked`, stop and report to user.

### Step 2: Launch Spec and Design (parallel)

After proposal completes successfully, launch BOTH in parallel:

**Spec sub-agent:**
```
Task(
  description: 'sdd-spec for {change-name}',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-spec/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|hybrid|none}
  - Previous artifacts: proposal at sdd/{change-name}/proposal

  TASK:
  Write specifications for the change "{change-name}" based on the proposal.

  Return structured output with: status, executive_summary, artifacts, next_recommended, risks.'
)
```

**Design sub-agent:**
```
Task(
  description: 'sdd-design for {change-name}',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-design/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|hybrid|none}
  - Previous artifacts: proposal at sdd/{change-name}/proposal

  TASK:
  Create the technical design for the change "{change-name}" based on the proposal.

  Return structured output with: status, executive_summary, artifacts, next_recommended, risks.'
)
```

If either returns `blocked`, stop and report to user.

### Step 3: Launch Tasks

After BOTH spec and design complete successfully:

```
Task(
  description: 'sdd-tasks for {change-name}',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-tasks/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|hybrid|none}
  - Previous artifacts: proposal at sdd/{change-name}/proposal, spec at sdd/{change-name}/spec, design at sdd/{change-name}/design

  TASK:
  Break down the change "{change-name}" into implementation tasks based on the spec and design.

  Return structured output with: status, executive_summary, artifacts, next_recommended, risks.'
)
```

### Step 4: Present Combined Summary

After ALL four phases complete, present a single summary:

```markdown
## Fast-Forward Complete: {change-name}

| Phase | Status | Summary |
|-------|--------|---------|
| Proposal | {status} | {one-line} |
| Spec | {status} | {one-line} |
| Design | {status} | {one-line} |
| Tasks | {status} | {one-line} |

### Artifacts Created
- {list all artifact keys/paths}

### Next Steps
Ready for implementation. Run `/sdd-apply {change-name}` to start coding.

### Risks
- {aggregated risks from all phases}
```

## Rules

- NEVER execute phase work inline — always delegate to sub-agents
- Run spec and design in PARALLEL (they both depend only on proposal)
- Tasks depends on BOTH spec and design — wait for both before launching
- Present ONE combined summary at the end, not between each phase
- If any phase returns `blocked`, stop the entire fast-forward and report
- Pass artifact references to sub-agents, NOT content
- Return a structured envelope with: `status`, `executive_summary`, `artifacts`, `next_recommended`, and `risks` (read `skills/_shared/sdd-phase-common.md` for the full envelope spec)
