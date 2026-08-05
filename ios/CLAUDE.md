# CLAUDE.md — iOS Project Development Guidelines

This file provides instructions and context for Claude Code when working in this repository.

## CRITICAL: Shell Command Safety Rules

These rules override any conflicting defaults. Follow them exactly:

1. **NEVER use `swift -e` or `python -c` with multi-line code.** Write code to a file and execute the file.
2. **NEVER use heredocs (`<<EOF`) or `$(cat ...)` substitution in shell commands.** These trigger security warnings that block execution.
3. **For git commits**: Use `git commit -m "short message"` for single-line messages. For multi-line messages, use the Write tool to create `/tmp/commit_msg.txt`, then run `git commit -F /tmp/commit_msg.txt`.
4. **NEVER chain or combine commands.** Each Bash tool call must be a single, simple command. Forbidden patterns:
   - `&&` `||` `;` (chaining)
   - `|` (piping)
   - `2>&1` `2>/dev/null` `>/dev/null` (redirection)
   - `$()` or backticks (command substitution)

   Instead, make separate Bash tool calls for each command. **This is the #1 cause of permission prompts** — compound commands never match allow patterns and will always block.

## Platform & Language

- **Platform**: iOS (iPhone/iPad). Minimum deployment target defined in the Xcode project.
- **Language**: Swift. Use the latest stable Swift version supported by the project's Xcode.
- **UI Framework**: SwiftUI preferred for new views. UIKit is acceptable when SwiftUI lacks needed capability.
- **Build system**: Xcode / xcodebuild. Use `xcodebuild` from the command line for builds and tests.
- **Package management**: Swift Package Manager (SPM) via Xcode. Dependencies are declared in `Package.swift` or the Xcode project's package dependencies.

## Development Philosophy

### Code Architecture
- **Highly functionalized**: Break logic into small, single-responsibility functions and types. Each should do one thing well.
- **Composable**: Build complex behavior by composing simple, reusable components. Prefer composition over inheritance.
- **Protocol-oriented**: Use protocols to define interfaces. Prefer protocol conformance over class inheritance.
- **Value types where possible**: Prefer structs and enums over classes for model/data types. Use classes only when reference semantics are needed.
- **Pure where possible**: Prefer pure functions (no side effects, deterministic output) for core logic. Isolate side effects at the edges (ViewModels, Services).

### App Architecture
- **MVVM**: Use Model-View-ViewModel as the primary architecture pattern.
  - **Models**: Plain data types (structs/enums). No UI or business logic.
  - **Views**: SwiftUI views or UIKit view controllers. Declarative, minimal logic — delegate to ViewModels.
  - **ViewModels**: `@Observable` classes (or `ObservableObject` for older targets) that own business logic and state.
- **Services layer**: Network, persistence, and other I/O isolated behind protocol interfaces for testability.
- **Dependency injection**: Pass dependencies explicitly (initializer injection). Avoid singletons for anything stateful.

### Testing
- **Test everything**: Every ViewModel, Service, and utility function should have corresponding tests.
- **Test-first when practical**: Write tests before or alongside implementation, not as an afterthought.
- **Unit tests for logic**: ViewModels and Services get unit tests covering normal cases, edge cases, and error cases.
- **UI tests for critical flows**: Key user journeys get XCUITest coverage.
- **Tests are documentation**: Write tests that clearly demonstrate expected behavior and serve as usage examples.
- **Run tests before committing**: Always verify all tests pass before creating a commit.
- **Running tests from CLI**: Use `xcodebuild test -scheme <SchemeName> -destination 'platform=iOS Simulator,name=iPhone 16'` (adjust device as needed).

### Documentation
- **Doc comments on all public types and functions**: Use `///` doc comments. Describe what it does, parameters, return values, and throws.
- **README for the project**: Explain setup, build instructions, architecture overview, and how to run tests.
- **Keep docs close to code**: Documentation should live next to the code it describes.
- **Update docs with code changes**: When you change behavior, update documentation in the same commit.

## Version Control — Git

- Use **git** for all version control.
- Write clear, descriptive commit messages: summarize the "why" in the first line, details in the body if needed.
- Make **small, focused commits** — one logical change per commit.
- Use **feature branches** for new work. Branch from `main`.
- Branch naming: `feature/<description>`, `fix/<description>`, `refactor/<description>`.

## Issue Tracking — Beads (bd)

"Beads" is the issue/task tracker for this project. The CLI command is `bd`. When someone says "beads", "issues", or "tasks", they mean `bd`. To see all issues, run `bd list`. To see ready work, run `bd ready`.

