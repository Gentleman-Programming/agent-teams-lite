<div align="center">

# Agent Teams Lite

> **This project has been deprecated in favor of [`gentle-ai`](https://github.com/Gentleman-Programming/gentle-ai).**
>
> Everything Agent Teams Lite provides — skills, orchestration, SDD workflow, skill registry — is now available through `gentle-ai` with a better installation experience, automatic updates, persistent memory via Engram, and support for **8 agents** out of the box.

</div>

---

## Migrating to gentle-ai

```bash
brew install gentleman-programming/tap/gentle-ai
gentle-ai install
```

That's it. `gentle-ai` detects your installed tools, installs all skills, configures MCP servers, injects the SDD orchestrator, and sets up Engram persistent memory — automatically.

### What you get with gentle-ai that ATL didn't have

| Feature | Agent Teams Lite | gentle-ai |
|---------|:---:|:---:|
| SDD orchestration (9 phases + judgment-day) | ✅ | ✅ |
| Skill registry + compact rules | ✅ | ✅ |
| branch-pr + issue-creation skills | ✅ | ✅ |
| Engram persistent memory (installed + configured) | ❌ | ✅ |
| Context7 documentation MCP | ❌ | ✅ |
| Persona injection | ❌ | ✅ |
| Automatic self-updates | ❌ | ✅ |
| Backup and rollback | ❌ | ✅ |
| Config sync and migration | ❌ | ✅ |
| GGA configuration | ❌ | ✅ |
| Permission management | ❌ | ✅ |
| TUI interactive installer | ❌ | ✅ |

### Supported agents (all 8)

| Agent | Sub-agent support |
|-------|:---:|
| Claude Code | Full |
| OpenCode | Full |
| Gemini CLI | Full |
| Codex | Full |
| Cursor | Inline |
| VS Code Copilot | Inline |
| Antigravity | Single-agent |
| Windsurf | Hybrid (Plan + Code mode) |

### If you already have ATL installed

Run `gentle-ai install` — it will detect your existing setup and upgrade in place. Your skills, orchestrator config, and MCP servers will be migrated to the managed format with marker-based sections that support future sync and updates.

---

## Why deprecate?

Maintaining feature parity across two distribution channels (shell scripts + Go binary) was unsustainable. Every change to a skill, orchestrator, or asset had to be replicated manually. With `gentle-ai`:

- **One source of truth** — assets are embedded in the binary, versioned with the release
- **Atomic updates** — `brew upgrade gentle-ai && gentle-ai sync` refreshes everything
- **No drift** — marker-based injection replaces stale content instead of appending duplicates
- **Cross-session memory** — Engram protocol is injected into every agent's prompt automatically

---

## This repo is archived

No new features or bug fixes will be made here. All development continues in [`gentle-ai`](https://github.com/Gentleman-Programming/gentle-ai).

The code remains available for reference. If you find value in the patterns described in the docs, they are all implemented (and improved) in gentle-ai.

## License

Apache 2.0 — see [LICENSE](LICENSE).

---

<div align="center">
  <sub>Built by <a href="https://github.com/Gentleman-Programming">Gentleman Programming</a></sub>
</div>
