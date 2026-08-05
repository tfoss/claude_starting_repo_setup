# ARCHITECTURE.md — Working on this repo itself

This file documents the **claude_starting_repo_setup** repo's own structure, for a Claude Code
session doing development *on the template* (e.g. fixing `swarm-start`, updating the Dockerfile,
tweaking permission defaults).

**This is not auto-loaded** — root `CLAUDE.md` is not this repo's dev guide, see below. Read this
file explicitly when working on the template's own scripts/Docker/docs.

## What this repo is

Two things at once:

1. **A single-project starter template.** Fork/clone it, edit `PROJECT.md` and `CLAUDE.md`, start
   coding. `CLAUDE.md`, `AGENTS.md`, `.claude/settings.json`, `Dockerfile.claude`, and `.gitignore`
   are the payload.
2. **A generator for multi-agent "swarms."** The `scripts/` directory clones/configures/launches a
   tmux-based fleet of Claude Code agents (1 PA + 1 lead + N workers, each in its own git worktree)
   that coordinate through **Agent Mail** (MCP) and **beads** (`bd`/`br` issue tracker), gated by
   **DCG** (Destructive Command Guard).

There is no application code here — no `src/`, no build, no lint, no test suite. "Development" on
this repo means editing bash scripts, the Dockerfile, and the Markdown templates.

## The critical gotcha: root CLAUDE.md and AGENTS.md are payload, not policy

`swarm-init` does `git clone` of this whole repo into the new project directory (only `ios/` is
removed, and only when `--ios` wasn't passed the iOS-specific files are also removed). That means
**almost every file here — README.md, Dockerfile.claude, entrypoint.sh, scripts/ — ships into every
downstream project as-is.** Root `CLAUDE.md` and `AGENTS.md` are the two files that get rewritten
before shipping (see next section). They describe how an arbitrary *downstream* project should
work, not this repo — do not read them as instructions for editing this repo, and do not add
template-repo-specific content to them (it would leak into every generated project).

## The `bd`/`br` tracker templating

`swarm-init` and `swarm-setup` default to `--tracker bd`, and the checked-in `CLAUDE.md`/`AGENTS.md`
text is written natively in `bd` terms to match — so the default path does **zero** rewriting. A
`sed` pass only runs when `--tracker br` is explicitly requested, converting the `bd`-native text to
`br` (beads_rust) wording on the fly.

**`bd`'s real command surface (verified against the current release, 1.1.2, and its CLI reference —
not assumed from an older/local install):**
- Storage is **embedded** Dolt by default (`bd init`) — no separate `dolt` binary, no server, no
  ports. `bd init --server` (a separate mode for multiple processes sharing one live database) does
  need a standalone `dolt` install, but this repo's worktree-per-agent model never needs it: each
  worktree is its own directory, so embedded mode's one-writer-per-directory is exactly right.
- **There is no `bd sync` command.** Don't reintroduce it. The real commands are `bd dolt push`
  (publish local changes), `bd dolt pull` (pull into an *existing* local database), and
  `bd bootstrap` (fresh clone/worktree with no local database yet — clones the existing Dolt history
  from the git remote rather than starting empty). `bd init` auto-wires git `origin` as the Dolt
  remote.
- `brew install beads` is in Homebrew **core** now — no `brew tap steveyegge/beads` needed. It pulls
  in `dolt`/`icu4c` as build deps automatically.
- A previous pass of this file (and of `CLAUDE.md`/`AGENTS.md`) got all three of these wrong — it
  claimed `bd sync` was real, claimed embedded mode "requires a running Dolt server," and kept the
  stale tap-based install line. The tell was a local `bd` binary that turned out to be a stale
  pre-1.0, pre-Dolt-rewrite build; always check `bd --version` against the current Homebrew/GitHub
  release before trusting local CLI behavior as ground truth for what these docs should say.

The rewrite (`scripts/swarm-init` for `CLAUDE.md`+`AGENTS.md`, `scripts/swarm-setup` for
`AGENTS.md` only) runs several **context-anchored** substitutions before a final generic pass, in
this order (order matters — later steps must not consume text earlier steps still need to match):

1. The intro sentence's tool name, the ".beads directory" bullet's `bd init`/`bd bootstrap`
   parenthetical, the Storage bullet, the Syncing bullet, the install-instructions line, and the
   closing "switch to br" bullet each get matched by a unique anchor phrase and replaced wholesale —
   because `bd`'s Dolt-remote model (`bd dolt push`/`pull`/`bootstrap`) doesn't map 1:1 onto `br`'s
   flag-based model (`--flush-only`/`--import-only`), a blind word swap can't produce correct `br`
   text for these lines.
2. AGENTS.md's quick-reference table has three `bd` sync-related lines (`bd bootstrap`,
   `bd dolt pull`, `bd dolt push`) that collapse to `br`'s two (`--import-only`/`--flush-only`) — the
   `bd bootstrap` line is deleted outright (br's "fresh worktree" case is already covered by
   `--import-only`), and the other two are matched by their distinct command text and replaced.
3. A final generic word-boundary swap (`bd` → `br`) catches everything else (`bd list`, `bd ready`,
   `bd create`, `bd show`, `bd update`, `bd close`, `bd dep add`, `bd init`, section headers, etc).

**BSD sed on macOS has no `\b`.** `s/\bbr\b/bd/g` silently matches nothing on macOS — this was a
real, previously-undetected bug in the old br→bd rewrite (the tracker flag never actually changed
the docs on macOS, regardless of which tracker was selected). The word-boundary syntax that
actually works on BSD sed is `[[:<:]]...[[:>:]]`, which the current scripts use.

