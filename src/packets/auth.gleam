import bytes/pack.{pack}
import bytes/packet.{type Unpack, Unpack}
import core/context.{type Context, Context}
import databaase/account
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/io
import gleam/list
import gleam/pgo.{Returned}
import gleam/result.{unwrap}
import packets/character_screen
import packets/dto.{type Auth, Auth}

pub fn auth(unpack: Unpack(Auth, AuthResp)) {
  let assert Unpack(data, handler) = unpack

  case data {
    <<
      key_len:16,
      key:bytes-size(key_len),
      login_len:16,
      login:bytes-size(login_len),
      password_len:16,
      password:bytes-size(password_len),
      mac_len:16,
      mac:bytes-size(mac_len),
      is_cheat:16,
      client_version:16,
    >> ->
      {
        let assert Ok(login_cut) = bit_array.slice(login, 0, login_len - 1)
        let assert Ok(mac_cut) = bit_array.slice(mac, 0, mac_len - 1)

        Auth(
          key,
          unwrap(bit_array.to_string(login_cut), ""),
          password,
          unwrap(bit_array.to_string(mac_cut), ""),
          is_cheat,
          client_version,
        )
      }
      |> handler
    _ -> {
      io.debug("pattern match is wrong")
      io.debug(data)
      AuthResp(<<>>, 0)
    }
  }
}

pub type AuthResp {
  AuthResp(buf: BitArray, account_id: Int)
}

type Errors {
  CantGetAccountID
}

pub fn handle(ctx: Context, auth: Auth) -> AuthResp {
  let assert Context(db, _, _, _) = ctx

  let assert Ok(account_id) = case account.create_account(db, auth) {
    Ok(account) -> {
      io.debug("account")
      io.debug(account)

      case account {
        Returned(_, accounts) ->
          case list.first(accounts) {
            Ok(one_account) -> {
              io.debug(one_account)
              Ok(one_account)
            }
            Error(err) -> {
              io.debug(err)
              Error(CantGetAccountID)
            }
          }
      }
    }
    Error(err) -> {
      io.debug(err)
      Error(CantGetAccountID)
    }
  }

  io.debug("got a new auth")
  io.debug(auth)

  character_screen.character_screen()
  |> pack.pack()
  |> AuthResp(account_id)
}
