import gleam/bool
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/pgo
import gleam/result
import wisp.{type Request, type Response}
import wisp_auth_example/features/login
import wisp_auth_example/features/registration
import wisp_auth_example/models/session
import wisp_auth_example/models/user
import wisp_auth_example/web.{type Context}

pub fn derive_session(
  req: Request,
  conn: pgo.Connection,
  handler: fn(Option(session.SessionQueryRecord)) -> Response,
) -> Response {
  let session = wisp.get_cookie(req, "session", wisp.Signed)
  use <- bool.guard(result.is_error(session), handler(None))

  let assert Ok(session) = session
  let session = session.get_by_session_key_string(conn, session)
  use <- bool.guard(result.is_error(session), wisp.internal_server_error())

  let assert Ok(session) = session
  use <- bool.guard(option.is_none(session), handler(None))

  let assert Some(session) = session
  use <- bool.guard(session.expired(session), handler(None))

  handler(Some(session))
}

pub fn derive_user(
  req: Request,
  conn: pgo.Connection,
  handler: fn(Option(user.UserDbRecord)) -> Response,
) -> Response {
  use session <- derive_session(req, conn)
  use <- bool.guard(option.is_none(session), handler(None))

  let assert Some(session) = session
  let user = user.get_by_id(conn, session.user_id)
  use <- bool.guard(result.is_error(user), wisp.internal_server_error())

  let assert Ok(Some(user)) = user
  use <- bool.guard(user.disabled_or_locked(user), handler(None))

  handler(Some(user))
}

pub fn require_user(
  ctx: web.Context,
  handler: fn(user.UserDbRecord) -> Response,
) -> Response {
  use <- bool.guard(option.is_none(ctx.user), wisp.redirect("/login"))
  let assert Some(user) = ctx.user
  handler(user)
}
