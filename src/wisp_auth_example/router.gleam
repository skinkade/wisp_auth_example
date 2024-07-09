import gleam/bool
import gleam/option.{type Option, None, Some}
import gleam/pgo
import gleam/result
import wisp.{type Request, type Response}
import wisp_auth_example/features/demo
import wisp_auth_example/features/login
import wisp_auth_example/features/registration
import wisp_auth_example/middleware
import wisp_auth_example/models/session
import wisp_auth_example/models/user
import wisp_auth_example/web.{type Context}

pub fn handle_request(
  req: Request,
  conn: pgo.Connection,
  static_dir: String,
) -> Response {
  use user <- middleware.derive_user(req, conn)

  let ctx = web.Context(db: conn, static_dir: static_dir, user: user)
  use req <- web.middleware(req, ctx)

  case wisp.path_segments(req) {
    ["demo"] -> demo.demo_handler(req, ctx)
    ["login"] -> login.login_handler(req, ctx)
    ["register"] -> registration.register_handler(req, ctx)
    _ -> wisp.not_found()
  }
}
