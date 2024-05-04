import bytes/packet.{type Pack, Pack}
import gleam/bit_array

pub fn pack(pack: Pack) -> BitArray {
  let assert Pack(bytes) = pack

  let prefinal_bytes =
    <<128:little-size(32)>>
    |> bit_array.append(bytes)

  let len = bit_array.byte_size(prefinal_bytes) + 2

  <<len:size(16)>>
  |> bit_array.append(prefinal_bytes)
}
