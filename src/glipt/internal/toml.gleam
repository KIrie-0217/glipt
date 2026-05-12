import gleam/list
import gleam/result
import gleam/string
import glipt/internal/project
import glipt/parser.{type Dependency, type ScriptMeta, Dependency}
import glipt/target.{type Target}

pub fn generate_runtime_toml(
  meta: ScriptMeta,
  target: Target,
  script_dir: String,
) -> String {
  let header =
    "name = \"glipt_script\"\nversion = \"0.0.0\"\ntarget = \""
    <> target.to_string(target)
    <> "\"\n"
  header
  <> gleam_section(meta)
  <> deps_section(ensure_stdlib(meta.deps), meta.project_paths, script_dir)
}

pub fn generate_project_toml(name: String, meta: ScriptMeta) -> String {
  let header = "name = \"" <> name <> "\"\nversion = \"0.1.0\"\n"
  header
  <> gleam_section(meta)
  <> "\n[dependencies]\n"
  <> format_dep_lines(ensure_stdlib(meta.deps))
  <> "\n[dev_dependencies]\ngleeunit = \">= 1.0.0 and < 2.0.0\"\n"
}

pub fn parse_deps(content: String) -> List(Dependency) {
  let lines = string.split(content, "\n")
  do_parse_section(lines, "[dependencies]")
}

pub fn parse_gleam_version(content: String) -> Result(String, Nil) {
  let lines = string.split(content, "\n")
  do_parse_gleam_version(lines, False)
}

fn gleam_section(meta: ScriptMeta) -> String {
  case meta.gleam_constraint {
    Ok(constraint) -> "\n[gleam]\nversion = \"" <> constraint <> "\"\n"
    Error(Nil) -> ""
  }
}

fn deps_section(
  deps: List(Dependency),
  project_paths: List(String),
  script_dir: String,
) -> String {
  let hex_lines = format_dep_lines(deps)
  let path_lines = resolve_path_deps(project_paths, script_dir)
  "\n[dependencies]\n" <> hex_lines <> path_lines
}

fn format_dep_lines(deps: List(Dependency)) -> String {
  let lines =
    list.map(deps, fn(dep) {
      case dep.constraint {
        "" -> dep.name <> " = \">= 0.0.0\""
        c ->
          case string.starts_with(c, "{") {
            True -> dep.name <> " = " <> c
            False -> {
              let clean = string.replace(c, "\"", "")
              dep.name <> " = \"" <> clean <> "\""
            }
          }
      }
    })
  case lines {
    [] -> ""
    _ -> string.join(lines, "\n") <> "\n"
  }
}

fn resolve_path_deps(project_paths: List(String), script_dir: String) -> String {
  let lines =
    list.filter_map(project_paths, fn(rel_path) {
      case project.resolve_project_path(script_dir, rel_path) {
        Ok(root) ->
          case project.read_project_name(root) {
            Ok(name) -> Ok(name <> " = { path = \"" <> root <> "\" }")
            Error(Nil) -> Error(Nil)
          }
        Error(Nil) -> Error(Nil)
      }
    })
  case lines {
    [] -> ""
    _ -> string.join(lines, "\n") <> "\n"
  }
}

fn ensure_stdlib(deps: List(Dependency)) -> List(Dependency) {
  let has_stdlib = list.any(deps, fn(dep) { dep.name == "gleam_stdlib" })
  case has_stdlib {
    True -> deps
    False -> [
      Dependency(name: "gleam_stdlib", constraint: ">= 0.44.0 and < 2.0.0"),
      ..deps
    ]
  }
}

fn do_parse_section(
  lines: List(String),
  section_header: String,
) -> List(Dependency) {
  case lines {
    [] -> []
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, section_header) {
        True -> collect_key_values(rest)
        False -> do_parse_section(rest, section_header)
      }
    }
  }
}

fn collect_key_values(lines: List(String)) -> List(Dependency) {
  case lines {
    [] -> []
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "[") {
        True -> []
        False ->
          case string.split_once(trimmed, "=") {
            Ok(#(key, value)) -> {
              let name = string.trim(key)
              let val = string.trim(value)
              case name {
                "" -> collect_key_values(rest)
                _ -> [
                  Dependency(name: name, constraint: val),
                  ..collect_key_values(rest)
                ]
              }
            }
            Error(Nil) -> collect_key_values(rest)
          }
      }
    }
  }
}

pub fn parse_manifest_packages(content: String) -> List(#(String, String)) {
  let lines = string.split(content, "\n")
  list.filter_map(lines, fn(line) {
    let trimmed = string.trim(line)
    case string.contains(trimmed, "name = \"") {
      True -> parse_manifest_line(trimmed)
      False -> Error(Nil)
    }
  })
}

fn parse_manifest_line(line: String) -> Result(#(String, String), Nil) {
  use name <- result.try(extract_field(line, "name"))
  use version <- result.map(extract_field(line, "version"))
  #(name, version)
}

fn extract_field(line: String, field: String) -> Result(String, Nil) {
  let prefix = field <> " = \""
  case string.split_once(line, prefix) {
    Ok(#(_, rest)) ->
      case string.split_once(rest, "\"") {
        Ok(#(value, _)) -> Ok(value)
        Error(Nil) -> Error(Nil)
      }
    Error(Nil) -> Error(Nil)
  }
}

fn do_parse_gleam_version(
  lines: List(String),
  in_gleam: Bool,
) -> Result(String, Nil) {
  case lines {
    [] -> Error(Nil)
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "[gleam]") {
        True -> do_parse_gleam_version(rest, True)
        False ->
          case in_gleam {
            False -> do_parse_gleam_version(rest, False)
            True ->
              case string.starts_with(trimmed, "[") {
                True -> Error(Nil)
                False ->
                  case string.starts_with(trimmed, "version") {
                    True ->
                      case string.split_once(trimmed, "=") {
                        Ok(#(_, value)) ->
                          Ok(value |> string.trim |> string.replace("\"", ""))
                        Error(Nil) -> do_parse_gleam_version(rest, True)
                      }
                    False -> do_parse_gleam_version(rest, True)
                  }
              }
          }
      }
    }
  }
}
