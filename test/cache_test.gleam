import gleam/int
import gleam/string
import gleeunit
import glipt/internal/cache
import glipt/parser
import glipt/runner
import glipt/target
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

fn setup_temp_dir(name: String) -> String {
  let dir = "/tmp/glipt_test_cache_" <> name
  let _ = simplifile.delete(dir)
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  dir
}

fn teardown(dir: String) -> Nil {
  let _ = simplifile.delete(dir)
  let _ = cache.clear_cache()
  Nil
}

pub fn slot_key_deterministic_test() {
  let key1 = cache.slot_key("/tmp/test/script.gleam", "main")
  let key2 = cache.slot_key("/tmp/test/script.gleam", "main")
  assert key1 == key2
}

pub fn slot_key_different_functions_test() {
  let key_main = cache.slot_key("/tmp/test/script.gleam", "main")
  let key_foo = cache.slot_key("/tmp/test/script.gleam", "foo")
  assert key_main != key_foo
}

pub fn slot_key_different_paths_test() {
  let key_a = cache.slot_key("/tmp/a/script.gleam", "main")
  let key_b = cache.slot_key("/tmp/b/script.gleam", "main")
  assert key_a != key_b
}

pub fn content_hash_changes_with_source_test() {
  let meta =
    parser.ScriptMeta(gleam_constraint: Error(Nil), project_paths: [], deps: [])
  let hash1 = cache.content_hash("pub fn main() { 1 }", meta, "main")
  let hash2 = cache.content_hash("pub fn main() { 2 }", meta, "main")
  assert hash1 != hash2
}

pub fn slot_reused_on_edit_test() {
  let dir = setup_temp_dir("slot_reuse")
  let script = dir <> "/reuse.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script,
      "import gleam/io\n\npub fn main() {\n  io.println(\"v1\")\n}\n",
    )

  let assert Ok(output1) =
    runner.run(
      runner.RunOptions(
        script_path: script,
        target: target.Erlang,
        function: "main",
        args: [],
      ),
    )
  assert string.contains(output1, "v1")

  let slot = cache.slot_key(script, "main")
  let slot_dir = cache.slot_path(slot)
  let assert Ok(True) = simplifile.is_directory(slot_dir)

  let assert Ok(Nil) =
    simplifile.write(
      script,
      "import gleam/io\n\npub fn main() {\n  io.println(\"v2\")\n}\n",
    )

  let assert Ok(output2) =
    runner.run(
      runner.RunOptions(
        script_path: script,
        target: target.Erlang,
        function: "main",
        args: [],
      ),
    )
  assert string.contains(output2, "v2")

  let assert Ok(entries) = simplifile.read_directory(cache.cache_dir())
  let slot_entries =
    entries
    |> list.filter(fn(e) { string.starts_with(e, slot) || e == slot })
  assert list.length(slot_entries) == 1

  teardown(dir)
}

pub fn gc_removes_stale_entries_test() {
  let _ = cache.clear_cache()
  let _ = cache.ensure_cache_dir()

  let stale_dir = cache.cache_dir() <> "/stale_slot"
  let assert Ok(Nil) = simplifile.create_directory_all(stale_dir)
  let assert Ok(Nil) = simplifile.write(stale_dir <> "/.content_hash", "abc")
  let old_ts = int.to_string(0)
  let assert Ok(Nil) = simplifile.write(stale_dir <> "/.last_used", old_ts)

  let fresh_dir = cache.cache_dir() <> "/fresh_slot"
  let assert Ok(Nil) = simplifile.create_directory_all(fresh_dir)
  let assert Ok(Nil) = simplifile.write(fresh_dir <> "/.content_hash", "def")
  let fresh_ts = int.to_string(2_000_000_000)
  let assert Ok(Nil) = simplifile.write(fresh_dir <> "/.last_used", fresh_ts)

  let assert Ok(Nil) = cache.gc()

  let assert Ok(False) = simplifile.is_directory(stale_dir)
  let assert Ok(True) = simplifile.is_directory(fresh_dir)

  let _ = cache.clear_cache()
  Nil
}

