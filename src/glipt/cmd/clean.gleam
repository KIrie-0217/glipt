import gleam/io
import gleam/string
import glipt/internal/cache

pub fn execute() -> Nil {
  case cache.clear_cache() {
    Ok(Nil) -> io.println("Cache cleared.")
    Error(e) -> io.println_error("Error clearing cache: " <> string.inspect(e))
  }
}
