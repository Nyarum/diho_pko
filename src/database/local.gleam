import gleam/erlang/process.{type Subject}
import gleam/io
import gleam/list
import gleam/otp/actor

pub const name = "storage"

pub type Msg {
  SaveAccount(id: Int)
  GetAccount(subj: Subject(Result(Account, Errors)), id: Int)
}

pub type Account {
  Account(id: Int)
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
        SaveAccount(id) -> {
          let new_state =
            State(
              ..state,
              accounts: state.accounts
                |> list.append([Account(id)]),
            )

          actor.continue(new_state)
        }
        GetAccount(subj, id) -> {
          case state.accounts {
            [Account(id)] -> {
              actor.send(subj, Ok(Account(id)))
              actor.continue(state)
            }
            _ -> {
              io.debug("account not found")
              io.debug(id)
              actor.continue(state)
            }
          }
        }
      }
    })
  subject
}
