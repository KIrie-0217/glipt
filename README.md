# glipt

A script runner for Gleam — run `.gleam` files directly without adding them to `src/`.

## Problem

Gleam requires all code to live in `src/` and be part of a project. There's no way to run a standalone `.gleam` file. This makes it awkward to:

- Run `examples/` files in a library project
- Write quick one-off scripts
- Verify code snippets during development

## Solution

```sh
glipt run script.gleam
```

glipt creates a temporary project context, compiles, and executes the script, then cleans up. If run inside an existing Gleam project, it automatically makes that project's dependencies available to the script.

## Installation

```sh
gleam add --dev glipt
```

Or install globally as an escript:

```sh
gleam run -m glipt/install
```

## Usage

### Run a script

```sh
glipt run examples/basic.gleam
```

### Run with dependencies from current project

When inside a Gleam project directory, glipt automatically detects `gleam.toml` and makes all dependencies available:

```sh
cd my_project/
glipt run scripts/check.gleam  # can import my_project's deps
```

### Declare script-level dependencies

Add dependencies in a comment at the top of the script:

```gleam
//! dep: gliff >= 1.0.0
//! dep: gleam_json >= 2.0.0

import gliff
import gleam/io

pub fn main() {
  let edits = gliff.diff("hello", "world")
  io.println("done")
}
```

### Target selection

```sh
glipt run --target erlang script.gleam   # default
glipt run --target javascript script.gleam
```

### Watch mode

Re-run automatically when the script file changes:

```sh
glipt watch script.gleam
```

## How It Works

1. Parse the script file for `//! dep:` directives
2. If inside a Gleam project, read its `gleam.toml` for additional dependencies
3. Create a temporary project in a cache directory (`~/.cache/glipt/<hash>/`)
4. Symlink or copy the script as `src/script.gleam`
5. Generate a `gleam.toml` with resolved dependencies
6. Run `gleam run -m script`
7. Cache the build for subsequent runs (invalidated by script content hash)

## Caching

glipt caches compiled builds keyed by:
- Script content hash (SHA-256)
- Dependency set

Subsequent runs of the same script skip compilation entirely, making execution near-instant after the first run.

## Limitations

- Scripts must define `pub fn main()` as the entry point
- Importing modules from the host project's `src/` is not supported (only its dependencies)
- The first run of a script incurs a compilation cost (~1-2 seconds)

## Development

```sh
gleam test
gleam run -m glipt -- run example.gleam
```

## License

MIT
