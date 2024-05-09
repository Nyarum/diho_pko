import bytes/pack.{pack}
import bytes/packet.{type Pack, type Unpack, Pack, Unpack}
import core/context.{type Context, Context}
import database/account.{Account}
import database/character
import gleam/bit_array
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/order
import gleam/pgo.{type Returned, Returned}
import gleam/result.{try, unwrap}
import gleam/string
import packets/character_screen.{type Character, Character}
import packets/dto.{type Auth, type InstAttr, Auth}

pub type Error {
  PatternMatchWrong
  CantGetAccountID
}

pub type Position {
  Position(x: Int, y: Int, radius: Int)
}

fn position(pos: Position) -> BitArray {
  <<pos.x:32, pos.y:32, pos.radius:32>>
}

pub type Side {
  Side(id: Int)
}

fn side(side: Side) -> BitArray {
  <<side.id:8>>
}

pub type EntityEvent {
  EntityEvent(id: Int, value: Int, event_id: Int, event_name: String)
}

fn entity_event(ee: EntityEvent) -> BitArray {
  <<
    ee.id:32,
    ee.value:8,
    ee.event_id:16,
    string.byte_size(ee.event_name):16,
    ee.event_name:utf8,
  >>
}

pub type LookItemSync {
  LookItemSync(endure: Int, energy: Int, is_valid: Int)
}

fn look_item_sync(li: LookItemSync) -> BitArray {
  <<li.endure:16, li.energy:16, li.is_valid:8>>
}

pub type LookItemShow {
  LookItemShow(
    num: Int,
    endure: List(Int),
    energy: List(Int),
    forge_lv: Int,
    is_valid: Int,
  )
}

fn look_item_show(li: LookItemShow) -> BitArray {
  let endure_bytes =
    list.fold(li.endure, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(<<one:16>>)
    })

  let energy_bytes =
    list.fold(li.energy, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(<<one:16>>)
    })

  <<
    li.num:16,
    endure_bytes:bits,
    energy_bytes:bits,
    li.forge_lv:8,
    li.is_valid:8,
  >>
}

pub type LookItem {
  LookItem(
    id: Int,
    item_sync: Option(LookItemSync),
    item_show: Option(LookItemShow),
    is_db_params: Int,
    db_params: List(Int),
    is_inst_attrs: Int,
    inst_attrs: List(InstAttr),
  )
}

const syn_look_switch = 0

const syn_look_change = 1

fn look_item(li: LookItem, syn_type: Int) -> BitArray {
  case li.id {
    0 -> <<>>
    _ ->
      case int.compare(syn_type, syn_look_change) {
        order.Eq ->
          look_item_show(option.unwrap(
            li.item_show,
            LookItemShow(0, [], [], 0, 0),
          ))
        _ -> {
          look_item_sync(option.unwrap(li.item_sync, LookItemSync(0, 0, 0)))
          |> bit_array.append(<<li.is_db_params:8>>)
          |> bit_array.append(case li.is_db_params {
            0 -> <<>>
            _ -> {
              list.fold(li.db_params, <<>>, fn(acc, one) {
                acc
                |> bit_array.append(<<one:32>>)
              })
              |> bit_array.append(<<li.is_inst_attrs:8>>)
              |> bit_array.append(case li.is_inst_attrs {
                0 -> <<>>
                _ -> {
                  list.fold(li.inst_attrs, <<>>, fn(acc, one_inst_attr) {
                    acc
                    |> bit_array.append(<<
                      one_inst_attr.id:little-16,
                      one_inst_attr.value:little-16,
                    >>)
                  })
                }
              })
            }
          })
        }
      }
  }
}

pub type LookHuman {
  LookHuman(hair_id: Int, item_grids: List(LookItem))
}

fn look_human(human: LookHuman, syn_type: Int) -> BitArray {
  let item_grids_bytes =
    list.fold(human.item_grids, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(look_item(one, syn_type))
    })

  <<human.hair_id:16, item_grids_bytes:bits>>
}

pub type LookBoat {
  LookBoat(
    pos_id: Int,
    boat_id: Int,
    header: Int,
    body: Int,
    engine: Int,
    cannon: Int,
    equipment: Int,
  )
}

