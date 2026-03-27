# Installation Guide

For the automated setup, run:
```bash
./scripts/setup.sh --all
```

For manual installation or specific tools, see below.

## Table of Contents
- [Claude Code](#claude-code)
- [OpenCode](#opencode)
- [Gemini CLI](#gemini-cli)
- [Codex](#codex)
- [VS Code Copilot](#vs-code-copilot)
- [Antigravity](#antigravity)
- [Cursor](#cursor)
- [Other Tools](#other-tools)

---

The recommended way to install is the **setup script** — it handles everything (skills + orchestrator prompts) in one step:

```bash
./scripts/setup.sh        # Interactive: detects agents, asks which to set up
./scripts/setup.sh --all  # Auto-detect + install all (no prompts)
```

Windows PowerShell:
```powershell
.\scripts\setup.ps1       # Interactive
.\scripts\setup.ps1 -All  # Auto-detect + install all
```

The setup script:
- Detects installed agents via PATH (`claude`, `opencode`, `gemini`, `cursor`, `code`, `codex`)
- Copies skills to the correct user-level directory
- Configures orchestrator prompts with idempotent markers (safe to re-run)
- Handles OpenCode's special case (commands + JSON config merge)
- For OpenCode: asks single vs multi-model mode (or use `--opencode-mode`)

> **For external installers** (e.g. [gentle-ai](https://github.com/gentleman-programming/gentleman-ai-installer)): use `--non-interactive` flag.

---

## Claude Code

> **Automatic:** `./scripts/setup.sh --agent claude-code` handles all steps below.

<details>
<summary>Manual installation</summary>

**1. Copy skills:**

```bash
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ~/.claude/skills/
```

**2. Add orchestrator to `~/.claude/CLAUDE.md`:**

Append the contents of [`examples/claude-code/CLAUDE.md`](../examples/claude-code/CLAUDE.md) to your existing `CLAUDE.md`.

The example is intentionally lean to avoid token bloat in always-loaded system prompts. Critical engram calls are inlined in each skill file. This keeps your existing assistant identity and adds SDD as an orchestration overlay.

</details>

**Verify:** Open Claude Code and type `/sdd-init` — it should recognize the command.

---

## OpenCode

> **Automatic:** `./scripts/setup.sh --agent opencode` handles all steps below.

Both configs include the full 10-agent setup: `sdd-orchestrator` + 9 phase sub-agents, with `delegate` tool support for async background delegation. The only difference is their intended use:

| | `opencode.single.json` | `opencode.multi.json` |
|---|---|---|
| **Use case** | Ready to use as-is | Template for per-agent model customization |
| **Agent structure** | Identical (10 agents) | Identical (10 agents) |
| **Models** | All inherit the default model | Add `"model"` fields to customize per phase |
| **delegate tool** | ✅ Included | ✅ Included |

```bash
./scripts/setup.sh --agent opencode                        # Interactive (asks which mode)
./scripts/setup.sh --agent opencode --opencode-mode single # Use as-is with default model
./scripts/setup.sh --agent opencode --opencode-mode multi  # Template for per-agent models
```

#### Per-Agent Model Customization (multi mode)

To assign different models per phase, edit `~/.config/opencode/opencode.json` and add `"model": "provider/model-id"` to each agent:

```json
{
  "agent": {
    "sdd-orchestrator": { "mode": "primary", "model": "anthropic/claude-sonnet-4-6" },
    "sdd-explore":      { "mode": "subagent", "model": "google/gemini-2.5-flash" },
    "sdd-spec":         { "mode": "subagent", "model": "anthropic/claude-opus-4-6" },
    "sdd-design":       { "mode": "subagent", "model": "anthropic/claude-opus-4-6" },
    "sdd-apply":        { "mode": "subagent", "model": "anthropic/claude-sonnet-4-6" },
    "sdd-verify":       { "mode": "subagent", "model": "openai/o3" }
  }
}
```

The format is `"provider/model-id"` — check your available models at `~/.cache/opencode/models.json`. Common providers: `anthropic`, `openai`, `google`, `openrouter`. Agents without a `model` field inherit the default model.

Both modes install the `background-agents` plugin (`examples/opencode/plugins/background-agents.ts`), which enables async sub-agent delegation. Use `delegate` to run sub-agents in the background (non-blocking) while the orchestrator continues other work; use `task` to block until the sub-agent completes.

The setup script preserves your model choices across updates — re-running `setup.sh` will update agent prompts and tools but keep any `model` fields you configured.

<details>
<summary>Manual installation</summary>

**1. Copy skills and commands:**

```bash
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ~/.config/opencode/skills/
cp examples/opencode/commands/sdd-*.md ~/.config/opencode/commands/
cp examples/opencode/AGENTS.md ~/.config/opencode/AGENTS.md
```

**2. Add orchestrator agent to `~/.config/opencode/opencode.json`:**

Merge the `agent` block from the config template into your existing config:
- Single mode: [`examples/opencode/opencode.single.json`](../examples/opencode/opencode.single.json)
- Multi mode: [`examples/opencode/opencode.multi.json`](../examples/opencode/opencode.multi.json)

The OpenCode examples now reference `~/.config/opencode/AGENTS.md` via `"prompt": "{file:./AGENTS.md}"`, so copy that file too.

For multi mode, also update the `agent:` field in each subtask command (`sdd-init.md`, `sdd-explore.md`, `sdd-apply.md`, `sdd-verify.md`, `sdd-archive.md`) to point to the corresponding subagent name instead of `sdd-orchestrator`.

</details>

**How to use in OpenCode:**
- Start OpenCode in your project: `opencode .`
- Use the agent picker (Tab) and choose `sdd-orchestrator`
- Run SDD commands: `/sdd-init`, `/sdd-new <name>`, `/sdd-apply`, etc.
- Switch back to your normal agent (Tab) for day-to-day coding

---

## Gemini CLI

> **Automatic:** `./scripts/setup.sh --agent gemini-cli` handles all steps below.

<details>
<summary>Manual installation</summary>

**1. Copy skills:**

```bash
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ~/.gemini/skills/
```

**2. Add orchestrator to `~/.gemini/GEMINI.md`:**

Append the contents of [`examples/gemini-cli/GEMINI.md`](../examples/gemini-cli/GEMINI.md) to your Gemini system prompt file (create it if it doesn't exist).

Make sure `GEMINI_SYSTEM_MD=1` is set in `~/.gemini/.env` so Gemini loads the system prompt.

</details>

**Verify:** Open Gemini CLI and type `/sdd-init`.

> **Note:** Gemini CLI doesn't have a native Task tool for sub-agent delegation. The skills work as inline instructions. For the best sub-agent experience, use Claude Code or OpenCode.

---

## Codex

> **Automatic:** `./scripts/setup.sh --agent codex` handles all steps below.

<details>
<summary>Manual installation</summary>

**1. Copy skills:**

```bash
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ~/.codex/skills/
```

**2. Add orchestrator instructions:**

Append the contents of [`examples/codex/agents.md`](../examples/codex/agents.md) to `~/.codex/agents.md` (or your `model_instructions_file` if configured).

</details>

**Verify:** Open Codex and type `/sdd-init`.

> **Note:** Like Gemini CLI, Codex runs skills inline rather than as true sub-agents. The planning phases still work well; implementation batching is handled by the orchestrator instructions.

---

## VS Code (Copilot)

> **Automatic:** `./scripts/setup.sh --agent vscode` handles all steps below.

<details>
<summary>Manual installation</summary>

**1. Copy skills:**

```bash
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ~/.copilot/skills/
```

**2. Add orchestrator instructions:**

Create a VS Code `.instructions.md` file in the User prompts folder with the orchestrator from [`examples/vscode/copilot-instructions.md`](../examples/vscode/copilot-instructions.md).

Prompt file paths:
- macOS: `~/Library/Application Support/Code/User/prompts/agent-teams-lite.instructions.md`
- Linux: `~/.config/Code/User/prompts/agent-teams-lite.instructions.md`
- Windows: `%APPDATA%\Code\User\prompts\agent-teams-lite.instructions.md`

</details>

**Verify:** Open VS Code, open the Chat panel (Ctrl+Cmd+I / Ctrl+Alt+I), and type `/sdd-init`.

> **Note:** VS Code Copilot supports agent mode with tool use. For true sub-agent delegation with fresh context windows, use Claude Code or OpenCode.

---

## Antigravity

[Antigravity](https://antigravity.google) is Google's AI-first IDE with native skill support. Not yet supported by the setup script — manual installation required.

**1. Copy skills:**

```bash
# Global (available across all projects)
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ~/.gemini/antigravity/skills/

# Workspace-specific (per project)
mkdir -p .agent/skills
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation .agent/skills/
```

**2. Add orchestrator instructions:**

Add the SDD orchestrator as a global rule in `~/.gemini/GEMINI.md`, or create a workspace rule in `.agent/rules/sdd-orchestrator.md`.

See [`examples/antigravity/sdd-orchestrator.md`](../examples/antigravity/sdd-orchestrator.md) for the rule content.

**3. Verify:**

Open Antigravity and type `/sdd-init` in the agent panel.

> **Note:** Antigravity uses `.agent/skills/` and `.agent/rules/` for workspace config, and `~/.gemini/antigravity/skills/` for global. It does NOT use `.vscode/` paths.

---

## Cursor

> **Automatic:** `./scripts/setup.sh --agent cursor` handles all steps below.

<details>
<summary>Manual installation</summary>

**1. Copy skills:**

```bash
# Global
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ~/.cursor/skills/

# Or per-project
cp -r skills/_shared skills/sdd-* skills/skill-registry skills/judgment-day skills/go-testing skills/skill-creator skills/branch-pr skills/issue-creation ./your-project/skills/
```

**2. Add orchestrator to `.cursorrules`:**

Append the contents of [`examples/cursor/.cursorrules`](../examples/cursor/.cursorrules) to your project's `.cursorrules` file.

</details>

**Note:** Cursor doesn't have a Task tool for true sub-agent delegation. The skills still work — Cursor reads them as instructions — but the orchestrator runs inline. For the best sub-agent experience, use Claude Code or OpenCode.

---

## Other Tools

The skills are pure Markdown. Any AI assistant that can read files can use them.

**1. Copy skills** to wherever your tool reads instructions from.

**2. Add orchestrator instructions** to your tool's system prompt or rules file.

**3. Adapt the sub-agent pattern:**
- If your tool has a Task/sub-agent mechanism → use the pattern from `examples/claude-code/CLAUDE.md`
- If not → the orchestrator reads the skills inline (still works, just uses more context)
