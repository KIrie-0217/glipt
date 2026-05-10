//! dep: gleam_stdlib >= 0.44.0 and < 2.0.0

import gleam/io
import gleam/list
import gleam/string

pub fn main() {
  let languages = ["Gleam", "Erlang", "Elixir", "Rust"]

  languages
  |> list.map(fn(lang) { string.concat(["Hello from ", lang, "!"]) })
  |> list.each(io.println)
}
