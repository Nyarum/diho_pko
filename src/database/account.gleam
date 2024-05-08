import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/pgo.{type Value}
import packets/dto.{type Auth}

pub fn get_account(db: pgo.Connection, login: String) {
  let sql =
    "SELECT id, login, password, mac, is_cheat, client_version FROM accounts WHERE login = $1"

  let args: List(Value) = [pgo.text(login)]

  let return_type =
    dynamic.tuple6(
      dynamic.int,
      dynamic.string,
      dynamic.string,
      dynamic.string,
      dynamic.int,
      dynamic.int,
    )

  let assert Ok(_) = pgo.execute(sql, db, args, return_type)
}

pub fn create_account(db: pgo.Connection, auth: Auth) {
  let sql =
    "INSERT INTO accounts (login, password, mac, is_cheat, client_version) VALUES ($1, $2, $3, $4, $5) RETURNING id"

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

  let return_type = dynamic.element(0, dynamic.int)

  let assert Ok(_) = pgo.execute(sql, db, args, return_type)
}
