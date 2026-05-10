import gleam/io
import gleam/result
import gleam/string
import glipt/internal/script
import glipt/internal/toml
import glipt/parser
import simplifile

pub fn execute(args: List(String)) -> Nil {
  let file_path = case args {
    [f] -> f
    _ -> "script.gleam"
  }
  case simplifile.read("gleam.toml") {
    Error(_) ->
      io.println_error(
        "Error: no gleam.toml found in current directory. Run from a Gleam project root.",
      )
    Ok(toml_content) -> {
      let deps = toml.parse_deps(toml_content)
      let gleam_constraint = toml.parse_gleam_version(toml_content)
      let meta =
        parser.ScriptMeta(
          gleam_constraint: gleam_constraint,
          project_paths: [],
          deps: deps,
        )
      let existing_source = simplifile.read(file_path) |> result.unwrap("")
      let new_content = script.reassemble(meta, existing_source)
      case simplifile.write(file_path, new_content) {
        Ok(Nil) -> io.println("Written directives to " <> file_path)
        Error(e) ->
          io.println_error("Error writing file: " <> string.inspect(e))
      }
    }
  }
}
