import gleeunit
import glipt/hex

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn parse_version_stable_test() {
  let body =
    "{\"latest_stable_version\": \"2.1.0\", \"latest_version\": \"3.0.0-rc1\"}"
  assert hex.parse_version(body) == Ok("2.1.0")
}

pub fn parse_version_fallback_to_latest_test() {
  let body = "{\"latest_version\": \"1.5.0\"}"
  assert hex.parse_version(body) == Ok("1.5.0")
}

pub fn parse_version_invalid_json_test() {
  assert hex.parse_version("not json")
    == Error("Failed to parse Hex API response")
}

pub fn parse_version_missing_fields_test() {
  assert hex.parse_version("{\"name\": \"some_package\"}")
    == Error("Failed to parse Hex API response")
}

pub fn parse_version_empty_object_test() {
  assert hex.parse_version("{}") == Error("Failed to parse Hex API response")
}

pub fn fetch_latest_version_real_package_test() {
  let result = hex.fetch_latest_version("gleam_stdlib")
  let assert Ok(_) = result
}

pub fn fetch_latest_version_not_found_test() {
  assert hex.fetch_latest_version("zzz_nonexistent_pkg_12345")
    == Error("Package 'zzz_nonexistent_pkg_12345' not found on Hex")
}
