# Claude Code Starter Repo

A template repository with sensible defaults for developing projects with Claude Code as an autonomous agent.

## What's Included

- **`CLAUDE.md`** — Development guidelines that Claude Code follows: highly functionalized code, thorough testing, composable architecture, documentation standards, git workflow, and beads-based issue tracking.
- **`.claude/settings.json`** — Permission configuration enabling largely autonomous agent workflows while blocking dangerous destructive operations.
- **`.gitignore`** — Comprehensive ignore file covering common languages and tools.

## Usage

1. Use this repo as a template or fork it for your new project.
2. Customize `CLAUDE.md` with project-specific conventions (language, framework, etc.).
3. Adjust `.claude/settings.json` permissions as needed for your stack.
4. Start building with Claude Code — it will follow the guidelines automatically.

## Permissions Philosophy

**Allowed freely:** File reads/writes, git operations, running tests, building, linting, package management, web searches, and common dev tools.

**Blocked:** Recursive force-deletes of critical paths, force-pushing to main/master, disk-wiping commands, system shutdown, and mass container/process killing.

**Everything else:** Will prompt for confirmation on first use, giving you control over anything unexpected.
