import antigone
import birl.{type Time}
import birl/duration
import gleam/bit_array
import gleam/dynamic.{type DecodeError, type Dynamic, DecodeError}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/pgo.{type Connection}
import gleam/result
import wisp_auth_example/token.{type Token}
import youid/uuid.{type Uuid}

const default_session_duration_days = 7

const lockout_duration_minutes = 15

pub fn dynamic_uuid(d: Dynamic) -> Result(Uuid, List(DecodeError)) {
  dynamic.bit_array(d)
  |> result.then(fn(ba) {
    uuid.from_bit_array(ba)
    |> result.replace_error([
      DecodeError(expected: "uuid", found: "?", path: []),
    ])
  })
}

pub type User {
  User(id: Uuid, password_hash: String, mfa_enabled: Bool)
}

pub fn get_enabled_user_by_email(
  db: Connection,
  email: String,
) -> Result(Option(User), pgo.QueryError) {
  let sql =
    "
      select id, password_hash, mfa_enabled
      from wuser
      where provider_id = $1
        and provider = 'email'
        and password_hash is not null
        and (
          locked_until is null
          or locked_until < now()
        )
    "

  use response <- result.try(pgo.execute(
    sql,
    db,
    [pgo.text(email)],
    dynamic.decode3(
      User,
      dynamic.element(0, dynamic_uuid),
      dynamic.element(1, dynamic.string),
      dynamic.element(2, dynamic.bool),
    ),
  ))

  case response.rows {
    [user] -> Ok(Some(user))
    _ -> Ok(None)
  }
}

pub fn valid_user_password(user: User, password: String) -> Bool {
  antigone.verify(bit_array.from_string(password), user.password_hash)
}

/// Use: delay response for 50 to 250ms
/// to obfuscate timing and do poor man's rate limiting
pub fn delay() -> Nil {
  process.sleep(int.random(201) + 50)
}

pub fn create_user_session(
  db: Connection,
  user_id: Uuid,
) -> Result(Token, pgo.TransactionError) {
  let user_id = user_id |> uuid.to_string()
  let expiration =
    birl.utc_now() |> birl.add(duration.days(default_session_duration_days))

  let session_sql =
    "
        insert into wuser_session
        (id, verification_hash, expires_at, wuser_id)
        values
        ($1, $2, $3, $4)
    "

  let login_update_sql =
    "
        update wuser
        set last_login = now(),
            failed_login_count = 0,
            failed_mfa_count = 0
        where id = $1
    "

  let token = token.new()

  use _ <- result.try(
    pgo.transaction(db, fn(db) {
      let assert Ok(_) =
        pgo.execute(
          session_sql,
          db,
          [
            pgo.text(token.id |> uuid.to_string()),
            pgo.bytea(token |> token.verification_hash()),
            pgo.timestamp(expiration |> birl.to_erlang_universal_datetime()),
            pgo.text(user_id),
          ],
          dynamic.dynamic,
        )

      let assert Ok(_) =
        pgo.execute(login_update_sql, db, [pgo.text(user_id)], dynamic.dynamic)

      // need something better here
      Ok(dynamic.from(0))
    }),
  )
  Ok(token)
}

pub type LoginFailureRecordResult {
  IncrementedFailureCount
  LockedAccount
}

pub fn lock_user_account(
  db: Connection,
  user_id: Uuid,
) -> Result(Nil, pgo.QueryError) {
  let lockout_sql =
    "
        update wuser
        set locked_until = $1
        where id = $2
    "

  let locked_until =
    birl.utc_now()
    |> birl.add(duration.minutes(lockout_duration_minutes))

  use _ <- result.try(pgo.execute(
    lockout_sql,
    db,
    [
      pgo.timestamp(locked_until |> birl.to_erlang_universal_datetime()),
      pgo.text(user_id |> uuid.to_string()),
    ],
    dynamic.dynamic,
  ))

  Ok(Nil)
}

pub type LoginFailureCount {
  LoginFailureCount(Int)
}

pub fn record_password_login_failure(
  db: Connection,
  user: User,
) -> Result(LoginFailureCount, pgo.QueryError) {
  let user_id = user.id |> uuid.to_string()

  let failed_attempt_sql =
    "
        update wuser
        set failed_login_count = failed_login_count + 1
        where id = $1
        returning failed_login_count
    "

  use failed_login_count_response <- result.try(pgo.execute(
    failed_attempt_sql,
    db,
    [pgo.text(user_id)],
    dynamic.element(0, dynamic.int),
  ))

  let assert Ok(failed_login_count) =
    list.first(failed_login_count_response.rows)

  Ok(LoginFailureCount(failed_login_count))
}

pub type MfaFailureCount {
  MfaFailureCount(Int)
}

pub fn record_mfa_login_failure(
  db: Connection,
  user_id: Uuid,
) -> Result(MfaFailureCount, pgo.QueryError) {
  let user_id = user_id |> uuid.to_string()

  let failed_attempt_sql =
    "
        update wuser
        set failed_mfa_count = failed_mfa_count + 1
        where id = $1
        returning failed_mfa_count
    "

  use failed_mfa_count_response <- result.try(pgo.execute(
    failed_attempt_sql,
    db,
    [pgo.text(user_id)],
    dynamic.element(0, dynamic.int),
  ))

  let assert Ok(failed_mfa_count) = list.first(failed_mfa_count_response.rows)

  Ok(MfaFailureCount(failed_mfa_count))
}
