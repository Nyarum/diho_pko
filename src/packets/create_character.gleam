import bytes/pack.{pack}
import bytes/packet.{type Pack, type Unpack, Pack, Unpack}
import core/context.{type Context, Context}
import database/account
import database/character
import database/local
import gleam/bit_array
import gleam/bool
import gleam/int
import gleam/io
import gleam/list
import gleam/result.{unwrap}
import packets/character_screen
import packets/dto.{
  type CreateCharacter, type InstAttr, type ItemAttr, type ItemGrid, type Look,
  CreateCharacter, InstAttr, ItemAttr, ItemGrid, Look,
}

type Errors {
  PatternMatchWrong
}

fn item_attr(unpack: Unpack(ItemAttr, BitArray)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<id:little-16, is_valid:8>> -> {
      let is_valid_bool = case is_valid {
        0 -> False
        _ -> True
      }

      ItemAttr(id, is_valid_bool)
      |> Ok
    }
    _ -> {
      io.debug("item_attr: pattern match is wrong")
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

fn inst_attr(unpack: Unpack(InstAttr, BitArray)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<id:little-16, value:little-16>> -> {
      InstAttr(id, value)
      |> Ok
    }
    _ -> {
      io.debug("inst_attr: pattern match is wrong")
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

fn item_grid(unpack: Unpack(ItemGrid, BitArray)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<
      id:little-16,
      num:little-16,
      endure_list_0:little-16,
      endure_list_1:little-16,
      energy_list_0:little-16,
      energy_list_1:little-16,
      forge_lv:little-8,
      db_params_0:little-32,
      db_params_1:little-32,
      inst_attrs_list:bits-size(160),
      item_attrs_list:bits-size(960),
      is_change:8,
    >> -> {
      let inst_attrs =
        list.range(0, 4)
        |> list.map(fn(i) {
          let inst_attrs_cut =
            unwrap(bit_array.slice(inst_attrs_list, i * 4, 4), <<>>)

          unwrap(
            inst_attr(Unpack(inst_attrs_cut, fn(_) { <<>> })),
            InstAttr(0, 0),
          )
        })

      let item_attrs =
        list.range(0, 39)
        |> list.map(fn(i) {
          let item_attrs_cut =
            unwrap(bit_array.slice(item_attrs_list, i * 3, 3), <<>>)

          unwrap(
            item_attr(Unpack(item_attrs_cut, fn(_) { <<>> })),
            ItemAttr(0, True),
          )
        })

      let is_change_bool = case is_change {
        0 -> False
        _ -> True
      }

      ItemGrid(
        id,
        num,
        [endure_list_0, endure_list_1],
        [energy_list_0, energy_list_1],
        forge_lv,
        [db_params_0, db_params_1],
        inst_attrs,
        item_attrs,
        is_change_bool,
      )
      |> Ok
    }
    _ -> {
      io.debug("item_grids: pattern match is wrong")
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

fn look(unpack: Unpack(Look, BitArray)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<ver:little-16, type_id:little-16, next:bytes-size(1620), hair:little-16>> -> {
      let item_grids =
        list.range(0, 9)
        |> list.map(fn(i) {
          let item_grids_cut = unwrap(bit_array.slice(next, i * 162, 162), <<>>)

          unwrap(
            item_grid(Unpack(item_grids_cut, fn(_) { <<>> })),
            ItemGrid(0, 0, [0, 0], [0, 0], 0, [0, 0], [], [], False),
          )
        })

      Look(ver, type_id, item_grids, hair)
      |> Ok
    }
    _ -> {
      io.debug("look: pattern match is wrong")
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

pub fn create_character(unpack: Unpack(CreateCharacter, BitArray)) {
  let assert Unpack(data, handler) = unpack

  case data {
    <<
      name_len:16,
      name:bytes-size(name_len),
      map_len:16,
      map:bytes-size(map_len),
      look_len:16,
      next:bytes-size(look_len),
    >> ->
      {
        let look = case look(Unpack(next, fn(_) { <<>> })) {
          Ok(look) -> look
          _ -> Look(0, 0, [], 0)
        }

        let assert Ok(name_cut) = bit_array.slice(name, 0, name_len - 1)
        let assert Ok(map_cut) = bit_array.slice(map, 0, map_len - 1)

        let name_string = unwrap(bit_array.to_string(name_cut), "unknown")
        let map_string = unwrap(bit_array.to_string(map_cut), "unknown")

        CreateCharacter(name_string, map_string, look_len, look)
      }
      |> handler
    _ -> {
      io.debug("create character: pattern match is wrong")
      io.debug(data)
      <<>>
    }
  }
}

pub fn create_character_reply() -> Pack {
  let prefinal_bytes = <<935:16, 0:16>>

  Pack(prefinal_bytes)
}

pub fn handle(ctx: Context, cc: CreateCharacter) -> BitArray {
  let assert Context(storage, _, _, account_id) = ctx

  io.debug("handle create character")
  io.debug(account_id)

  let assert Ok(_) =
    local.save_character(
      storage,
      account_id,
      local.Character("", account_id, cc.name, cc.map, cc.look),
    )

  create_character_reply()
  |> pack
}
