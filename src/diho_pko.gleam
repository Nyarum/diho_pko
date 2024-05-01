import gleam/io
import gleam/list

pub fn main() {
  io.println("Hello from diho_pko!")
  [1, 2]
  |> list.map(fn(v) { v + 1 })
  |> list.map(fn(v) {
    io.debug(v)
    v
  })
  |> list.append([5, 5, 7])
  |> list.unique
  |> io.debug
}
