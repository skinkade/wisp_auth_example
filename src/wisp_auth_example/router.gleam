import gleam/pgo
import wisp.{type Request, type Response}
import wisp_auth_example/features/demo
import wisp_auth_example/features/login
import wisp_auth_example/features/mfa
import wisp_auth_example/features/registration
import wisp_auth_example/middleware
import wisp_auth_example/web.{type Context}
import youid/uuid

pub fn handle_request(req: Request, db: pgo.Connection) -> Response {
  let request_id = uuid.v4_string()
  let ctx = web.Context(db: db, request_id: request_id)
  use req <- web.middleware(req)
  use req <- middleware.wrap_basic_content_security_policy(req)
  use req <- middleware.wrap_csrf(req, ctx)

  case wisp.path_segments(req) {
    ["user-demo"] -> demo.user_demo(req, ctx)
    ["login"] -> login.login_handler(req, ctx)
    ["mfa", "verify"] -> mfa.handler(req, ctx)
    ["register"] -> registration.register_handler(req, ctx)
    ["register", "confirm"] -> registration.confirm_registration(req, ctx)
    ["register", "confirm", token] ->
      registration.confirm_registration_handler(req, ctx, token)
    _ -> wisp.not_found()
  }
}
