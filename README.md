# Claude Code Starter Repo

A template repository with sensible defaults for developing projects with Claude Code as an autonomous agent.

## What's Included

- **`CLAUDE.md`** — Development guidelines that Claude Code follows: highly functionalized code, thorough testing, composable architecture, documentation standards, git workflow, and beads-based issue tracking.
- **`AGENTS.md`** — Multi-agent coordination protocol: lead/worker roles, BV-driven triage, Agent Mail messaging and file reservations, DCG safety rules.
- **`.claude/settings.json`** — Permission configuration with DCG PreToolUse hook, granular allow list, and deny list for destructive operations.
- **`Dockerfile.claude`** — Shared base Docker image for Claude Code agents (extend with `FROM claude-agent:latest`). Includes bd beads tracker, DCG hook pre-registered, Python 3.12 + uv, Node 22, gh, tini as PID 1, and ripgrep/fd/bat/fzf/tmux.
- **`scripts/`** — Swarm lifecycle scripts: `swarm-init`, `swarm-start`, `swarm-kill`.
- **`.gitignore`** — Comprehensive ignore file covering common languages and tools.

## Quick Start — Single Agent

1. Use this repo as a template or fork it for your new project.
2. Customize `PROJECT.md` with your project details and `CLAUDE.md` with language/framework specifics.
3. Adjust `.claude/settings.json` permissions as needed for your stack.
4. Start building with Claude Code — it will follow the guidelines automatically.

## Quick Start — Agent Swarm

Prerequisites: `tmux`, `claude`, `bd` (or `br`), `bv`, Agent Mail MCP server.

```bash
# Create a new project from this template
scripts/swarm-init my-app

# Edit PROJECT.md and CLAUDE.md, then:
scripts/swarm-start ~/code/my-app --workers 3

# View the swarm
tmux attach -t swarm-my-app

# Stop and clean up
scripts/swarm-kill ~/code/my-app
```

The swarm launches a **lead agent** (triages with `bv`, assigns work via Agent Mail) and **N worker agents** (each in its own git worktree and tmux pane). See `AGENTS.md` for the full coordination protocol.

## Picking an Issue Tracker — `bd` vs `br`

`swarm-init`, `swarm-setup`, and `swarm-start` all accept `--tracker bd` (default) or `--tracker br`. The choice is **made at init time** and bakes the tracker's CLI name and sync commands into `CLAUDE.md` and `AGENTS.md` for the new project, so switch later by re-running `swarm-setup` with the other flag.

| | `bd` (beads, original) — **default** | `br` (beads_rust) |
|---|---|---|
| Backend | Dolt (versioned SQL database) | SQLite + JSONL files (git-portable) |
| Install | `brew tap steveyegge/beads && brew install beads`, plus `brew install dolt` | `curl -fsSL .../install.sh \| bash` (single binary) |
| External services | Requires a running dolt server | None |
| Docker | Needs dolt networking set up | Works identically in/out of containers |
| Sync model | One-shot: `bd sync` | Explicit: `br sync --flush-only`, `--import-only`, `--rebuild` |

**Pick `bd` if (default):**
- You want the original `beads` toolchain with Dolt's branching/merging model for issue history.
- You're already running a Dolt server or comfortable operating one.
- You want richer query/diff semantics on issue data.

**Pick `br` if:**
- You want zero infrastructure — a single binary, files in git, nothing else.
- You're running agents in Docker or across machines and don't want to operate a database.
- You need identical behavior in and out of containers.

Examples:

```bash
scripts/swarm-init my-app                  # bd (default)
scripts/swarm-init my-app --tracker br     # br (beads_rust, no server)
scripts/swarm-setup ~/code/existing-app --tracker br
```

## Docker

The included `Dockerfile.claude` is the **shared base image** for running Claude Code agents in containers. It provides the same tooling as a local macOS setup plus the DCG hook pre-installed. Per-project images should extend it:

```dockerfile
FROM claude-agent:latest
# ... project-specific additions (pnpm, playwright system deps, etc.)
```

### Build

Pass your host UID/GID at build time so bind-mounted files have correct ownership on Colima and Linux Docker (Docker Desktop on macOS handles this differently, but matching is harmless there):

```bash
docker build -f Dockerfile.claude \
  --build-arg HOST_UID=$(id -u) \
  --build-arg HOST_GID=$(id -g) \
  -t claude-agent:latest .
```

The args default to `501:20` (typical macOS user). If you skip them and bind-mounted files come up owned by `root` or a wrong UID, rebuild with the explicit args above.

### Run

The container needs your project directory, Claude credentials, and GitHub CLI config mounted in:

