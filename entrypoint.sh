#!/bin/bash
# Fix git worktree paths for container environment.
# Worktrees have a .git file (not directory) pointing to the main repo's
# .git/worktrees/<name> via an absolute host path. The main repo's .git
# is mounted at its original host path (via claude-agent shell helper),
# but the reverse pointer (gitdir) needs updating to /workspace.
if [ -f /workspace/.git ]; then
    gitdir_path=$(sed 's/gitdir: //' /workspace/.git)
    if [ -d "$gitdir_path" ]; then
        echo "/workspace" > "$gitdir_path/gitdir"
    fi
fi

# Configure git to use gh for authentication (if gh is logged in)
if gh auth status &>/dev/null; then
    gh auth setup-git
fi

exec "$@"
