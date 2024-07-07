import gleam/dict
import gleam/int
import gleam/list
import gleam/string

pub fn digit_code(length: Int) -> String {
  // Erlang Gleam backend uses:
  // float.random() *. to_float(max)
  // Ergo we use 2^53 - 1
  int.random(9_007_199_254_740_991)
  |> int.to_string()
  |> string.slice(0, length)
  |> string.pad_right(to: length, with: "0")
}

pub fn verification_code() -> String {
  digit_code(8)
}