fn look_boat(boat: LookBoat) -> BitArray {
  <<
    boat.pos_id:16,
    boat.boat_id:16,
    boat.header:16,
    boat.body:16,
    boat.engine:16,
    boat.cannon:16,
    boat.equipment:16,
  >>
}

pub type Look {
  Look(
    syn_type: Int,
    type_id: Int,
    is_boat: Int,
    boat: Option(LookBoat),
    human: Option(LookHuman),
  )
}

fn look(look: Look) -> BitArray {
  let boat_or_human_bytes = case look.is_boat {
    1 -> look_boat(option.unwrap(look.boat, LookBoat(0, 0, 0, 0, 0, 0, 0)))
    _ -> look_human(option.unwrap(look.human, LookHuman(0, [])), look.syn_type)
  }

  <<look.syn_type:8, look.type_id:16, look.is_boat:8, boat_or_human_bytes:bits>>
}

pub type LookAppend {
  LookAppend(look_id: Int, is_valid: Int)
}

fn look_append(look_append: LookAppend) -> BitArray {
  <<look_append.look_id:16, look_append.is_valid:8>>
}

pub type Base {
  Base(
    cha_id: Int,
    world_id: Int,
    comm_id: Int,
    comm_name: String,
    gm_lvl: Int,
    handle: Int,
    ctrl_type: Int,
    name: String,
    motto_name: String,
    icon: Int,
    guild_id: Int,
    guild_name: String,
    guild_motto: String,
    stall_name: String,
    state: Int,
    position: Position,
    angle: Int,
    team_leader_id: Int,
    side: Side,
    entity_event: EntityEvent,
    look: Look,
    pk_ctrl: Int,
    look_append: List(LookAppend),
  )
}

fn base(base: Base) -> BitArray {
  let side_bytes = side(base.side)
  let position_bytes = position(base.position)
  let entity_event_bytes = entity_event(base.entity_event)
  let look_bytes = look(base.look)

  let look_append_bytes =
    list.fold(base.look_append, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(look_append(one))
    })

  <<
    base.cha_id:32,
    base.world_id:32,
    base.comm_id:32,
    string.byte_size(base.comm_name):16,
    base.comm_name:utf8,
    base.gm_lvl:8,
    base.handle:32,
    base.ctrl_type:8,
    string.byte_size(base.name):16,
    base.name:utf8,
    string.byte_size(base.motto_name):16,
    base.motto_name:utf8,
    base.icon:16,
    base.guild_id:32,
    string.byte_size(base.guild_name):16,
    base.guild_name:utf8,
    string.byte_size(base.guild_motto):16,
    base.guild_motto:utf8,
    string.byte_size(base.stall_name):16,
    base.stall_name:utf8,
    base.state:16,
    position_bytes:bits,
    base.angle:16,
    base.team_leader_id:32,
    side_bytes:bits,
    entity_event_bytes:bits,
    look_bytes:bits,
    base.pk_ctrl:8,
    look_append_bytes:bits,
  >>
}

pub type Skill {
  Skill(
    id: Int,
    state: Int,
    level: Int,
    use_sp: Int,
    use_endure: Int,
    use_energy: Int,
    resume_time: Int,
    range_type: Int,
    params: List(Int),
  )
}

fn skill(skill: Skill) -> BitArray {
  let params_bytes =
    list.fold(skill.params, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(<<one:16>>)
    })

  <<
    skill.id:16,
    skill.state:8,
    skill.level:8,
    skill.use_sp:16,
    skill.use_endure:16,
    skill.use_energy:16,
    skill.resume_time:32,
    skill.range_type:16,
    params_bytes:bits,
  >>
}

pub type SkillBag {
  SkillBag(skill_id: Int, value_type: Int, skill_num: Int, skills: List(Skill))
}

fn skill_bag(skill_bag: SkillBag) -> BitArray {
  let skills_bytes =
    list.fold(skill_bag.skills, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(skill(one))
    })

  <<
    skill_bag.skill_id:16,
    skill_bag.value_type:8,
    skill_bag.skill_num:16,
    skills_bytes:bits,
  >>
}

pub type SkillState {
  SkillState(id: Int, level: Int)
}

fn skill_state(skill_state: SkillState) -> BitArray {
  <<skill_state.id:8, skill_state.level:8>>
}

