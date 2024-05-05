import core/context.{type Context}

pub type Pack {
  Pack(BitArray)
}

pub type Unpack(object, return) {
  Unpack(data: BitArray, handler: fn(object) -> return)
}
