import argv
import gleam/io
import glipt/cmd/add
import glipt/cmd/clean
import glipt/cmd/project
import glipt/cmd/run
import glipt/cmd/script

const version = "1.0.0"

pub fn main() -> Nil {
  case argv.load().arguments {
    ["run", ..rest] -> run.execute(rest)
    ["add", ..rest] -> add.execute(rest)
    ["project", file] -> project.execute(file)
    ["script", ..rest] -> script.execute(rest)
    ["clean"] -> clean.execute()
    ["--version"] -> io.println("glipt " <> version)
    ["--help"] -> print_help()
    _ -> print_help()
  }
}

fn print_help() -> Nil {
  io.println("glipt " <> version <> " — A script runner for Gleam

Usage:
  glipt run [--target erlang|javascript] <file.gleam>
  glipt add <package@version> <file.gleam>
  glipt project <file.gleam>
  glipt script [<file.gleam>]
  glipt clean
  glipt --version
  glipt --help")
}
