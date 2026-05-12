import gleam/dynamic/decode
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/json
import gleam/result

pub fn fetch_latest_version(package_name: String) -> Result(String, String) {
  let url = "https://hex.pm/api/packages/" <> package_name

  use req <- result.try(
    request.to(url)
    |> result.replace_error("Invalid request URL"),
  )

  let req = request.set_header(req, "accept", "application/json")

  use resp <- result.try(
    httpc.send(req)
    |> result.replace_error("Failed to fetch package info from Hex"),
  )

  case resp.status {
    200 -> parse_version(resp.body)
    404 -> Error("Package '" <> package_name <> "' not found on Hex")
    status -> Error("Hex API returned status " <> int.to_string(status))
  }
}

pub fn parse_version(body: String) -> Result(String, String) {
  let decoder =
    decode.one_of(decode.at(["latest_stable_version"], decode.string), [
      decode.at(["latest_version"], decode.string),
    ])

  json.parse(body, decoder)
  |> result.replace_error("Failed to parse Hex API response")
}
