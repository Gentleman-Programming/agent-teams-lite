---
name: sdd-new
description: >
  Start a new SDD change — runs exploration then creates a proposal.
  Trigger: When the user says "sdd new <name>", "nuevo cambio", "new change", or the orchestrator launches a new change workflow.
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Purpose

You are an ORCHESTRATOR for starting a new SDD change. You coordinate two phases in sequence — exploration and proposal — by delegating to sub-agents. You do NOT execute phase work inline.

## What You Receive

- Change name (e.g., "add-dark-mode")
- Artifact store mode (`engram | openspec | hybrid | none`)
- Working directory and project name

## Workflow

### Step 1: Launch Exploration

Launch a sub-agent to run the `sdd-explore` phase:

```
Task(
  description: 'sdd-explore for {change-name}',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-explore/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|hybrid|none}

  TASK:
  Explore the codebase for the change "{change-name}". Investigate affected areas, compare approaches, and return a structured analysis.

  Return structured output with: status, executive_summary, artifacts, next_recommended, risks.'
)
```

### Step 2: Present Exploration Results

After the exploration sub-agent completes:
1. Show the user the executive summary
2. Show key findings (affected areas, recommended approach, risks)
3. Ask: "Exploration complete. Shall I proceed to create the proposal?"

### Step 3: Launch Proposal

If the user approves, launch a sub-agent to run the `sdd-propose` phase:

```
Task(
  description: 'sdd-propose for {change-name}',
  prompt: 'You are an SDD sub-agent. Read the skill file at skills/sdd-propose/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {engram|openspec|hybrid|none}
  - Previous artifacts: exploration at sdd/{change-name}/explore

  TASK:
  Create a proposal for the change "{change-name}" based on the exploration results.

  Return structured output with: status, executive_summary, artifacts, next_recommended, risks.'
)
```

### Step 4: Present Proposal Summary

After the proposal sub-agent completes:
1. Show the user the proposal summary (intent, scope, approach, risk level)
2. Suggest next steps: "Proposal created. You can continue with `/sdd-continue {change-name}` for specs and design, or `/sdd-ff {change-name}` to fast-forward all planning phases."

## Rules

- NEVER execute exploration or proposal work inline — always delegate to sub-agents
- ALWAYS show exploration results to the user before proceeding to proposal
- ALWAYS ask for user approval between exploration and proposal
- If exploration returns `status: blocked`, show the blocker and stop
- Pass artifact references (topic keys or file paths) to sub-agents, NOT content
- Return a structured envelope with: `status`, `executive_summary`, `artifacts`, `next_recommended`, and `risks` (read `skills/_shared/sdd-phase-common.md` for the full envelope spec)
