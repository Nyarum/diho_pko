import gleam/erlang/process.{type Subject}
import gleam/otp/actor.{type StartError, Ready, Spec}

pub fn periodic_save_to_database(
  every period_milliseconds: Int,
  run callback: fn() -> Nil,
) -> Result(Subject(Nil), StartError) {
  let init = fn() {
    let subject = process.new_subject()
    let selector =
      process.new_selector()
      |> process.selecting(subject, fn(x) { x })

    process.send_after(subject, period_milliseconds, Nil)
    Ready(subject, selector)
  }

  let loop = fn(_msg, subject) {
    process.send_after(subject, period_milliseconds, Nil)

    callback()

    actor.continue(subject)
  }

  actor.start_spec(Spec(
    init: init,
    loop: loop,
    init_timeout: period_milliseconds,
  ))
}
