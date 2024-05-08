import bytes/pack.{pack}
import bytes/packet.{type Unpack, Unpack}
import core/context.{type Context, Context}
import database/account
import database/character
import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/dynamic
import gleam/io
import gleam/list
import gleam/pgo.{Returned}
import gleam/result.{unwrap}
import packets/character_screen.{type Character, Character}
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
  Continue
}

type Errors {
  CantGetAccountID
}

pub fn handle(ctx: Context, auth: Auth) -> AuthResp {
  let assert Context(db, _, _, _) = ctx

  let assert Ok(account_return) = account.get_account(db, auth.login)
  let assert Returned(count, account) = account_return

  let assert Ok(account_id) = case count {
    0 -> {
      case account.create_account(db, auth) {
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
    }
    _ -> {
      let #(id, _, _, _, _, _) =
        result.unwrap(list.first(account), #(0, "", "", "", 0, 0))
      Ok(id)
    }
  }

  let assert Ok(get_characters) = character.get_characters(db, account_id)

  let characters = case get_characters {
    Returned(_, characters) -> characters
  }

  let characters_format =
    list.map(characters, fn(character) {
      let #(id, account_id, name, map, look, hair) = character
      let assert Ok(look) = dto.json_to_look(look)
      Character(True, name, "Job", map, 1, 0, look)
    })

  io.debug(characters_format)

  character_screen.CharacterScreen(
    931,
    0,
    <<0x7C, 0x35, 0x09, 0x19, 0xB2, 0x50, 0xD3, 0x49>>,
    list.length(characters_format),
    characters_format,
    1,
    0,
    12_820,
  )
  |> character_screen.character_screen
  |> pack.pack()
  |> io.debug
  |> AuthResp(account_id)
}
