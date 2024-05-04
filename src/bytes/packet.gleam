pub type Pack {
  Pack(BitArray)
}

pub type Unpack(object) {
  Unpack(data: BitArray, handler: fn(object) -> Nil)
}
