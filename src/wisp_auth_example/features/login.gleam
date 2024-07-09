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
import wisp_auth_example/models/user
import wisp_auth_example/types/email.{type Email}
import wisp_auth_example/types/password.{type Password}
import wisp_auth_example/web.{type Context}

pub fn login_handler(req: Request, ctx: Context) {
  case req.method {
    Get -> login_form()
    Post -> submit_login_form(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

type LoginSubmission {
  LoginSubmission(email: Email, password: Password)
}

type LoginError {
  InvalidCredentials
  UnknownLoginError
}

fn disabled_or_locked(user: user.UserDbRecord) {
  use <- bool.guard(option.is_some(user.disabled_at), True)

  case user.locked_until {
    None -> False
    Some(ts) -> {
      case birl.compare(birl.utc_now(), ts) {
        order.Lt -> False
        _ -> True
      }
    }
  }
}

fn login(
  conn: pgo.Connection,
  email: Email,
  password: Password,
) -> Result(user.UserDbRecord, LoginError) {
  use user <- result.try({
    case user.get_by_email(conn, email) {
      Ok(user) -> Ok(user)
      Error(e) -> {
        io.debug(e)
        Error(UnknownLoginError)
      }
    }
  })

  use <- bool.guard(option.is_none(user), Error(InvalidCredentials))

  let assert Some(user) = user

  use <- bool.guard(disabled_or_locked(user), Error(InvalidCredentials))

  use <- bool.guard(
    !password.valid(password, user.password_hash),
    Error(InvalidCredentials),
  )

  Ok(user)
}

fn login_form() -> Response {
  let form = form.new()

  html_templating.base_html("Login", [render_login_form(form, None)])
  |> wisp.html_response(200)
}

fn submit_login_form(req: Request, ctx: Context) -> Response {
  use formdata <- wisp.require_form(req)

  let result =
    form.decoding({
      use email <- form.parameter
      use password <- form.parameter
      LoginSubmission(email: email, password: password)
    })
    |> form.with_values(formdata.values)
    |> form.field("email", form.string |> form.and(email.parse))
    |> form.field(
      "password",
      form.string
        |> form.and(password.create),
    )
    |> form.finish

  case result {
    // The form was valid! Do something with the data and render a page to the user
    Ok(data) -> {
      case login(ctx.db, data.email, data.password) {
        Ok(user) -> render_demo(user) |> wisp.html_response(200)
        Error(InvalidCredentials) -> {
          html_templating.base_html("Login", [
            render_login_form(
              form.initial_values([#("email", email.to_string(data.email))]),
              Some("Invalid credentials"),
            ),
          ])
          |> wisp.html_response(401)
        }
        Error(UnknownLoginError) -> {
          html_templating.base_html("Login", [
            render_login_form(
              form.new(),
              Some("An error occurred trying to authenticate"),
            ),
          ])
          |> wisp.html_response(500)
        }
      }
    }

    // The form was invalid. Render the HTML form again with the errors
    Error(form) -> {
      html_templating.base_html("Register", [render_login_form(form, None)])
      |> wisp.html_response(422)
    }
  }
}

fn render_login_form(form: Form, error: Option(String)) {
  html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
    html.div(
      [
        attribute.class(
          "min-w-96 max-w-96 border rounded drop-shadow-sm p-4 flex flex-col justify-center",
        ),
      ],
      [
        html.div([], [
          html.form([attribute.method("post")], [
            html_templating.email_input(form, "email"),
            html_templating.password_input(form, "password"),
            html.div([attribute.class("my-4 flex justify-center")], [
              //   html.input([attribute.type_("submit"), attribute.value("Submit")]),
              html.button(
                [attribute.class("btn btn-primary"), attribute.type_("submit")],
                [html.text("Login")],
              ),
            ]),
            form_error(error),
          ]),
        ]),
      ],
    ),
  ])
}

fn render_demo(user: user.UserDbRecord) {
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
}
