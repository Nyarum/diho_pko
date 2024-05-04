import bytes/pack
import bytes/packet.{Unpack}
import gleam/bytes_builder
import gleam/erlang/process.{Normal}
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
      fn(msg, _, conn) {
        let assert Packet(msg) = msg

        let switch = case msg {
          <<_:16>> -> {
            let assert Ok(_) =
              glisten.send(conn, bytes_builder.from_bit_array(msg))
            Ok(Ok(Nil))
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
                auth.handle
                |> Unpack(next, _)
                |> auth.auth
                |> Ok
              432 -> {
                Error(Normal)
              }
              _ -> {
                Error(Normal)
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
          Error(_) -> actor.Stop(Normal)
        }
      },
    )
    |> glisten.serve(1973)

  process.sleep_forever()
}
