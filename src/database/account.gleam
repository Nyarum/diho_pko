import gleam/bit_array
import gleam/crypto
import gleam/dynamic
import gleam/io
import gleam/option.{type Option}
import gleam/pgo.{type Value}
import packets/dto.{type Auth}

pub type Account {
  Account(
    id: Int,
    login: String,
    password: String,
    mac: String,
    is_cheat: Int,
    client_version: Int,
    pincode: Option(String),
  )
}

fn get_field(data: dynamic.Dynamic, b) -> j {
  let assert Ok(x) = b(data)
  x
}

pub fn get_account(db: pgo.Connection, login: String) {
  let sql =
    "SELECT id, login, password, mac, is_cheat, client_version, pincode FROM accounts WHERE login = $1"

  let args: List(Value) = [pgo.text(login)]

  let return_type =
    dynamic.any([
      fn(x) {
        Ok(Account(
          get_field(x, dynamic.element(0, dynamic.int)),
          get_field(x, dynamic.element(1, dynamic.string)),
          get_field(x, dynamic.element(2, dynamic.string)),
          get_field(x, dynamic.element(3, dynamic.string)),
          get_field(x, dynamic.element(4, dynamic.int)),
          get_field(x, dynamic.element(5, dynamic.int)),
          get_field(x, dynamic.element(6, dynamic.optional(dynamic.string))),
        ))
      },
    ])

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

pub fn update_pincode(db: pgo.Connection, pincode: String, account_id: Int) {
  let sql = "UPDATE accounts SET pincode = $1 WHERE id = $2"

  let args: List(Value) = [pgo.text(pincode), pgo.int(account_id)]

  let return_type = dynamic.element(0, dynamic.int)

  let assert Ok(_) = pgo.execute(sql, db, args, return_type)
}
