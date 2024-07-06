import birl
import birl/duration
import gleam/dynamic
import gleam/http.{Get, Post}
import gleam/int
import gleam/io
import gleam/list
import gleam/pgo
import gleam/result
import gleam/string
import gleam/string_builder
import wisp.{type Request}
import wisp_auth_example/features/shared/auth
import wisp_auth_example/token
import wisp_auth_example/web.{type Context}
import youid/uuid

pub fn generate_server_code() -> String {
  // Erlang Gleam backend uses:
  // float.random() *. to_float(max)
  // Ergo we use 2^53 - 1
  int.random(9_007_199_254_740_991)
  |> int.to_string()
  |> string.slice(0, 6)
  |> string.pad_right(to: 6, with: "0")
}

const temp_session_expiration_minutes = 5

const mfa_attempt_threshold = 5

pub fn create_mfa_session(
  db: pgo.Connection,
  user_id: String,
) -> #(token.Token, String) {
  let token = token.new()
  let code = generate_server_code()

  let sql =
    "
    insert into mfa_temp_session
    (id, verification_hash, expires_at, wuser_id, verification_code)
    values
    ($1, $2, $3, $4, $5)
  "

  let expiration =
    birl.utc_now()
    |> birl.add(duration.minutes(temp_session_expiration_minutes))

  let assert Ok(_) =
    pgo.execute(
      sql,
      db,
      [
        pgo.text(token.id |> uuid.to_string()),
        pgo.bytea(token |> token.verification_hash()),
        pgo.timestamp(expiration |> birl.to_erlang_universal_datetime()),
        pgo.text(user_id),
        pgo.text(code),
      ],
      dynamic.dynamic,
    )

  io.println(code)
  #(token, code)
}

pub fn handler(req: Request, ctx: Context) {
  case req.method {
    Get -> mfa_view()
    Post -> mfa_attempt(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn mfa_view() {
  let html =
    string_builder.from_string(
      "<form method='post'>
        <label>Code:
          <input name='code'>
        </label>
        <input type='submit' value='Submit'>
      </form>",
    )
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn mfa_attempt(req: Request, ctx: Context) {
  use formdata <- wisp.require_form(req)

  let parsed = {
    use code <- result.try(list.key_find(formdata.values, "code"))
    use cookie <- result.try(wisp.get_cookie(req, "mfa_id", wisp.Signed))
    use token <- result.try(token.from_string(cookie))
    Ok(#(token, code))
  }

  case parsed {
    Error(_) -> wisp.bad_request()
    Ok(#(token, code)) -> {
      let sql =
        "
        select wuser_id, verification_code
        from mfa_temp_session
        where id = $1
          and verification_hash = $2
          and expires_at > now()
      "

      let assert Ok(response) =
        pgo.execute(
          sql,
          ctx.db,
          [
            pgo.text(token.id |> uuid.to_string()),
            pgo.bytea(token |> token.verification_hash()),
          ],
          dynamic.tuple2(auth.dynamic_uuid, dynamic.string),
        )

      case response.rows {
        [#(user_id, verification_code)] -> {
          case code == verification_code {
            False -> {
              case auth.record_mfa_login_failure(ctx.db, user_id) {
                Ok(auth.MfaFailureCount(count)) -> {
                  case count >= mfa_attempt_threshold {
                    True -> {
                      // If we've gotten to this point,
                      // someone has the correct email+password but is failing on MFA
                      // In that case, we should lock the account and notify the user
                      // TODO: notify user
                      let assert Ok(_) = auth.lock_user_account(ctx.db, user_id)
                      Nil
                    }
                    False -> Nil
                  }
                }
                Error(err) -> {
                  io.debug(err)
                  Nil
                }
              }
              auth.delay()
              wisp.response(401)
            }
            True -> {
              let assert Ok(session_token) =
                pgo.transaction(ctx.db, fn(db) {
                  let cleanup_sql =
                    "
                      delete from mfa_temp_session
                      where id = $1
                    "
                  let assert Ok(session_token) =
                    auth.create_user_session(db, user_id)

                  let assert Ok(_) =
                    pgo.execute(
                      cleanup_sql,
                      db,
                      [pgo.text(token.id |> uuid.to_string())],
                      dynamic.dynamic,
                    )

                  Ok(session_token)
                })

              wisp.redirect("/user-demo")
              |> wisp.set_cookie(
                req,
                "session",
                token.to_string(session_token),
                wisp.Signed,
                60 * 60 * 24 * 7,
              )
            }
          }
        }
        _ -> wisp.bad_request()
      }
    }
  }
}
