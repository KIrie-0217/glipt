import gleam/list
import gleam/result
import gleam/string
import glipt/internal/cache
import glipt/internal/path
import glipt/internal/project
import glipt/internal/toml
import glipt/parser
import glipt/target.{type Target}
import shellout
import simplifile

pub type RunError {
  FileError(simplifile.FileError)
  BuildError(String)
  RunError(String)
}

pub type RunOptions {
  RunOptions(
    script_path: String,
    target: Target,
    function: String,
    args: List(String),
  )
}

pub fn run(opts: RunOptions) -> Result(String, RunError) {
  use source <- result.try(
    simplifile.read(opts.script_path) |> result.map_error(FileError),
  )

  let parsed = parser.parse(source)
  let script_dir = path.dirname(opts.script_path)
  let meta = maybe_inherit_host_deps(parsed, script_dir)
  let slot = cache.slot_key(opts.script_path, opts.function)
  let hash = cache.content_hash(source, meta, opts.function)
  let module_name = path.drop_extension(path.basename(opts.script_path))
  let entry_module = case opts.function {
    "main" -> module_name
    _ -> "glipt_entry"
  }

  case cache.is_cached(slot, hash) {
    True -> {
      let _ = cache.touch_last_used(slot)
      execute(slot, entry_module, opts.target, opts.args)
    }
    False -> {
      let _ = cache.gc()
      use _ <- result.try(setup_project(
        slot,
        opts.script_path,
        source,
        meta,
        opts.target,
        opts.function,
        module_name,
      ))
      use _ <- result.try(
        cache.write_metadata(slot, hash) |> result.map_error(FileError),
      )
      execute(slot, entry_module, opts.target, opts.args)
    }
  }
}

fn setup_project(
  slot: String,
  script_path: String,
  source: String,
  meta: parser.ScriptMeta,
  t: Target,
  function: String,
  module_name: String,
) -> Result(Nil, RunError) {
  let project_dir = cache.slot_path(slot)
  let src_dir = project_dir <> "/src"
  let _ = simplifile.delete(src_dir)
  let _ = simplifile.delete(project_dir <> "/gleam.toml")

  use _ <- result.try(cache.ensure_cache_dir() |> result.map_error(FileError))
  use _ <- result.try(
    simplifile.create_directory_all(src_dir) |> result.map_error(FileError),
  )

  let script_dir = path.dirname(script_path)
  let toml_content = toml.generate_runtime_toml(meta, t, script_dir)
  use _ <- result.try(
    simplifile.write(project_dir <> "/gleam.toml", toml_content)
    |> result.map_error(FileError),
  )

  let dest = src_dir <> "/" <> module_name <> ".gleam"
  let clean_source = parser.strip_directives(source)
  use _ <- result.try(
    simplifile.write(dest, clean_source) |> result.map_error(FileError),
  )

  use _ <- result.try(case function {
    "main" -> Ok(Nil)
    func -> {
      let entry_source =
        "import "
        <> module_name
        <> "\n\npub fn main() {\n  "
        <> module_name
        <> "."
        <> func
        <> "()\n}\n"
      simplifile.write(src_dir <> "/glipt_entry.gleam", entry_source)
      |> result.map_error(FileError)
    }
  })

  use _ <- result.try(
    shellout.command("gleam", ["deps", "download"], project_dir, [
      shellout.LetBeStderr,
    ])
    |> result.map_error(fn(e) { BuildError("deps download failed: " <> e.1) }),
  )

  let target_str = target.to_string(t)
  restore_packages_from_pool(project_dir, target_str)

  use _ <- result.try(
    shellout.command("gleam", ["build", "--target", target_str], project_dir, [
      shellout.LetBeStderr,
    ])
    |> result.map_error(fn(e) { BuildError(e.1) }),
  )

  save_packages_to_pool(project_dir, target_str)
  Ok(Nil)
}

fn restore_packages_from_pool(project_dir: String, target_str: String) -> Nil {
  let manifest_path = project_dir <> "/manifest.toml"
  case simplifile.read(manifest_path) {
    Ok(content) -> {
      let packages = toml.parse_manifest_packages(content)
      let build_dir = project_dir <> "/build/dev/" <> target_str
      let _ = simplifile.create_directory_all(build_dir)
      let any_restored =
        list.fold(packages, False, fn(acc, pkg) {
          let #(name, version) = pkg
          let key = cache.package_pool_key(name, version, target_str)
          let dest = build_dir <> "/" <> name
          case cache.is_package_cached(key), simplifile.is_directory(dest) {
            True, Ok(True) -> {
              let _ = cache.touch_package_used(key)
              acc
            }
            True, _ -> {
              let pool_path = cache.package_pool_path(key)
              let _ = simplifile.copy_directory(at: pool_path, to: dest)
              let _ = cache.touch_package_used(key)
              True
            }
            _, _ -> acc
          }
        })
      case any_restored {
        True -> copy_gleam_version_from_pool(build_dir)
        False -> Nil
      }
    }
    Error(_) -> Nil
  }
}

