import bytes/pack
import bytes/packet.{Unpack}
import core/context.{type Context, Context}
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process.{Normal}
import gleam/float
import gleam/int
import gleam/io
import gleam/option.{None}
import gleam/order
import gleam/otp/actor
import gleam/pgo
import gleam/result
import gleam/string
import glisten.{Packet}
import packets/auth.{type AuthResp as AuthRespPkt, AuthResp as AuthRespPkt}
import packets/create_character
import packets/first_date
import packets/world

type Errors {
  NotFoundOpcode
  SendError
  Nothing
  Closed
  CantHandle
}

fn ttt() {
  use val <- result.try(float.divide(1.0, 0.01))
  io.println(float.to_string(val))
  Ok(val)
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
        #(Context(db, <<>>, 0, 0), None)
      },
      fn(msg, state, conn) {
        let assert Packet(msg) = msg

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
          Context(
            db,
            state.buf
              |> bit_array.append(msg),
            len_pkt,
            state.account_id,
          )

        case int.compare(bit_array.byte_size(new_state.buf), len_pkt) {
          order.Lt -> {
            actor.continue(new_state)
          }
          order.Eq -> {
            case process_packet(new_state, conn) {
              Ok(ctx) -> actor.continue(Context(..ctx, buf: <<>>, last_len: 0))
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
            actor.continue(new_state)
          }
        }
      },
    )
    |> glisten.serve(1973)

  process.sleep_forever()
}

type BufOrData {
  Data(buf: BitArray, account_id: Int)
  Buf(buf: BitArray)
}

fn process_packet(ctx: Context, conn) -> Result(Context, Errors) {
  case ctx.buf {
    <<_:16>> -> {
      case glisten.send(conn, bytes_builder.from_bit_array(ctx.buf)) {
        Ok(_) -> Ok(ctx)
        Error(err) -> {
          io.debug("can't send message")
          io.debug(err)

          Error(SendError)
        }
      }
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

      let res: Result(BufOrData, Errors) = case opcode {
        431 -> {
          let auth_handle =
            auth.handle(ctx, _)
            |> Unpack(next, _)
            |> auth.auth

          case auth_handle {
            Ok(AuthRespPkt(buf, account_id)) -> Ok(Data(buf, account_id))
            Error(err) -> {
              io.debug(err)
              Error(CantHandle)
            }
          }
        }
        435 -> {
          create_character.handle(ctx, _)
          |> Unpack(next, _)
          |> create_character.create_character
          |> Buf
          |> Ok
        }
        346 -> {
          let pincode_handle =
            auth.pincode_handle(ctx, _)
            |> Unpack(next, _)
            |> auth.pincode

          case pincode_handle {
            Ok(buf) -> Ok(Buf(buf))
            Error(err) -> {
              io.debug(err)
              Error(CantHandle)
            }
          }
        }
        347 -> {
          let change_pincode_handle =
            auth.change_pincode_handle(ctx, _)
            |> Unpack(next, _)
            |> auth.change_pincode

          case change_pincode_handle {
            Ok(buf) -> Ok(Buf(buf))
            Error(err) -> {
              io.debug(err)
              Error(CantHandle)
            }
          }
        }
        436 -> {
          let remove_character_handler =
            auth.remove_character_handle(ctx, _)
            |> Unpack(next, _)
            |> auth.remove_character

          case remove_character_handler {
            Ok(buf) -> Ok(Buf(buf))
            Error(err) -> {
              io.debug(err)
              Error(CantHandle)
            }
          }
        }
        433 -> {
          let enter_game_handler =
            world.enter_game_handle(ctx, _)
            |> Unpack(next, _)
            |> world.enter_game

          case enter_game_handler {
            Ok(buf) -> Ok(Buf(buf))
            Error(err) -> {
              io.debug(err)
              Error(CantHandle)
            }
          }
        }
        432 -> {
          io.debug("account exited")
          Error(Closed)
        }
        _ -> {
          io.debug("unknown opcode")
          Error(NotFoundOpcode)
        }
      }

      case res {
        Ok(Data(buf, account_id)) -> {
          let assert Ok(_) =
            glisten.send(conn, bytes_builder.from_bit_array(buf))

          Ok(Context(..ctx, account_id: account_id))
        }
        Ok(Buf(buf)) -> {
          let assert Ok(_) =
            glisten.send(conn, bytes_builder.from_bit_array(buf))

          Ok(ctx)
        }
        Error(state) -> Error(state)
      }
    }
    _ -> {
      io.debug("something wrong with unpack header")
      Ok(ctx)
    }
  }
}
