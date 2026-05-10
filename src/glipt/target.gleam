pub type Target {
  Erlang
  JavaScript
}

pub fn to_string(target: Target) -> String {
  case target {
    Erlang -> "erlang"
    JavaScript -> "javascript"
  }
}
