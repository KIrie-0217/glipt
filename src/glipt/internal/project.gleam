import gleam/string
import glipt/internal/path
import simplifile

pub fn find_project_root(from: String) -> Result(String, Nil) {
  let toml_path = from <> "/gleam.toml"
  case simplifile.is_file(toml_path) {
    Ok(True) -> Ok(from)
    _ -> {
      let parent = path.dirname(from)
      case parent == from || parent == "." {
        True -> Error(Nil)
        False -> find_project_root(parent)
      }
    }
  }
}

pub fn resolve_project_path(
  script_dir: String,
  relative_path: String,
) -> Result(String, Nil) {
  let absolute = case string.starts_with(relative_path, "/") {
    True -> relative_path
    False -> script_dir <> "/" <> relative_path
  }
  find_project_root(absolute)
}

pub fn read_project_name(project_root: String) -> Result(String, Nil) {
  let toml_path = project_root <> "/gleam.toml"
  case simplifile.read(toml_path) {
    Ok(content) -> parse_name_from_toml(content)
    Error(_) -> Error(Nil)
  }
}

fn parse_name_from_toml(content: String) -> Result(String, Nil) {
  let lines = string.split(content, "\n")
  find_name_line(lines)
}

fn find_name_line(lines: List(String)) -> Result(String, Nil) {
  case lines {
    [] -> Error(Nil)
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "name") {
        True ->
          case string.split_once(trimmed, "=") {
            Ok(#(_, value)) ->
              Ok(value |> string.trim |> string.replace("\"", ""))
            Error(Nil) -> find_name_line(rest)
          }
        False -> find_name_line(rest)
      }
    }
  }
}
