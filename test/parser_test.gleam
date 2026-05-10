import gleeunit
import glipt/parser.{Dependency, ScriptMeta}

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parse_empty_source_test() {
  let meta = parser.parse("")
  assert meta.gleam_constraint == Error(Nil)
  assert meta.deps == []
}

pub fn parse_no_directives_test() {
  let source = "import gleam/io\n\npub fn main() {\n  io.println(\"hi\")\n}\n"
  let meta = parser.parse(source)
  assert meta.gleam_constraint == Error(Nil)
  assert meta.deps == []
}

pub fn parse_dep_directives_test() {
  let source =
    "//! dep: gleam_json >= 1.0.0 and < 2.0.0\n//! dep: simplifile >= 2.0.0\n\nimport gleam/io\n"
  let meta = parser.parse(source)
  assert meta.deps
    == [
      Dependency(name: "gleam_json", constraint: ">= 1.0.0 and < 2.0.0"),
      Dependency(name: "simplifile", constraint: ">= 2.0.0"),
    ]
}

pub fn parse_gleam_directive_test() {
  let source = "//! gleam: >= 1.0.0\n//! dep: foo >= 1.0.0\n\nimport gleam/io\n"
  let meta = parser.parse(source)
  assert meta.gleam_constraint == Ok(">= 1.0.0")
  assert meta.deps == [Dependency(name: "foo", constraint: ">= 1.0.0")]
}

pub fn parse_dep_name_only_test() {
  let source = "//! dep: some_package\n"
  let meta = parser.parse(source)
  assert meta.deps == [Dependency(name: "some_package", constraint: "")]
}

pub fn strip_directives_test() {
  let source =
    "//! gleam: >= 1.0.0\n//! dep: foo >= 1.0.0\n\nimport gleam/io\n\npub fn main() {\n  io.println(\"hi\")\n}\n"
  let result = parser.strip_directives(source)
  assert result
    == "import gleam/io\n\npub fn main() {\n  io.println(\"hi\")\n}\n"
}

pub fn format_directives_test() {
  let meta =
    ScriptMeta(gleam_constraint: Ok(">= 1.0.0"), project_paths: [], deps: [
      Dependency(name: "gleam_json", constraint: ">= 1.0.0 and < 2.0.0"),
      Dependency(name: "foo", constraint: ""),
    ])
  let result = parser.format_directives(meta)
  assert result
    == "//! gleam: >= 1.0.0\n//! dep: gleam_json >= 1.0.0 and < 2.0.0\n//! dep: foo"
}

pub fn update_dep_new_test() {
  let meta =
    ScriptMeta(gleam_constraint: Error(Nil), project_paths: [], deps: [])
  let updated = parser.update_dep(meta, "foo", ">= 1.0.0")
  assert updated.deps == [Dependency(name: "foo", constraint: ">= 1.0.0")]
}

pub fn update_dep_replace_test() {
  let meta =
    ScriptMeta(gleam_constraint: Error(Nil), project_paths: [], deps: [
      Dependency(name: "foo", constraint: ">= 1.0.0"),
      Dependency(name: "bar", constraint: ">= 2.0.0"),
    ])
  let updated = parser.update_dep(meta, "foo", ">= 3.0.0")
  assert updated.deps
    == [
      Dependency(name: "bar", constraint: ">= 2.0.0"),
      Dependency(name: "foo", constraint: ">= 3.0.0"),
    ]
}

pub fn parse_project_directive_test() {
  let source = "//! project: .\n//! dep: foo >= 1.0.0\n\nimport gleam/io\n"
  let meta = parser.parse(source)
  assert meta.project_paths == ["."]
}

pub fn parse_multiple_project_directives_test() {
  let source =
    "//! project: .\n//! project: ../other_lib\n//! dep: foo >= 1.0.0\n"
  let meta = parser.parse(source)
  assert meta.project_paths == [".", "../other_lib"]
}

pub fn format_directives_with_project_test() {
  let meta =
    ScriptMeta(gleam_constraint: Ok(">= 1.0.0"), project_paths: ["."], deps: [
      Dependency(name: "foo", constraint: ">= 1.0.0"),
    ])
  let result = parser.format_directives(meta)
  assert result == "//! gleam: >= 1.0.0\n//! project: .\n//! dep: foo >= 1.0.0"
}

pub fn expand_shorthand_version_test() {
  assert parser.expand_shorthand_version("1.2.3") == ">= 1.2.3 and < 2.0.0"
  assert parser.expand_shorthand_version("0.5.0") == ">= 0.5.0 and < 1.0.0"
}
