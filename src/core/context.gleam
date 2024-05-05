import gleam/pgo.{type Connection}

pub type Context {
  Context(conn: Connection, buf: BitArray, last_len: Int, account_id: Int)
}
