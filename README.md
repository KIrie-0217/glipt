# glipt

[![Package Version](https://img.shields.io/hexpm/v/glipt)](https://hex.pm/packages/glipt)

A script runner for Gleam — run `.gleam` files directly without adding them to `src/`.

## Problem

Gleam requires all code to live in `src/` and be part of a project. There's no way to run a standalone `.gleam` file. This makes it awkward to:

- Write quick one-off scripts
- Run `examples/` files in a library project
- Share self-contained utilities without a full project structure

glipt is lightweight — only 4 runtime dependencies (`gleam_stdlib`, `argv`, `simplifile`, `shellout`).

## Installation

### Nix (recommended)

```sh
# Run directly
nix run github:KIrie-0217/glipt -- run script.gleam

# Install to profile
nix profile install github:KIrie-0217/glipt
```

### From source

```sh
git clone https://github.com/KIrie-0217/glipt.git
cd glipt
gleam export erlang-shipment
# Use build/erlang-shipment/entrypoint.sh run
```

## Usage

### Run a script

```sh
glipt run script.gleam
```

When run inside a Gleam project (a parent directory has `gleam.toml`), scripts with no `//!` directives automatically inherit the project's dependencies:

```sh
cd my_project/
glipt run scripts/check.gleam  # can use my_project's Hex deps
```

Adding any `//! dep:` or `//! project:` directive disables this and gives the script full control.

### Passing arguments to scripts

Scripts must define `pub fn main()` as the entry point. To accept arguments, use the `argv` package:

```gleam
//! dep: argv >= 1.0.0 and < 2.0.0

import argv
import gleam/io

pub fn main() {
  case argv.load().arguments {
    [name, ..] -> io.println("Hello, " <> name <> "!")
    [] -> io.println("Hello, world!")
  }
}
```

```sh
glipt run greet.gleam -- Alice
# Hello, Alice!
```

### Running a specific function

By default, `pub fn main()` is called. Use `-f` to run any other public zero-argument function:

```gleam
import gleam/io

pub fn main() {
  io.println("default")
}

pub fn migrate() {
  io.println("running migration!")
}
```

```sh
glipt run tasks.gleam -f migrate
# running migration!
```

### Declare dependencies

Add dependencies as directives at the top of the script:

```gleam
//! gleam: >= 1.0.0
//! dep: gleam_json >= 2.0.0 and < 3.0.0

import gleam/io
import gleam/json

pub fn main() {
  io.println("hello")
}
```

> [!NOTE]
> `//! dep:` directives use the same version constraint syntax as `gleam.toml`
> (e.g. `>= 1.0.0 and < 2.0.0`). Only packages published on
> [Hex](https://hex.pm) are supported — git and path dependencies cannot be
> declared via `//! dep:`. Use `//! project:` to reference a local project
> instead (see below).

### Add a dependency

```sh
glipt add gleam_json@2.0.0 script.gleam
```

This inserts `//! dep: gleam_json >= 2.0.0 and < 3.0.0` into the file.

### Use host project modules

When your script lives inside a Gleam project, declare it with `//! project:`:

```gleam
//! project: .
//! dep: gleam_stdlib >= 0.44.0 and < 2.0.0

import my_lib/parser
import gleam/io

pub fn main() {
  io.println(parser.do_something("test"))
}
```

Without `//! project:`, the host project is never implicitly loaded — scripts remain portable.

### Target selection

```sh
glipt run --target erlang script.gleam     # default
glipt run --target javascript script.gleam
```

### Script ↔ Project conversion

Graduate a script into a full project:

```sh
glipt project script.gleam
# Creates ./script/gleam.toml + ./script/src/script.gleam
```

Export a project's dependencies as script directives:

```sh
cd my_project/
glipt script tool.gleam
# Writes //! dep: lines into tool.gleam from gleam.toml
```

### Cache management

```sh
glipt clean  # Clear all cached builds
```

## CLI reference

```
glipt run [--target erlang|javascript] [-f function] <file.gleam> [-- args...]
glipt add <package@version> <file.gleam>
glipt project <file.gleam>
glipt script [<file.gleam>]
glipt clean
glipt --version
glipt --help
```

## How it works

1. Parse `//! dep:`, `//! gleam:`, and `//! project:` directives
2. Compute a SHA-256 cache key from script content + dependencies
3. On cache miss: create a temp project in `~/.cache/glipt/<hash>/`, run `gleam build`
4. On cache hit: skip compilation
5. Execute via `gleam run`

Subsequent runs of an unchanged script are near-instant.


## Development

```sh
nix develop        # or install gleam + erlang + rebar3 manually
gleam test         # unit + integration tests
gleam format src test
```

## License

MIT
