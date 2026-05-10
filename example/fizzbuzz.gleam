//! dep: gleam_stdlib >= 0.44.0 and < 2.0.0

import gleam/int
import gleam/io
import gleam/list

fn range(from: Int, to: Int) -> List(Int) {
  case from > to {
    True -> []
    False -> [from, ..range(from + 1, to)]
  }
}

pub fn main() {
  range(1, 30)
  |> list.each(fn(n) {
    let result = case n % 3, n % 5 {
      0, 0 -> "FizzBuzz"
      0, _ -> "Fizz"
      _, 0 -> "Buzz"
      _, _ -> int.to_string(n)
    }
    io.println(result)
  })
}

