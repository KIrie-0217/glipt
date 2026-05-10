//! dep: gleam_stdlib >= 0.44.0 and < 2.0.0

import gleam/io
import gleam/int

pub fn main() {
  io.println("This is the default main function.")
  io.println("Try: glipt run -f greet example/functions.gleam")
  io.println("Try: glipt run -f count example/functions.gleam")
}

pub fn greet() {
  io.println("Hello! This was called via -f greet")
}

pub fn count() {
  count_loop(1, 5)
}

fn count_loop(current: Int, max: Int) {
  case current > max {
    True -> Nil
    False -> {
      io.println(int.to_string(current))
      count_loop(current + 1, max)
    }
  }
}