```bash
docker run -it -d \
  -v ~/code/my-project:/workspace \
  -v $HOME/.claude-docker:/home/claude-user/.claude \
  -v $HOME/.claude-docker/.claude.json:/home/claude-user/.claude.json \
  -v $HOME/.gh-docker:/home/claude-user/.config/gh \
  --name agent-myproject \
  claude-agent:latest
```

| Mount | Purpose |
|-------|---------|
| `~/code/my-project:/workspace` | Your project repo |
| `$HOME/.claude-docker:/home/claude-user/.claude` | Claude Code settings and session data |
| `$HOME/.claude-docker/.claude.json:/home/claude-user/.claude.json` | Claude API credentials |
| `$HOME/.gh-docker:/home/claude-user/.config/gh` | GitHub CLI auth (for `gh` commands) |

> **Using worktrees?** The shell helper below handles an additional mount (`$repo/.git` at its original host path) so git worktree references resolve inside the container. If you're running `docker run` manually with a worktree, you'll need that extra mount too.

> **Issue tracker in Docker:** The image ships with `bd` pre-installed via its upstream install script, which handles its Dolt dependency. If you'd rather use `br` (SQLite + JSONL, no server), init the project with `--tracker br` — note that `br` is not pre-installed in this image, so you'll need to add it yourself or rebuild with the `br` install line.

**First-time setup:** Create the host directories and Docker-specific permissions before your first run:

```bash
mkdir -p ~/.claude-docker ~/.gh-docker
```

Create `~/.claude-docker/settings.json` with broad permissions (safe because Docker is already a sandbox):

```json
{
  "permissions": {
    "allow": [
      "Bash(*)"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf /*)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf ~/*)",
      "Bash(rm -rf .)",
      "Bash(rm -rf ./*)",
      "Bash(rm -rf ..)",
      "Bash(rm -rf .git)",
      "Bash(sudo rm -rf *)",
      "Bash(chmod -R 777 /)",
      "Bash(git push --force origin main)",
      "Bash(git push --force origin master)",
      "Bash(git reset --hard origin/*)"
    ]
  }
}
```

This is the **user-level** settings file — it lives outside any project repo and only applies inside the container. The project-level `.claude/settings.json` (checked into git) stays granular for local use.

Then authenticate `gh` inside the container (`gh auth login`) or copy your existing `~/.config/gh/` contents into `~/.gh-docker/`.

### Shell helper (optional)

Add this to your `~/.zshrc` to launch agents with a single command. Each agent gets its own git worktree so multiple agents can work on the same project in parallel without conflicts.

```bash
function claude-agent() {
  local name="${1:-agent-1}"
  local project="${2:-$(basename "$PWD")}"
  local repo="$HOME/code/$project"
  local workdir="${repo}-${name}"

  # Verify the main repo exists
  if [ ! -d "$repo/.git" ]; then
    echo "ERROR: No git repo at $repo"
    return 1
  fi

  # Warn if there are uncommitted changes (worktrees only get committed files)
  if git -C "$repo" status --porcelain CLAUDE.md .claude/settings.json 2>/dev/null | grep -q .; then
    echo "WARNING: Uncommitted CLAUDE.md or settings.json changes won't appear in worktree."
    echo "Commit them first, or the agent won't have your latest rules."
  fi

  # Create a git worktree for this agent (reuse if it already exists)
  if [ ! -d "$workdir" ]; then
    git -C "$repo" worktree add "$workdir" -b "$name"
    echo "Created worktree: $workdir (branch: $name)"
  fi

  # Verify the worktree has files before mounting
  if [ -z "$(ls -A "$workdir" 2>/dev/null)" ]; then
    echo "ERROR: Worktree at $workdir is empty — mount would fail."
    return 1
  fi

  # Remove existing container with same name if it exists
  docker rm -f "$name" 2>/dev/null || true

  echo "Mounting $workdir → /workspace"
  docker run -it -d \
    -v "$workdir":/workspace \
    -v "$repo/.git":"$repo/.git" \
    -v "$HOME/.claude-docker":/home/claude-user/.claude \
    -v "$HOME/.claude-docker/.claude.json":/home/claude-user/.claude.json \
    -v "$HOME/.gh-docker":/home/claude-user/.config/gh \
    --name "$name" \
    claude-agent

  echo "Started $name → $workdir"
  docker exec -it "$name" bash
}

function claude-agent-cleanup() {
  local name="${1:?usage: claude-agent-cleanup <name> <project>}"
  local project="${2:-$(basename "$PWD")}"
  local repo="$HOME/code/$project"
  local workdir="${repo}-${name}"

  docker rm -f "$name" 2>/dev/null || true

  # Restore the gitdir reverse pointer before removing the worktree.
  # The entrypoint rewrites it to /workspace (container path), which makes
  # the host think a phantom worktree at /workspace holds the branch.
  local gitdir_file="$repo/.git/worktrees/$name/gitdir"
  if [ -f "$gitdir_file" ]; then
    echo "$workdir" > "$gitdir_file"
  fi

  git -C "$repo" worktree remove "$workdir" 2>/dev/null || true
  git -C "$repo" branch -d "$name" 2>/dev/null || true
  echo "Cleaned up: $name"
}
```

