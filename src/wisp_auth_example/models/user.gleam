import birl.{type Time}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option, None, Some}
import gleam/pgo.{type Connection}
import gleam/result
import wisp_auth_example/types/email.{type Email}
import wisp_auth_example/types/password.{type Password}
import wisp_auth_example/types/time
import wisp_auth_example/types/uuid as uuid_extensions
import youid/uuid

pub type UserId {
  UserId(value: uuid.Uuid)
}

pub fn id_pgo(user_id: UserId) {
  pgo.text(user_id.value |> uuid.to_string())
}

pub fn dynamic_user_id(d: Dynamic) {
  use uuid <- result.try(uuid_extensions.dynamic_uuid(d))
  Ok(UserId(uuid))
}

pub type UserDbRecord {
  UserDbRecord(
    id: UserId,
    email: Email,
    email_verified_at: Option(Time),
    password_hash: String,
    created_at: Time,
    disabled_at: Option(Time),
    last_login: Option(Time),
    login_failures: Int,
    locked_until: Option(Time),
  )
}

pub fn from_dynamic_tuple(d: Dynamic) {
  let decoder =
    dynamic.decode9(
      UserDbRecord,
      dynamic.element(0, dynamic_user_id),
      dynamic.element(1, email.dynamic_email),
      dynamic.element(2, dynamic.optional(time.dynamic_time)),
      dynamic.element(3, dynamic.string),
      dynamic.element(4, time.dynamic_time),
      dynamic.element(5, dynamic.optional(time.dynamic_time)),
      dynamic.element(6, dynamic.optional(time.dynamic_time)),
      dynamic.element(7, dynamic.int),
      dynamic.element(8, dynamic.optional(time.dynamic_time)),
    )

  decoder(d)
}

pub fn create(
  conn: Connection,
  email: Email,
  password: Password,
) -> Result(UserDbRecord, pgo.QueryError) {
  let user =
    UserDbRecord(
      id: UserId(uuid.v4()),
      email: email,
      email_verified_at: None,
      password_hash: password.hash(password),
      created_at: birl.utc_now(),
      disabled_at: None,
      last_login: None,
      login_failures: 0,
      locked_until: None,
    )

  let sql =
    "
        insert into users
        (id, email, email_verified_at, password_hash, created_at, disabled_at, last_login, login_failures, locked_until)
        values
        ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    "

  use _ <- result.try({
    pgo.execute(
      sql,
      conn,
      [
        user.id |> id_pgo,
        user.email |> email.to_string |> pgo.text,
        pgo.null(),
        user.password_hash |> pgo.text,
        user.created_at |> birl.to_erlang_universal_datetime |> pgo.timestamp,
        pgo.null(),
        pgo.null(),
        user.login_failures |> pgo.int,
        pgo.null(),
      ],
      dynamic.dynamic,
    )
  })

  Ok(user)
}

pub fn get_by_email(
  conn: Connection,
  email: Email,
) -> Result(Option(UserDbRecord), pgo.QueryError) {
  let sql =
    "
    select
        id,
        email,
        email_verified_at::text,
        password_hash,
        created_at::text,
        disabled_at::text,
        last_login::text,
        login_failures,
        locked_until::text
    from users
    where email = $1
  "

  use result <- result.try({
    pgo.execute(
      sql,
      conn,
      [email |> email.to_string |> pgo.text],
      from_dynamic_tuple,
    )
  })

  case result.rows {
    [] -> Ok(None)
    [user] -> Ok(Some(user))
    _ -> panic as "Multiple users with same email"
  }
}
