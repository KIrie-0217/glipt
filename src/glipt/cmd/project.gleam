import gleam/io
import gleam/result
import gleam/string
import glipt/internal/path
import glipt/internal/toml
import glipt/parser
import simplifile

pub fn execute(file_path: String) -> Nil {
  case simplifile.read(file_path) {
    Error(e) -> io.println_error("Error reading file: " <> string.inspect(e))
    Ok(source) -> {
      let meta = parser.parse(source)
      let project_name = path.drop_extension(path.basename(file_path))
      let dir = project_name
      let src_dir = dir <> "/src"

      case simplifile.is_directory(dir) {
        Ok(True) ->
          io.println_error("Error: directory '" <> dir <> "' already exists")
        _ -> {
          let toml_content = toml.generate_project_toml(project_name, meta)
          let result = {
            use _ <- result.try(simplifile.create_directory_all(src_dir))
            use _ <- result.try(simplifile.write(
              dir <> "/gleam.toml",
              toml_content,
            ))
            simplifile.copy(
              file_path,
              src_dir <> "/" <> path.basename(file_path),
            )
          }
          case result {
            Ok(_) ->
              io.println(
                "Created project '" <> project_name <> "/' from " <> file_path,
              )
            Error(e) -> io.println_error("Error: " <> string.inspect(e))
          }
        }
      }
    }
  }
}
