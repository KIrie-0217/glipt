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
  let dir = "/tmp/glipt_test_" <> name
  let _ = simplifile.delete(dir)
  let assert Ok(Nil) = simplifile.create_directory_all(dir)
  dir
}

fn teardown(dir: String) -> Nil {
  let _ = simplifile.delete(dir)
  let _ = cache.clear_cache()
  Nil
}

pub fn run_simple_script_test() {
  let dir = setup_temp_dir("run_simple")
  let script = dir <> "/hello.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script,
      "import gleam/io\n\npub fn main() {\n  io.println(\"hello\")\n}\n",
    )

  let assert Ok(output) = runner.run(script, target.Erlang)
  assert string.contains(output, "hello")

  teardown(dir)
}

pub fn run_with_deps_test() {
  let dir = setup_temp_dir("run_deps")
  let script = dir <> "/sum.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script,
      "//! dep: gleam_stdlib >= 0.44.0 and < 2.0.0\n\nimport gleam/int\nimport gleam/io\nimport gleam/list\n\npub fn main() {\n  let sum = list.fold([1, 2, 3], 0, fn(acc, x) { acc + x })\n  io.println(int.to_string(sum))\n}\n",
    )

  let assert Ok(output) = runner.run(script, target.Erlang)
  assert string.contains(output, "6")

  teardown(dir)
}

pub fn run_missing_file_test() {
  let assert Error(runner.FileError(_)) =
    runner.run("/tmp/nonexistent_glipt_script.gleam", target.Erlang)
}

pub fn run_cache_hit_test() {
  let dir = setup_temp_dir("cache_hit")
  let script = dir <> "/cached.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script,
      "import gleam/io\n\npub fn main() {\n  io.println(\"cached\")\n}\n",
    )

  let assert Ok(_) = runner.run(script, target.Erlang)
  let assert Ok(output) = runner.run(script, target.Erlang)
  assert string.contains(output, "cached")

  teardown(dir)
}

pub fn run_with_project_directive_test() {
  let dir = setup_temp_dir("project_dep")
  let lib_dir = dir <> "/mylib"
  let lib_src = lib_dir <> "/src"
  let assert Ok(Nil) = simplifile.create_directory_all(lib_src)
  let assert Ok(Nil) =
    simplifile.write(
      lib_dir <> "/gleam.toml",
      "name = \"mylib\"\nversion = \"0.1.0\"\n\n[dependencies]\ngleam_stdlib = \">= 0.44.0 and < 2.0.0\"\n",
    )
  let assert Ok(Nil) =
    simplifile.write(
      lib_src <> "/mylib.gleam",
      "pub fn greet() -> String {\n  \"hi from mylib\"\n}\n",
    )

  let script = dir <> "/use_lib.gleam"
  let assert Ok(Nil) =
    simplifile.write(
      script,
      "//! project: ./mylib\n\nimport gleam/io\nimport mylib\n\npub fn main() {\n  io.println(mylib.greet())\n}\n",
    )

  let assert Ok(output) = runner.run(script, target.Erlang)
  assert string.contains(output, "hi from mylib")

  teardown(dir)
}

pub fn parser_roundtrip_test() {
  let source =
    "//! gleam: >= 1.0.0\n//! project: .\n//! dep: foo >= 1.0.0\n\nimport gleam/io\n\npub fn main() {\n  io.println(\"hi\")\n}\n"
  let meta = parser.parse(source)
  let header = parser.format_directives(meta)
  let body = parser.strip_directives(source)
  let reassembled = header <> "\n\n" <> body

  assert reassembled == source
}
