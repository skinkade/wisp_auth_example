import gleam/bit_array
import gleam/bool
import gleam/crypto
import gleam/io
import gleam/result
import youid/uuid

const id_byte_length = 16

const verifier_byte_length = 20

const verifier_hash_method = crypto.Sha256

pub type Token {
  Token(id: uuid.Uuid, verifier: BitArray)
}

pub fn new() -> Token {
  let verifier = crypto.strong_random_bytes(verifier_byte_length)
  let id = uuid.v7()
  Token(id, verifier)
}

pub fn to_string(token: Token) -> String {
  token.id
  |> uuid.to_bit_array()
  |> bit_array.append(token.verifier)
  |> bit_array.base64_url_encode(False)
}

pub fn from_string(token_str: String) -> Result(Token, Nil) {
  use a <- result.try(bit_array.base64_url_decode(token_str))
  io.debug("Decoded token")
  let len = bit_array.byte_size(a)
  io.debug(len)
  use <- bool.guard(len <= id_byte_length, Error(Nil))
  io.debug("Token is right length")

  let assert Ok(id_bytes) = bit_array.slice(a, 0, id_byte_length)
  use id <- result.try(uuid.from_bit_array(id_bytes))

  let assert Ok(verifier) =
    bit_array.slice(a, id_byte_length, len - id_byte_length)

  Ok(Token(id, verifier))
}

pub fn verification_hash(token: Token) -> BitArray {
  crypto.hash(verifier_hash_method, token.verifier)
}

pub fn verify_hash(token: Token, hash: BitArray) -> Bool {
  let reference = verification_hash(token)
  crypto.secure_compare(reference, hash)
}
