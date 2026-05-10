import gleam/list
import gleam/string

pub fn basename(path: String) -> String {
  case string.split(path, "/") {
    [] -> path
    parts ->
      case list.last(parts) {
        Ok(last) -> last
        Error(Nil) -> path
      }
  }
}

pub fn dirname(path: String) -> String {
  case string.split(path, "/") {
    [] -> "."
    [_] -> "."
    parts -> {
      let parent = init(parts)
      case parent {
        [] -> "."
        [""] -> "/"
        _ -> string.join(parent, "/")
      }
    }
  }
}

pub fn drop_extension(filename: String) -> String {
  case string.ends_with(filename, ".gleam") {
    True -> string.drop_end(filename, 6)
    False -> filename
  }
}

fn init(items: List(String)) -> List(String) {
  case items {
    [] -> []
    [_] -> []
    [x, ..rest] -> [x, ..init(rest)]
  }
}
