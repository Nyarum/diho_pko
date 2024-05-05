import gleam/dict
import gleam/dynamic.{type DecodeErrors, type Dynamic}
import gleam/io
import gleam/json.{
  type Json, array, bool, decode, int, object, string, to_string,
}
import gleam/result.{unwrap}
import jasper.{Number, Object, String}

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
  ItemAttr(id: Int, is_valid: Bool)
}

pub fn item_attr_to_json(item_attr: ItemAttr) -> Json {
  object([#("id", int(item_attr.id)), #("is_valid", bool(item_attr.is_valid))])
}

pub fn json_to_item_attr(from data: Dynamic) {
  data
  |> dynamic.decode2(
    ItemAttr,
    dynamic.field("id", dynamic.int),
    dynamic.field("is_valid", dynamic.bool),
  )
}

pub type InstAttr {
  InstAttr(id: Int, value: Int)
}

pub fn inst_attr_to_json(inst_attr: InstAttr) -> Json {
  object([#("id", int(inst_attr.id)), #("value", int(inst_attr.value))])
}

pub fn json_to_inst_attr(from data: Dynamic) {
  data
  |> dynamic.decode2(
    InstAttr,
    dynamic.field("id", dynamic.int),
    dynamic.field("value", dynamic.int),
  )
}

pub type ItemGrid {
  ItemGrid(
    id: Int,
    num: Int,
    endure: List(Int),
    energy: List(Int),
    forge_lv: Int,
    db_params: List(Int),
    inst_attrs: List(InstAttr),
    item_attrs: List(ItemAttr),
    is_change: Bool,
  )
}

pub fn item_grid_to_json(item_grid: ItemGrid) -> Json {
  object([
    #("id", int(item_grid.id)),
    #("num", int(item_grid.num)),
    #("endure", array(item_grid.endure, of: int)),
    #("energy", array(item_grid.energy, of: int)),
    #("forge_lv", int(item_grid.forge_lv)),
    #("db_params", array(item_grid.db_params, of: int)),
    #("inst_attrs", array(item_grid.inst_attrs, of: inst_attr_to_json)),
    #("item_attrs", array(item_grid.item_attrs, of: item_attr_to_json)),
    #("is_change", bool(item_grid.is_change)),
  ])
}

pub fn json_to_item_grid(from data: Dynamic) {
  data
  |> dynamic.decode9(
    ItemGrid,
    dynamic.field("id", dynamic.int),
    dynamic.field("num", dynamic.int),
    dynamic.field("endure", dynamic.list(of: dynamic.int)),
    dynamic.field("energy", dynamic.list(of: dynamic.int)),
    dynamic.field("forge_lv", dynamic.int),
    dynamic.field("db_params", dynamic.list(of: dynamic.int)),
    dynamic.field("inst_attrs", dynamic.list(of: json_to_inst_attr)),
    dynamic.field("item_attrs", dynamic.list(of: json_to_item_attr)),
    dynamic.field("is_change", dynamic.bool),
  )
}

pub type Look {
  Look(ver: Int, type_id: Int, item_grids: List(ItemGrid), hair: Int)
}

pub fn look_to_json(look: Look) -> Json {
  object([
    #("ver", int(look.ver)),
    #("type_id", int(look.type_id)),
    #("item_grids", array(look.item_grids, of: item_grid_to_json)),
    #("hair", int(look.hair)),
  ])
}

pub fn json_to_look(data: String) {
  decode(
    data,
    dynamic.decode4(
      Look,
      dynamic.field("ver", dynamic.int),
      dynamic.field("type_id", dynamic.int),
      dynamic.field("item_grids", dynamic.list(of: json_to_item_grid)),
      dynamic.field("hair", dynamic.int),
    ),
  )
}

pub type CreateCharacter {
  CreateCharacter(name: String, map: String, look_size: Int, look: Look)
}
