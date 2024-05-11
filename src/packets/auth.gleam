import bytes/pack.{pack}
import bytes/packet.{type Pack, type Unpack, Pack, Unpack}
import core/context.{type Context, Context}
import database/account.{Account}
import database/character
import database/local
import gleam/bit_array
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/io
import gleam/json
import gleam/list
import gleam/option
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
  AuthResp(buf: BitArray, account_id: String)
}

pub fn get_account_id(
  returned: Returned(#(id, account_id, name, map, look, hair)),
) {
  let assert Ok(first) = list.first(returned.rows)
  let #(id, _, _, _, _, _) = first
  id
}

pub type Account {
  Account(
    id: Int,
    login: String,
    password: String,
    mac: String,
    is_cheat: Int,
    client_version: Int,
    pincode: String,
  )
}

fn parse_tuple(x) {
  io.debug("x")
  io.debug(dynamic.int(x))
  io.debug(x)
  Ok("test")
}

fn parse_account(x: Dynamic) {
  let bro = dynamic.decode1(fn(b) { x }, parse_tuple)
  let assert Ok(id) = bro(x)
  io.debug(id)
}

pub fn handle(ctx: Context, auth: Auth) -> AuthResp {
  let assert Context(storage, _, _, _) = ctx

  let account = case local.get_account(storage, auth.login) {
    Ok(account) -> {
      account
    }
    _ -> {
      let assert Ok(account) =
        local.save_account(
          storage,
          local.Account(
            "",
            auth.login,
            auth.password,
            auth.mac,
            auth.is_cheat,
            auth.client_version,
            option.None,
            [],
          ),
        )

      account
    }
  }

  let characters_format = {
    use character <- list.map(account.characters)
    Character(True, character.name, "Job", character.map, 1, 0, character.look)
  }

  io.debug(characters_format)

  let is_pincode = case account.pincode {
    option.Some(_) -> 1
    _ -> 0
  }

  character_screen.CharacterScreen(
    931,
    0,
    <<0x7C, 0x35, 0x09, 0x19, 0xB2, 0x50, 0xD3, 0x49>>,
    list.length(characters_format),
    characters_format,
    is_pincode,
    0,
    12_820,
  )
  |> character_screen.character_screen
  |> pack.pack()
  |> io.debug
  |> AuthResp(account.id)
}

pub type Pincode {
  Pincode(hash: String)
}

pub fn pincode(unpack: Unpack(Pincode, BitArray)) -> Result(BitArray, Error) {
  let assert Unpack(data, handler) = unpack

  case data {
    <<hash_len:16, hash:bytes-size(hash_len)>> -> {
      bit_array.base64_encode(hash, True)

      Pincode(bit_array.base64_encode(hash, True))
      |> handler
      |> Ok
    }
    _ -> {
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

pub type ChangePincode {
  ChangePincode(old_hash: String, hash: String)
}

pub fn change_pincode(
  unpack: Unpack(ChangePincode, BitArray),
) -> Result(BitArray, Error) {
  let assert Unpack(data, handler) = unpack

  case data {
    <<
      old_hash_len:16,
      old_hash:bytes-size(old_hash_len),
      hash_len:16,
      hash:bytes-size(hash_len),
    >> -> {
      ChangePincode(
        bit_array.base64_encode(old_hash, True),
        bit_array.base64_encode(hash, True),
      )
      |> handler
      |> Ok
    }
    _ -> {
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

pub fn pincode_handle(ctx: Context, pincode: Pincode) -> BitArray {
  let assert Context(storage, _, _, account_id) = ctx
  local.update_pincode(storage, account_id, pincode.hash)

  pincode_confirm(941)
  |> pack.pack()
}

pub fn change_pincode_handle(ctx: Context, pincode: ChangePincode) -> BitArray {
  let assert Context(storage, _, _, account_id) = ctx
  local.update_pincode(storage, account_id, pincode.hash)

  pincode_confirm(942)
  |> pack.pack()
}

pub fn pincode_confirm(opcode: Int) -> Pack {
  let prefinal_bytes =
    <<opcode:size(16)>>
    |> bit_array.append(<<0x00, 0x00>>)

  Pack(prefinal_bytes)
}

pub type RemoveCharacter {
  RemoveCharacter(name: String, hash: String)
}

pub fn remove_character(
  unpack: Unpack(RemoveCharacter, BitArray),
) -> Result(BitArray, Error) {
  let assert Unpack(data, handler) = unpack

  case data {
    <<
      name_len:16,
      name:bytes-size(name_len),
      hash_len:16,
      hash:bytes-size(hash_len),
    >> -> {
      let assert Ok(name_cut) = {
        use name_cut <- try(bit_array.slice(name, 0, name_len - 1))
        use name_cut <- try(bit_array.to_string(name_cut))
        Ok(name_cut)
      }

      RemoveCharacter(name_cut, bit_array.base64_encode(hash, True))
      |> handler
      |> Ok
    }
    _ -> {
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

pub fn remove_character_handle(
  ctx: Context,
  remove_character: RemoveCharacter,
) -> BitArray {
  let assert Context(storage, _, _, account_id) = ctx
  local.remove_character(storage, account_id, remove_character.name)

  remove_character_confirm()
  |> pack.pack()
}

pub fn remove_character_confirm() -> Pack {
  let prefinal_bytes =
    <<936:size(16)>>
    |> bit_array.append(<<0x00, 0x00>>)

  Pack(prefinal_bytes)
}