pub fn last_used_updated_on_cache_hit_test() {
  let dir = setup_temp_dir("last_used")
  let script = dir <> "/touch.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script,
      "import gleam/io\n\npub fn main() {\n  io.println(\"ok\")\n}\n",
    )

  let assert Ok(_) =
    runner.run(
      runner.RunOptions(
        script_path: script,
        target: target.Erlang,
        function: "main",
        args: [],
      ),
    )

  let slot = cache.slot_key(script, "main")
  let last_used_path = cache.slot_path(slot) <> "/.last_used"
  let assert Ok(ts1_str) = simplifile.read(last_used_path)

  let assert Ok(_) =
    runner.run(
      runner.RunOptions(
        script_path: script,
        target: target.Erlang,
        function: "main",
        args: [],
      ),
    )

  let assert Ok(ts2_str) = simplifile.read(last_used_path)
  let assert Ok(ts1) = int.parse(string.trim(ts1_str))
  let assert Ok(ts2) = int.parse(string.trim(ts2_str))
  assert ts2 >= ts1

  teardown(dir)
}

import gleam/list
import glipt/internal/toml

pub fn package_pool_key_test() {
  assert cache.package_pool_key("gleam_stdlib", "1.0.0", "erlang")
    == "gleam_stdlib@1.0.0+erlang"
  assert cache.package_pool_key("gleam_json", "3.1.0", "javascript")
    == "gleam_json@3.1.0+javascript"
}

pub fn gc_preserves_packages_dir_test() {
  let _ = cache.clear_cache()
  let _ = cache.ensure_cache_dir()

  let pkg_dir = cache.packages_dir() <> "/gleam_stdlib@1.0.0+erlang"
  let assert Ok(Nil) = simplifile.create_directory_all(pkg_dir)
  let fresh_ts = int.to_string(2_000_000_000)
  let assert Ok(Nil) = simplifile.write(pkg_dir <> "/.last_used", fresh_ts)

  let assert Ok(Nil) = cache.gc()

  let assert Ok(True) = simplifile.is_directory(cache.packages_dir())
  let assert Ok(True) = simplifile.is_directory(pkg_dir)

  let _ = cache.clear_cache()
  Nil
}

pub fn gc_removes_stale_packages_test() {
  let _ = cache.clear_cache()
  let _ = cache.ensure_cache_dir()

  let pkg_dir = cache.packages_dir() <> "/old_pkg@0.1.0+erlang"
  let assert Ok(Nil) = simplifile.create_directory_all(pkg_dir)
  let old_ts = int.to_string(0)
  let assert Ok(Nil) = simplifile.write(pkg_dir <> "/.last_used", old_ts)

  let assert Ok(Nil) = cache.gc()

  let assert Ok(False) = simplifile.is_directory(pkg_dir)

  let _ = cache.clear_cache()
  Nil
}

pub fn parse_manifest_packages_test() {
  let content =
    "packages = [\n  { name = \"gleam_stdlib\", version = \"1.0.0\", build_tools = [\"gleam\"] },\n  { name = \"gleam_json\", version = \"3.1.0\", build_tools = [\"gleam\"] },\n]\n"
  let packages = toml.parse_manifest_packages(content)
  assert packages == [#("gleam_stdlib", "1.0.0"), #("gleam_json", "3.1.0")]
}

pub fn pool_restores_across_slots_test() {
  let _ = cache.clear_cache()
  let dir = setup_temp_dir("pool_cross")

  let script_a = dir <> "/a.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script_a,
      "import gleam/io\n\npub fn main() {\n  io.println(\"a\")\n}\n",
    )

  let assert Ok(_) =
    runner.run(
      runner.RunOptions(
        script_path: script_a,
        target: target.Erlang,
        function: "main",
        args: [],
      ),
    )

  let assert Ok(True) = simplifile.is_directory(cache.packages_dir())

  let script_b = dir <> "/b.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script_b,
      "import gleam/io\n\npub fn main() {\n  io.println(\"b\")\n}\n",
    )

  let assert Ok(_) =
    runner.run(
      runner.RunOptions(
        script_path: script_b,
        target: target.Erlang,
        function: "main",
        args: [],
      ),
    )

  let slot_b = cache.slot_key(script_b, "main")
  let stdlib_dir = cache.slot_path(slot_b) <> "/build/dev/erlang/gleam_stdlib"
  let assert Ok(True) = simplifile.is_directory(stdlib_dir)

  teardown(dir)
}
