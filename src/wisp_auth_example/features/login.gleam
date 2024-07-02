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

pub fn login_handler(req: Request, ctx: Context) {
  case req.method {
    Get -> login_view()
    Post -> login_attempt(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn login_view() {
  let html =
    string_builder.from_string(
      "<form method='post'>
        <label>Email:
          <input type='email' name='email'>
        </label>
        <label>Password:
          <input type='password' name='password'>
        </label>
        <input type='submit' value='Submit'>
      </form>",
    )
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn create_session(
  db: pgo.Connection,
  email: String,
  password: String,
) -> Result(token.Token, Nil) {
  let hash_sql =
    "
      select id::text, password_hash
      from wuser
      where provider_id = $1
        and provider = 'email'
        and password_hash is not null
        and (
          locked_until is null
          or locked_until < now()
        )
    "

  let assert Ok(hash_response) =
    pgo.execute(
      hash_sql,
      db,
      [pgo.text(email)],
      dynamic.tuple2(dynamic.string, dynamic.string),
    )

  case hash_response.rows {
    [#(user_id, password_hash)] -> {
      case antigone.verify(bit_array.from_string(password), password_hash) {
        False -> Error(Nil)
        True -> {
          let token = token.new()
          let expiration = birl.utc_now() |> birl.add(duration.days(7))
          let session_sql =
            "
              insert into wuser_session
              (id, verification_hash, expires_at, wuser_id)
              values
              ($1, $2, $3, $4)
            "
          let assert Ok(_) =
            pgo.execute(
              session_sql,
              db,
              [
                pgo.text(token.id |> uuid.to_string()),
                pgo.bytea(token |> token.verification_hash()),
                pgo.timestamp(expiration |> birl.to_erlang_universal_datetime()),
                pgo.text(user_id),
              ],
              dynamic.dynamic,
            )
          Ok(token)
        }
      }
    }
    _ -> Error(Nil)
  }
}

pub fn login_attempt(req: Request, ctx: Context) {
  use formdata <- wisp.require_form(req)

  let parsed = {
    use email <- result.try(list.key_find(formdata.values, "email"))
    use password <- result.try(list.key_find(formdata.values, "password"))
    Ok(#(email, password))
  }

  case parsed {
    Error(_) -> wisp.bad_request()
    Ok(#(email, password)) -> {
      case create_session(ctx.db, email, password) {
        Error(_) -> wisp.bad_request()
        Ok(token) -> {
          wisp.redirect("/user-demo")
          |> wisp.set_cookie(
            req,
            "session",
            token.to_string(token),
            wisp.Signed,
            60 * 60 * 24 * 7,
          )
        }
      }
    }
  }
}