fn save_packages_to_pool(project_dir: String, target_str: String) -> Nil {
  let manifest_path = project_dir <> "/manifest.toml"
  case simplifile.read(manifest_path) {
    Ok(content) -> {
      let packages = toml.parse_manifest_packages(content)
      let _ = simplifile.create_directory_all(cache.packages_dir())
      save_gleam_version_to_pool(project_dir, target_str)
      list.each(packages, fn(pkg) {
        let #(name, version) = pkg
        let key = cache.package_pool_key(name, version, target_str)
        case cache.is_package_cached(key) {
          True -> {
            let _ = cache.touch_package_used(key)
            Nil
          }
          False -> {
            let src = project_dir <> "/build/dev/" <> target_str <> "/" <> name
            case simplifile.is_directory(src) {
              Ok(True) -> {
                let dest = cache.package_pool_path(key)
                let _ = simplifile.copy_directory(at: src, to: dest)
                let _ = cache.touch_package_used(key)
                Nil
              }
              _ -> Nil
            }
          }
        }
      })
    }
    Error(_) -> Nil
  }
}

fn copy_gleam_version_from_pool(build_dir: String) -> Nil {
  let src = cache.packages_dir() <> "/.gleam_version"
  case simplifile.read(src) {
    Ok(content) -> {
      let _ = simplifile.write(build_dir <> "/gleam_version", content)
      Nil
    }
    Error(_) -> Nil
  }
}

fn save_gleam_version_to_pool(project_dir: String, target_str: String) -> Nil {
  let src = project_dir <> "/build/dev/" <> target_str <> "/gleam_version"
  let dest = cache.packages_dir() <> "/.gleam_version"
  case simplifile.read(src) {
    Ok(content) -> {
      let _ = simplifile.write(dest, content)
      Nil
    }
    Error(_) -> Nil
  }
}

fn execute(
  slot: String,
  module_name: String,
  t: Target,
  script_args: List(String),
) -> Result(String, RunError) {
  let project_dir = cache.slot_path(slot)
  case t {
    target.Erlang -> execute_erl(project_dir, module_name, script_args)
    target.JavaScript -> execute_gleam(project_dir, module_name, t, script_args)
  }
}

fn execute_erl(
  project_dir: String,
  module_name: String,
  script_args: List(String),
) -> Result(String, RunError) {
  let build_dir = project_dir <> "/build/dev/erlang"
  case simplifile.read_directory(build_dir) {
    Ok(entries) -> {
      let pa_args =
        entries
        |> list.filter(fn(e) {
          !string.starts_with(e, ".") && e != "gleam_version"
        })
        |> list.flat_map(fn(e) { ["-pa", build_dir <> "/" <> e <> "/ebin"] })
      let eval = module_name <> ":main(), init:stop()."
      let base_args = list.flatten([pa_args, ["-noshell", "-eval", eval]])
      let args = case script_args {
        [] -> base_args
        _ -> list.append(base_args, ["-extra", ..script_args])
      }
      shellout.command("erl", args, project_dir, [shellout.LetBeStderr])
      |> result.map_error(fn(e) { RunError(e.1) })
    }
    Error(e) ->
      Error(RunError("Cannot read build directory: " <> string.inspect(e)))
  }
}

fn execute_gleam(
  project_dir: String,
  module_name: String,
  t: Target,
  script_args: List(String),
) -> Result(String, RunError) {
  let base_args = ["run", "--target", target.to_string(t), "-m", module_name]
  let args = case script_args {
    [] -> base_args
    _ -> list.append(base_args, ["--", ..script_args])
  }
  shellout.command("gleam", args, project_dir, [shellout.LetBeStderr])
  |> result.map_error(fn(e) { RunError(e.1) })
}

fn maybe_inherit_host_deps(
  meta: parser.ScriptMeta,
  script_dir: String,
) -> parser.ScriptMeta {
  let has_directives =
    meta.gleam_constraint != Error(Nil)
    || !list.is_empty(meta.deps)
    || !list.is_empty(meta.project_paths)
  case has_directives {
    True -> meta
    False ->
      case project.find_project_root(script_dir) {
        Error(Nil) -> meta
        Ok(root) ->
          case simplifile.read(root <> "/gleam.toml") {
            Error(_) -> meta
            Ok(content) -> {
              let deps = toml.parse_deps(content)
              let resolved_deps = resolve_relative_paths(deps, root)
              let gleam_constraint = toml.parse_gleam_version(content)
              parser.ScriptMeta(
                gleam_constraint: gleam_constraint,
                project_paths: [],
                deps: resolved_deps,
              )
            }
          }
      }
  }
}

fn resolve_relative_paths(
  deps: List(parser.Dependency),
  project_root: String,
) -> List(parser.Dependency) {
  list.map(deps, fn(dep) {
    case string.contains(dep.constraint, "path") {
      True -> {
        let resolved = resolve_path_in_constraint(dep.constraint, project_root)
        parser.Dependency(..dep, constraint: resolved)
      }
      False -> dep
    }
  })
}

fn resolve_path_in_constraint(
  constraint: String,
  project_root: String,
) -> String {
  case string.split_once(constraint, "path") {
    Ok(#(before, after)) ->
      case string.split_once(after, "\"") {
        Ok(#(middle, rest)) ->
          case string.split_once(rest, "\"") {
            Ok(#(rel_path, end)) -> {
              let abs_path = case string.starts_with(rel_path, "/") {
                True -> rel_path
                False -> project_root <> "/" <> rel_path
              }
              before <> "path" <> middle <> "\"" <> abs_path <> "\"" <> end
            }
            Error(Nil) -> constraint
          }
        Error(Nil) -> constraint
      }
    Error(Nil) -> constraint
  }
}
