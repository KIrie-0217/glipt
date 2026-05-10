import gleam/int
import gleam/list
import gleam/string

pub type Dependency {
  Dependency(name: String, constraint: String)
}

pub type ScriptMeta {
  ScriptMeta(
    gleam_constraint: Result(String, Nil),
    project_paths: List(String),
    deps: List(Dependency),
  )
}

pub fn parse(source: String) -> ScriptMeta {
  let lines = string.split(source, "\n")
  let directive_lines =
    list.filter(lines, fn(line) { string.starts_with(string.trim(line), "//!") })

  let gleam_constraint = parse_gleam_directive(directive_lines)
  let project_paths = parse_project_directives(directive_lines)
  let deps = parse_dep_directives(directive_lines)

  ScriptMeta(
    gleam_constraint: gleam_constraint,
    project_paths: project_paths,
    deps: deps,
  )
}

fn parse_gleam_directive(lines: List(String)) -> Result(String, Nil) {
  list.find_map(lines, fn(line) {
    let trimmed = string.trim(line)
    let rest = string.trim(drop_prefix(trimmed, "//!"))
    case string.starts_with(rest, "gleam:") {
      True -> Ok(string.trim(drop_prefix(rest, "gleam:")))
      False -> Error(Nil)
    }
  })
}

fn parse_project_directives(lines: List(String)) -> List(String) {
  list.filter_map(lines, fn(line) {
    let trimmed = string.trim(line)
    let rest = string.trim(drop_prefix(trimmed, "//!"))
    case string.starts_with(rest, "project:") {
      True -> {
        let path = string.trim(drop_prefix(rest, "project:"))
        case path {
          "" -> Error(Nil)
          p -> Ok(p)
        }
      }
      False -> Error(Nil)
    }
  })
}

fn parse_dep_directives(lines: List(String)) -> List(Dependency) {
  list.filter_map(lines, fn(line) {
    let trimmed = string.trim(line)
    let rest = string.trim(drop_prefix(trimmed, "//!"))
    case string.starts_with(rest, "dep:") {
      True -> {
        let body = string.trim(drop_prefix(rest, "dep:"))
        parse_dep_body(body)
      }
      False -> Error(Nil)
    }
  })
}

fn parse_dep_body(body: String) -> Result(Dependency, Nil) {
  case string.trim(body) {
    "" -> Error(Nil)
    trimmed -> {
      case string.split_once(trimmed, " ") {
        Ok(#(name, constraint)) ->
          Ok(Dependency(
            name: string.trim(name),
            constraint: string.trim(constraint),
          ))
        Error(Nil) -> Ok(Dependency(name: trimmed, constraint: ""))
      }
    }
  }
}

pub fn strip_directives(source: String) -> String {
  let lines = string.split(source, "\n")
  let filtered =
    list.filter(lines, fn(line) {
      !string.starts_with(string.trim(line), "//!")
    })
  let result = string.join(filtered, "\n")
  let trimmed = string.trim(result)
  case trimmed {
    "" -> ""
    s -> s <> "\n"
  }
}

pub fn format_directives(meta: ScriptMeta) -> String {
  let gleam_line = case meta.gleam_constraint {
    Ok(constraint) -> ["//! gleam: " <> constraint]
    Error(Nil) -> []
  }
  let project_lines =
    list.map(meta.project_paths, fn(p) { "//! project: " <> p })
  let dep_lines =
    list.map(meta.deps, fn(dep) {
      case dep.constraint {
        "" -> "//! dep: " <> dep.name
        c -> "//! dep: " <> dep.name <> " " <> c
      }
    })
  let all_lines =
    gleam_line
    |> list.append(project_lines)
    |> list.append(dep_lines)
  string.join(all_lines, "\n")
}

pub fn update_dep(
  meta: ScriptMeta,
  name: String,
  constraint: String,
) -> ScriptMeta {
  let existing = list.filter(meta.deps, fn(d) { d.name != name })
  let new_deps =
    list.append(existing, [Dependency(name: name, constraint: constraint)])
  ScriptMeta(..meta, deps: new_deps)
}

pub fn expand_shorthand_version(version: String) -> String {
  case string.split(version, ".") {
    [major, _minor, _patch] -> {
      let next_major = case int.parse(major) {
        Ok(n) -> int.to_string(n + 1)
        Error(Nil) -> "1"
      }
      ">= " <> version <> " and < " <> next_major <> ".0.0"
    }
    _ -> ">= " <> version
  }
}

fn drop_prefix(s: String, prefix: String) -> String {
  let prefix_len = string.length(prefix)
  string.drop_start(s, prefix_len)
}
