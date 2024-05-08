import bytes/packet.{type Pack, Pack}
import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import packets/dto.{type InstAttr, type ItemAttr, type ItemGrid, type Look}

pub type Character {
  Character(
    is_active: Bool,
    name: String,
    job: String,
    map: String,
    level: Int,
    look_size: Int,
    look: Look,
  )
}

pub type CharacterScreen {
  CharacterScreen(
    opcode: Int,
    error: Int,
    key: BitArray,
    char_len: Int,
    characters: List(Character),
    pincode: Int,
    encryption: Int,
    dw_flag: Int,
  )
}

pub fn item_grid(item_grid: ItemGrid) -> BitArray {
  let endure_bytes =
    list.fold(item_grid.endure, <<>>, fn(acc, one_endure) {
      acc
      |> bit_array.append(<<one_endure:little-16>>)
    })
  let energy_bytes =
    list.fold(item_grid.energy, <<>>, fn(acc, one_energy) {
      acc
      |> bit_array.append(<<one_energy:little-16>>)
    })
  let db_params_bytes =
    list.fold(item_grid.db_params, <<>>, fn(acc, one_db_param) {
      acc
      |> bit_array.append(<<one_db_param:little-32>>)
    })
  let inst_attr_bytes =
    list.fold(item_grid.inst_attrs, <<>>, fn(acc, one_inst_attr) {
      acc
      |> bit_array.append(<<
        one_inst_attr.id:little-16,
        one_inst_attr.value:little-16,
      >>)
    })
  let item_attr_bytes =
    list.fold(item_grid.item_attrs, <<>>, fn(acc, one_item_attr) {
      acc
      |> bit_array.append(<<
        one_item_attr.id:little-16,
        bool.to_int(one_item_attr.is_valid):8,
      >>)
    })

  <<
    item_grid.id:little-16,
    item_grid.num:little-16,
    endure_bytes:bits,
    energy_bytes:bits,
    item_grid.forge_lv:8,
    db_params_bytes:bits,
    inst_attr_bytes:bits,
    item_attr_bytes:bits,
    bool.to_int(item_grid.is_change):8,
  >>
}

pub fn look(look: Look) -> BitArray {
  let item_grids_bytes =
    list.fold(look.item_grids, <<>>, fn(acc, one_grid) {
      acc
      |> bit_array.append(item_grid(one_grid))
    })

  io.debug("item grids:")
  io.debug(bit_array.byte_size(item_grids_bytes))

  <<
    look.ver:little-16,
    look.type_id:little-16,
    item_grids_bytes:bits,
    look.hair:little-16,
  >>
}

pub fn character(character: Character) -> BitArray {
  let look_bytes = look(character.look)

  io.debug("look len")
  io.debug(bit_array.byte_size(look_bytes))

  let name =
    bit_array.from_string(character.name)
    |> bit_array.append(<<0x00>>)
  let job =
    bit_array.from_string(character.job)
    |> bit_array.append(<<0x00>>)

  <<
    1:8,
    bit_array.byte_size(name):16,
    name:bits,
    bit_array.byte_size(job):16,
    job:bits,
    character.level:16,
    bit_array.byte_size(look_bytes):16,
    look_bytes:bits,
  >>
}

pub fn character_screen(character_screen: CharacterScreen) -> Pack {
  let characters_bytes =
    list.fold(character_screen.characters, <<>>, fn(acc, one_character) {
      acc
      |> bit_array.append(character(one_character))
    })

  let bytes = <<
    character_screen.opcode:16,
    character_screen.error:16,
    bit_array.byte_size(character_screen.key):16,
    character_screen.key:bits,
    character_screen.char_len:8,
    characters_bytes:bits,
    character_screen.pincode:8,
    character_screen.encryption:32,
    character_screen.dw_flag:32,
  >>

  Pack(bytes)
}
