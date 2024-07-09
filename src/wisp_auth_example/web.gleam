import gleam/option.{type Option}
import gleam/pgo
import wisp
import wisp_auth_example/models/user

pub type Context {
  Context(
    db: pgo.Connection,
    static_dir: String,
    user: Option(user.UserDbRecord),
  )
}

pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use req <- wisp.handle_head(req)
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_dir)

  handle_request(req)
}
