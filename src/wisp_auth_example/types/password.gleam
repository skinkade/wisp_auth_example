import antigone
import gleam/bit_array
import gleam/bool
import gleam/list
import gleam/regex
import gleam/result
import gleam/string

pub opaque type Password {
  Password(value: String)
}

@external(erlang, "unicode", "characters_to_nfc_binary")
fn characters_to_nfc_binary(str: String) -> String

@external(erlang, "unicode", "characters_to_nfkc_binary")
fn characters_to_nfkc_binary(str: String) -> String

fn printable_non_space_ascii(grapheme) {
  case string.to_utf_codepoints(grapheme) {
    [codepoint] -> {
      let codepoint = string.utf_codepoint_to_int(codepoint)
      codepoint >= 0x21 && codepoint <= 0x7e
    }
    _ -> False
  }
}

fn has_compat(grapheme) {
  let nfkc = characters_to_nfkc_binary(grapheme) |> bit_array.from_string()
  let grapheme = grapheme |> bit_array.from_string()
  nfkc != grapheme
}

fn normalize(str) {
  let assert Ok(letter_digit) =
    regex.from_string("[\\p{Ll}\\p{Lu}\\p{Lo}\\p{Nd}\\p{Lm}\\p{Mn}\\p{Mc}]")
  let assert Ok(space) = regex.from_string("[\\p{Zs}]")
  let assert Ok(symbol) = regex.from_string("[\\p{Sm}\\p{Sc}\\p{Sk}\\p{So}]")
  let assert Ok(punctuation) =
    regex.from_string("[\\p{Pc}\\p{Pd}\\p{Ps}\\p{Pe}\\p{Pi}\\p{Pf}\\p{Po}]")
  let assert Ok(other_letter_digit) =
    regex.from_string("[\\p{Lt}\\p{Nl}\\p{No}\\p{Me}]")

  let graphemes = string.to_graphemes(str)

  use <- bool.guard(
    !list.all(graphemes, fn(g) {
      regex.check(letter_digit, g)
      || printable_non_space_ascii(g)
      || regex.check(space, g)
      || regex.check(symbol, g)
      || regex.check(punctuation, g)
      || has_compat(g)
      || regex.check(other_letter_digit, g)
    }),
    Error(Nil),
  )

  graphemes
  |> list.map(fn(g) {
    case regex.check(space, g) {
      True -> " "
      False -> g
    }
  })
  |> string.join("")
  |> characters_to_nfc_binary()
  |> Ok()
}

// https://www.rfc-editor.org/rfc/rfc8265.html#section-4
// TODO: add parse/validation error types
pub fn create(str: String) -> Result(Password, Nil) {
  let trimmed = string.trim(str)
  use <- bool.guard(string.is_empty(trimmed), Error(Nil))

  use normalized <- result.try(normalize(trimmed))

  Ok(Password(normalized))
}

pub fn to_string(password: Password) -> String {
  password.value
}

pub fn to_bytes(password: Password) -> BitArray {
  password.value |> bit_array.from_string()
}

pub fn hash(password: Password) -> String {
  antigone.hash(antigone.hasher(), to_bytes(password))
}

pub fn valid(password: Password, hash: String) -> Bool {
  antigone.verify(to_bytes(password), hash)
}