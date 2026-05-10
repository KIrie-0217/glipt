import glipt/parser

pub fn reassemble(meta: parser.ScriptMeta, original_source: String) -> String {
  let header = parser.format_directives(meta)
  let body = parser.strip_directives(original_source)
  case body {
    "" -> header <> "\n"
    b -> header <> "\n\n" <> b
  }
}
