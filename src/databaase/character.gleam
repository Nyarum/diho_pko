import gleam/bit_array
import gleam/crypto
import gleam/dict
import gleam/dynamic
import gleam/io
import gleam/json.{type Json}
import gleam/pgo.{type Value}
import jasper.{Object, String}
import packets/dto.{type CreateCharacter, type Look}

pub fn create_character(
  db: pgo.Connection,
  account_id: Int,
  create_character: CreateCharacter,
) {
  // An SQL statement to run. It takes one int as a parameter
  let sql =
    "INSERT INTO characters (account_id, name, map, look, hair) VALUES ($1, $2, $3, $4, $5)"

  let look_dict =
    dict.new()
    |> dict.insert("test", String("tett"))

  io.debug(jasper.stringify_json(Object(look_dict)))

  let args: List(Value) = [
    pgo.int(account_id),
    pgo.text(create_character.name),
    pgo.text(create_character.map),
    pgo.text(""),
    pgo.int(create_character.look.hair),
  ]

  // Run the query against the PostgreSQL database
  // The int `1` is given as a parameter
  let assert Ok(_) = pgo.execute(sql, db, args, dynamic.dynamic)
}