- Create a bead for each discrete task, bug, or feature.
- Reference bead IDs in commit messages when applicable.
- Update bead status as work progresses.
- The `.beads` directory is in the repo root. If `bd` cannot find it, run `bd init` first (or `bd bootstrap` — see Syncing below).
- Use `bd list`, `bd show`, `bd create`, etc. — always use `bd`, not `beads`.
- **`bd create` syntax**: The title is a **positional argument**, NOT a `-t` flag. `-t`/`--type` sets the issue **type** (bug/feature/task/epic/chore/decision). Correct usage:
  - `bd create "My issue title"` — title is the first positional arg
  - `bd create "My title" -d "Description here"` — with description
  - `bd create "My title" -t feature -d "Description"` — with type and description
  - **WRONG**: `bd create -t "My title"` — this sets type to "My title", not the title
- **Storage**: `bd` uses an embedded, Dolt-backed database (`.beads/embeddeddolt/`). Nothing separate to install or run — no external `dolt` binary, no server, no ports. `bd init` auto-wires your git `origin` as the Dolt remote.
- **Syncing — there is no `bd sync` command.** After making changes, run `bd dolt push` to publish them. On a fresh clone or a brand-new worktree (no local database yet), run `bd bootstrap` — it clones the existing Dolt history from the git remote instead of starting an empty database. To pull others' changes into an existing local database, run `bd dolt pull`.
- If `bd` is not installed, install it: `brew install beads` (in Homebrew core — no tap needed; pulls in its `dolt`/`icu4c` build dependencies automatically)
- This project can switch to `br` (beads_rust — SQLite + JSONL, no embedded database) via `scripts/swarm-setup --tracker br`; see README.md "Picking an Issue Tracker".

## Xcode Project Conventions

- **One target per app**: Keep a single app target unless there's a clear need for extensions or frameworks.
- **Group by feature**: Organize files by feature/module, not by type. Each feature folder contains its Views, ViewModels, and Models.
- **No storyboards**: Use SwiftUI or programmatic UIKit. Storyboards and xibs cause merge conflicts and are harder to review.
- **Assets in Asset Catalogs**: Colors, images, and other assets go in `.xcassets`.
- **Localization**: Use String Catalogs (`.xcstrings`) for localized strings.
- **Info.plist**: Keep in the project directory. Add keys as needed for permissions, URL schemes, etc.

## Code Style & Conventions

- Follow **Swift API Design Guidelines** and Swift community conventions.
- Use meaningful, descriptive names for types, functions, variables, and files.
- Keep functions short — if a function exceeds ~30 lines, consider breaking it up.
- Avoid deep nesting — extract helper functions or use early returns / `guard`.
- No magic numbers or strings — use named constants or enums.
- Use `guard` for early exits and precondition checks.
- Mark types and functions with appropriate access control (`private`, `internal`, `public`).
- Use `// MARK: -` comments to organize sections within files.
- **No inline multi-line scripts in bash commands.** Write code to a file and execute it instead.

## Project Structure Conventions

```
<AppName>/
  App/                  # App entry point, AppDelegate, SceneDelegate
  Features/
    <FeatureName>/
      Views/            # SwiftUI views or UIKit view controllers
      ViewModels/       # ViewModels for this feature
      Models/           # Data models specific to this feature
  Services/             # Network, persistence, and other shared services
  Extensions/           # Swift extensions on Foundation/UIKit/SwiftUI types
  Utilities/            # Shared helpers, constants, formatters
  Resources/            # Assets.xcassets, Localizable.xcstrings, fonts, etc.
<AppName>Tests/         # Unit tests mirroring source structure
<AppName>UITests/       # UI tests for critical flows
```

## Output Files

- **Never overwrite existing output files.** When generating output files (exports, screenshots, data files, etc.), always use a unique name — e.g., by appending a timestamp, sequence number, or run identifier.
- Only overwrite an existing output file if the user explicitly requests it by name.

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
4. **Implement** the solution with small, composable functions/types.
5. **Build** with `xcodebuild` to verify compilation.
6. **Run all tests** and ensure they pass.
7. **Commit** with a clear message referencing the bead.
8. **Push** the branch to the remote.

## Agent Commit Policy

**You MUST commit your work.** When you complete a task, bead, or meaningful unit of work:
- Stage the relevant files and create a git commit.
- Write a clear commit message summarizing the change and referencing the bead ID if applicable.
- Push the branch to the remote.
- Do NOT leave uncommitted work. If tests pass and the task is done, commit and push immediately.
- If work is partially complete and you are stopping, commit what you have with a message noting it is work-in-progress.
- **Commit message format**: For short single-line messages, use `git commit -m "message"`. For longer or multi-line messages, first write the message to a file using the Write tool (e.g., `/tmp/commit_msg.txt`), then run `git commit -F /tmp/commit_msg.txt`. Do NOT use heredocs, `$(cat ...)` substitution, or inline multi-line strings — these trigger security warnings about command substitution and hidden arguments.