pub type SkillStates {
  SkillStates(len: Int, states: List(SkillState))
}

fn skill_states(skill_states: SkillStates) -> BitArray {
  let states_bytes =
    list.fold(skill_states.states, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(skill_state(one))
    })

  <<skill_states.len:8, states_bytes:bits>>
}

pub type Attribute {
  Attribute(id: Int, value: Int)
}

fn attribute(attribute: Attribute) -> BitArray {
  <<attribute.id:16, attribute.value:16>>
}

pub type Attributes {
  Attributes(value_type: Int, num: Int, attrs: List(Attribute))
}

fn attributes(attributes: Attributes) -> BitArray {
  let attrs_bytes =
    list.fold(attributes.attrs, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(attribute(one))
    })

  <<attributes.value_type:8, attributes.num:16, attrs_bytes:bits>>
}

pub type KitbagItem {
  KitbagItem(
    grid_id: Int,
    id: Int,
    num: Int,
    endure: List(Int),
    energy: List(Int),
    forge_lv: Int,
    is_valid: Bool,
    item_db_inst_id: Int,
    item_db_forge: Int,
    is_params: Bool,
    inst_attrs: List(InstAttr),
  )
}

const boat_id = 3988

fn kitbag_item(kitbag_item: KitbagItem) -> BitArray {
  let grid_id = <<kitbag_item.grid_id:16>>

  case kitbag_item.grid_id {
    65_535 -> grid_id
    _ -> {
      let id_bytes =
        grid_id
        |> bit_array.append(<<kitbag_item.id:16>>)

      case int.compare(kitbag_item.id, 0) {
        order.Gt -> {
          let first_bytes =
            id_bytes
            |> bit_array.append(<<kitbag_item.num:16>>)
            |> bit_array.append(
              list.fold(kitbag_item.endure, <<>>, fn(acc, one) {
                acc
                |> bit_array.append(<<one:16>>)
              }),
            )
            |> bit_array.append(
              list.fold(kitbag_item.energy, <<>>, fn(acc, one) {
                acc
                |> bit_array.append(<<one:16>>)
              }),
            )
            |> bit_array.append(<<
              kitbag_item.forge_lv:8,
              bool.to_int(kitbag_item.is_valid):8,
            >>)
            |> bit_array.append(case int.compare(kitbag_item.id, boat_id) {
              order.Eq -> <<kitbag_item.item_db_inst_id:32>>
              _ -> <<>>
            })
            |> bit_array.append(<<kitbag_item.item_db_forge:32>>)
            |> bit_array.append(case int.compare(kitbag_item.id, boat_id) {
              order.Eq -> <<0:32>>
              _ -> <<kitbag_item.item_db_inst_id:32>>
            })
            |> bit_array.append(<<bool.to_int(kitbag_item.is_params):8>>)
            |> bit_array.append(case bool.compare(kitbag_item.is_params, True) {
              order.Eq ->
                list.fold(kitbag_item.inst_attrs, <<>>, fn(acc, one) {
                  acc
                  |> bit_array.append(<<one.id:16, one.value:16>>)
                })
              _ -> <<>>
            })
        }
        _ -> id_bytes
      }
    }
  }
}

pub type Kitbag {
  Kitbag(value_type: Int, num: Int, items: List(KitbagItem))
}

fn kitbag(kitbag: Kitbag) -> BitArray {
  let items_bytes =
    list.fold(kitbag.items, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(kitbag_item(one))
    })

  <<kitbag.value_type:8, kitbag.num:16, items_bytes:bits>>
}

pub type Shortcut {
  Shortcut(value_type: Int, grid_id: Int)
}

fn shortcut(shortcut: Shortcut) -> BitArray {
  <<shortcut.value_type:8, shortcut.grid_id:16>>
}

pub type Shortcuts {
  Shortcuts(items: List(Shortcut))
}

fn shortcuts(shortcuts: Shortcuts) -> BitArray {
  list.fold(shortcuts.items, <<>>, fn(acc, one) {
    acc
    |> bit_array.append(shortcut(one))
  })
}

pub type Boat {
  Boat(
    base: Base,
    attribute: Attributes,
    kitbag: Kitbag,
    skill_state: SkillStates,
  )
}

