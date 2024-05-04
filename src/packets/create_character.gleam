import bytes/pack.{pack}
import bytes/packet.{type Unpack, Unpack}
import core/context.{type Context, Context}
import databaase/account
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

fn item_attr(unpack: Unpack(ItemAttr)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<id:16, is_valid:8>> -> {
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

fn inst_attr(unpack: Unpack(InstAttr)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<id:16, value:16>> -> {
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

fn item_grid(unpack: Unpack(ItemGrid)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<
      id:16,
      num:16,
      endure_list_0:16,
      endure_list_1:16,
      energy_list_0:16,
      energy_list_1:16,
      forge_lv:8,
      db_params_0:32,
      db_params_1:32,
      inst_attrs_list:bits-size(160),
      item_attrs_list:bits-size(960),
      is_change:8,
    >> -> {
      let inst_attrs =
        list.range(0, 5)
        |> list.map(fn(_) {
          unwrap(
            inst_attr(Unpack(inst_attrs_list, fn(_) { <<>> })),
            InstAttr(0, 0),
          )
        })

      let item_attrs =
        list.range(0, 40)
        |> list.map(fn(_) {
          unwrap(
            item_attr(Unpack(item_attrs_list, fn(_) { <<>> })),
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

fn look(unpack: Unpack(Look)) {
  let assert Unpack(data, _) = unpack

  case data {
    <<ver:16, type_id:16, next:bytes>> -> {
      io.debug("check")
      io.debug(next)
      io.debug("double check")
      io.debug(bit_array.byte_size(next))
      io.debug(next)

      let item_grids =
        list.range(0, 9)
        |> list.map(fn(_) {
          //let item_grids_cut = bit_array.slice(item_grids, 0)

          unwrap(
            item_grid(Unpack(next, fn(_) { <<>> })),
            ItemGrid(0, 0, [0, 0], [0, 0], 0, [0, 0], [], [], False),
          )
        })

      Look(ver, type_id, item_grids, 222)
      |> Ok
    }
    _ -> {
      io.debug("look: pattern match is wrong")
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

pub fn create_character(unpack: Unpack(CreateCharacter)) {
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
        io.debug("test_let")
        io.debug(next)
        io.debug(map_len)
        io.debug(name_len)

        let look = case look(Unpack(next, fn(_) { <<>> })) {
          Ok(look) -> look
          _ -> Look(0, 0, [], 0)
        }

        io.debug("look size")
        io.debug(look_len)

        let name_string = unwrap(bit_array.to_string(name), "")
        let map_string = unwrap(bit_array.to_string(map), "")

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

pub fn handle(ctx: Context, cc: CreateCharacter) -> BitArray {
  let assert Context(db) = ctx

  io.debug("handle create character")
  <<>>
}
