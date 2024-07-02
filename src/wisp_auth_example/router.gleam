import wisp.{type Request, type Response}
import wisp_auth_example/features/demo
import wisp_auth_example/features/login
import wisp_auth_example/features/registration
import wisp_auth_example/web.{type Context}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    ["user-demo"] -> demo.user_demo(req, ctx)
    ["login"] -> login.login_handler(req, ctx)
    ["register"] -> registration.register_handler(req, ctx)
    ["register", "confirm"] -> registration.confirm_registration(req, ctx)
    ["register", "confirm", token] ->
      registration.confirm_registration_handler(req, ctx, token)
    _ -> wisp.not_found()
  }
}
