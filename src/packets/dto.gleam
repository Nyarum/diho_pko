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
