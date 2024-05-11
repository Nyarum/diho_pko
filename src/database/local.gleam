import gleam/bit_array
import gleam/dynamic.{type Dynamic}
import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/json.{type Json}
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import packets/dto.{type Look}
import youid/uuid

pub const name = "storage"

pub type Msg {
  Init(subj: Subject(String), data: String)
  GetCurrentState(subj: Subject(String))
  SaveAccount(subj: Subject(Result(Account, Errors)), account: Account)
  GetAccount(subj: Subject(Result(Account, Errors)), login: String)
  SaveCharacter(
    subj: Subject(Result(Account, Errors)),
    account_id: String,
    character: Character,
  )
  UpdatePincode(account_id: String, pincode: String)
  RemoveCharacter(account_id: String, name: String)
}

pub type Character {
  Character(
    id: String,
    account_id: String,
    name: String,
    map: String,
    look: Look,
  )
}

pub fn character_to_json(character: Character) -> Json {
  json.object([
    #("id", json.string(character.id)),
    #("account_id", json.string(character.account_id)),
    #("name", json.string(character.name)),
    #("map", json.string(character.map)),
    #("look", json.string(json.to_string(dto.look_to_json(character.look)))),
  ])
}

pub fn json_to_character(from data: Dynamic) {
  data
  |> dynamic.decode5(
    Character,
    dynamic.field("id", dynamic.string),
    dynamic.field("account_id", dynamic.string),
    dynamic.field("name", dynamic.string),
    dynamic.field("map", dynamic.string),
    dynamic.field(
      "look",
      dynamic.any([
        fn(x) {
          let assert Ok(look_string) = dynamic.string(x)
          let assert Ok(look_decoded) = dto.json_to_look(look_string)
          Ok(look_decoded)
        },
      ]),
    ),
  )
}

pub type Account {
  Account(
    id: String,
    login: String,
    password: BitArray,
    mac: String,
    is_cheat: Int,
    client_version: Int,
    pincode: Option(String),
    characters: List(Character),
  )
}

pub fn account_to_json(account: Account) -> Json {
  json.object([
    #("id", json.string(account.id)),
    #("login", json.string(account.login)),
    #("password", json.string(bit_array.base64_encode(account.password, True))),
    #("mac", json.string(account.mac)),
    #("is_cheat", json.int(account.is_cheat)),
    #("client_version", json.int(account.client_version)),
    #("pincode", json.nullable(account.pincode, of: json.string)),
    #("characters", json.array(account.characters, of: character_to_json)),
  ])
}

pub fn json_to_account(from data: Dynamic) {
  data
  |> dynamic.decode8(
    Account,
    dynamic.field("id", dynamic.string),
    dynamic.field("login", dynamic.string),
    dynamic.field(
      "password",
      dynamic.any([
        fn(x) {
          let assert Ok(password_encoded) = dynamic.string(x)
          let assert Ok(password_decoded) =
            bit_array.base64_decode(password_encoded)
          Ok(password_decoded)
        },
      ]),
    ),
    dynamic.field("mac", dynamic.string),
    dynamic.field("is_cheat", dynamic.int),
    dynamic.field("client_version", dynamic.int),
    dynamic.field("pincode", dynamic.optional(dynamic.string)),
    dynamic.field("characters", dynamic.list(of: json_to_character)),
  )
}

pub type State {
  State(accounts: List(Account))
}

pub fn state_to_json(state: State) -> Json {
  json.object([#("accounts", json.array(state.accounts, of: account_to_json))])
}

pub fn json_to_state(data: String) {
  json.decode(
    data,
    dynamic.decode1(
      State,
      dynamic.field("accounts", dynamic.list(of: json_to_account)),
    ),
  )
}

pub type Errors {
  AccountNotFound
}

pub fn storage() {
  let assert Ok(subject) =
    actor.start(State(accounts: []), fn(msg, state: State) {
      case msg {
        Init(subj, data) -> {
          let new_state = case data {
            "" -> {
              State(accounts: [])
            }
            _ -> {
              let assert Ok(state) = json_to_state(data)
              state
            }
          }

          actor.send(subj, "")
          actor.continue(new_state)
        }
        GetCurrentState(subj) -> {
          actor.send(subj, json.to_string(state_to_json(state)))
          actor.continue(state)
        }
        SaveAccount(subj, account) -> {
          let account_with_id = case account {
            Account("", ..) -> {
              Account(..account, id: uuid.v4_string())
            }
            _ -> account
          }

          let new_state =
            State(
              accounts: state.accounts
              |> list.append([account_with_id]),
            )

          actor.send(subj, Ok(account_with_id))
          actor.continue(new_state)
        }
        GetAccount(subj, login) -> {
          case list.filter(state.accounts, fn(x) { x.login == login }) {
            [account] -> {
              io.debug("got it")
              actor.send(subj, Ok(account))
              actor.continue(state)
            }
            _ -> {
              actor.send(subj, Error(AccountNotFound))
              actor.continue(state)
            }
          }
        }
        SaveCharacter(subj, account_id, character) -> {
          let accounts =
            list.map(state.accounts, fn(x) {
              case x {
                account if account.id == account_id -> {
                  let new_account =
                    Account(
                      ..account,
                      characters: account.characters
                        |> list.append([character]),
                    )
                  actor.send(subj, Ok(new_account))
                  new_account
                }
                _ -> {
                  x
                }
              }
            })

          actor.continue(State(accounts: accounts))
        }
        UpdatePincode(account_id, pincode) -> {
          io.debug("update pincode")
          io.debug(account_id)
          io.debug(pincode)

          let accounts =
            list.map(state.accounts, fn(x) {
              case x {
                account if account.id == account_id -> {
                  let new_account =
                    Account(..account, pincode: option.Some(pincode))
                  new_account
                }
                _ -> {
                  x
                }
              }
            })

          actor.continue(State(accounts: accounts))
        }
        RemoveCharacter(account_id, name) -> {
          let accounts =
            list.map(state.accounts, fn(x) {
              case x {
                account if account.id == account_id -> {
                  Account(
                    ..account,
                    characters: list.drop_while(account.characters, fn(char) {
                      char.name == name
                    }),
                  )
                }
                _ -> {
                  x
                }
              }
            })

          actor.continue(State(accounts: accounts))
        }
      }
    })
  subject
}

pub fn init(subj: Subject(Msg), data: String) {
  actor.call(subj, Init(_, data), 1000)
}

pub fn get_current_state(subj: Subject(Msg)) {
  actor.call(subj, GetCurrentState(_), 1000)
}

pub fn get_account(subj: Subject(Msg), id: String) {
  actor.call(subj, GetAccount(_, id), 1000)
}

pub fn save_account(subj: Subject(Msg), account: Account) {
  actor.call(subj, SaveAccount(_, account), 1000)
}

pub fn save_character(
  subj: Subject(Msg),
  account_id: String,
  character: Character,
) {
  process.try_call(subj, SaveCharacter(_, account_id, character), 1000)
}

pub fn update_pincode(subj: Subject(Msg), account_id: String, pincode: String) {
  process.send(subj, UpdatePincode(account_id, pincode))
}

pub fn remove_character(subj: Subject(Msg), account_id: String, name: String) {
  process.send(subj, RemoveCharacter(account_id, name))
}
