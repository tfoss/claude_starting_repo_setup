# CLAUDE.md — Project Development Guidelines

This file provides instructions and context for Claude Code when working in this repository.

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

- Use **beads** for issue and task tracking.
- Create a bead for each discrete task, bug, or feature.
- Reference bead IDs in commit messages when applicable.
- Update bead status as work progresses.

## Code Style & Conventions

- Follow the language's idiomatic conventions (PEP 8 for Python, StandardJS for JS, etc.).
- Use meaningful, descriptive names for functions, variables, and files.
- Keep functions short — if a function exceeds ~30 lines, consider breaking it up.
- Avoid deep nesting — extract helper functions or use early returns.
- No magic numbers or strings — use named constants.

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

## Workflow

1. **Check beads** for assigned tasks or pick the next priority item.
2. **Create a feature branch** from `main`.
3. **Write tests** for the new functionality.
4. **Implement** the solution with small, composable functions.
5. **Run all tests** and ensure they pass.
6. **Commit** with a clear message referencing the bead.
7. **Push** and create a PR for review.
