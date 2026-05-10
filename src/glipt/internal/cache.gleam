import gleam/list
import gleam/string
import glipt/parser.{type ScriptMeta}
import simplifile

pub fn cache_dir() -> String {
  let home = get_home_dir()
  home <> "/.cache/glipt"
}

pub fn cache_key(source: String, meta: ScriptMeta) -> String {
  let dep_str =
    meta.deps
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })
    |> list.map(fn(d) { d.name <> ":" <> d.constraint })
    |> string.join(",")
  let input = source <> "\n" <> dep_str
  sha256(input)
}

pub fn cached_project_path(key: String) -> String {
  cache_dir() <> "/" <> key
}

pub fn is_cached(key: String) -> Bool {
  let path = cached_project_path(key) <> "/build"
  case simplifile.is_directory(path) {
    Ok(True) -> True
    _ -> False
  }
}

pub fn ensure_cache_dir() -> Result(Nil, simplifile.FileError) {
  simplifile.create_directory_all(cache_dir())
}

pub fn clear_cache() -> Result(Nil, simplifile.FileError) {
  let dir = cache_dir()
  case simplifile.is_directory(dir) {
    Ok(True) -> simplifile.delete(dir)
    _ -> Ok(Nil)
  }
}

@external(erlang, "glipt_ffi", "get_home_dir")
fn get_home_dir() -> String

@external(erlang, "glipt_ffi", "sha256_hex")
fn sha256(input: String) -> String
