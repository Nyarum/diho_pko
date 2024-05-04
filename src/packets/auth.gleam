import bytes/pack.{pack}
import bytes/packet.{type Unpack, Unpack}
import core/context.{type Context, Context}
import databaase/account
import gleam/bit_array
import gleam/io
import gleam/result.{unwrap}
import packets/character_screen
import packets/dto.{type Auth, Auth}

pub fn auth(unpack: Unpack(Auth)) {
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
      <<>>
    }
  }
}

pub fn handle(ctx: Context, auth: Auth) -> BitArray {
  let assert Context(db) = ctx

  let assert Ok(_) = io.debug(account.create_account(db, auth))

  io.debug("got a new auth")
  io.debug(auth)

  character_screen.character_screen()
  |> pack.pack()
}
