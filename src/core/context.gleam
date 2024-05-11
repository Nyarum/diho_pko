import database/local.{type Msg}
import gleam/erlang/process.{type Subject}

pub type Context {
  Context(
    storage: Subject(Msg),
    buf: BitArray,
    last_len: Int,
    account_id: String,
  )
}
