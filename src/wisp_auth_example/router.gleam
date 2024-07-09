import wisp.{type Request, type Response}
import wisp_auth_example/features/login
import wisp_auth_example/features/registration
import wisp_auth_example/web.{type Context}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  case wisp.path_segments(req) {
    ["login"] -> login.login_handler(req, ctx)
    ["register"] -> registration.register_handler(req, ctx)
    _ -> wisp.not_found()
  }
}
