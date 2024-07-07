import gleam/http.{Get, Post}
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string_builder
import wisp.{type Request}
import wisp_auth_example/features/mfa
import wisp_auth_example/features/shared/auth
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

pub type LoginResult {
  UserNotFound
  InvalidPassword(auth.User)
  LoginSuccess(token.Token)
  NeedsMfa(token.Token, String)
  LoginError
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
      let login_result = {
        case auth.get_enabled_user_by_email(ctx.db, email) {
          Error(err) -> {
            io.debug(err)
            LoginError
          }
          Ok(None) -> UserNotFound
          Ok(Some(user)) -> {
            case auth.valid_user_password(user, password) {
              False -> InvalidPassword(user)
              True -> {
                case user.mfa_enabled {
                  True -> {
                    let #(token, code) =
                      mfa.create_mfa_session(
                        ctx.db,
                        user.id |> uuid.to_string(),
                      )
                    NeedsMfa(token, code)
                  }
                  False -> {
                    case auth.create_user_session(ctx.db, user.id) {
                      Ok(token) -> LoginSuccess(token)
                      Error(err) -> {
                        io.debug(err)
                        LoginError
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
      case login_result {
        LoginSuccess(session_token) -> {
          wisp.redirect("/user-demo")
          |> wisp.set_cookie(
            req,
            "session",
            token.to_string(session_token),
            wisp.Signed,
            60 * 60 * 24 * 7,
          )
        }
        // TODO: notify user somehow
        NeedsMfa(mfa_id_token, _mfa_code) -> {
          wisp.redirect("/mfa/verify")
          |> wisp.set_cookie(
            req,
            "mfa_id",
            token.to_string(mfa_id_token),
            wisp.Signed,
            60 * 5,
          )
        }
        InvalidPassword(user) -> {
          io.debug("bar")
          // Let's not, for the moment, disable accounts for subsequent password failures
          let assert Ok(_) = auth.record_password_login_failure(ctx.db, user)
          auth.delay()
          wisp.response(401)
        }
        _ -> {
          io.debug("foo")
          auth.delay()
          wisp.response(401)
        }
      }
    }
  }
}
