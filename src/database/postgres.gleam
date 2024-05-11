import gleam/dynamic
import gleam/pgo.{type Value}

pub fn get_storage(db: pgo.Connection) {
  let sql = "SELECT id, data FROM storage WHERE id = 1"

  let args: List(Value) = []

  let return_type = dynamic.tuple2(dynamic.int, dynamic.string)

  let assert Ok(_) = pgo.execute(sql, db, args, return_type)
}

pub fn upsert_storage(db: pgo.Connection, data: String) {
  let sql =
    "INSERT INTO storage (id, data) VALUES ($1, $2) ON CONFLICT (id) DO UPDATE 
     SET data = excluded.data"

  let args: List(Value) = [pgo.int(1), pgo.text(data)]

  let assert Ok(_) = pgo.execute(sql, db, args, dynamic.dynamic)
}
