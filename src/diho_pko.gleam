import bytes/pack
import bytes/packet.{Unpack}
import core/context.{type Context, Context}
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
import packets/auth.{AuthResp, Continue}
import packets/create_character
import packets/first_date

type Errors {
  SucessContinue
  SendError
  Nothing
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
                case err {
                  SucessContinue ->
                    actor.continue(Context(..state, buf: <<>>, last_len: 0))
                  _ -> {
                    io.debug("happened some shit")
                    io.debug(err)
                    actor.Stop(Normal)
                  }
                }
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

      let auth_res = case opcode {
        431 ->
          auth.handle(ctx, _)
          |> Unpack(next, _)
          |> auth.auth
          |> Ok
        _ -> {
          io.debug("something wrong")
          Ok(Continue)
        }
      }

      let res = case opcode {
        435 -> {
          io.debug(bit_array.byte_size(next))
          create_character.handle(ctx, _)
          |> Unpack(next, _)
          |> create_character.create_character
          |> Ok
        }
        432 -> {
          io.debug("account exited")
          Error(Closed)
        }
        _ -> {
          case auth_res {
            Ok(AuthResp(buf, account_id)) -> Ok(buf)
            Ok(Continue) -> Error(SucessContinue)
            Error(err) -> Error(err)
          }
        }
      }

      case res {
        Ok(buf) -> {
          case glisten.send(conn, bytes_builder.from_bit_array(buf)) {
            Ok(_) ->
              case auth_res {
                Ok(AuthResp(buf, account_id)) ->
                  Ok(Context(..ctx, account_id: account_id))
                Ok(Continue) -> Error(SucessContinue)
                Error(err) -> Error(err)
              }
            Error(err) -> {
              io.debug("can't send message")
              io.debug(err)

              Error(SendError)
            }
          }
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
