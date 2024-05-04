pub type Auth {
  Auth(
    key: BitArray,
    login: String,
    password: BitArray,
    mac: String,
    is_cheat: Int,
    client_version: Int,
  )
}

pub type ItemAttr {
  // 2 + 1
  ItemAttr(id: Int, is_valid: Bool)
}

pub type InstAttr {
  // 2 + 2
  InstAttr(id: Int, value: Int)
}

pub type ItemGrid {
  ItemGrid(
    id: Int,
    // 16
    num: Int,
    // 16
    endure: List(Int),
    // [2] 16
    energy: List(Int),
    // [2] 16
    forge_lv: Int,
    // 8
    db_params: List(Int),
    // [2] 32
    inst_attrs: List(InstAttr),
    // [5]
    item_attrs: List(ItemAttr),
    // [40]
    is_change: Bool,
  )
  // 16
}

pub type Look {
  Look(
    ver: Int,
    type_id: Int,
    // 10
    item_grids: List(ItemGrid),
    hair: Int,
  )
}

pub type CreateCharacter {
  CreateCharacter(name: String, map: String, look_size: Int, look: Look)
}
