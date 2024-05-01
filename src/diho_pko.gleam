import birl.{
  type Month, Apr, Aug, Dec, Feb, Jan, Jul, Jun, Mar, May, Nov, Oct, Sep,
}

import bytes/pack
import gleam/bit_array
import gleam/bytes_builder
import gleam/erlang/process.{type Selector}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/order
import gleam/otp/actor
import gleam/result
import gleam/string
import glisten.{Packet}

fn first_date_packet() -> BitArray {
  let now = birl.now()
  let day = birl.get_day(now)
  let time = birl.get_time_of_day(now)

  let month = case int.compare(day.month, 10) {
    order.Lt -> "0" <> int.to_string(day.month)
    _ -> int.to_string(day.month)
  }

  let day = case int.compare(day.date, 10) {
    order.Lt -> "0" <> int.to_string(day.date)
    _ -> int.to_string(day.date)
  }

  let hour = case int.compare(time.hour, 10) {
    order.Lt -> "0" <> int.to_string(time.hour)
    _ -> int.to_string(time.hour)
  }

  let minute = case int.compare(time.minute, 10) {
    order.Lt -> "0" <> int.to_string(time.minute)
    _ -> int.to_string(time.minute)
  }

  let seconds = case int.compare(time.second, 10) {
    order.Lt -> "0" <> int.to_string(time.second)
    _ -> int.to_string(time.second)
  }

  let milliseconds = case int.compare(time.milli_second, 1000) {
    order.Lt -> int.to_string(time.milli_second)
    _ -> "000"
  }

  let final_string =
    "["
    <> month
    <> "-"
    <> day
    <> " "
    <> hour
    <> "-"
    <> minute
    <> "-"
    <> seconds
    <> "-"
    <> milliseconds
    <> "]"

  let date_bytes =
    final_string
    |> bit_array.from_string

  let prefinal_bytes =
    <<80:little-size(32)>>
    |> bit_array.append(<<940:size(16)>>)
    |> bit_array.append(date_bytes)

  let final_bytes =
    <<bit_array.byte_size(prefinal_bytes):size(16)>>
    |> bit_array.append(prefinal_bytes)

  final_bytes
}

pub fn main() {
  io.debug(bytes_builder.from_bit_array(first_date_packet()))

  let assert Ok(_) =
    glisten.handler(
      fn(conn) {
        io.debug(
          "new connection with client ip:" <> string.inspect(conn.client_ip),
        )
        let assert Ok(_) =
          glisten.send(conn, bytes_builder.from_bit_array(first_date_packet()))
        #(Nil, None)
      },
      fn(msg, state, conn) {
        let assert Packet(msg) = msg
        let assert Ok(_) = glisten.send(conn, bytes_builder.from_bit_array(msg))
        actor.continue(state)
      },
    )
    |> glisten.serve(1973)

  process.sleep_forever()
}
