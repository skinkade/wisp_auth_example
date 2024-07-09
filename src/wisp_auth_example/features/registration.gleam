import formal/form.{type Form}
import gleam/http.{Get, Post}
import gleam/io
import gleam/option.{type Option, None, Some}
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

pub fn register_handler(req: Request, ctx: Context) {
  case req.method {
    Get -> register_form()
    Post -> submit_register_form(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

type RegistrationSubmission {
  RegistrationSubmission(email: Email, password: Password)
}

fn register_form() -> Response {
  // Create a new empty Form to render the HTML form with.
  // If the form is for updating something that already exists you may want to
  // use `form.initial_values` to pre-fill some fields.
  let form = form.new()

  html_templating.base_html("Register", [render_register_form(form, None)])
  |> wisp.html_response(200)
}

fn submit_register_form(req: Request, ctx: Context) -> Response {
  let password_policy = password.PasswordPolicy(min_length: 12, max_length: 50)
  use formdata <- wisp.require_form(req)

  let result =
    form.decoding({
      use email <- form.parameter
      use password <- form.parameter
      RegistrationSubmission(email: email, password: password)
    })
    |> form.with_values(formdata.values)
    |> form.field("email", form.string |> form.and(email.parse))
    |> form.field(
      "password",
      form.string
        |> form.and(password.create)
        |> form.and(password.policy_compliant(_, password_policy)),
    )
    |> form.finish

  case result {
    // The form was valid! Do something with the data and render a page to the user
    Ok(data) -> {
      case user.create(ctx.db, data.email, data.password) {
        Ok(_user) -> wisp.redirect("/demo")
        Error(e) -> {
          io.debug(e)
          html_templating.base_html("Register", [
            render_register_form(
              form.new(),
              Some("An error occurred trying to create your account"),
            ),
          ])
          |> wisp.html_response(500)
        }
      }
    }

    // The form was invalid. Render the HTML form again with the errors
    Error(form) -> {
      html_templating.base_html("Register", [render_register_form(form, None)])
      |> wisp.html_response(422)
    }
  }
}

fn render_register_form(form: Form, error: Option(String)) {
  html.div([attribute.class("flex justify-center p-4 xs:mt-8 sm:mt-16")], [
    html.div(
      [
        attribute.class(
          "min-w-96 max-w-96 border rounded drop-shadow-sm p-4 flex flex-col justify-center",
        ),
      ],
      [
        // html.div([attribute.class("flex justify-center")], [
        //   html.h1([attribute.class("text-lg font-bold")], [
        //     html.text("Register"),
        //   ]),
        // ]),
        html.div([], [
          html.form([attribute.method("post")], [
            html_templating.email_input(form, "email"),
            html_templating.password_input(form, "password"),
            html.div([attribute.class("my-4 flex justify-center")], [
              //   html.input([attribute.type_("submit"), attribute.value("Submit")]),
              html.button(
                [attribute.class("btn btn-primary"), attribute.type_("submit")],
                [html.text("Register")],
              ),
            ]),
            form_error(error),
          ]),
        ]),
      ],
    ),
  ])
}
