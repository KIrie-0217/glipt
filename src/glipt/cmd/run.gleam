import gleam/io
import gleam/string
import glipt/runner
import glipt/target

pub fn execute(args: List(String)) -> Nil {
  let #(t, func, file, script_args) = parse_args(args, target.Erlang, "main")
  case file {
    "" -> {
      io.println_error("Error: no script file specified")
      io.println_error(
        "Usage: glipt run [--target erlang|javascript] [-f function] <file.gleam> [-- args...]",
      )
    }
    p -> {
      let opts =
        runner.RunOptions(
          script_path: p,
          target: t,
          function: func,
          args: script_args,
        )
      case runner.run(opts) {
        Ok(Nil) -> Nil
        Error(runner.FileError(e)) ->
          io.println_error("File error: " <> string.inspect(e))
        Error(runner.BuildError(msg)) ->
          io.println_error("Build error:\n" <> msg)
        Error(runner.RunError(msg)) -> io.println_error("Run error:\n" <> msg)
      }
    }
  }
}

fn parse_args(
  args: List(String),
  t: target.Target,
  func: String,
) -> #(target.Target, String, String, List(String)) {
  case args {
    ["--target", "erlang", ..rest] -> parse_args(rest, target.Erlang, func)
    ["--target", "javascript", ..rest] ->
      parse_args(rest, target.JavaScript, func)
    ["-f", f, ..rest] -> parse_args(rest, t, f)
    [file, "--", ..script_args] -> #(t, func, file, script_args)
    [file, ..script_args] -> #(t, func, file, script_args)
    _ -> #(t, func, "", [])
  }
}
