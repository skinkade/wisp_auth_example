import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

pub fn digit_code(length: Int, separation: Option(#(String, Int))) -> String {
  case separation {
    None -> {
      list.range(0, length)
      |> list.map(fn(_) { int.random(10) |> int.to_string() })
      |> string.join("")
    }
    Some(#(separator, every)) -> {
      list.range(0, length)
      |> list.map(fn(i) {
        case int.modulo(i + 1, every) == Ok(0) {
          True -> { int.random(10) |> int.to_string() } <> separator
          False -> int.random(10) |> int.to_string()
        }
      })
      |> string.join("")
    }
  }
}

pub fn account_verification_code() -> String {
  digit_code(9, Some(#("-", 3)))
}
