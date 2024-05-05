import gleam/bit_array
import gleam/crypto
import gleam/dict
import gleam/dynamic
import gleam/io
import gleam/json.{type Json, to_string}
import gleam/pgo.{type Value}
import packets/dto.{type CreateCharacter, type Look}

pub fn create_character(
  db: pgo.Connection,
  account_id: Int,
  create_character: CreateCharacter,
) {
  let sql =
    "INSERT INTO characters (account_id, name, map, look, hair) VALUES ($1, $2, $3, $4, $5) RETURNING id"

  let args: List(Value) = [
    pgo.int(account_id),
    pgo.text(create_character.name),
    pgo.text(create_character.map),
    pgo.text(to_string(dto.look_to_json(create_character.look))),
    pgo.int(create_character.look.hair),
  ]

  let return_type = dynamic.element(0, dynamic.int)

  let assert Ok(_) = pgo.execute(sql, db, args, return_type)
}

pub fn get_characters(db: pgo.Connection, account_id: Int) {
  let sql =
    "SELECT id, account_id, name, map, look, hair FROM characters WHERE account_id = $1"

  let return_type =
    dynamic.tuple6(
      dynamic.int,
      dynamic.int,
      dynamic.string,
      dynamic.string,
      dynamic.string,
      dynamic.int,
    )

  let assert Ok(_) = pgo.execute(sql, db, [pgo.int(account_id)], return_type)
}
