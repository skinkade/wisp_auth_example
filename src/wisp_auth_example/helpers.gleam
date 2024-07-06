import gleam/bit_array
import gleam/crypto.{Sha256}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import wisp.{type Request}
import wisp_auth_example/web

pub fn form(
  req: Request,
  ctx: web.Context,
  attrs: List(Attribute(a)),
  children: List(Element(a)),
) {
  let assert Ok(csrf_token) = {
    case wisp.get_cookie(req, "session", wisp.Signed) {
      Ok(session) -> Ok(session)
      Error(_) ->
        case wisp.get_cookie(req, "presession", wisp.Signed) {
          Ok(presession) -> Ok(presession)
          Error(_) -> Ok(ctx.request_id)
        }
    }
  }

  let csrf_token = crypto.hash(Sha256, bit_array.from_string(csrf_token))

  let signature = wisp.sign_message(req, csrf_token, crypto.Sha256)
  let input =
    html.input([
      attribute.type_("hidden"),
      attribute.name("__csrf"),
      attribute.value(signature),
    ])

  html.form([attribute.method("post"), ..attrs], [input, ..children])
}
