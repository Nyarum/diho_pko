import bytes/packet.{type Pack, Pack}
import gleam/bit_array

pub fn pack(pack: Pack) -> BitArray {
  let assert Pack(bytes) = pack

  let prefinal_bytes =
    <<80:little-size(32)>>
    |> bit_array.append(bytes)

  <<bit_array.byte_size(bytes):size(16)>>
  |> bit_array.append(prefinal_bytes)
}
