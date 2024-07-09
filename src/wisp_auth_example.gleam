import gleam/erlang/process
import gleam/option.{Some}
import gleam/pgo
import mist
import wisp
import wisp_auth_example/router
import wisp_auth_example/web

pub fn main() {
  wisp.configure_logger()
  let secret_key_base = wisp.random_string(64)

  let db =
    pgo.connect(
      pgo.Config(
        ..pgo.default_config(),
        host: "localhost",
        password: Some("postgres"),
        database: "wisp_auth_example",
        pool_size: 15,
      ),
    )

  let context = web.Context(db: db, static_dir: static_directory())

  let handler = router.handle_request(_, context)

  let assert Ok(_) =
    handler
    |> wisp.mist_handler(secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start_http

  process.sleep_forever()
}

pub fn static_directory() -> String {
  let assert Ok(priv_directory) = wisp.priv_directory("wisp_auth_example")
  priv_directory <> "/static"
}
