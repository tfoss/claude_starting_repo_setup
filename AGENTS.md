# AGENTS.md — Multi-Agent Coordination Protocol

This file defines how agents coordinate when working in parallel on this codebase. Every agent must read and follow these rules. They apply whether you are a team lead, a teammate, or an autonomous agent.

---

## Roles

### Lead Agent
The lead agent is responsible for planning, task routing, and coordination. The lead:
- Uses `bv` to analyze the dependency graph and determine optimal task ordering
- Creates and assigns beads to worker agents
- Monitors progress and resolves blockers
- Merges completed work

### Worker Agents
Worker agents execute tasks assigned by the lead (or self-claimed from `br ready`). Workers:
- Claim tasks, reserve files, do the work, release, and report back
- Communicate via Agent Mail, not by modifying shared files
- Never merge to main without lead approval

---

## Identity and Session Startup

At the start of every session:

1. **Register with Agent Mail.** Call `macro_start_session` with this project's absolute path. This gives you an identity (e.g., "GreenCastle"), registers you, and fetches your inbox.
2. **Check your inbox.** Read any messages from other agents. Acknowledge messages that require it.
3. **Check beads.** Run `br ready` to see what work is available.

---

## Lead Agent: Task Routing with BV

<!-- BEGIN_BV_BLURB -->

### Using bv as an AI sidecar

bv is a graph-aware triage engine for Beads projects (.beads/issues.jsonl). Instead of parsing JSONL or hallucinating graph traversal, use robot flags for deterministic, dependency-aware outputs with precomputed metrics (PageRank, betweenness, critical path, cycles, HITS, eigenvector, k-core).

**Scope boundary:** bv handles *what to work on* (triage, priority, planning). For agent-to-agent coordination (messaging, work claiming, file reservations), use Agent Mail.

**CRITICAL: Use ONLY `--robot-*` flags. Bare `bv` launches an interactive TUI that blocks your session.**

#### The Workflow: Start With Triage

**`bv --robot-triage` is your single entry point.** It returns everything you need in one call:
- `quick_ref`: at-a-glance counts + top 3 picks
- `recommendations`: ranked actionable items with scores, reasons, unblock info
- `quick_wins`: low-effort high-impact items
- `blockers_to_clear`: items that unblock the most downstream work
- `project_health`: status/type/priority distributions, graph metrics
- `commands`: copy-paste shell commands for next steps

```bash
bv --robot-triage                    # THE MEGA-COMMAND: start here
bv --robot-next                      # Minimal: just the single top pick + claim command

# Token-optimized output (TOON) for lower LLM context usage:
bv --robot-triage --format toon
export BV_OUTPUT_FORMAT=toon
bv --robot-next
```

#### Planning and Assignment

| Command | Returns |
|---------|---------|
| `--robot-plan` | Parallel execution tracks with `unblocks` lists |
| `--robot-priority` | Priority misalignment detection with confidence |
| `--robot-forecast <id\|all>` | ETA predictions with dependency-aware scheduling |
| `--robot-capacity` | Capacity simulation and completion projection |

#### Graph Analysis

| Command | Returns |
|---------|---------|
| `--robot-insights` | Full metrics: PageRank, betweenness, HITS, eigenvector, critical path, cycles, k-core, articulation points, slack |
| `--robot-label-health` | Per-label health: `health_level`, `velocity_score`, `staleness`, `blocked_count` |
| `--robot-label-flow` | Cross-label dependency: `flow_matrix`, `dependencies`, `bottleneck_labels` |
| `--robot-label-attention` | Attention-ranked labels by: (pagerank x staleness x block_impact) / velocity |
| `--robot-alerts` | Stale issues, blocking cascades, priority mismatches |
| `--robot-suggest` | Hygiene: duplicates, missing deps, label suggestions, cycle breaks |

#### History and Change Tracking

| Command | Returns |
|---------|---------|
| `--robot-history` | Bead-to-commit correlations |
| `--robot-diff --diff-since <ref>` | Changes since ref: new/closed/modified, cycles introduced/resolved |
| `--robot-burndown <sprint>` | Sprint burndown, scope changes, at-risk items |

#### Scoping and Filtering

```bash
bv --robot-plan --label backend          # Scope to label's subgraph
bv --robot-insights --as-of HEAD~30      # Historical point-in-time
bv --recipe actionable --robot-plan      # Pre-filter: ready to work (no blockers)
bv --recipe high-impact --robot-triage   # Pre-filter: top PageRank scores
bv --robot-triage --robot-triage-by-track  # Group by parallel work streams
bv --robot-triage --robot-triage-by-label  # Group by domain
```

#### jq Quick Reference

```bash
bv --robot-triage | jq '.quick_ref'                  # At-a-glance summary
bv --robot-triage | jq '.recommendations[0]'         # Top recommendation
bv --robot-plan | jq '.plan.summary.highest_impact'   # Best unblock target
bv --robot-insights | jq '.Cycles'                    # Circular deps (must fix!)
```

