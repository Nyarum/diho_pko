import bytes/pack
import bytes/packet.{Unpack}
import core/context.{Context}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process.{Normal}
import gleam/int
import gleam/int
import gleam/io
import gleam/option.{None}
import gleam/order
import gleam/otp/actor
import gleam/pgo
import gleam/string
import glisten.{Packet}
import packets/auth
import packets/create_character
import packets/first_date

type Buffer {
  Buffer(buf: BitArray, len: Int)
}

pub fn main() {
  let db =
    pgo.connect(
      pgo.Config(
        ..pgo.default_config(),
        host: "127.0.0.1",
        database: "postgres",
        user: "postgres",
        password: option.Some("example"),
        pool_size: 15,
      ),
    )

  let buffer_collect = Buffer(<<>>, 0)
  let collect_bytes = fn(buffer, len, buf) -> BitArray {
    case int.compare(bit_array.byte_size(buf), len) {
      order.Lt -> {
        Buffer(..buffer_collect, buf: buf, len: len)
      }
    }
  }

  let assert Ok(_) =
    glisten.handler(
      fn(conn) {
        io.debug(
          "new connection with client ip:" <> string.inspect(conn.client_ip),
        )
        let first_date_pack =
          first_date.first_date()
          |> pack.pack()
        let assert Ok(_) =
          bytes_builder.from_bit_array(first_date_pack)
          |> glisten.send(conn, _)
        #(Nil, None)
      },
      fn(msg, state, conn) {
        let assert Packet(msg) = msg
        io.debug("state")
        io.debug(state)

        let switch = case msg {
          <<_:16>> -> {
            glisten.send(conn, bytes_builder.from_bit_array(msg))
            |> Ok
          }
          <<len:16, id:little-size(32), opcode:big-16, next:bytes>> -> {
            io.debug(
              "unpacked header with len: "
              <> int.to_string(len)
              <> " and id:"
              <> int.to_string(id)
              <> " and opcode:"
              <> int.to_string(opcode),
            )

            let res = case opcode {
              431 ->
                auth.handle(Context(db), _)
                |> Unpack(next, _)
                |> auth.auth
                |> Ok
              435 -> {
                io.debug(bit_array.byte_size(next))
                create_character.handle(Context(db), _)
                |> Unpack(next, _)
                |> create_character.create_character
                |> Ok
              }
              432 -> {
                io.debug("account exited")
                Error(Normal)
              }
              _ -> {
                io.debug("something wrong")
                Ok(<<>>)
              }
            }

            case res {
              Ok(buf) ->
                bytes_builder.from_bit_array(buf)
                |> glisten.send(conn, _)
                |> Ok
              Error(state) -> Error(state)
            }
          }
          _ -> {
            io.debug("something wrong with unpack header")
            Ok(Ok(Nil))
          }
        }

        case switch {
          Ok(Ok(Nil)) -> actor.continue(Nil)
          Ok(Error(state)) -> {
            io.debug("error send")
            io.debug(state)
            actor.Stop(Normal)
          }
          Error(err) -> {
            io.debug("maybe stop?")
            io.debug(err)
            actor.Stop(Normal)
          }
        }
      },
    )
    |> glisten.serve(1973)

  process.sleep_forever()
}
