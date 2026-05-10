# glipt

> A script runner for Gleam — run .gleam files directly without adding them to src/.

## Project Overview

- Package name: `glipt`
- Language: Gleam (targets Erlang)
- Purpose: Execute standalone .gleam files as scripts, with automatic dependency resolution and caching
- CLI tool distributed as an escript

## Architecture

### Core workflow

```
script.gleam → parse deps → generate temp project → gleam build + run → output
                                    ↓
                            ~/.cache/glipt/<hash>/
```

### Module structure

| Module | Responsibility |
|---|---|
| `glipt` | CLI entry point, argument parsing |
| `glipt/runner` | Core execution logic: temp project creation, compilation, execution |
| `glipt/parser` | Parse `//! dep:` directives from script files |
| `glipt/project` | Detect host project, read gleam.toml, merge dependencies |
| `glipt/cache` | Content hashing, cache directory management, invalidation |
| `glipt/watcher` | File change detection for watch mode |

### Key design decisions

- **Cache by content hash**: SHA-256 of script content + sorted dependency list → cache key
- **Symlink over copy**: Link script into temp project's `src/` to avoid duplication
- **Explicit host project**: Only loaded when `//! project: <path>` is declared. Adds the host as a path dependency in the temp project's `gleam.toml`
- **Erlang-only**: The tool itself targets Erlang (for filesystem/process operations), but scripts can target either Erlang or JavaScript via `--target`

## Dependency resolution

Script-level dependencies are declared as structured comments:

```gleam
//! dep: package_name >= 1.0.0 and < 2.0.0
//! dep: another_package >= 0.5.0
```

If `//! project: <path>` is declared, the project at that path is added as a path dependency. Its transitive dependencies become available to the script. The script's own `//! dep:` constraints take precedence on conflict.

### Auto-inherit from host project

When a script has **no directives at all** (no `//! dep:`, `//! gleam:`, or `//! project:`) and resides inside a Gleam project (a parent directory contains `gleam.toml`), glipt automatically inherits that project's `[dependencies]`. This enables zero-config scripting within existing projects — scripts can use the project's Hex dependencies without any boilerplate. Adding any directive disables this behavior and gives the script full control.

## Caching strategy

```
~/.cache/glipt/
  <sha256-of-script-content>/
    gleam.toml
    src/
      script.gleam → (symlink to original)
    build/
      ...
```

Cache hit: hash matches → skip compilation → directly run from cached build.
Cache miss: create project, `gleam deps download`, `gleam build`, then run.

## Development Guidelines

### Development flow

Write implementation → write tests → pass tests → move on.

Always run `gleam format src test` before committing.

### Design principles

- Fast feedback: cached scripts run in <100ms
- Zero config: works without any setup in existing Gleam projects
- Transparent: if something fails, show the underlying gleam error as-is
- Minimal dependencies: only what's needed for file I/O, process execution, and hashing

### Testing strategy

- Unit tests for parser (dep directive extraction)
- Unit tests for project detection (gleam.toml finding)
- Integration tests: run actual scripts and verify output
- Edge cases: missing main function, syntax errors, missing deps, nested projects

### CLI interface

```
glipt run [--target erlang|javascript] <file.gleam>
glipt watch [--target erlang|javascript] <file.gleam>
glipt add <package[@version]> <file.gleam>  # add dep directive to script
glipt project <file.gleam>   # script → project (new directory)
glipt script [<file.gleam>]  # project → script (create or update)
glipt clean                  # clear cache
glipt --version
glipt --help
```

## Script ↔ Project conversion

Scripts and projects are two representations of the same thing. glipt provides bidirectional conversion between them.

### `glipt project <file.gleam>` — Script → Project

Graduates a script into a full Gleam project:

1. Parse `//! dep:` and `//! gleam:` directives from the script
2. Create a new directory named after the script (e.g., `script.gleam` → `./script/`)
3. Generate `gleam.toml` with extracted dependencies and Gleam version constraint
4. Create `src/` directory and place the script into it (keeping `//! dep:` lines intact)

The `//! dep:` lines are preserved in the source file. This keeps the script self-contained — it can still be run directly via `glipt run`. To resync directives with `gleam.toml` later, run `glipt script` again.

Use case: a prototype script has grown complex enough to warrant proper project structure, tests, and multi-module organization.

### `glipt script [<file.gleam>]` — Project → Script

Collapses a project's dependencies into script directives:

1. Read `[dependencies]` and `[gleam]` from `gleam.toml` in CWD
2. If `<file.gleam>` does not exist: create a new script file with `//! dep:` and `//! gleam:` header
3. If `<file.gleam>` exists: update/add directive header at the top of the file

Use case: sharing a quick utility without requiring recipients to clone a repo, or bootstrapping a new script with the current project's dependencies.

### Meta-directives

```gleam
//! gleam: >= 1.0.0
//! project: .
//! dep: gleam_stdlib >= 0.44.0 and < 2.0.0
//! dep: simplifile >= 2.0.0 and < 3.0.0
```

- `//! gleam:` — maps to the `[gleam]` version constraint in `gleam.toml`
- `//! project: <path>` — adds the project at `<path>` (relative to the script) as a path dependency. Without this directive, the host project is never implicitly loaded. This keeps scripts portable — if you move a script to a different location without a matching project, it won't silently break. The path `.` means "the Gleam project containing this script" (walks up to find `gleam.toml`).

### `glipt add <package[@version]> <file.gleam>` — Add dependency

Adds or updates a `//! dep:` directive in a script file:

- `glipt add gleam_json script.gleam` — version required in v0.1 (error if omitted)
- `glipt add gleam_json@1.0.0 script.gleam` — shorthand, expands to `>= 1.0.0 and < 2.0.0`
- `glipt add "gleam_json >= 1.0.0" script.gleam` — explicit constraint

If the package already has a directive, it is replaced with the new version constraint.

Future: when version is omitted, query Hex API for the latest version and auto-generate the constraint.

### Scope constraints

- Initially supports Hex packages with version constraints only
- git/path dependencies are out of scope for v0.1 (emit a warning and skip)
- Multi-module projects cannot be embedded via `glipt script` (error if `src/` contains more than one `.gleam` file)
