import bytes/pack
import bytes/packet.{Unpack}
import gleam/bytes_builder
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/option.{None}
import gleam/otp/actor
import gleam/string
import glisten.{Packet}
import packets/auth
import packets/first_date

pub fn main() {
  let first_date_pack =
    first_date.first_date()
    |> pack.pack()

  io.debug(bytes_builder.from_bit_array(first_date_pack))

  let assert Ok(_) =
    glisten.handler(
      fn(conn) {
        io.debug(
          "new connection with client ip:" <> string.inspect(conn.client_ip),
        )
        let assert Ok(_) =
          glisten.send(conn, bytes_builder.from_bit_array(first_date_pack))
        #(Nil, None)
      },
      fn(msg, state, conn) {
        let assert Packet(msg) = msg

        case msg {
          <<
            len:little-size(16),
            id:little-size(32),
            opcode:little-size(16),
            next:bytes,
          >> -> {
            io.debug(
              "unpacked header with len: "
              <> int.to_string(len)
              <> " and id:"
              <> int.to_string(id),
            )

            case opcode {
              431 ->
                auth.auth(
                  Unpack(next, fn(auth) {
                    io.debug("got a new auth")
                    io.debug(auth)
                    Nil
                  }),
                )
              _ -> {
                io.debug("unknown opcode")
                Nil
              }
            }
          }
          _ -> {
            io.debug("something wrong with unpack header")
            Nil
          }
        }
        let assert Ok(_) = glisten.send(conn, bytes_builder.from_bit_array(msg))
        actor.continue(state)
      },
    )
    |> glisten.serve(1973)

  process.sleep_forever()
}
