import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import packets/dto.{type Look}
import youid/uuid

pub const name = "storage"

pub type Msg {
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

pub type State {
  State(accounts: List(Account))
}

pub type Errors {
  AccountNotFound
}

pub fn storage() {
  let assert Ok(subject) =
    actor.start(State(accounts: []), fn(msg, state: State) {
      case msg {
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
