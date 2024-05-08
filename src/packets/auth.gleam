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
import gleam/pgo.{type Returned, Returned}
import gleam/result.{try, unwrap}
import packets/character_screen.{type Character, Character}
import packets/dto.{type Auth, Auth}

pub type Error {
  PatternMatchWrong
  CantGetAccountID
}

pub fn auth(unpack: Unpack(Auth, AuthResp)) -> Result(AuthResp, Error) {
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
    >> -> {
      let assert Ok(login_cut) = {
        use login_cut <- try(bit_array.slice(login, 0, login_len - 1))
        use login_cut <- try(bit_array.to_string(login_cut))
        Ok(login_cut)
      }

      let assert Ok(mac_cut) = {
        use mac_cut <- try(bit_array.slice(mac, 0, mac_len - 1))
        use mac_cut <- try(bit_array.to_string(mac_cut))
        Ok(mac_cut)
      }

      Auth(key, login_cut, password, mac_cut, is_cheat, client_version)
      |> handler
      |> Ok
    }
    _ -> {
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

pub type AuthResp {
  AuthResp(buf: BitArray, account_id: Int)
}

pub fn get_account_id(
  returned: Returned(#(id, account_id, name, map, look, hair)),
) {
  let assert Ok(first) = list.first(returned.rows)
  let #(id, _, _, _, _, _) = first
  id
}

pub fn handle(ctx: Context, auth: Auth) -> AuthResp {
  let assert Context(db, _, _, _) = ctx

  let assert Ok(account_return) = account.get_account(db, auth.login)
  let assert Returned(count, account) = account_return

  let account_id = case count {
    0 -> {
      let assert Ok(create_account) = account.create_account(db, auth)
      let assert Returned(_, create_account_rows) = create_account
      let assert Ok(create_account_one) = list.first(create_account_rows)

      create_account_one
    }
    _ -> {
      let assert Ok(#(id, _, _, _, _, _)) = list.first(account)
      id
    }
  }

  let assert Ok(get_characters) = character.get_characters(db, account_id)

  let characters = case get_characters {
    Returned(_, characters) -> characters
  }

  let characters_format = {
    use character <- list.map(characters)
    let #(id, account_id, name, map, look, hair) = character
    let assert Ok(look) = dto.json_to_look(look)
    Character(True, name, "Job", map, 1, 0, look)
  }

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
