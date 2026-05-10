import gleam/io
import gleam/string
import glipt/runner
import glipt/target

pub fn execute(args: List(String)) -> Nil {
  let #(t, file) = parse_args(args, target.Erlang)
  case file {
    "" -> {
      io.println_error("Error: no script file specified")
      io.println_error(
        "Usage: glipt run [--target erlang|javascript] <file.gleam>",
      )
    }
    p -> {
      case runner.run(p, t) {
        Ok(output) -> io.print(output)
        Error(runner.FileError(e)) ->
          io.println_error("File error: " <> string.inspect(e))
        Error(runner.BuildError(msg)) ->
          io.println_error("Build error:\n" <> msg)
        Error(runner.RunError(msg)) -> io.println_error("Run error:\n" <> msg)
      }
    }
  }
}

fn parse_args(args: List(String), t: target.Target) -> #(target.Target, String) {
  case args {
    ["--target", "erlang", ..rest] -> parse_args(rest, target.Erlang)
    ["--target", "javascript", ..rest] -> parse_args(rest, target.JavaScript)
    [file] -> #(t, file)
    _ -> #(t, "")
  }
}
