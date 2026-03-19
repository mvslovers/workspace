# mvslovers/workspace

Shared development environment for all mvslovers projects. Contains the root `CLAUDE.md` context file and shared Claude Code commands.

## Quick Setup

```bash
cd ~/repos                    # your mvslovers project directory
git clone https://github.com/mvslovers/workspace.git .workspace
./.workspace/setup.sh
```

This creates:
- A symlink `~/repos/CLAUDE.md` → `.workspace/CLAUDE.md` (root context for Claude Code)
- Symlinks in `~/.claude/commands/` for all shared commands

## Shared Commands

These commands are available in **every** mvslovers project after setup:

| Command | Description |
|---------|-------------|
| `/fix-issue <number>` | Resolve a GitHub issue end-to-end: read → branch → implement → test → PR → Notion update |
| `/create-issue <title>` | Interactively create a new issue on GitHub + Notion |
| `/close-issue <number>` | Close issue on GitHub + set Notion status to "Done" |
| `/review-pr <number>` | Review a PR with MVS-specific checks |
| `/plan-feature <name>` | Full planning workflow: spec → issues → Notion tracking |
| `/sync-docs` | Check endpoint docs against implementation |
| `/project-status` | Overview of open issues, PRs, and Notion task status |

## How It Works

```
~/repos/
├── .workspace/           ← this repo (git-managed)
│   ├── CLAUDE.md         ← root context (platform constraints, ecosystem overview)
│   ├── commands/         ← shared slash commands
│   │   ├── fix-issue.md
│   │   ├── create-issue.md
│   │   └── ...
│   ├── setup.sh          ← one-time setup script
│   └── README.md
├── CLAUDE.md             ← symlink → .workspace/CLAUDE.md
├── mvsmf/                ← project repo (has its own CLAUDE.md)
├── crent370/             ← project repo
├── httpd/                ← project repo
└── ...
```

Claude Code reads context in this order:
1. `~/.claude/commands/*.md` — shared commands (symlinked to `.workspace/commands/`)
2. `~/repos/CLAUDE.md` — root context (symlinked to `.workspace/CLAUDE.md`)
3. `~/repos/mvsmf/CLAUDE.md` — project-specific context (in each repo)
4. `~/repos/mvsmf/.claude/commands/*.md` — project-specific commands (if any, override shared)

## Updating

```bash
cd ~/repos/.workspace
git pull
```

Symlinks stay intact — commands and CLAUDE.md update automatically.

## Notion Integration

The shared commands integrate with the MVSLOVERS Notion workspace:
- **Projects DB** — each project tracked with status, language, repo URL
- **Issues & Tasks DB** — mirrors GitHub issues with Kanban board
- **Concepts DB** — specs and architecture documents

Commands automatically search and update Notion when the MCP connector is available.
