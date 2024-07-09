import formal/form.{type Form}
import gleam/option.{type Option, None, Some}
import lustre
import lustre/attribute.{type Attribute, attribute}
import lustre/element.{type Element, element}
import lustre/element/html.{text}

pub fn base_html(title: String, children) {
  html.html([], [
    html.head([], [
      html.meta([attribute.attribute("charset", "UTF-8")]),
      html.meta([
        attribute.attribute("name", "viewport"),
        attribute.attribute("content", "width=device-width, initial-scale=1.0"),
      ]),
      html.title([], title),
      html.link([
        attribute.rel("stylesheet"),
        attribute.href("/static/css/main.css"),
      ]),
    ]),
    html.body([], children),
  ])
  |> element.to_document_string_builder
}

pub fn field_error(message: String) {
  html.div(
    [
      attribute.class("alert alert-error p-2 text-sm rounded"),
      attribute.role("alert"),
    ],
    [html.span([], [text(message)])],
  )
}

pub fn form_field(
  form: Form,
  name name: String,
  kind kind: String,
  title title: String,
  attributes additional_attributes: List(Attribute(a)),
) -> Element(a) {
  // Make an element containing the error message, if there is one.
  let error_element = case form.field_state(form, name) {
    Ok(_) -> element.none()
    Error(message) -> field_error(message)
  }

  // Render a label and an input using the error and the value from the form.
  // In a real program you likely want to add attributes for client side
  // validation and for accessibility.
  html.label([], [
    html.div([], [element.text(title)]),
    html.input([
      attribute.type_(kind),
      attribute.name(name),
      attribute.value(form.value(form, name)),
      ..additional_attributes
    ]),
    error_element,
  ])
}

pub fn form_error(error: Option(String)) {
  case error {
    None -> element.none()
    Some(error) ->
      html.div(
        [
          attribute.class("alert alert-error p-2 text-sm rounded"),
          attribute.role("alert"),
        ],
        [html.span([], [text(error)])],
      )
  }
}

pub fn email_input(form: Form, name: String) {
  let error_element = case form.field_state(form, name) {
    Ok(_) -> element.none()
    Error(message) -> field_error(message)
  }

  html.div([], [
    html.label(
      [attribute.class("input input-bordered flex items-center gap-2 my-4")],
      [
        html.svg(
          [
            attribute.class("h-4 w-4 opacity-70"),
            attribute("fill", "currentColor"),
            attribute("viewBox", "0 0 16 16"),
            attribute("xmlns", "http://www.w3.org/2000/svg"),
          ],
          [
            element(
              "path",
              [
                attribute(
                  "d",
                  "M2.5 3A1.5 1.5 0 0 0 1 4.5v.793c.026.009.051.02.076.032L7.674 8.51c.206.1.446.1.652 0l6.598-3.185A.755.755 0 0 1 15 5.293V4.5A1.5 1.5 0 0 0 13.5 3h-11Z",
                ),
              ],
              [],
            ),
            element(
              "path",
              [
                attribute(
                  "d",
                  "M15 6.954 8.978 9.86a2.25 2.25 0 0 1-1.956 0L1 6.954V11.5A1.5 1.5 0 0 0 2.5 13h11a1.5 1.5 0 0 0 1.5-1.5V6.954Z",
                ),
              ],
              [],
            ),
          ],
        ),
        html.input([
          attribute.placeholder("awesomeperson@example.com"),
          attribute.class("grow"),
          attribute.type_("email"),
          attribute.name(name),
          attribute.value(form.value(form, name)),
          attribute.autocomplete("off"),
        ]),
      ],
    ),
    error_element,
  ])
}

pub fn password_input(form: Form, name: String) {
  let error_element = case form.field_state(form, name) {
    Ok(_) -> element.none()
    Error(message) -> field_error(message)
  }

  html.div([], [
    html.label(
      [attribute.class("input input-bordered flex items-center gap-2 my-4")],
      [
        html.svg(
          [
            attribute.class("h-4 w-4 opacity-70"),
            attribute("fill", "currentColor"),
            attribute("viewBox", "0 0 16 16"),
            attribute("xmlns", "http://www.w3.org/2000/svg"),
          ],
          [
            element(
              "path",
              [
                attribute("clip-rule", "evenodd"),
                attribute(
                  "d",
                  "M14 6a4 4 0 0 1-4.899 3.899l-1.955 1.955a.5.5 0 0 1-.353.146H5v1.5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1-.5-.5v-2.293a.5.5 0 0 1 .146-.353l3.955-3.955A4 4 0 1 1 14 6Zm-4-2a.75.75 0 0 0 0 1.5.5.5 0 0 1 .5.5.75.75 0 0 0 1.5 0 2 2 0 0 0-2-2Z",
                ),
                attribute("fill-rule", "evenodd"),
              ],
              [],
            ),
          ],
        ),
        html.input([
          attribute.placeholder("************"),
          attribute.class("grow"),
          attribute.type_("password"),
          attribute.name(name),
          attribute.value(form.value(form, name)),
          attribute.autocomplete("off"),
        ]),
      ],
    ),
    error_element,
  ])
}
