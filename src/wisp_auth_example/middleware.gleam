import gleam/bit_array
import gleam/crypto.{Sha256}
import gleam/http.{Get, Post}
import gleam/http/request
import gleam/io
import gleam/list
import gleam/result
import gleam/string_builder
import wisp.{type Request, type Response}
import wisp_auth_example/web

fn csrf_error(reason: String) -> Response {
  io.debug(reason)
  wisp.bad_request() |> wisp.string_body("CSRF")
}

fn valid_csrf_signature(req, form_value, possible_tokens) {
  case possible_tokens {
    [] -> False
    [Error(_)] -> False
    [Error(_), ..rest] -> valid_csrf_signature(req, form_value, rest)
    [Ok(token)] -> {
      let token = crypto.hash(Sha256, bit_array.from_string(token))
      let signature =
        wisp.sign_message(req, token, Sha256)
        |> bit_array.from_string()
      crypto.secure_compare(form_value, signature)
    }
    [Ok(token), ..rest] -> {
      let token = crypto.hash(Sha256, bit_array.from_string(token))
      let signature =
        wisp.sign_message(req, token, Sha256)
        |> bit_array.from_string()
      case crypto.secure_compare(form_value, signature) {
        True -> True
        False -> valid_csrf_signature(req, form_value, rest)
      }
    }
  }
}

pub fn wrap_csrf(req: Request, ctx: web.Context, apply: fn(Request) -> Response) {
  case req.method {
    // Make sure we have a presession
    Get -> {
      case wisp.get_cookie(req, "presession", wisp.Signed) {
        Ok(_) -> apply(req)
        Error(_) -> {
          let rand = wisp.random_string(32)
          req
          |> apply()
          |> wisp.set_cookie(req, "presession", rand, wisp.Signed, 60 * 60)
        }
      }
    }
    // TODO: fix nesting
    Post -> {
      case list.key_find(req.headers, "content-type") {
        Ok("application/x-www-form-urlencoded")
        | Ok("application/x-www-form-urlencoded;" <> _)
        | Ok("multipart/form-data; boundary=" <> _) -> {
          let possible_tokens = [
            wisp.get_cookie(req, "session", wisp.Signed),
            wisp.get_cookie(req, "presession", wisp.Signed),
            Ok(ctx.request_id),
          ]

          use form <- wisp.require_form(req)
          case list.key_find(form.values, "__csrf") {
            Error(_) -> csrf_error("Could not extract CSRF form value")
            Ok(form_csrf) -> {
              let form_csrf = bit_array.from_string(form_csrf)
              case valid_csrf_signature(req, form_csrf, possible_tokens) {
                False -> csrf_error("CSRF comparison failure")
                True -> apply(req)
              }
            }
          }
        }
        _ -> apply(req)
      }
    }
    _ -> apply(req)
  }
}

/// https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html#basic-non-strict-csp-policy
pub fn wrap_basic_content_security_policy(
  req: Request,
  apply: fn(Request) -> Response,
) -> Response {
  case req.method {
    Get -> {
      let csp =
        string_builder.new()
        |> string_builder.append("default-src 'self';")
        |> string_builder.append("frame-ancestors 'self';")
        |> string_builder.append("form-action 'self';")
        |> string_builder.to_string()

      req
      |> apply()
      |> wisp.set_header("Content-Security-Policy", csp)
    }
    _ -> apply(req)
  }
}

/// https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html#nonce-based-strict-policy
pub fn wrap_strict_content_security_policy(
  req: Request,
  ctx: web.Context,
  apply: fn(Request) -> Response,
) -> Response {
  case req.method {
    Get -> {
      let csp =
        string_builder.new()
        |> string_builder.append("script-src 'nonce-")
        |> string_builder.append(ctx.request_id)
        |> string_builder.append("' 'strict-dynamic';")
        |> string_builder.append("object-src 'none';")
        |> string_builder.append("base-uri 'none';")
        |> string_builder.to_string()

      req
      |> apply()
      |> wisp.set_header("Content-Security-Policy", csp)
    }
    _ -> apply(req)
  }
}
