import gleam/bit_array
import gleam/dynamic
import gleam/io
import gleam/pgo.{type Value}
import gleam/result
import packets/dto.{type Auth}

pub fn create_account(db: pgo.Connection, auth: Auth) {
  // An SQL statement to run. It takes one int as a parameter
  let sql =
    "INSERT INTO accounts (login, password, mac, is_cheat, client_version) VALUES ($1, 's', 's', 1, 1)"

  let args: List(Value) = [
    pgo.text(auth.login),
    pgo.text(result.unwrap(bit_array.to_string(auth.password), "")),
    pgo.text(auth.mac),
    pgo.int(auth.is_cheat),
    pgo.int(auth.client_version),
  ]

  io.debug(args)

  // Run the query against the PostgreSQL database
  // The int `1` is given as a parameter
  let assert Ok(_) =
    pgo.execute(sql, db, [pgo.text(auth.login)], dynamic.dynamic)
}