<!-- END_BV_BLURB -->

### Lead Agent Workflow

1. **Triage:** Run `bv --robot-triage` to get ranked recommendations.
2. **Plan:** Run `bv --robot-plan` to see parallel execution tracks.
3. **Assign:** For each track, assign beads to available worker agents via Agent Mail. Include the bead ID, expected files, and any context.
4. **Monitor:** Periodically check `bv --robot-alerts` for blockers and `fetch_inbox` for worker messages.
5. **Unblock:** When workers report blockers, re-triage with `bv --robot-triage` and reassign or reprioritize.
6. **Merge:** Review completed branches and merge to main. Run `bv --robot-diff --diff-since <last-merge>` to verify what changed.

---

## Agent Mail: Coordination Layer

<!-- BEGIN_AGENT_MAIL_BLURB -->

### MCP Agent Mail: coordination for multi-agent workflows

What it is:
- A mail-like layer that lets coding agents coordinate asynchronously via MCP tools and resources.
- Provides identities, inbox/outbox, searchable threads, and advisory file reservations, with human-auditable artifacts in Git.

Why it's useful:
- Prevents agents from stepping on each other with explicit file reservations (leases) for files/globs.
- Keeps communication out of your token budget by storing messages in a per-project archive.
- Offers quick reads (`resource://inbox/...`, `resource://thread/...`) and macros that bundle common flows.

How to use effectively:
1. **Register:** Call `ensure_project`, then `register_agent` using this repo's absolute path as `project_key`.
2. **Reserve files before you edit:** `file_reservation_paths(project_key, agent_name, ["src/**"], ttl_seconds=3600, exclusive=true)` to signal intent and avoid conflict.
3. **Communicate with threads:** Use `send_message(..., thread_id="FEAT-123")`; check inbox with `fetch_inbox` and acknowledge with `acknowledge_message`.
4. **Read fast:** `resource://inbox/{Agent}?project=<abs-path>&limit=20` or `resource://thread/{id}?project=<abs-path>&include_bodies=true`.
5. **Set `AGENT_NAME`** in your environment so the pre-commit guard can block commits that conflict with others' active exclusive file reservations.

Macros vs granular tools:
- **Prefer macros** when you want speed: `macro_start_session`, `macro_prepare_thread`, `macro_file_reservation_cycle`, `macro_contact_handshake`.
- **Use granular tools** when you need control: `register_agent`, `file_reservation_paths`, `send_message`, `fetch_inbox`, `acknowledge_message`.

Common pitfalls:
- "from_agent not registered": always `register_agent` in the correct `project_key` first.
- "FILE_RESERVATION_CONFLICT": adjust patterns, wait for expiry, or use a non-exclusive reservation.

<!-- END_AGENT_MAIL_BLURB -->

---

## Safety: Destructive Command Guard (DCG)

All agents in this project run behind DCG, a PreToolUse hook that intercepts every Bash command and blocks destructive operations before they execute. DCG is configured in `.claude/settings.json` and fires automatically — agents do not need to invoke it.

### What DCG protects against
- Recursive force-deletes (`rm -rf /`, `rm -rf .git`, etc.)
- Destructive git operations (`git reset --hard`, `git push --force`, `git clean -fd`)
- Dangerous filesystem operations (disk writes, permission clobbering)
- Inline script attacks (heredocs, `python -c "os.remove(...)"`)

### What agents need to know
- **DCG is transparent.** Safe commands pass through with sub-millisecond overhead. You will only notice it when it blocks something.
- **If DCG blocks your command**, do not try to work around it. The command was blocked for a reason. Find an alternative approach:
  - Instead of `rm -rf dir/`, remove specific files or use `git clean` on untracked files only.
  - Instead of `git reset --hard`, use `git stash` or `git checkout <file>`.
  - Instead of `git push --force`, use `git push --force-with-lease`.
- **Do not disable or bypass DCG.** The `DCG_BYPASS` env var and `dcg allow-once` exist for human operators, not agents.
- **Additional security packs** can be enabled in `~/.config/dcg/config.toml` for database, cloud, Kubernetes, and other tooling protection.

### Enabled packs (default)
- `core.filesystem` — blocks destructive file operations
- `core.git` — blocks destructive git operations

### Testing a command (lead agent / debug only)
```bash
dcg test "rm -rf node_modules"    # Check if a command would be blocked
dcg explain "git reset --hard"    # Detailed decision trace
```

---

## Claiming Work

1. Run `br ready` to see open, unblocked tasks.
2. Pick a task (or use the one assigned to you by the lead).
3. Run `br update <id> --status=in_progress` to claim it.
4. **Send a message** to all agents announcing what you're working on. Include the bead ID and which files/directories you expect to touch.
5. **Reserve the files** you plan to edit using `file_reservation_paths` with `exclusive=true`. Use glob patterns for directories (e.g., `src/auth/**`). Set a reasonable TTL.
6. If reservations conflict, coordinate with the holding agent via Agent Mail. Do not proceed with edits on conflicted files.

