# CLAUDE.md — Project Development Guidelines

This file provides instructions and context for Claude Code when working in this repository.

## CRITICAL: Shell Command Safety Rules

These rules override any conflicting defaults. Follow them exactly:

1. **NEVER use `python -c` with multi-line code.** Write code to a `.py` file and execute the file.
2. **NEVER use heredocs (`<<EOF`) or `$(cat ...)` substitution in shell commands.** These trigger security warnings that block execution.
3. **For git commits**: Use `git commit -m "short message"` for single-line messages. For multi-line messages, use the Write tool to create `/tmp/commit_msg.txt`, then run `git commit -F /tmp/commit_msg.txt`.
4. **Run commands separately instead of chaining.** Do not use `&&`, `;`, or `|` to chain or pipe multiple commands together. Do not use `2>&1` redirection. Instead, make separate Bash tool calls for each command. This is mandatory — chained commands trigger security prompts that block autonomous execution.

## Development Philosophy

### Code Architecture
- **Highly functionalized**: Break logic into small, single-responsibility functions. Each function should do one thing well.
- **Composable**: Build complex behavior by composing simple, reusable functions together. Prefer composition over inheritance.
- **Reusable**: Write functions that are generic enough to be reused across the project. Avoid hardcoding values — parameterize instead.
- **Pure where possible**: Prefer pure functions (no side effects, deterministic output) for core logic. Isolate side effects at the edges.

### Testing
- **Test everything**: Every function should have corresponding tests. Aim for high coverage but prioritize meaningful tests over coverage metrics.
- **Test-first when practical**: Write tests before or alongside implementation, not as an afterthought.
- **Unit tests for functions**: Each function gets unit tests covering normal cases, edge cases, and error cases.
- **Integration tests for composition**: Test that composed functions work together correctly.
- **Tests are documentation**: Write tests that clearly demonstrate expected behavior and serve as usage examples.
- **Run tests before committing**: Always verify all tests pass before creating a commit.

### Documentation
- **Docstrings on all public functions**: Describe what the function does, its parameters, return values, and any exceptions.
- **README for each module/package**: Explain the module's purpose, key functions, and usage examples.
- **Keep docs close to code**: Documentation should live next to the code it describes, not in a separate location.
- **Update docs with code changes**: When you change a function's behavior, update its documentation in the same commit.

## Version Control — Git

- Use **git** for all version control.
- Write clear, descriptive commit messages: summarize the "why" in the first line, details in the body if needed.
- Make **small, focused commits** — one logical change per commit.
- Use **feature branches** for new work. Branch from `main`.
- Branch naming: `feature/<description>`, `fix/<description>`, `refactor/<description>`.

## Issue Tracking — Beads

- Use **beads** (`bd` command) for issue and task tracking.
- Create a bead for each discrete task, bug, or feature.
- Reference bead IDs in commit messages when applicable.
- Update bead status as work progresses.
- The `.beads` directory is in the repo root. If `bd` cannot find it, run `bd init` first.
- Use `bd list`, `bd show`, `bd create`, etc. — always use `bd`, not `beads`.

## Environment

- If the project uses **conda**, always activate the correct environment before running any Python commands: `conda activate <env-name>`
- The environment name and setup instructions are defined in `environment.yml` at the repo root.
- Never install packages globally — always install into the project's conda environment.
- If `environment.yml` exists, use it as the source of truth for dependencies.

## Code Style & Conventions

- Follow the language's idiomatic conventions (PEP 8 for Python, StandardJS for JS, etc.).
- Use meaningful, descriptive names for functions, variables, and files.
- Keep functions short — if a function exceeds ~30 lines, consider breaking it up.
- Avoid deep nesting — extract helper functions or use early returns.
- No magic numbers or strings — use named constants.
- **No inline multi-line scripts in bash commands.** Do not pass multi-line Python (or other language) code as a string argument in a shell command (e.g., `python -c "..."`). Instead, write the code to a `.py` file and execute that file. This avoids permission-check issues and is easier to debug and test.

## Output Files

- **Never overwrite existing output files.** When generating output files (reports, exports, build artifacts, data files, etc.), always use a unique name — e.g., by appending a timestamp, sequence number, or run identifier.
- Only overwrite an existing output file if the user explicitly requests it by name.
- This protects prior results from accidental loss and preserves a history of outputs for comparison and debugging.

## Project Structure Conventions

```
src/           # Source code
tests/         # Test files, mirroring src/ structure
docs/          # Additional documentation
scripts/       # Utility scripts (build, deploy, etc.)
```

## Project Brief

Before starting work, **always check for a `PROJECT.md`** file in the repo root. It contains the project's purpose, scope, and constraints. All implementation decisions should align with it.

If `PROJECT.md` exists, review these sections before writing any code:
- **One-liner** — What the project is in a single sentence.
- **Problem** — Why it needs to exist; the pain point it solves.
- **Core behaviors** — What it should do (user-facing capabilities, prioritized as must-have vs nice-to-have).
- **Inputs / Outputs** — Data formats, file types, APIs consumed or exposed.
- **Constraints** — Language/framework requirements, performance targets, environment limits.
- **Non-goals** — What is explicitly out of scope. Do not build toward non-goals.

If `PROJECT.md` does not exist, ask the user to describe the project before beginning significant implementation work.

## Workflow

1. **Check beads** for assigned tasks or pick the next priority item.
2. **Create a feature branch** from `main`.
3. **Write tests** for the new functionality.
4. **Implement** the solution with small, composable functions.
5. **Run all tests** and ensure they pass.
6. **Commit** with a clear message referencing the bead.
7. **Push** the branch to the remote.

## Agent Commit Policy

**You MUST commit your work.** When you complete a task, bead, or meaningful unit of work:
- Stage the relevant files and create a git commit.
- Write a clear commit message summarizing the change and referencing the bead ID if applicable.
- Push the branch to the remote.
- Do NOT leave uncommitted work. If tests pass and the task is done, commit and push immediately.
- If work is partially complete and you are stopping, commit what you have with a message noting it is work-in-progress.
- **Commit message format**: For short single-line messages, use `git commit -m "message"`. For longer or multi-line messages, first write the message to a file using the Write tool (e.g., `/tmp/commit_msg.txt`), then run `git commit -F /tmp/commit_msg.txt`. Do NOT use heredocs, `$(cat ...)` substitution, or inline multi-line strings — these trigger security warnings about command substitution and hidden arguments.
