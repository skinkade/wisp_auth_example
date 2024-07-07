import gleeunit/should
import wisp_auth_example/types/email
import wisp_auth_example/types/password

pub fn valid_passwords_test() {
  let result =
    password.create("correct horse battery staple")
    |> should.be_ok()
  password.valid(result, password.hash(result))
  |> should.be_true()

  let result =
    password.create("πßå")
    |> should.be_ok()
  password.valid(result, password.hash(result))
  |> should.be_true()

  let result =
    password.create("Jack of ♦s")
    |> should.be_ok()
  password.valid(result, password.hash(result))
  |> should.be_true()

  let result =
    password.create("foo bar")
    |> should.be_ok()
  password.valid(result, password.hash(result))
  |> should.be_true()
}

pub fn invalid_passwords_test() {
  password.create("")
  |> should.be_error()

  password.create("my cat is a \tboy")
  |> should.be_error()
}

pub fn valid_emails_test() {
  email.parse("foo@example.com")
  |> should.be_ok()

  email.parse("foo+site@example.com")
  |> should.be_ok()
}

pub fn invalid_emails_test() {
  email.parse("foo")
  |> should.be_error()

  email.parse("foo@")
  |> should.be_error()

  email.parse("@foo")
  |> should.be_error()

  email.parse("foo@example")
  |> should.be_error()
}
