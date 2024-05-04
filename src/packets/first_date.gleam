import birl
import bytes/packet.{type Pack, Pack}
import gleam/bit_array
import gleam/int
import gleam/order

pub fn first_date() -> Pack {
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
    <<940:size(16)>>
    |> bit_array.append(date_bytes)

  Pack(prefinal_bytes)
}
