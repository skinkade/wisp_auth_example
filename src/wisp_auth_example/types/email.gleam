import gleam/bool
import gleam/dynamic.{type DecodeError, type Dynamic, DecodeError}
import gleam/list
import gleam/result
import gleam/string

pub opaque type Email {
  Email(value: String)
}

// https://thecopenhagenbook.com/email-verification#input-validation
pub fn parse(str: String) -> Result(Email, Nil) {
  let str = string.trim(str)
  use <- bool.guard(string.is_empty(str), Error(Nil))
  use <- bool.guard(string.length(str) > 255, Error(Nil))

  use #(head, domain) <- result.try({
    case string.split(str, "@") {
      [head, domain] -> Ok(#(head, domain))
      [head, ..tail] -> {
        use <- bool.guard(list.is_empty(tail), Error(Nil))
        let assert Ok(domain) = list.last(tail)
        Ok(#(head, domain))
      }
      _ -> Error(Nil)
    }
  })

  use <- bool.guard(string.is_empty(head), Error(Nil))
  use <- bool.guard(string.is_empty(domain), Error(Nil))

  use <- bool.guard(
    {
      case string.split(domain, ".") {
        [_head, ..tail] -> {
          case tail {
            [] -> True
            _ -> False
          }
        }
        _ -> True
      }
    },
    Error(Nil),
  )

  Ok(Email(str))
}

pub fn to_string(email: Email) -> String {
  email.value
}

pub fn dynamic_email(d: Dynamic) {
  use str <- result.try(dynamic.string(d))
  case parse(str) {
    Error(_) -> Error([DecodeError(expected: "email", found: "?", path: [])])
    Ok(email) -> Ok(email)
  }
}
