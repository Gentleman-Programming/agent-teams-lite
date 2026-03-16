# Background Agents for OpenCode

> Claude Code-style async background delegation for OpenCode — fire off sub-agents in parallel, keep working, results persist to disk.

Adapted from [kdcokenny/opencode-background-agents](https://github.com/kdcokenny/opencode-background-agents) (MIT License).

## What It Does

Adds 3 tools to OpenCode that let agents run sub-agents **in the background**:

| Tool | What it does |
|------|-------------|
| `delegate(prompt, agent)` | Launch a sub-agent async. Returns a readable ID immediately. |
| `delegation_read(id)` | Retrieve the full result of a completed delegation. |
| `delegation_list()` | List all delegations (running + completed) for the session. |

The agent keeps working while delegations run. When a delegation completes, a `<task-notification>` arrives with the full result. Results are persisted to disk as markdown files — they survive context compaction, session restarts, and process crashes.

## delegate vs task

| Tool | Behavior | Use When |
|------|----------|----------|
| `delegate` | Async, background, persisted to disk | You want to continue working while it runs |
| `task` | Synchronous, blocks until complete | You need the result before continuing |

The real value of `delegate` is **parallelization** — launch 2-3 sub-agents at once and keep chatting while they work.

## How It Works

```
1. Agent calls     delegate("Research OAuth2 PKCE", "sdd-explore")
2. Plugin creates  isolated child session, fires prompt, returns ID immediately
3. Agent continues working (responds to user, launches more delegates, etc.)
4. Sub-agent works in background session with full tool access
5. On completion   → session.idle event triggers result extraction
6. Plugin          → persists result as markdown to disk
7. Plugin          → generates title/description via small_model (with fallback)
8. Plugin          → sends <task-notification> to parent session
9. Agent receives  notification with full result inline
```

Results are stored at: `~/.local/share/opencode/delegations/{projectId}/{sessionId}/{delegationId}.md`

## Installation

### Prerequisites

- [OpenCode](https://github.com/sst/opencode) v1.2.27+ installed
- `@opencode-ai/plugin` package in `~/.config/opencode/node_modules/`

### Step 1: Install dependency

```bash
cd ~/.config/opencode
npm install unique-names-generator
```

### Step 2: Copy the plugin

Copy `background-agents.ts` to `~/.config/opencode/plugins/`:

```bash
cp background-agents.ts ~/.config/opencode/plugins/
```

Plugins in `~/.config/opencode/plugins/` are loaded automatically by OpenCode — no registration needed in `opencode.json`.

### Step 3: Enable tools for your agents

By default, if your agent has an explicit `tools` config, plugin tools are NOT included. You must add them:

```json
{
  "agent": {
    "your-agent": {
      "tools": {
        "delegate": true,
        "delegation_list": true,
        "delegation_read": true,
        "bash": true,
        "edit": true,
        "read": true,
        "write": true
      }
    }
  }
}
```

Add `delegate`, `delegation_list`, and `delegation_read` to every agent that should be able to launch background work.

### Step 4: Restart OpenCode

The plugin logs initialization to the debug log. Verify it loaded:

```bash
cat ~/.local/share/opencode/delegations/*/background-agents-debug.log
# Should show: "BackgroundAgents initialized with delegation system"
```

## Differences from Original

This is a direct port of [kdcokenny/opencode-background-agents](https://github.com/kdcokenny/opencode-background-agents) with the following changes:

### 1. Inlined `kdco-primitives`

The original depends on shared utilities from the OCX ecosystem. Since we don't use OCX, these are inlined directly in the plugin file:

| Module | What it provides |
|--------|-----------------|
| `types.ts` | `OpencodeClient` type alias |
| `with-timeout.ts` | `TimeoutError` class + `withTimeout<T>()` function |
| `log-warn.ts` | `logWarn()` — logs via OpenCode API with console fallback |
| `get-project-id.ts` | Stable project ID from git root commit hash (with worktree support) |

### 2. Removed read-only agent restriction

The original only allows `delegate` for read-only agents (edit=deny, write=deny, bash=deny) and forces write-capable agents to use the native `task` tool.

**We removed this restriction.** Any agent can use `delegate`.

**Why:** The original restriction exists because background sessions are isolated from OpenCode's undo/branching tree — reverting won't affect changes made in background sessions. In our setup, sub-agents are coordinated by an orchestrator and undo behavior is not critical.

**Tradeoff:** Changes made by sub-agents in background delegations cannot be reverted via OpenCode's undo system.

### 3. Removed `tool.execute.before` routing hook

The original intercepts `task` calls to read-only agents and throws an error directing them to use `delegate` instead. This symmetric enforcement was removed — both `task` and `delegate` are available without restrictions.

### 4. Updated system prompt injection

The `DELEGATION_RULES` injected into the system prompt now reflect that any agent can use `delegate`, and explain the `delegate` vs `task` tradeoff without mentioning read-only restrictions.

### 5. Export convention

Exported as `BackgroundAgents` (named + default) to match the local plugin naming convention used by `engram.ts` → `Engram`.

## Plugin Architecture

```
background-agents.ts (1447 lines)
├── Inlined primitives
│   ├── OpencodeClient type
│   ├── TimeoutError + withTimeout()
│   ├── logWarn()
│   └── getProjectId() (git root hash + worktree support + caching)
├── ID generation
│   └── generateReadableId() — adjective-color-animal via unique-names-generator
├── Metadata generation
│   └── generateMetadata() — uses small_model or fallback truncation
├── DelegationManager class
│   ├── delegate() — create session, fire prompt, track state
│   ├── handleSessionIdle() — extract result, generate metadata, persist, notify
│   ├── getResult() — read assistant messages from child session
│   ├── persistOutput() — write markdown to disk
│   ├── notifyParent() — batched notifications, triggers response on all-complete
│   ├── readOutput() — read from disk (blocks if still running)
│   ├── listDelegations() — merge in-memory + filesystem
│   ├── handleTimeout() — 15-minute max runtime
│   ├── getRootSessionID() — walk parent chain for storage scoping
│   └── findBySession() — lookup by child session ID
├── Tool creators
│   ├── createDelegate() — the `delegate` tool
│   ├── createDelegationRead() — the `delegation_read` tool
│   └── createDelegationList() — the `delegation_list` tool
├── System prompt
│   └── DELEGATION_RULES — injected into every conversation
├── Compaction support
│   └── formatDelegationContext() — running + completed delegations for context recovery
└── Plugin export (BackgroundAgents)
    ├── tool: { delegate, delegation_read, delegation_list }
    ├── experimental.chat.system.transform — injects DELEGATION_RULES
    ├── experimental.session.compacting — injects delegation context
    └── event — handles session.idle + message.updated
```

## Limitations

- **No UI shortcut**: Unlike Claude Code's `Ctrl+B`, delegations are launched by the agent, not by the user from the keyboard. OpenCode doesn't have native background session support in its TUI yet.
- **15-minute timeout**: Delegations that exceed 15 minutes are automatically cancelled.
- **No undo tracking**: Background sessions are isolated from OpenCode's session tree — undo/branching cannot revert changes made by delegated agents.
- **Metadata generation**: Requires `small_model` configured in OpenCode for AI-generated titles/descriptions. Falls back to first-line truncation if not configured.

## Monitoring

Navigate background sessions in OpenCode's TUI:

| Shortcut | Action |
|----------|--------|
| `Ctrl+X Up` | Jump to parent session |
| `Ctrl+X Left` | Previous sub-agent session |
| `Ctrl+X Right` | Next sub-agent session |

## Credits

- Original plugin: [kdcokenny/opencode-background-agents](https://github.com/kdcokenny/opencode-background-agents) by [@kdcokenny](https://github.com/kdcokenny) (MIT License)
- Based on [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) by [@code-yeongyu](https://github.com/code-yeongyu) (MIT License)
- Adapted for Agent Teams Lite by [@alanbuscaglia](https://github.com/alanbuscaglia)
