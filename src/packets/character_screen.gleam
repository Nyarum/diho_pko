import bytes/packet.{type Pack, Pack}

pub fn character_screen() -> Pack {
  let prefinal_bytes = <<
    931:16, 0:16, 8:16, 0x7C, 0x35, 0x09, 0x19, 0xB2, 0x50, 0xD3, 0x49, 0:8, 1:8,
    0:32, 12_820:32,
  >>

  Pack(prefinal_bytes)
}