## File Reservation Rules

- **Always reserve before editing.** Call `file_reservation_paths` with `exclusive=true` for files you will modify.
- **Use shared reservations** (`exclusive=false`) for files you only need to read.
- **Reserve at the narrowest scope possible.** Prefer `src/auth/oauth.py` over `src/**`.
- **Renew if your work takes longer than expected.** Call `renew_file_reservations` before TTL expires.
- **Release immediately when done.** Call `release_file_reservations` as soon as you finish editing — don't wait for session end.
- **Never force-release another agent's reservation** unless you have confirmed (via Agent Mail) that the agent is unresponsive.

## Working on Tasks

1. Create a feature branch: `git checkout -b feature/<bead-id>-<short-description>`
2. Write tests first when practical.
3. Implement in small, composable functions (see CLAUDE.md for code style).
4. Run tests before committing.
5. Commit frequently with clear messages referencing the bead ID.

## Communication Protocol

Use Agent Mail for all inter-agent communication:

- **Starting work:** Send a message announcing the bead ID and files you'll touch.
- **Blocking issues:** If your task depends on another agent's work, message them directly and add a dependency in beads (`br dep add <your-id> <their-id>`).
- **Completing work:** Send a message when you finish. Include what changed and any downstream tasks now unblocked.
- **Acknowledge** messages that have `ack_required=true`. Other agents may be waiting on your response.

## Completing Tasks

1. Ensure all tests pass.
2. Release your file reservations.
3. Close the bead: `br close <id>`
4. Sync beads to JSONL: `br sync --flush-only`
5. Commit everything (code + `.beads/` changes).
6. Push your feature branch.
7. Create a PR: `gh pr create --title "<bead-id>: description" --body "summary of changes"`
8. Send a completion message via Agent Mail to the lead agent — include the **PR number/URL** and bead ID.
9. Wait for the lead agent to review and merge (check `fetch_inbox` for feedback).
10. If the lead requests changes, fix them, push, and notify via Agent Mail.
11. Once merged, check `br ready` for the next available task.

## Code Review (Lead Agent)

All worker PRs must be reviewed before merging. The lead agent:

1. **Reads the diff:** `gh pr diff <PR-number>`
2. **Checks for:**
   - Does the code match what was requested in the bead?
   - Are there tests covering the key functionality?
   - Any obvious bugs, security issues, or missing error handling?
   - Does it follow the project's code style (see CLAUDE.md)?
   - Are there files that shouldn't have been modified?
3. **If issues found:** `gh pr review <PR-number> --request-changes --body "feedback"` and notify the worker via Agent Mail with specific fixes needed.
4. **If approved:** `gh pr review <PR-number> --approve` then `gh pr merge <PR-number> --merge`

## Session End Checklist

Before ending any session:

1. `git status` — check for uncommitted work.
2. Stage and commit any remaining changes.
3. `br sync --flush-only` — export beads to JSONL.
4. `git add .beads/` — stage beads changes.
5. Commit and push.
6. Release all file reservations.
7. Send a session-end message via Agent Mail summarizing what you accomplished.

## Conflict Resolution

- **File conflicts:** Do not force-resolve merge conflicts. Message the other agent to coordinate. If unresponsive (no ack within 10 minutes), resolve yourself and document in the bead.
- **Task conflicts:** First agent to set `in_progress` owns it. Others pick a different task.
- **Dependency cycles:** If discovered, message the lead agent and pause affected tasks until resolved. The lead can run `bv --robot-insights | jq '.Cycles'` to diagnose.

## Quick Reference

### Beads (br)
```bash
br ready                    # Show actionable work
br list --status=open       # All open issues
br show <id>                # Full details + dependencies
br create "Title" -d "..."  # Create new task
br update <id> --status=in_progress  # Claim task
br close <id>               # Complete task
br dep add <id> <blocks-id> # Add dependency
br sync --flush-only        # Export DB to JSONL for git
br sync --import-only       # Import JSONL after git pull
```

### BV (lead agent)
```bash
bv --robot-triage            # Full triage with ranked recommendations
bv --robot-next              # Single top pick
bv --robot-plan              # Parallel execution tracks
bv --robot-alerts            # Blockers and issues needing attention
bv --robot-suggest           # Hygiene suggestions
bv --robot-diff --diff-since <ref>  # What changed since last check
```

### Agent Mail
```
macro_start_session          # Register + reserve + inbox (do this first)
send_message                 # Send to one or all agents
reply_message                # Reply in-thread
fetch_inbox                  # Check for new messages
acknowledge_message          # Ack required messages
file_reservation_paths       # Reserve files before editing
release_file_reservations    # Release when done editing
renew_file_reservations      # Extend TTL if work takes longer
install_precommit_guard      # Install git hook (once per repo)
```

### DCG (automatic — no agent action needed)
```bash
dcg test "<command>"         # Check if command would be blocked (debug)
dcg explain "<command>"      # Detailed decision trace (debug)
dcg packs                    # List available security packs
```
