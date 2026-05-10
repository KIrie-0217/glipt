# glipt

[![Package Version](https://img.shields.io/hexpm/v/glipt)](https://hex.pm/packages/glipt)

A script runner for Gleam — run `.gleam` files directly without adding them to `src/`.

## Installation

```sh
# Nix
nix run github:KIrie-0217/glipt -- run script.gleam
nix profile install github:KIrie-0217/glipt

# From source
git clone https://github.com/KIrie-0217/glipt.git && cd glipt
gleam export erlang-shipment
./build/erlang-shipment/entrypoint.sh run
```

## Quick start

```sh
glipt run script.gleam                   # run a script
glipt run script.gleam -f migrate        # run a specific function
glipt run script.gleam -- arg1 arg2      # pass arguments
glipt add gleam_json@2.0.0 script.gleam  # add a dependency
```

## Script directives

```gleam
//! gleam: >= 1.0.0
//! project: .
//! dep: gleam_json >= 2.0.0 and < 3.0.0
//! dep: simplifile >= 2.0.0 and < 3.0.0

import gleam/io

pub fn main() {
  io.println("hello")
}
```

| Directive | Purpose |
|---|---|
| `//! gleam:` | Gleam version constraint |
| `//! project: <path>` | Add a local project as path dependency (modules importable) |
| `//! dep: <pkg> <constraint>` | Hex package dependency |

> [!NOTE]
> `//! dep:` only supports Hex packages. Use `//! project:` for local dependencies.

Scripts with **no directives** inside a Gleam project automatically inherit that project's dependencies (including path/git deps).

## Function selection

By default `pub fn main()` runs. Use `-f` to call any public zero-argument function:

```gleam
import gleam/io

pub fn main() { io.println("default") }
pub fn migrate() { io.println("migrating!") }
pub fn seed() { io.println("seeding!") }
```

```sh
glipt run tasks.gleam -f migrate
```

## Arguments

Pass arguments via `--`. Read them with the `argv` package:

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
```

## Script ↔ Project conversion

```sh
glipt project script.gleam   # → ./script/gleam.toml + ./script/src/script.gleam
glipt script tool.gleam      # ← writes //! dep: lines from gleam.toml
```

## CLI reference

```
glipt run [--target erlang|javascript] [-f function] <file.gleam> [-- args...]
glipt add <package@version> <file.gleam>
glipt project <file.gleam>
glipt script [<file.gleam>]
glipt clean
glipt --version
```

## How it works

1. Parse directives → compute SHA-256 cache key
2. Cache miss: generate temp project in `~/.cache/glipt/<hash>/`, build
3. Cache hit: skip build
4. Execute via `gleam run`

Subsequent runs of unchanged scripts are near-instant.

## Development

```sh
nix develop
gleam test
gleam format src test
```

## License

MIT
