import gleam/result
import glipt/internal/cache
import glipt/internal/path
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

pub fn run(script_path: String, t: Target) -> Result(String, RunError) {
  use source <- result.try(
    simplifile.read(script_path) |> result.map_error(FileError),
  )

  let meta = parser.parse(source)
  let key = cache.cache_key(source, meta)
  let module_name = path.drop_extension(path.basename(script_path))

  case cache.is_cached(key) {
    True -> execute(key, module_name, t)
    False -> {
      use _ <- result.try(setup_project(key, script_path, source, meta, t))
      execute(key, module_name, t)
    }
  }
}

fn setup_project(
  key: String,
  script_path: String,
  source: String,
  meta: parser.ScriptMeta,
  t: Target,
) -> Result(Nil, RunError) {
  let project_dir = cache.cached_project_path(key)
  let src_dir = project_dir <> "/src"

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

  let module_name = path.drop_extension(path.basename(script_path))
  let dest = src_dir <> "/" <> module_name <> ".gleam"
  let clean_source = parser.strip_directives(source)
  use _ <- result.try(
    simplifile.write(dest, clean_source) |> result.map_error(FileError),
  )

  use _ <- result.try(
    shellout.command("gleam", ["deps", "download"], project_dir, [
      shellout.LetBeStderr,
    ])
    |> result.map_error(fn(e) { BuildError("deps download failed: " <> e.1) }),
  )

  shellout.command(
    "gleam",
    ["build", "--target", target.to_string(t)],
    project_dir,
    [shellout.LetBeStderr],
  )
  |> result.map_error(fn(e) { BuildError(e.1) })
  |> result.map(fn(_) { Nil })
}

fn execute(
  key: String,
  module_name: String,
  t: Target,
) -> Result(String, RunError) {
  let project_dir = cache.cached_project_path(key)
  shellout.command(
    "gleam",
    ["run", "--target", target.to_string(t), "-m", module_name],
    project_dir,
    [shellout.LetBeStderr],
  )
  |> result.map_error(fn(e) { RunError(e.1) })
}