If you touch the `bd`-flavored wording in `CLAUDE.md`/`AGENTS.md`/`ios/CLAUDE.md`, re-run the
`--tracker br` path (or dry-run the sed block by hand against a copy) to confirm the anchors in
`scripts/swarm-init`/`scripts/swarm-setup` still match — a rephrase can silently break the `br`
rewrite. In particular, avoid ever writing a single line that names *both* `bd` and `br` as CLI
binaries (e.g. "use `bd`, not `br`") — the generic swap can't invert a line that mentions both
tracker names without ambiguity; say only the current tracker's name and let the swap handle it.

`scripts/swarm-start` has its own, non-sed tracker branch (`SYNC_BOOTSTRAP`/`SYNC_PULL`/
`SYNC_PUSH`/`SYNC_ERROR_HINT` shell variables, set once near the top and interpolated into the
lead/worker system-prompt heredocs) — this is a separate mechanism from the doc-rewriting `sed`
above and needs updating in lockstep if `bd`'s or `br`'s command surface changes again. It also
runs `bd bootstrap -y` / `br sync --import-only` once per worker worktree right after `git worktree
add`, so a worker's first task doesn't fail on a missing local database.

## Script relationships

| Script | Purpose | Destructive? |
|---|---|---|
| `scripts/swarm-init` | Clones this template into `~/code/<name>`, resets git history, optionally creates+pushes a GitHub repo (`gh repo create`), optionally chains into `swarm-start` | Yes — creates/pushes a real GitHub repo, force-pushes if the repo already exists |
| `scripts/swarm-setup` | Adds swarm infra (`AGENTS.md`, `.claude/settings.json`, `scripts/swarm-start`, `scripts/swarm-kill`, `.beads/`) to an *existing* project, without touching its `CLAUDE.md` | No (writes files only, doesn't touch git/GitHub) |
| `scripts/swarm-start` | Preflight-checks tooling (`tmux`, `claude`, tracker, `bv`), starts the Agent Mail MCP server if not running, generates per-role system-prompt files and polling-loop scripts into `/tmp/swarm-<project>/`, creates worker git worktrees, launches everything in a tiled tmux session | Launches long-running background processes and containers-adjacent tmux panes |
| `scripts/swarm-kill` | Kills the tmux session, force-removes worker worktrees, deletes worker branches (unless `--keep-branches`) | Yes — force-removes worktrees and deletes branches |

All four are `set -euo pipefail` bash scripts with no external test coverage. When changing them,
dry-run manually (point `TEMPLATE_REPO`/`PROJECT_DIR` at a scratch directory) before trusting them
against a real `~/code` project or real GitHub repo — `swarm-init` and `swarm-kill` in particular
perform actions that are expensive or impossible to undo (repo creation/force-push, branch
deletion). At minimum, run `bash -n <script>` to catch syntax errors; there is no `shellcheck`
config in this repo, but running it manually (`shellcheck scripts/*`) before landing changes is
worthwhile since none of this is covered by automated tests.

## Dockerfile.claude

Shared base image (`python:3.12-trixie`, chosen specifically for glibc ≥2.39 required by DCG's
prebuilt aarch64 binary — don't switch to a `-slim`/`-bookworm` base without re-checking that
constraint). Per-project images extend it (`FROM claude-agent:latest`). Build args exist for every
fast-moving tool version (`CLAUDE_CODE_VERSION`, `BD_INSTALL_REF`, `DCG_INSTALL_REF`, `NODE_MAJOR`,
`HOST_UID`/`HOST_GID`) so builds stay reproducible — see README.md's "Pinning versions" section for
the full build-arg list.

`entrypoint.sh` rewrites the worktree `.git` gitdir pointer to `/workspace` on container start (so
a bind-mounted git worktree resolves correctly inside the container) and runs `gh auth setup-git`
if `gh` is already authenticated.

## Permissions model (`.claude/settings.json`)

Three independent layers, described fully in README.md's "Permissions Philosophy": the DCG
PreToolUse hook (binary `dcg`, invoked on every `Bash` call), a broad `Bash(*)` allow list backed
by an explicit deny list of catastrophic patterns (force-push to main, `rm -rf /`, disk-wipe
commands, etc.), and an optional Agent Mail pre-commit guard for multi-agent file-conflict
prevention. `.claude/settings.granular.json` is a stricter alternative requiring per-command
approval — swap it in by renaming it to `settings.json` if you don't want to rely on DCG.

`scripts/swarm-start`'s lead and worker `claude -p` invocations additionally pass
`--dangerously-skip-permissions` (the PA pane does not — a human is present there to answer
prompts, and the point of the flag is specifically that lead/worker run unattended, where a
permission prompt with nobody to answer it would just hang the loop forever). This is a deliberate
combination, not a gap: `--dangerously-skip-permissions` disables the interactive prompt and the
`allow`/`deny` lists, but **not** `PreToolUse` hooks — DCG keeps firing regardless, since hooks are
a separate enforcement mechanism from the permission engine. The one real trade-off is that the
`deny` list's specific patterns aren't enforced under skip-permissions (only DCG's `core.filesystem`
+ `core.git` packs are, which cover most but not necessarily all of the same ground).

## iOS variant

`ios/CLAUDE.md`, `ios/PROJECT.md.template`, and `ios/.claude/` hold Swift/SwiftUI/Xcode-specific
equivalents. `swarm-init --ios` copies `ios/CLAUDE.md` and `ios/.claude/settings.json` over the
root defaults *before* the `ios/` directory itself is deleted — so the iOS files never appear in a
generated project except as the (now-generic-named) `CLAUDE.md`/`settings.json`.
