import bytes/packet.{type Unpack, Unpack}
import gleam/bit_array
import gleam/io
import gleam/result.{unwrap}

pub type Auth {
  Auth(
    key: BitArray,
    login: String,
    password: BitArray,
    mac: String,
    is_cheat: Int,
    client_version: Int,
  )
}

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
      Auth(
        key,
        unwrap(bit_array.to_string(login), ""),
        password,
        unwrap(bit_array.to_string(mac), ""),
        is_cheat,
        client_version,
      )
      |> handler
    _ -> {
      io.debug("pattern match is wrong")
      io.debug(data)
      Nil
    }
  }
}
