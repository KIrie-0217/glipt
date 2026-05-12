import gleam/io
import gleam/result
import gleam/string
import glipt/hex
import glipt/internal/script
import glipt/parser
import simplifile

pub fn execute(args: List(String)) -> Nil {
  case args {
    [package_spec, file_path] -> {
      let #(name, constraint) = parse_package_spec(package_spec)
      case resolve_constraint(name, constraint) {
        Ok(resolved) -> add_dep(file_path, name, resolved)
        Error(msg) -> io.println_error("Error: " <> msg)
      }
    }
    _ -> io.println_error("Usage: glipt add <package[@version]> <file.gleam>")
  }
}

fn resolve_constraint(
  name: String,
  constraint: String,
) -> Result(String, String) {
  case constraint {
    "" -> {
      use version <- result.map(hex.fetch_latest_version(name))
      parser.expand_shorthand_version(version)
    }
    c -> Ok(c)
  }
}

fn add_dep(file_path: String, name: String, constraint: String) -> Nil {
  let source = simplifile.read(file_path) |> result.unwrap("")
  let meta = parser.parse(source)
  let updated = parser.update_dep(meta, name, constraint)
  let new_content = script.reassemble(updated, source)
  case simplifile.write(file_path, new_content) {
    Ok(Nil) ->
      io.println("Added " <> name <> " " <> constraint <> " to " <> file_path)
    Error(e) -> io.println_error("Error writing file: " <> string.inspect(e))
  }
}

fn parse_package_spec(spec: String) -> #(String, String) {
  case string.contains(spec, "@") {
    True ->
      case string.split_once(spec, "@") {
        Ok(#(name, ver)) -> #(name, parser.expand_shorthand_version(ver))
        Error(Nil) -> #(spec, "")
      }
    False ->
      case string.split_once(spec, " ") {
        Ok(#(name, constraint)) -> #(name, constraint)
        Error(Nil) -> #(spec, "")
      }
  }
}
