import bytes/pack.{pack}
import bytes/packet.{type Pack, type Unpack, Pack, Unpack}
import core/context.{type Context, Context}
import database/account.{Account}
import database/character
import gleam/bit_array
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/pgo.{type Returned, Returned}
import gleam/result.{try, unwrap}
import packets/character_screen.{type Character, Character}
import packets/dto.{type Auth, type InstAttr, Auth}

pub type Error {
  PatternMatchWrong
  CantGetAccountID
}

type Position {
  Position(x: Int, y: Int, radius: Int)
}

type Side {
  Side(side_id: Int)
}

type EntityEvent {
  EntityEvent(id: Int, value: Int, event_id: Int, event_name: String)
}

type LookItemSync {
  LookItemSync(endure: Int, energy: Int, is_valid: Int)
}

type LookItemShow {
  LookItemShow(
    num: Int,
    endure: List(Int),
    energy: List(Int),
    forge_lv: Int,
    is_valid: Int,
  )
}

type LookItem {
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

type LookHuman {
  LookHuman(hair_id: Int, item_grids: List(LookItem))
}

type LookBoat {
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

type Look {
  Look(
    syn_type: Int,
    type_id: Int,
    is_boat: Int,
    boat: Option(LookBoat),
    human: Option(LookHuman),
  )
}

type LookAppend {
  LookAppend(look_id: Int, is_valid: Int)
}

type Base {
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

type Skill {
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

type SkillBag {
  SkillBag(skill_id: Int, value_type: Int, skill_num: Int, skills: List(Skill))
}

type SkillState {
  SkillState(id: Int, level: Int)
}

type SkillStates {
  SkillStates(len: Int, states: List(SkillState))
}

type Attribute {
  Attribute(id: Int, value: Int)
}

type Attributes {
  Attributes(id: Int, num: Int, attrs: List(Attribute))
}

type KitbagItem {
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

type Kitbag {
  Kitbag(value_type: Int, num: Int, items: List(KitbagItem))
}

type Shortcut {
  Shortcut(value_type: Int, grid_id: Int)
}

type Shortcuts {
  Shortcuts(items: List(Shortcut))
}

type Boat {
  Boat(
    base: Base,
    attribute: Attributes,
    kitbag: Kitbag,
    skill_state: SkillStates,
  )
}

type World {
  World(
    enter_ret: Int,
    auto_lock: Int,
    kitbag_lock: Int,
    enter_type: Int,
    is_new_char: Int,
    // map len
    map_name: String,
    can_team: Int,
    character_base: Base,
    character_skill_bag: SkillBag,
    character_skill_state: SkillStates,
    character_attribute: Attributes,
    character_kitbag: Kitbag,
    character_shortcut: Shortcuts,
    // boat len
    character_boat: List(Boat),
    cha_main_id: Int,
  )
}

pub fn pincode_confirm() -> Pack {
  let prefinal_bytes =
    <<942:size(16)>>
    |> bit_array.append(<<0x00, 0x00>>)

  Pack(prefinal_bytes)
}
