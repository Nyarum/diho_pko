import bytes/pack
import bytes/packet.{Unpack}
import core/context.{Context}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process.{Normal}
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
  Buffer(buf: BitArray, last_len: Int)
}

type Errors {
  SucessContinue
  SendError
  Closed
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
        #(Buffer(<<>>, 0), None)
      },
      fn(msg, state, conn) {
        let assert Packet(msg) = msg
        io.debug("First state")
        io.debug(state.last_len)
        io.debug(state)

        let len_pkt = case state.last_len {
          0 -> {
            let assert <<len_pkt:16, _:bytes>> = msg
            len_pkt
          }
          _ -> {
            state.last_len
          }
        }

        let new_state =
          Buffer(
            state.buf
              |> bit_array.append(msg),
            len_pkt,
          )

        case int.compare(bit_array.byte_size(new_state.buf), len_pkt) {
          order.Lt -> {
            actor.continue(new_state)
          }
          order.Eq -> {
            io.debug("all is okay, pkt full")

            case process_packet(new_state.buf, db, conn) {
              Ok(_) -> actor.continue(Buffer(<<>>, 0))
              Error(err) -> {
                io.debug("happened some shit")
                io.debug(err)
                actor.Stop(Normal)
              }
            }
          }
          _ -> {
            io.debug("by some issue it above")
            io.debug(bit_array.byte_size(new_state.buf))
            io.debug(len_pkt)
            actor.continue(Buffer(<<>>, 0))
          }
        }
      },
    )
    |> glisten.serve(1973)

  process.sleep_forever()
}

fn process_packet(msg, db, conn) {
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
    Ok(Ok(Nil)) -> Ok(SucessContinue)
    Ok(Error(state)) -> {
      io.debug("error send")
      io.debug(state)
      Error(SendError)
    }
    Error(err) -> {
      io.debug("maybe stop?")
      io.debug(err)
      Error(SendError)
    }
  }
}
