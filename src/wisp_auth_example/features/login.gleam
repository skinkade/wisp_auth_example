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
import wisp_auth_example/features/mfa
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

const login_attempt_threshold = 5

const lockout_duration_minutes = 15

pub type LoginToken {
  RegularLogin(token.Token)
  MfaLogin(token.Token)
}

pub fn create_session(
  db: pgo.Connection,
  email: String,
  password: String,
) -> Result(LoginToken, Nil) {
  let hash_sql =
    "
      select id::text, password_hash, mfa_enabled
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
      dynamic.tuple3(dynamic.string, dynamic.string, dynamic.bool),
    )

  case hash_response.rows {
    [#(user_id, password_hash, mfa_enabled)] -> {
      case antigone.verify(bit_array.from_string(password), password_hash) {
        False -> {
          let failed_attempt_sql =
            "
            update wuser
            set failed_login_count = failed_login_count + 1
            where id = $1
            returning failed_login_count
          "

          let assert Ok(failed_login_count_response) =
            pgo.execute(
              failed_attempt_sql,
              db,
              [pgo.text(user_id)],
              dynamic.element(0, dynamic.int),
            )

          let assert Ok(failed_login_count) =
            list.first(failed_login_count_response.rows)

          let _ = case failed_login_count >= login_attempt_threshold {
            True -> {
              let lockout_sql =
                "
                  update wuser
                  set locked_until = $1
                  where id = $2
                "

              let locked_until =
                birl.utc_now()
                |> birl.add(duration.minutes(lockout_duration_minutes))

              let assert Ok(_) =
                pgo.execute(
                  lockout_sql,
                  db,
                  [
                    pgo.timestamp(
                      locked_until |> birl.to_erlang_universal_datetime(),
                    ),
                    pgo.text(user_id),
                  ],
                  dynamic.dynamic,
                )
              Nil
            }
            False -> Nil
          }

          Error(Nil)
        }
        True -> {
          case mfa_enabled {
            True -> {
              Ok(MfaLogin(mfa.create_mfa_session(db, user_id)))
            }
            False -> {
              let token = token.new()
              let expiration = birl.utc_now() |> birl.add(duration.days(7))
              let session_sql =
                "
              insert into wuser_session
              (id, verification_hash, expires_at, wuser_id)
              values
              ($1, $2, $3, $4)
            "

              let login_update_sql =
                "
            update wuser
            set last_login = now(), failed_login_count = 0
          "

              let assert Ok(_) =
                pgo.transaction(db, fn(db) {
                  let assert Ok(_) =
                    pgo.execute(
                      session_sql,
                      db,
                      [
                        pgo.text(token.id |> uuid.to_string()),
                        pgo.bytea(token |> token.verification_hash()),
                        pgo.timestamp(
                          expiration |> birl.to_erlang_universal_datetime(),
                        ),
                        pgo.text(user_id),
                      ],
                      dynamic.dynamic,
                    )

                  let assert Ok(_) =
                    pgo.execute(login_update_sql, db, [], dynamic.dynamic)

                  Ok(dynamic.from(0))
                })

              Ok(RegularLogin(token))
            }
          }
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
        Ok(RegularLogin(token)) -> {
          wisp.redirect("/user-demo")
          |> wisp.set_cookie(
            req,
            "session",
            token.to_string(token),
            wisp.Signed,
            60 * 60 * 24 * 7,
          )
        }
        Ok(MfaLogin(token)) -> {
          wisp.redirect("/mfa/verify")
          |> wisp.set_cookie(
            req,
            "mfa_id",
            token.to_string(token),
            wisp.Signed,
            60 * 5,
          )
        }
      }
    }
  }
}
