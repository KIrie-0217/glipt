import argv
import gleam/io
import glipt/cmd/add
import glipt/cmd/clean
import glipt/cmd/project
import glipt/cmd/run
import glipt/cmd/script

const version = "1.1.0"

pub fn main() -> Nil {
  case argv.load().arguments {
    ["run", ..rest] -> run.execute(rest)
    ["add", ..rest] -> add.execute(rest)
    ["project", file] -> project.execute(file)
    ["script", ..rest] -> script.execute(rest)
    ["clean"] -> clean.execute()
    ["--version"] | ["-v"] -> io.println("glipt " <> version)
    ["--help"] | ["-h"] -> print_help()
    _ -> print_help()
  }
}

fn print_help() -> Nil {
  io.println("glipt " <> version <> " — A script runner for Gleam

Usage:
  glipt run [--target erlang|javascript] [-f function] <file.gleam> [-- args...]
  glipt add <package@version> <file.gleam>
  glipt project <file.gleam>
  glipt script [<file.gleam>]
  glipt clean
  glipt --version | -v
  glipt --help | -h

Options:
  -f function    Run a specific public function instead of main
  --target       Set compilation target (erlang or javascript)
  -- args...     Pass arguments to the script (use argv package to read)")
}
