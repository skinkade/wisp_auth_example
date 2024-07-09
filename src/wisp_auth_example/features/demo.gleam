import birl
import formal/form.{type Form}
import gleam/bool
import gleam/http.{Get, Post}
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/order
import gleam/pgo
import gleam/result
import gleam/string
import gleam/string_builder.{type StringBuilder}
import lustre
import lustre/attribute.{type Attribute}
import lustre/element.{type Element}
import lustre/element/html
import wisp.{type Request, type Response}
import wisp_auth_example/html_templating.{form_error, form_field}
import wisp_auth_example/middleware
import wisp_auth_example/models/session
import wisp_auth_example/models/user
import wisp_auth_example/types/email.{type Email}
import wisp_auth_example/types/password.{type Password}
import wisp_auth_example/web.{type Context}

pub fn demo_handler(_req: Request, ctx: Context) -> Response {
  use user <- middleware.require_user(ctx)

  html_templating.base_html("Welcome!", [
    html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
      html.div(
        [
          attribute.class(
            "min-w-96 max-w-96 border rounded drop-shadow-sm p-4 flex flex-col justify-center",
          ),
        ],
        [html.span([], [html.text("Welcome, " <> email.to_string(user.email))])],
      ),
    ]),
  ])
  |> wisp.html_response(200)
}
