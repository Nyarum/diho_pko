import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/pgo.{type Value}
import packets/dto.{type Auth}

pub fn create_account(db: pgo.Connection, auth: Auth) {
  // An SQL statement to run. It takes one int as a parameter
  let sql =
    "INSERT INTO accounts (login, password, mac, is_cheat, client_version) VALUES ($1, $2, $3, $4, $5)"

  let password_md5_hex =
    crypto.hash(crypto.Md5, auth.password)
    |> bit_array.base64_encode(True)

  let args: List(Value) = [
    pgo.text(auth.login),
    pgo.text(password_md5_hex),
    pgo.text(auth.mac),
    pgo.int(auth.is_cheat),
    pgo.int(auth.client_version),
  ]

  // Run the query against the PostgreSQL database
  // The int `1` is given as a parameter
  let assert Ok(_) = pgo.execute(sql, db, args, dynamic.dynamic)
}
