# Claude Code Starter Repo

A template repository with sensible defaults for developing projects with Claude Code as an autonomous agent.

## What's Included

- **`CLAUDE.md`** — Development guidelines that Claude Code follows: highly functionalized code, thorough testing, composable architecture, documentation standards, git workflow, and beads-based issue tracking.
- **`.claude/settings.json`** — Permission configuration enabling largely autonomous agent workflows while blocking dangerous destructive operations.
- **`Dockerfile.claude`** — Docker image for running Claude Code agents with full tool parity (br/beads, conda, Python, Node).
- **`.gitignore`** — Comprehensive ignore file covering common languages and tools.

## Usage

1. Use this repo as a template or fork it for your new project.
2. Customize `CLAUDE.md` with project-specific conventions (language, framework, etc.).
3. Adjust `.claude/settings.json` permissions as needed for your stack.
4. Start building with Claude Code — it will follow the guidelines automatically.

## Docker

The included `Dockerfile.claude` provides a containerized environment for running Claude Code agents with the same tooling as a local macOS setup.

### Build

```bash
docker build -f Dockerfile.claude -t claude-agent .
```

### Run

The container needs your project directory, Claude credentials, and GitHub CLI config mounted in:

```bash
docker run -it -d \
  -v ~/code/my-project:/workspace \
  -v $HOME/.claude-docker:/home/claude-user/.claude \
  -v $HOME/.claude-docker/.claude.json:/home/claude-user/.claude.json \
  -v $HOME/.gh-docker:/home/claude-user/.config/gh \
  --name agent-myproject \
  claude-agent
```

| Mount | Purpose |
|-------|---------|
| `~/code/my-project:/workspace` | Your project repo |
| `$HOME/.claude-docker:/home/claude-user/.claude` | Claude Code settings and session data |
| `$HOME/.claude-docker/.claude.json:/home/claude-user/.claude.json` | Claude API credentials |
| `$HOME/.gh-docker:/home/claude-user/.config/gh` | GitHub CLI auth (for `gh` commands) |

> **Using worktrees?** The shell helper below handles an additional mount (`$repo/.git` at its original host path) so git worktree references resolve inside the container. If you're running `docker run` manually with a worktree, you'll need that extra mount too.

> **Beads (br):** No special Docker networking needed. `br` uses SQLite + JSONL files, so it works identically inside and outside containers. No dolt server required.

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

### What's in the image

| Tool | Purpose |
|------|---------|
| **claude** | Claude Code CLI agent |
| **gh** | GitHub CLI — git push/pull auth via mounted credentials |
| **br** (beads_rust) | Agent-first issue tracker (SQLite + JSONL, no database server needed) |
| **conda** (miniforge) | Python environment and package management |
| **python3** | Python runtime |
| **node 20** | Node.js runtime (base image) |
| **git, curl, jq** | Standard dev utilities |

### Keeping br versions in sync

The host and Docker should run the same version of `br` to avoid JSONL format incompatibilities.

- **macOS host:** `curl -fsSL https://raw.githubusercontent.com/Dicklesworthstone/beads_rust/main/install.sh | bash` (upgrade with `br upgrade`)
- **Docker:** Uses the same install script automatically during build

Check both with `br --version`. If they drift, rebuild the Docker image.

## Permissions Philosophy

Two-tier approach:

**Local (project `.claude/settings.json`):** Granular allow list — specific commands are pre-approved, everything else prompts. This gives you control when running Claude directly on your machine.

**Docker (user `~/.claude-docker/settings.json`):** Broad `Bash(*)` allow — the container is already sandboxed, so the agent runs autonomously without permission prompts. A deny list still blocks destructive operations.

**Deny list (both tiers):** Recursive force-deletes of critical paths, force-pushing to main/master, disk-wiping commands, and system shutdown.
