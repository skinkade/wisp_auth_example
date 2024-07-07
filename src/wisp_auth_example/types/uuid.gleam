import gleam/dynamic.{type DecodeError, type Dynamic, DecodeError}
import gleam/result
import youid/uuid.{type Uuid}

pub fn dynamic_uuid(d: Dynamic) -> Result(Uuid, List(DecodeError)) {
  dynamic.bit_array(d)
  |> result.then(fn(ba) {
    uuid.from_bit_array(ba)
    |> result.replace_error([
      DecodeError(expected: "uuid", found: "?", path: []),
    ])
  })
}
