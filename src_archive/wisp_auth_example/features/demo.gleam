import antigone
import birl
import birl/duration
import gleam/bit_array
import gleam/dynamic
import gleam/http.{Get, Post}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/pgo
import gleam/result
import gleam/string_builder
import wisp.{type Request}
import wisp_auth_example/token
import wisp_auth_example/web.{type Context}
import youid/uuid

fn email_by_session_token(
  db: pgo.Connection,
  token_str: String,
) -> Result(String, Nil) {
  use token <- result.try(token.from_string(token_str))

  let sql =
    "
        select provider_id
        from wuser_session
        join wuser
            on wuser_session.wuser_id = wuser.id
        where wuser_session.id = $1
            and verification_hash = $2
            and expires_at > now()
            and (
                locked_until is null
                or locked_until < now()
            )
    "

  let assert Ok(response) =
    pgo.execute(
      sql,
      db,
      [
        pgo.text(token.id |> uuid.to_string()),
        pgo.bytea(token |> token.verification_hash()),
      ],
      dynamic.element(0, dynamic.string),
    )

  case response.rows {
    [email] -> Ok(email)
    _ -> Error(Nil)
  }
}

pub fn user_demo(req: Request, ctx: Context) {
  let non_auth_html = string_builder.from_string("<span>Not signed in!</span>")

  let cookie = wisp.get_cookie(req, "session", wisp.Signed)
  case cookie {
    Error(_) -> wisp.ok() |> wisp.html_body(non_auth_html)
    Ok(session) -> {
      case email_by_session_token(ctx.db, session) {
        Error(_) -> wisp.ok() |> wisp.html_body(non_auth_html)
        Ok(email) -> {
          let email = wisp.escape_html(email)
          let html = string_builder.from_string("
                <span>Signed in as <b>" <> email <> "</b></span>
            ")

          wisp.ok() |> wisp.html_body(html)
        }
      }
    }
  }
}