fn boat(boat: Boat) -> BitArray {
  let base_bytes = base(boat.base)
  let attribute_bytes = attributes(boat.attribute)
  let kitbag_bytes = kitbag(boat.kitbag)
  let skill_state_bytes = skill_states(boat.skill_state)

  <<
    base_bytes:bits,
    attribute_bytes:bits,
    kitbag_bytes:bits,
    skill_state_bytes:bits,
  >>
}

pub type World {
  World(
    enter_ret: Int,
    auto_lock: Int,
    kitbag_lock: Int,
    enter_type: Int,
    is_new_char: Int,
    map_name: String,
    can_team: Int,
    character_base: Base,
    character_skill_bag: SkillBag,
    character_skill_state: SkillStates,
    character_attribute: Attributes,
    character_kitbag: Kitbag,
    character_shortcut: Shortcuts,
    character_boat: List(Boat),
    cha_main_id: Int,
  )
}

pub fn world(world: World) -> Pack {
  let character_boat_bytes =
    list.fold(world.character_boat, <<>>, fn(acc, one) {
      acc
      |> bit_array.append(boat(one))
    })

  <<
    516:16,
    world.enter_ret:16,
    world.auto_lock:8,
    world.kitbag_lock:8,
    world.enter_type:8,
    world.is_new_char:8,
    string.byte_size(world.map_name):16,
    world.map_name:utf8,
    world.can_team:8,
    base(world.character_base):bits,
    skill_bag(world.character_skill_bag):bits,
    skill_states(world.character_skill_state):bits,
    attributes(world.character_attribute):bits,
    kitbag(world.character_kitbag):bits,
    shortcuts(world.character_shortcut):bits,
    list.length(world.character_boat):8,
    character_boat_bytes:bits,
    world.cha_main_id:32,
  >>
  |> Pack
}

pub type EnterGame {
  EnterGame(name: String)
}

pub fn enter_game(
  unpack: Unpack(EnterGame, BitArray),
) -> Result(BitArray, Error) {
  let assert Unpack(data, handler) = unpack

  case data {
    <<name_len:16, name:bytes-size(name_len)>> -> {
      let assert Ok(name_cut) = {
        use name_cut <- try(bit_array.slice(name, 0, name_len - 1))
        use name_cut <- try(bit_array.to_string(name_cut))
        Ok(name_cut)
      }

      EnterGame(name_cut)
      |> handler
      |> Ok
    }
    _ -> {
      io.debug(data)
      Error(PatternMatchWrong)
    }
  }
}

pub fn enter_game_handle(ctx: Context, enter_game: EnterGame) -> BitArray {
  let assert Context(db, _, _, account_id) = ctx

  let item_grids =
    list.repeat(LookItem(0, option.None, option.None, 0, [], 0, []), 10)

  let look_appends = list.repeat(LookAppend(0, 0), 4)

  let skills = list.repeat(Skill(0, 0, 0, 0, 0, 0, 0, 0, []), 9)

  let attributes =
    list.repeat(Attribute(0, 0), 74)
    |> list.index_map(fn(attr, index) { Attribute(index, 1) })

  let kitbag_items =
    list.repeat(KitbagItem(65_535, 0, 0, [], [], 0, False, 0, 0, False, []), 24)

  let shortcuts = list.repeat(Shortcut(0, 0), 36)

  world(World(
    0,
    0,
    0,
    1,
    0,
    "garner",
    0,
    Base(
      4,
      10_271,
      10_271,
      "ingrysty (comm)",
      0,
      33_565_845,
      1,
      "ingrysty",
      "motto_name",
      4,
      0,
      "guild_name",
      "guild_motto",
      "stall_name",
      1,
      Position(217_475, 278_175, 40),
      71,
      0,
      Side(0),
      EntityEvent(10_271, 1, 0, "test event"),
      Look(0, 4, 0, option.None, option.Some(LookHuman(2291, item_grids))),
      0,
      look_appends,
    ),
    SkillBag(36, 0, 9, skills),
    SkillStates(0, []),
    Attributes(0, 74, attributes),
    Kitbag(0, 24, kitbag_items),
    Shortcuts(shortcuts),
    [],
    10_271,
  ))
  |> pack.pack()
}
