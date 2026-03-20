---
name: sdd-continue
description: >
  Continue the next SDD phase in the dependency chain for an active change.
  Trigger: When the user says "sdd continue", "continuar", or wants to advance to the next planning phase.
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Purpose

You are an ORCHESTRATOR for continuing an active SDD change. You determine which artifacts already exist, identify the next phase in the dependency chain, and delegate that phase to a sub-agent. You do NOT execute phase work inline.

## What You Receive

- Change name (e.g., "add-dark-mode") — may be omitted if only one active change exists
- Artifact store mode (`engram | openspec | hybrid | none`)
- Working directory and project name

## Dependency Graph

```
proposal -> specs --> tasks -> apply -> verify -> archive
             ^
             |
           design
```

- `specs` and `design` both depend on `proposal`
- `tasks` depends on BOTH `specs` and `design`
- `apply` depends on `tasks`
- `verify` depends on `apply`
- `archive` depends on `verify`

## Workflow

### Step 1: Discover Existing Artifacts

Check which artifacts already exist for this change.

**If mode is `engram`:**
```
mem_search(query: "sdd/{change-name}/", project: "{project}")
```
Parse the results to identify which artifact types exist (explore, proposal, spec, design, tasks, apply-progress, verify-report, archive-report).

**If mode is `openspec` or `hybrid`:**
Check for files in `openspec/changes/{change-name}/`:
- `exploration.md` → explore exists
- `proposal.md` → proposal exists
- `spec.md` → spec exists
- `design.md` → design exists
- `tasks.md` → tasks exists

**If mode is `none`:**
Report that state was not persisted and ask the user which phase to run next.

### Step 2: Determine Next Phase

Based on what exists, determine the next phase:

| Exists | Missing | Next Phase |
|--------|---------|------------|
| nothing | proposal | `sdd-propose` |
| proposal | specs, design | `sdd-spec` + `sdd-design` (parallel) |
| proposal, specs | design | `sdd-design` |
| proposal, design | specs | `sdd-spec` |
| proposal, specs, design | tasks | `sdd-tasks` |
| all planning | apply | `sdd-apply` |
| apply done | verify | `sdd-verify` |
| verify done | archive | `sdd-archive` |
| all done | — | Report: change is complete |

### Step 3: Launch Next Phase

Launch the appropriate sub-agent(s) via Task tool. Use the same launch pattern as other SDD orchestrator skills:

```
Task(
  description: 'sdd-{phase} for {change-name}',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-{phase}/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|hybrid|none}
  - Previous artifacts: {list of existing artifact references}

  TASK:
  {Phase-specific task description}

  Return structured output with: status, executive_summary, artifacts, next_recommended, risks.'
)
```

If both `sdd-spec` and `sdd-design` are needed, launch them in PARALLEL.

### Step 4: Present Results

After the sub-agent(s) complete:

```markdown
## Continue: {change-name}

### Phase Completed
{phase name} — {status}

### Summary
{executive summary from sub-agent}

### Artifact State
| Artifact | Status |
|----------|--------|
| Proposal | {done/missing} |
| Spec | {done/missing} |
| Design | {done/missing} |
| Tasks | {done/missing} |
| Apply | {done/missing} |
| Verify | {done/missing} |
| Archive | {done/missing} |

### Next Step
{next recommended phase, or "all planning complete — ready for /sdd-apply"}
```

## Rules

- NEVER execute phase work inline — always delegate to sub-agents
- ALWAYS check existing artifacts before deciding the next phase
- If specs and design are both missing, launch them in PARALLEL
- If mode is `none`, ask the user which phase to run (state is not persisted)
- Pass artifact references to sub-agents, NOT content
- Return a structured envelope with: `status`, `executive_summary`, `artifacts`, `next_recommended`, and `risks` (read `skills/_shared/sdd-phase-common.md` for the full envelope spec)
