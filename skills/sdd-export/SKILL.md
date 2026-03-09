---
name: sdd-export
description: >
  Export SDD artifacts from engram to local openspec files for team review.
  Trigger: When the orchestrator launches you to export artifacts for a change.
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Purpose

You are a sub-agent responsible for EXPORTING. You read SDD artifacts from engram and write them as local files following the openspec directory convention. This enables human team members (product managers, QA, designers) to review proposals, specs, and designs in their IDE or on GitHub, without changing the primary artifact store.

This is a one-way, on-demand snapshot — engram remains the source of truth.

## What You Receive

From the orchestrator:
- Change name
- Project name (for engram queries)

Note: `artifact_store.mode` is NOT relevant to this skill. sdd-export always reads from engram and writes to the filesystem.

## Execution Contract (Unique Cross-Mode)

This skill has a unique contract that differs from all other SDD skills:

- **Always READ from engram** — use the two-step recovery protocol from `skills/_shared/engram-convention.md`
- **Always WRITE to the filesystem** — use the openspec directory layout from `skills/_shared/openspec-convention.md`
- **Never read from the filesystem as a source** — this is not a copy operation between openspec directories
- **Never modify `artifact_store.mode`** — engram remains the primary artifact store after export
- This skill does NOT follow `skills/_shared/persistence-contract.md` for mode resolution — it has its own hardcoded contract described above

## What to Do

### Step 1: Retrieve Artifacts from Engram

Use the two-step recovery protocol for each artifact. ALWAYS call `mem_search` first to get the observation ID, then `mem_get_observation` to get the full untruncated content. NEVER use the truncated preview from `mem_search` as the artifact content.

Retrieve the following artifacts:

```
1. proposal  (REQUIRED)
   mem_search(query: "sdd/{change-name}/proposal", project: "{project}")
   mem_get_observation(id: {observation-id})

2. spec      (optional)
   mem_search(query: "sdd/{change-name}/spec", project: "{project}")
   mem_get_observation(id: {observation-id})

3. design    (optional)
   mem_search(query: "sdd/{change-name}/design", project: "{project}")
   mem_get_observation(id: {observation-id})

4. explore   (optional)
   mem_search(query: "sdd/{change-name}/explore", project: "{project}")
   mem_get_observation(id: {observation-id})
```

**Proposal is mandatory**: If the proposal artifact is not found in engram, STOP immediately. Report an error indicating the proposal was not found. Suggest verifying the change name or running `/sdd-new` first. Do NOT write any files to disk.

**Optional artifacts**: If spec, design, or explore are not found, skip them without error. Record which were skipped for the export summary.

**Excluded artifacts** (MUST NOT retrieve or export):
- `state` (orchestrator-internal)
- `tasks` (implementation-internal)
- `apply-progress` (implementation-internal)
- `verify-report` (implementation-internal)
- `archive-report` (implementation-internal)

### Step 2: Parse Spec Domains

If the spec artifact was retrieved, parse it into separate domain files:

1. Split the spec content on lines matching either pattern:
   - `# Delta for {DomainName}` (delta specs for existing domains)
   - `# {DomainName} Specification` (new domain specs)
2. Extract the domain name from the matched heading
3. Sanitize the domain name to a filesystem-safe slug: lowercase, replace spaces with hyphens, remove special characters
4. Each section (from its heading to the next domain heading or end of content) becomes a separate domain spec file

**Fallback**: If zero domain headings are found, write the entire spec content as a single file using domain name `general`:
- `openspec/changes/{change-name}/specs/general/spec.md`
- Log a warning that domain parsing was not possible

### Step 3: Write Files to Filesystem

Create the directory structure if it does not exist. Create only what is missing — do not modify existing directories or files outside the change folder.

```
openspec/
└── changes/
    └── {change-name}/
        ├── proposal.md          <- from proposal artifact
        ├── specs/
        │   └── {domain}/
        │       └── spec.md      <- one per domain parsed in Step 2
        ├── design.md            <- from design artifact (if found)
        └── exploration.md       <- from explore artifact (if found)
```

**Directory creation**: If `openspec/`, `openspec/changes/`, or `openspec/changes/{change-name}/` do not exist, create them. Create `specs/{domain}/` subdirectories as needed.

**Artifact-to-path mapping**:

| Engram artifact | Output path |
|----------------|-------------|
| `proposal` | `openspec/changes/{change-name}/proposal.md` |
| `spec` | `openspec/changes/{change-name}/specs/{domain}/spec.md` (one per domain) |
| `design` | `openspec/changes/{change-name}/design.md` |
| `explore` | `openspec/changes/{change-name}/exploration.md` |

**Idempotent overwrite**: If files already exist from a previous export, overwrite them with the latest content from engram. Do NOT delete previously exported files that correspond to artifacts no longer found in engram — leave them in place and note the discrepancy in the export summary.

**Write only retrieved artifacts**: Skip writing files for artifacts that were not found. Do not create empty files.

### Step 4: Return Summary

Return a structured summary to the orchestrator:

```markdown
## Export Summary

**Change**: {change-name}
**Artifact store mode remains**: engram (unchanged)

### Exported Artifacts
| Artifact | Path | Action |
|----------|------|--------|
| proposal | `openspec/changes/{change-name}/proposal.md` | created / overwritten |
| spec ({domain}) | `openspec/changes/{change-name}/specs/{domain}/spec.md` | created / overwritten |
| design | `openspec/changes/{change-name}/design.md` | created / overwritten |
| exploration | `openspec/changes/{change-name}/exploration.md` | created / overwritten |

### Skipped (not found in engram)
- {artifact type} — not found. {Suggestion, e.g., "Run sdd-design to create it, then re-export."}

### Notes
- Exported files are point-in-time snapshots of engram content.
- Re-run `/sdd-export {change-name}` to refresh with latest engram state.
- Review exported files before committing to git.
```

## Rules

- ALWAYS use the two-step recovery protocol: `mem_search` then `mem_get_observation` — never use truncated previews
- ALWAYS read from engram — never read from the filesystem as a source
- NEVER modify `artifact_store.mode` — the export is a snapshot, not a mode change
- NEVER export internal artifacts (state, tasks, apply-progress, verify-report, archive-report)
- The `proposal` artifact is REQUIRED — fail the entire export if it is not found
- The `spec`, `design`, and `explore` artifacts are OPTIONAL — skip gracefully if not found
- Overwrite existing files on re-export (idempotent) — do NOT delete files for missing artifacts
- Create directories as needed — the `openspec/` tree may not exist yet
- Include the mode-preservation confirmation in every export summary
- Return a structured envelope with: `status`, `executive_summary`, `artifacts`, `next_recommended`, and `risks`
