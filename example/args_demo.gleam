//! dep: gleam_stdlib >= 0.44.0 and < 2.0.0
//! dep: argv >= 1.0.0 and < 2.0.0

import argv
import gleam/io
import gleam/list
import gleam/string

pub fn main() {
  let args = argv.load().arguments
  case args {
    [] -> io.println("Usage: glipt run args_demo.gleam -- <name> [names...]")
    names -> {
      let greeting =
        names
        |> list.map(fn(name) { string.concat(["Hi, ", name, "!"]) })
        |> string.join("\n")
      io.println(greeting)
    }
  }
}
