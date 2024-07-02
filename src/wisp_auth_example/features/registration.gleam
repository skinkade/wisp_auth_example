import antigone
import birl
import birl/duration
import gleam/bit_array
import gleam/dynamic
import gleam/http.{Get, Post}
import gleam/io
import gleam/list
import gleam/pgo
import gleam/result
import gleam/string_builder
import wisp.{type Request}
import wisp_auth_example/token
import wisp_auth_example/web.{type Context}
import youid/uuid

pub fn register_handler(req: Request, ctx: Context) {
  case req.method {
    Get -> email_register_view()
    Post -> register_email(req, ctx)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

pub fn email_register_view() {
  let html =
    string_builder.from_string(
      "<form method='post'>
        <label>Email:
          <input type='email' name='email'>
        </label>
        <input type='submit' value='Submit'>
      </form>",
    )
  wisp.ok()
  |> wisp.html_body(html)
}

pub fn register_email(req: Request, ctx: Context) {
  use formdata <- wisp.require_form(req)

  case list.key_find(formdata.values, "email") {
    Ok(email) -> {
      save_email_registration(ctx.db, email)
      let html = string_builder.from_string("<span>Sent!</span>")
      wisp.ok()
      |> wisp.html_body(html)
    }
    Error(_) -> {
      wisp.bad_request()
    }
  }
}

fn save_email_registration(db: pgo.Connection, email: String) {
  let token = token.new()
  let expiration = birl.utc_now() |> birl.add(duration.days(1))
  let sql =
    "
        insert into email_registration
        (id, verification_hash, expires_at, sent_to)
        values
        ($1, $2, $3, $4)
    "

  let assert Ok(_) =
    pgo.execute(
      sql,
      db,
      [
        pgo.text(token.id |> uuid.to_string()),
        pgo.bytea(token |> token.verification_hash()),
        pgo.timestamp(expiration |> birl.to_erlang_universal_datetime()),
        pgo.text(email),
      ],
      dynamic.dynamic,
    )

  io.println(
    "http://localhost:8000/register/confirm/" <> token.to_string(token),
  )
}

pub fn confirm_registration_handler(req: Request, _ctx: Context, token: String) {
  case req.method {
    Get -> confirm_registration_view(token)
    _ -> wisp.method_not_allowed([Get])
  }
}

pub fn confirm_registration_view(token: String) {
  let html =
    string_builder.from_string("<form method='post' action='/register/confirm'>
        <input type='hidden' name='token' value='" <> wisp.escape_html(token) <> "'/>
        <label>Password:
          <input type='password' name='password'>
        </label>
        <input type='submit' value='Submit'>
      </form>")
  wisp.ok()
  |> wisp.html_body(html)
}

fn email_from_token(
  token_str: String,
  db: pgo.Connection,
) -> Result(String, Nil) {
  use token <- result.try(token.from_string(token_str))

  let sql =
    "
        select sent_to
        from email_registration
        where id = $1
            and verification_hash = $2
            and expires_at > now()
    "

  let assert Ok(response) =
    pgo.execute(
      sql,
      db,
      [
        pgo.text(token.id |> uuid.to_string()),
        pgo.bytea(token |> token.verification_hash()),
      ],
      dynamic.element(0, dynamic.string),
    )

  io.debug(response)

  case response.rows {
    [email] -> Ok(email)
    _ -> Error(Nil)
  }
}

fn save_user(db: pgo.Connection, email: String, password: String) {
  let id = uuid.v7()
  let password_hash =
    antigone.hash(antigone.hasher(), bit_array.from_string(password))

  let sql =
    "
    insert into wuser
    (id, provider_id, provider, password_hash)
    values
    ($1, $2, 'email', $3)
  "

  let assert Ok(_) =
    pgo.execute(
      sql,
      db,
      [
        pgo.text(id |> uuid.to_string()),
        pgo.text(email),
        pgo.text(password_hash),
      ],
      dynamic.dynamic,
    )
}

pub fn confirm_registration(req: Request, ctx: Context) {
  use formdata <- wisp.require_form(req)

  let parsed = {
    use token <- result.try(list.key_find(formdata.values, "token"))
    use password <- result.try(list.key_find(formdata.values, "password"))
    Ok(#(token, password))
  }

  io.debug(parsed)

  case parsed {
    Ok(#(token, password)) -> {
      case email_from_token(token, ctx.db) {
        Ok(email) -> {
          let _ = save_user(ctx.db, email, password)
          let html = string_builder.from_string("<span>Registered!</span>")
          wisp.ok()
          |> wisp.html_body(html)
        }
        Error(_) -> {
          io.debug("Could not find token")
          wisp.bad_request()
        }
      }
    }
    Error(_) -> {
      io.debug("Failed to parsed request")
      wisp.bad_request()
    }
  }
}