Usage:

```bash
# Launch agents (each gets its own worktree and branch)
claude-agent agent-1 pixel-wave-art
claude-agent agent-2 pixel-wave-art

# See all active worktrees from the main repo
git -C ~/code/pixel-wave-art worktree list

# Attach to a running agent
docker exec -it agent-1 bash

# Clean up after an agent is done (removes container, worktree, and branch)
claude-agent-cleanup agent-1 pixel-wave-art
```

**Important:** Worktrees only contain **committed** files. If you've modified `CLAUDE.md` or `.claude/settings.json` but haven't committed, the worktree (and therefore the Docker agent) won't have your latest changes. Always commit config changes before launching agents.

### What's in the base image

Base: `python:3.12-trixie` (Debian 13). Trixie's newer glibc (2.39+) is required for DCG's prebuilt aarch64 binary, which is why this isn't built on `node:*-bookworm` or `*-slim`.

| Tool | Purpose |
|------|---------|
| **claude** | Claude Code CLI agent (version pinnable via `--build-arg CLAUDE_CODE_VERSION=...`) |
| **gh** | GitHub CLI — git push/pull auth via mounted credentials |
| **bd** (beads, Dolt-backed) | Default issue tracker; installed via the upstream `steveyegge/beads` install script |
| **dcg** (Destructive Command Guard) | Rust-based PreToolUse hook; binary installed `--system`, hook registration baked into `/etc/claude-defaults/settings.json` and reconciled into the user's settings by `entrypoint.sh` |
| **uv** | Astral's fast Python package manager (system-wide, replaces pip/poetry/venv) |
| **python 3.12** | From the base image (no conda) |
| **node 22** | Installed via NodeSource on top of the Python base (pinnable via `--build-arg NODE_MAJOR=...`) |
| **tini** | PID 1 — reaps zombie subprocesses when `claude` spawns children |
| **ripgrep, fd, bat, fzf, tmux, jq, less, unzip, xz-utils** | Agent-friendly shell tooling |
| **git, curl, build-essential** | Standard dev utilities |

### Pinning versions

The Dockerfile exposes build args for the fast-moving tools so builds are reproducible:

```bash
docker build -f Dockerfile.claude \
  --build-arg CLAUDE_CODE_VERSION=2.1.143 \
  --build-arg BD_INSTALL_REF=main \
  --build-arg DCG_INSTALL_REF=main \
  --build-arg NODE_MAJOR=22 \
  --build-arg HOST_UID=$(id -u) \
  --build-arg HOST_GID=$(id -g) \
  -t claude-agent:latest .
```

Override these to upgrade deliberately rather than picking up `latest` on every rebuild. Python is fixed to 3.12 by the base image — change the `FROM` line to upgrade.

### Keeping bd versions in sync

The host and Docker should run the same `bd` version to avoid issue-store format drift.

- **macOS host:** `brew tap steveyegge/beads && brew install beads` (also `brew install dolt` if not bundled)
- **Docker:** Uses the upstream `steveyegge/beads` install script during build — pin with `--build-arg BD_INSTALL_REF=<tag-or-sha>`

Check both with `bd --version`. If they drift, rebuild the Docker image.

## Permissions Philosophy

Three layers of protection:

**1. DCG (Destructive Command Guard):** A PreToolUse hook that intercepts every Bash command before execution. Blocks destructive filesystem and git operations with sub-millisecond overhead using SIMD-accelerated pattern matching. Configured in `.claude/settings.json` under `hooks`. **Pre-installed in `Dockerfile.claude`** (via `install.sh --system --no-configure`) with a baseline hook registration at `/etc/claude-defaults/settings.json` that `entrypoint.sh` reconciles into the user's mounted settings. For host installs: `curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/destructive_command_guard/main/install.sh" | bash -s -- --easy-mode`

**2. Permission allow/deny lists:** Broad `Bash(*)` allow — DCG is the safety net, not the allow list. A deny list explicitly blocks recursive force-deletes, force-pushing to main/master, disk-wiping commands, and system shutdown. A granular alternative (`settings.granular.json`) is included if you prefer explicit per-command approval.

**3. Agent Mail pre-commit guard:** Optional git hook (`install_precommit_guard`) that blocks commits touching files reserved by other agents. Prevents multi-agent file conflicts at commit time.

A granular alternative (`settings.granular.json`) is included for environments where you want explicit per-command approval instead of relying on DCG. To use it, rename it to `settings.json`.
