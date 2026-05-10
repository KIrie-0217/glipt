import gleam/int
import gleam/list
import gleam/result
import gleam/string
import glipt/parser.{type ScriptMeta}
import simplifile

const default_ttl_seconds = 2_592_000

pub fn cache_dir() -> String {
  let home = get_home_dir()
  home <> "/.cache/glipt"
}

pub fn slot_key(script_path: String, function: String) -> String {
  let abs = resolve_path(script_path)
  sha256(abs <> "\n" <> function)
}

pub fn content_hash(
  source: String,
  meta: ScriptMeta,
  function: String,
) -> String {
  let dep_str =
    meta.deps
    |> list.sort(fn(a, b) { string.compare(a.name, b.name) })
    |> list.map(fn(d) { d.name <> ":" <> d.constraint })
    |> string.join(",")
  let input = source <> "\n" <> dep_str <> "\n" <> function
  sha256(input)
}

pub fn slot_path(slot: String) -> String {
  cache_dir() <> "/" <> slot
}

pub fn is_cached(slot: String, expected_hash: String) -> Bool {
  let dir = slot_path(slot)
  case simplifile.read(dir <> "/.content_hash") {
    Ok(stored) -> string.trim(stored) == expected_hash
    Error(_) -> False
  }
}

pub fn write_metadata(
  slot: String,
  hash: String,
) -> Result(Nil, simplifile.FileError) {
  let dir = slot_path(slot)
  use _ <- result.try(simplifile.write(dir <> "/.content_hash", hash))
  touch_last_used(slot)
}

pub fn touch_last_used(slot: String) -> Result(Nil, simplifile.FileError) {
  let dir = slot_path(slot)
  let ts = int.to_string(unix_timestamp())
  simplifile.write(dir <> "/.last_used", ts)
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

pub fn gc() -> Result(Nil, simplifile.FileError) {
  let dir = cache_dir()
  let ttl = get_ttl_seconds()
  let now = unix_timestamp()
  case simplifile.read_directory(dir) {
    Ok(entries) -> {
      list.each(entries, fn(entry) {
        let entry_path = dir <> "/" <> entry
        let last_used_path = entry_path <> "/.last_used"
        case simplifile.read(last_used_path) {
          Ok(ts_str) -> {
            case int.parse(string.trim(ts_str)) {
              Ok(ts) ->
                case now - ts > ttl {
                  True -> {
                    let _ = simplifile.delete(entry_path)
                    Nil
                  }
                  False -> Nil
                }
              Error(Nil) -> {
                let _ = simplifile.delete(entry_path)
                Nil
              }
            }
          }
          Error(_) -> {
            let _ = simplifile.delete(entry_path)
            Nil
          }
        }
      })
      Ok(Nil)
    }
    Error(_) -> Ok(Nil)
  }
}

fn get_ttl_seconds() -> Int {
  case get_env("GLIPT_CACHE_TTL") {
    Ok(val) ->
      case int.parse(val) {
        Ok(n) -> n
        Error(Nil) -> default_ttl_seconds
      }
    Error(Nil) -> default_ttl_seconds
  }
}

@external(erlang, "glipt_ffi", "get_home_dir")
fn get_home_dir() -> String

@external(erlang, "glipt_ffi", "sha256_hex")
fn sha256(input: String) -> String

@external(erlang, "glipt_ffi", "unix_timestamp")
fn unix_timestamp() -> Int

@external(erlang, "glipt_ffi", "resolve_path")
pub fn resolve_path(path: String) -> String

@external(erlang, "glipt_ffi", "get_env")
fn get_env(name: String) -> Result(String, Nil)
