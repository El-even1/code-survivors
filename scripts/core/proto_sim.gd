class_name ProtoSim
extends RefCounted

## Stage I Color Prototype · World Simulation (pure data, no scene tree, headless testable)
## Iron Law: No physics engine, custom circle distance + spatial grid; object pool pre-warmed; tail-swap removal; floating text merge
## Attack Mode: Auto-attack nearest enemy at fixed cooldown; no trigger, no manual aim

## ---------- Character System ----------
var char_id := ""
var char_name := ""
var char_weapon := ""
var char_passive := ""

## ---------- Stage 2 Level System ----------
var level_sim: LevelSim
var current_sector: String = ""
var current_boss: String = ""

## Boss state（运行时）
var boss_id := ""
var boss_hp := 0.0
var boss_max_hp := 0.0
var boss_phase := 1
var boss_immunity: Array = []
var boss_pos := Vector2.ZERO
var boss_radius := 46.0
var boss_speed := 58.0
var boss_attack_timer := 0.0
var boss_shots_pos: Array[Vector2] = []
var boss_shots_dir: Array[Vector2] = []
var boss_shots_life: Array[float] = []

## 安全区状态
var safe_zone_healed := false

var char_base_hp := 140.0
var char_base_speed := 265.0
var char_base_cooldown := 0.60

## ---------- Player ----------
var player_pos := Vector2(Tuning.WORLD_W * 0.5, Tuning.WORLD_H * 0.5)
var player_hp := Tuning.PLAYER_MAX_HP
var player_max_hp: float = Tuning.PLAYER_MAX_HP
var player_speed := Tuning.PLAYER_SPEED
var alive := true
var iframe_timer := 0.0

## ---------- 蓝量（每次施法消耗，持续回复）----------
var mana := 100.0
var mana_max := 100.0
var mana_regen := 8.0

## ---------- Attack System ----------
var attack_cooldown := 0.60
var attack_timer := 0.0
var attack_damage := 18.0
var attack_radius := 108.0
var attack_pierce := 1
var attack_multi := 1
var attack_track := false
var attack_track_stacks := 0
var attack_flash := 0.0   # 攻击闪现倒计时，供视觉层渲染武器攻击特效

## 角色被动（选人时写入）
var contact_damage_mult := 1.0
var lifesteal_on_kill := 0.0

## ---------- 弹道（远程角色真正发射子弹）----------
var shot_pos: Array[Vector2] = []
var shot_dir: Array[Vector2] = []
var shot_life: Array[float] = []
var shot_pierce: Array[int] = []
var shot_hits: Array[int] = []
var shot_hit_ids: Array = []         # 每颗子弹已命中的 enemy_id（防止同一颗重复命中）
var shot_speed := 560.0
var shot_radius := 7.0
const SHOT_MAX := 60

var magnet_radius := Tuning.MAGNET_RADIUS
var aoe_timer := 0.0
var aoe_pulses := 0
var aoe_cooldown := 0.60

var base_attack_cooldown := 0.60
var base_attack_damage := 18.0
var base_attack_radius := 108.0
var base_attack_pierce := 1
var base_attack_multi := 1

## ---------- Pipeline Slot System ----------
var slots: Array = []
var active_slot := 0
var slot_switch_cooldown := 0.0
var last_hit_time := -999.0
var persist_store: Dictionary = {}
var owned: Dictionary = {}   # 已获得升级：id -> level

## ---------- Entities ----------
var enemy_pos: Array[Vector2] = []
var enemy_hp: Array[float] = []
var enemy_id: Array[int] = []

var gem_pos: Array[Vector2] = []
var gem_value: Array[int] = []

var dmg_pos: Array[Vector2] = []
var dmg_age: Array[float] = []
var dmg_value: Array[float] = []
var dmg_count: Array[int] = []
var dmg_alive: Array[bool] = []

## ---------- Stats ----------
var kills := 0
var gems_collected := 0
var peak_enemies := 0
var damage_dealt := 0.0
var elapsed := 0.0
var spawn_timer := 0.0
var level := 1
var xp := 0.0
var xp_to_next := Tuning.XP_BASE
var pending_levels := 0

var _rng := RandomNumberGenerator.new()

## ---------- 指令块掉落 / 库存 ----------
var block_inventory: Dictionary = {}      # block_id -> 未装备数量
var block_drop_pos: Array[Vector2] = []   # 地上掉落的指令块位置
var block_drop_id: Array[String] = []     # 对应 block_id
var block_toast := ""                     # 拾取提示（block_id）
var block_toast_timer := 0.0


func _init(seed_value: int = 20261111) -> void:
	_rng.seed = seed_value
	# Initialize 3 empty pipeline slots
	for i in range(3):
		slots.append([])
	# Initialize LevelSim
	level_sim = LevelSim.new()
	level_sim.init(self)


func _select_char(cid: String) -> void:
	char_id = cid
	var cfg: Dictionary = Tuning.CHARACTER_BASE[cid]
	if cfg == null:
		return
	char_name = cfg["name"]
	char_weapon = cfg["weapon"]
	char_passive = cfg["passive"]
	char_base_hp = float(cfg["hp"])
	char_base_speed = float(cfg["speed"])
	char_base_cooldown = float(cfg["attack_cooldown"])

	player_max_hp = char_base_hp
	player_hp = player_max_hp
	player_speed = char_base_speed
	base_attack_cooldown = char_base_cooldown
	attack_cooldown = char_base_cooldown
	attack_timer = 0.0

	# 蓝量池与回复（按角色）
	mana_max = float(cfg.get("mana", 100.0))
	mana = mana_max
	mana_regen = float(cfg.get("mana_regen", 8.0))

	# 角色被动（Tuning 里写的被动现在真正生效）
	contact_damage_mult = 1.0
	lifesteal_on_kill = 0.0
	var atk_speed_mult := 1.0
	var move_mult := 1.0

	if cid == "mage":
		# 法师：小范围 AoE 弹（一次打 3 个），范围给足，前期不弱势
		base_attack_damage = 24.0
		base_attack_radius = 85.0
		base_attack_pierce = 3
		base_attack_multi = 1
		atk_speed_mult = 1.10          # 被动：攻速 +10%
	elif cid == "warrior":
		# 近战横扫：刀光覆盖一圈，范围内敌人全部命中（范围攻击）
		base_attack_damage = 30.0
		base_attack_radius = 95.0
		base_attack_pierce = 99
		base_attack_multi = 1
		contact_damage_mult = 0.70     # 被动：接触伤害 -30%
	elif cid == "hunter":
		# 双发：每次攻击 2 轮命中
		base_attack_damage = 20.0
		base_attack_radius = 60.0
		base_attack_pierce = 1
		base_attack_multi = 2
		move_mult = 1.15               # 被动：移速 +15%
	elif cid == "priest":
		base_attack_damage = 12.0
		base_attack_radius = 90.0
		base_attack_pierce = 2
		base_attack_multi = 1
		lifesteal_on_kill = 0.02       # 被动：击杀回复 2% 最大生命

	base_attack_cooldown = char_base_cooldown / atk_speed_mult
	attack_cooldown = base_attack_cooldown
	player_speed = char_base_speed * move_mult
	attack_track = false

	_recalc_attack_stats()
	_reset_slots_for_char(cid)
	# 新角色开局：清空掉落与库存（指令块只能靠击杀掉落获得）
	block_inventory.clear()
	block_drop_pos.clear()
	block_drop_id.clear()
	block_toast = ""
	block_toast_timer = 0.0
	clear_shots()
	level_sim.start_sector("sector_a")


func start_boss(boss_id: String) -> void:
	# 兼容旧接口：让 LevelSim 进入 Boss 战，下次 step 会同步出 Boss 实体
	level_sim.start_boss(boss_id)
	self.boss_id = boss_id
	var data: Dictionary = LevelData.get_boss(boss_id)
	boss_max_hp = float(data["max_hp"])
	boss_hp = boss_max_hp
	boss_phase = 1
	boss_immunity = data.get("immunity", [])


func _reset_slots_for_char(cid: String) -> void:
	for i in range(slots.size()):
		slots[i].clear()
	if cid == "mage":
		slots[0].append(CommandBlock.from_template("action_projectile", 1, "white"))
	elif cid == "warrior":
		slots[0].append(CommandBlock.from_template("action_melee", 1, "white"))
	elif cid == "hunter":
		slots[0].append(CommandBlock.from_template("action_projectile", 1, "white"))
		slots[0].append(CommandBlock.from_template("mod_multi", 1, "white"))
	elif cid == "priest":
		slots[0].append(CommandBlock.from_template("action_field", 1, "white"))


func _recalc_attack_stats() -> void:
	attack_cooldown = base_attack_cooldown
	attack_damage = base_attack_damage
	attack_radius = base_attack_radius
	attack_pierce = base_attack_pierce
	attack_multi = base_attack_multi
	attack_track = false
	attack_track_stacks = 0


func _apply_all_modifiers() -> void:
	_recalc_attack_stats()
	for slot_idx in range(slots.size()):
		var block_arr: Array = slots[slot_idx]
		for block_item in block_arr:
			var block: CommandBlock = block_item
			if block.kind == CommandBlock.KIND_MODIFIER:
				var id := block.id
				match id:
					"mod_penetrate":
						attack_pierce += int(block.get_param("extra_pierce", 2))
					"mod_multi":
						attack_multi += int(block.get_param("extra_count", 1))
					"mod_range":
						attack_radius *= float(block.get_param("range_mult", 1.30))
					"mod_cooldown":
						attack_cooldown = maxf(0.05, attack_cooldown * float(block.get_param("cd_mult", 0.86)))
					"mod_dot":
						pass
					"mod_track":
						attack_track = true
						attack_track_stacks += 1
					_:
						pass
	# 追踪：每层 +35% 攻击范围，并且优先命中最近的敌人（可叠加）
	if attack_track_stacks > 0:
		attack_radius *= pow(1.35, float(attack_track_stacks))


func apply_upgrade(id: String) -> void:
	var info: Dictionary = ProtoLogic.Tuning_UPGRADES.get(id, {})
	if info.is_empty():
		return
	owned[id] = int(owned.get(id, 0)) + 1
	# 数值型升级直接折进 base 值，再由 _apply_all_modifiers() 重算，
	# 这样管线修饰符与角色基础值的叠加关系不会被升级破坏。
	match String(info.get("kind", "")):
		"damage":
			base_attack_damage *= 1.25
		"radius":
			base_attack_radius *= 1.18
		"cooldown":
			base_attack_cooldown = maxf(0.05, base_attack_cooldown * 0.86)
		"move":
			player_speed *= 1.12
		"magnet":
			magnet_radius *= 1.30
		"vitality":
			player_max_hp *= 1.20
			player_hp = player_max_hp
		_:
			pass
	_apply_all_modifiers()
	pending_levels = maxi(0, pending_levels - 1)


func add_command(slot_idx: int, block: CommandBlock) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	slots[slot_idx].append(block)
	_apply_all_modifiers()
	return true


func remove_command(slot_idx: int, block_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	if block_idx < 0 or block_idx >= slots[slot_idx].size():
		return false
	var block: CommandBlock = slots[slot_idx][block_idx]
	slots[slot_idx].remove_at(block_idx)
	# 卸下的指令块退回库存，可再装备到别的槽位
	block_inventory[block.id] = block_stock(block.id) + 1
	_apply_all_modifiers()
	return true


## ---------- 指令块：掉落 → 库存 → 装备 ----------
## 存放区有格子上限，满了就捡不进来（掉落留在地上）
func grant_block(block_id: String) -> bool:
	if block_id == "":
		return false
	if storage_used() >= BlockLibrary.STORAGE_CAP:
		block_toast = "storage_full"
		block_toast_timer = 2.0
		return false
	block_inventory[block_id] = block_stock(block_id) + 1
	block_toast = block_id
	block_toast_timer = 2.4
	return true


func block_stock(block_id: String) -> int:
	return int(block_inventory.get(block_id, 0))


## 该角色可用的全部指令块 id（通用 + 专属）
func allowed_blocks() -> Array[String]:
	return BlockLibrary.for_char(char_id)


## 装备一个掉落指令块到指定槽位：必须角色可用且库存 > 0
func equip_block(slot_idx: int, block_id: String) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	if not BlockLibrary.is_allowed(char_id, block_id):
		return false
	if block_stock(block_id) <= 0:
		return false
	var block := CommandBlock.from_template(block_id, 1, "white")
	slots[slot_idx].append(block)
	block_inventory[block_id] = block_stock(block_id) - 1
	_apply_all_modifiers()
	return true


## ---------- 工坊插槽（背包拖拽用）----------
## socket 0 = 主动槽；1..MOD_SOCKETS = 修饰槽
const MOD_SOCKETS := 3


func slot_action_id(slot_idx: int) -> String:
	if slot_idx < 0 or slot_idx >= slots.size():
		return ""
	for b in slots[slot_idx]:
		if b.kind == CommandBlock.KIND_ACTION:
			return String(b.id)
	return ""


func slot_modifier_ids(slot_idx: int) -> Array:
	var out: Array = []
	if slot_idx < 0 or slot_idx >= slots.size():
		return out
	for b in slots[slot_idx]:
		if b.kind == CommandBlock.KIND_MODIFIER:
			out.append(String(b.id))
	return out


func _modifier_indices(slot_idx: int) -> Array:
	var out: Array = []
	var arr: Array = slots[slot_idx]
	for i in range(arr.size()):
		var b: CommandBlock = arr[i]
		if b.kind == CommandBlock.KIND_MODIFIER:
			out.append(i)
	return out


## ---------- 建造约束：蓝量 / 链路方向 / 存放区 ----------
## 一条管线槽已用蓝量
func slot_mana_used(slot_idx: int) -> int:
	# 兼容旧接口：现在返回「每次施法耗蓝」
	return cast_mana_cost(slot_idx)


## 存放区（未装备的指令块）已用格子
func storage_used() -> int:
	var total := 0
	for k in block_inventory.keys():
		total += int(block_inventory[k])
	return total


func storage_free() -> int:
	return maxi(0, BlockLibrary.STORAGE_CAP - storage_used())


## 能否把块放进该插槽；返回 "" 表示可以，否则返回原因 key
## 原因：slot_invalid / not_allowed / no_stock / wrong_kind / chain_gap / socket_full / mana_low
func can_equip_socket(slot_idx: int, socket: int, block_id: String) -> String:
	if slot_idx < 0 or slot_idx >= slots.size():
		return "slot_invalid"
	if not BlockLibrary.is_allowed(char_id, block_id):
		return "not_allowed"
	if block_stock(block_id) <= 0:
		return "no_stock"
	var tpl: Dictionary = CommandBlock.BLOCK_TEMPLATES.get(block_id, {})
	if tpl.is_empty():
		return "not_allowed"
	var tpl_kind := String(tpl.get("kind", ""))

	if socket == 0:
		if tpl_kind != CommandBlock.KIND_ACTION:
			return "wrong_kind"
	elif socket >= 1 and socket <= MOD_SOCKETS:
		if tpl_kind != CommandBlock.KIND_MODIFIER:
			return "wrong_kind"
		var mods := _modifier_indices(slot_idx)
		var mi := socket - 1
		# 链路方向：必须从左往右依次填，不能跳格
		if mi > mods.size():
			return "chain_gap"
	else:
		return "socket_full"

	# 蓝量不再是建造预算：每块只影响「每次施法耗蓝」，由 cast_mana_cost() 汇总
	return ""


## 该管线槽每次施法的耗蓝（主动块 + 所有修饰块叠加）
func cast_mana_cost(slot_idx: int) -> int:
	if slot_idx < 0 or slot_idx >= slots.size():
		return 0
	var total := 0
	for b in slots[slot_idx]:
		total += BlockLibrary.cast_cost(String(b.id))
	return total


## 把掉落块放进指定插槽：类型匹配 + 链路顺序 + 蓝量上限，任一不满足都会被拒
func equip_socket(slot_idx: int, socket: int, block_id: String) -> bool:
	var reason := can_equip_socket(slot_idx, socket, block_id)
	if reason != "":
		return false

	if socket == 0:
		# 替换原主动块：旧的退回库存
		for i in range(slots[slot_idx].size() - 1, -1, -1):
			var old: CommandBlock = slots[slot_idx][i]
			if old.kind == CommandBlock.KIND_ACTION:
				slots[slot_idx].remove_at(i)
				block_inventory[old.id] = block_stock(old.id) + 1
				break
	else:
		var mods := _modifier_indices(slot_idx)
		var mi := socket - 1
		if mi < mods.size():
			# 该修饰槽已有块：替换，旧的退回库存
			var at: int = mods[mi]
			var old_mod: CommandBlock = slots[slot_idx][at]
			slots[slot_idx].remove_at(at)
			block_inventory[old_mod.id] = block_stock(old_mod.id) + 1

	slots[slot_idx].append(CommandBlock.from_template(block_id, 1, "white"))
	block_inventory[block_id] = block_stock(block_id) - 1
	_apply_all_modifiers()
	return true


## 卸下某个插槽的块，退回库存
func unequip_socket(slot_idx: int, socket: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	if socket == 0:
		for i in range(slots[slot_idx].size() - 1, -1, -1):
			var b: CommandBlock = slots[slot_idx][i]
			if b.kind == CommandBlock.KIND_ACTION:
				slots[slot_idx].remove_at(i)
				block_inventory[b.id] = block_stock(b.id) + 1
				_apply_all_modifiers()
				return true
		return false
	var mods := _modifier_indices(slot_idx)
	var mi := socket - 1
	if mi < 0 or mi >= mods.size():
		return false
	var at: int = mods[mi]
	var old: CommandBlock = slots[slot_idx][at]
	slots[slot_idx].remove_at(at)
	block_inventory[old.id] = block_stock(old.id) + 1
	_apply_all_modifiers()
	return true


func _update_block_drops(delta: float) -> void:
	# 拾取半径略大于宝石，避免手感太苛刻
	var pick_r := Tuning.PICKUP_RADIUS * 1.4
	var pr2 := pick_r * pick_r
	var i := block_drop_pos.size() - 1
	while i >= 0:
		var p := block_drop_pos[i]
		if p.distance_squared_to(player_pos) <= pr2:
			# 存放区满：捡不进来，掉落留在地上
			if grant_block(block_drop_id[i]):
				ProtoLogic.swap_pop(block_drop_pos, i)
				ProtoLogic.swap_pop(block_drop_id, i)
		i -= 1
	if block_toast_timer > 0.0:
		block_toast_timer -= delta
		if block_toast_timer <= 0.0:
			block_toast = ""


func switch_slot(idx: int) -> bool:
	if idx < 0 or idx >= slots.size():
		return false
	if slot_switch_cooldown > 0.0:
		return false
	active_slot = idx
	slot_switch_cooldown = 0.5
	return true


func get_pipeline(slot_idx: int):
	if slot_idx < 0 or slot_idx >= slots.size():
		return null
	return slots[slot_idx]


func get_active_slot() -> int:
	return active_slot


func get_pipelines() -> Array:
	return slots.duplicate()


func sim_player_pos() -> Vector2:
	return player_pos

func get_last_hit() -> bool:
	return (elapsed - last_hit_time) < 0.1

func get_elapsed() -> float:
	return elapsed

func get_persist(key: String, default) -> Variant:
	return persist_store.get(key, default)

func set_persist(key: String, value: Variant) -> void:
	persist_store[key] = value

func get_nearest_enemy_dist() -> float:
	if enemy_pos.size() == 0:
		return 9999.0
	var best := 9999.0
	for p in enemy_pos:
		var d := p.distance_to(player_pos)
		if d < best:
			best = d
	return best

func has_buff(buff_id: String) -> bool:
	return false


func step(delta: float, input_dir: Vector2) -> void:
	if not alive:
		return
	elapsed += delta

	# Level simulation
	level_sim.step(delta)
	_sync_level_state()
	# If game ended, stop
	if level_sim.is_victory:
		return

	if input_dir.length_squared() > 0.0001:
		player_pos += input_dir.normalized() * player_speed * delta
		_clamp_player()

	# 安全区：不刷怪、不攻击，只回蓝 + 捡东西，等玩家点「继续」
	if is_safe_zone():
		mana = minf(mana_max, mana + mana_regen * delta)
		_update_boss_shots(delta)
		_update_gems(delta)
		_update_block_drops(delta)
		_age_dmg_text(delta)
		if attack_flash > 0.0:
			attack_flash -= delta
		return

	if is_boss_fight():
		_update_boss(delta)
		_update_boss_shots(delta)
	else:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = ProtoLogic.spawn_interval(elapsed)
			_spawn_wave()
		_move_enemies(delta)

	# 蓝量持续回复
	mana = minf(mana_max, mana + mana_regen * delta)

	attack_timer -= delta
	if attack_timer <= 0.0:
		# 攻击范围内有目标、且蓝够施法才开火；否则保持待发（进圈/回蓝后立刻打）
		var cast_cost := cast_mana_cost(active_slot)
		if _has_target_in_range() and mana >= float(cast_cost):
			mana -= float(cast_cost)
			attack_timer = attack_cooldown
			attack_flash = 0.15
			_fire_attack()
		else:
			attack_timer = 0.0
	if attack_flash > 0.0:
		attack_flash -= delta

	# 弹道推进（子弹飞行 / 追踪 / 穿透命中）
	_update_shots(delta)

	var pipeline_events := _execute_pipeline(delta)
	_apply_pipeline_events(pipeline_events)

	_update_gems(delta)
	_update_block_drops(delta)
	_enemy_touch(delta)
	_age_dmg_text(delta)

	if player_hp <= 0.0:
		player_hp = 0.0
		alive = false


func _execute_pipeline(delta: float) -> Array:
	if active_slot < 0 or active_slot >= slots.size():
		return []
	# 修饰符是「静态属性」：统一由 _apply_all_modifiers() 从 base 值重算。
	# 这里若也乘一次，冷却/范围会逐帧塌陷到下限（曾导致攻速测试失败）。
	# 保留此入口给后续 trigger / condition / action 使用。
	return []


func _apply_modifier(block: CommandBlock) -> Dictionary:
	var id := block.id
	match id:
		"mod_penetrate":
			return {"type": "attr", "attr": "pierce", "value": float(block.get_param("extra_pierce", 2))}
		"mod_multi":
			return {"type": "attr", "attr": "multi", "value": float(block.get_param("extra_count", 1))}
		"mod_range":
			return {"type": "attr", "attr": "radius", "value": float(block.get_param("range_mult", 1.30))}
		"mod_cooldown":
			return {"type": "attr", "attr": "cooldown", "value": float(block.get_param("cd_mult", 0.86))}
		"mod_dot":
			return {"type": "attr", "attr": "dot_damage", "value": block.get_param("dot_damage", 5.0)}
		"mod_track":
			return {"type": "attr", "attr": "track", "value": 1.0}
		_:
			return {}


func _apply_pipeline_events(events: Array) -> void:
	for ev in events:
		var etype: String = ev.get("type", "")
		match etype:
			"attr":
				_apply_attr_event(ev)
			_:
				pass


func _apply_attr_event(ev: Dictionary) -> void:
	var attr: String = ev.get("attr", "move_speed")
	var value: float = float(ev.get("value", 1.0))
	match attr:
		"move_speed":
			player_speed *= value
		"max_hp":
			player_max_hp *= value
			player_hp = player_max_hp
		"damage":
			attack_damage *= value
		"radius":
			attack_radius *= value
		"cooldown":
			attack_cooldown = maxf(0.05, attack_cooldown * value)
		"magnet":
			magnet_radius *= value
		"pierce":
			attack_pierce += int(value)
		"multi":
			attack_multi += int(value)
		"track":
			attack_track = true
		_:
			pass


func _clamp_player() -> void:
	var m := Tuning.PLAYER_EDGE_MARGIN
	player_pos.x = clampf(player_pos.x, m, Tuning.WORLD_W - m)
	player_pos.y = clampf(player_pos.y, m, Tuning.WORLD_H - m)


## 攻击范围内是否有目标（Boss 战中 Boss 就是目标）
## 实际攻击范围（含追踪块加成）
func effective_attack_radius() -> float:
	return attack_radius


func _has_target_in_range() -> bool:
	if current_boss != "":
		# Boss 体积大：按 Boss 边缘到玩家距离判断，站近了才打得到
		var reach := effective_attack_radius() + boss_radius
		return boss_pos.distance_squared_to(player_pos) <= reach * reach
	var r2 := effective_attack_radius() * effective_attack_radius()
	for p in enemy_pos:
		if p.distance_squared_to(player_pos) <= r2:
			return true
	return false


## ---------- 关卡状态：安全区 / Boss 战 ----------
func is_safe_zone() -> bool:
	return level_sim != null and level_sim.current_sector == "safe_zone"


func is_boss_fight() -> bool:
	return current_boss != ""


## 安全区点「继续」进入下一阶段
func continue_from_safe_zone() -> void:
	if not is_safe_zone():
		return
	level_sim.next_sector()


## 关卡显示用：当前区域名 / 剩余时间
func sector_name() -> String:
	if is_boss_fight():
		var bd: Dictionary = LevelData.get_boss(current_boss)
		return String(bd.get("name", current_boss))
	var sd: Dictionary = LevelData.get_sector(level_sim.current_sector)
	return String(sd.get("name", level_sim.current_sector))


func sector_time_left() -> float:
	if is_safe_zone() or is_boss_fight():
		return 0.0
	var sd: Dictionary = LevelData.get_sector(level_sim.current_sector)
	var dur := float(sd.get("duration_sec", 0.0))
	return maxf(0.0, dur - level_sim.sector_timer)


## 同步关卡状态机 → 战斗内状态（进入 Boss / 退出 Boss / 进入安全区）
func _sync_level_state() -> void:
	current_sector = level_sim.current_sector
	var lb := String(level_sim.current_boss)
	if lb != current_boss:
		if lb != "":
			_enter_boss(lb)
		else:
			_exit_boss()
	if is_safe_zone():
		if not safe_zone_healed:
			_enter_safe_zone()
	else:
		safe_zone_healed = false


func _enter_boss(bid: String) -> void:
	current_boss = bid
	boss_id = bid
	boss_hp = level_sim.boss_hp
	boss_max_hp = level_sim.boss_max_hp
	boss_phase = 1
	boss_pos = player_pos + Vector2(0.0, -260.0)
	boss_attack_timer = 1.5
	# 清场：Boss 战不再刷小怪
	enemy_pos.clear()
	enemy_hp.clear()
	enemy_id.clear()
	clear_shots()
	boss_shots_pos.clear()
	boss_shots_dir.clear()
	boss_shots_life.clear()


func _exit_boss() -> void:
	current_boss = ""
	boss_id = ""
	boss_hp = 0.0
	boss_max_hp = 0.0
	boss_shots_pos.clear()
	boss_shots_dir.clear()
	boss_shots_life.clear()


func _enter_safe_zone() -> void:
	safe_zone_healed = true
	# 清场 + 恢复 30% 最大生命
	enemy_pos.clear()
	enemy_hp.clear()
	enemy_id.clear()
	clear_shots()
	boss_shots_pos.clear()
	boss_shots_dir.clear()
	boss_shots_life.clear()
	player_hp = minf(player_max_hp, player_hp + player_max_hp * 0.3)


## Boss 行为：追击 + 接触伤害 + 阶段加速 + 环形弹幕
func _update_boss(delta: float) -> void:
	if current_boss == "":
		return
	boss_hp = level_sim.boss_hp
	boss_max_hp = level_sim.boss_max_hp
	if boss_hp <= 0.0:
		return

	# 阶段：66% / 33%
	var ratio: float = 0.0
	if boss_max_hp > 0.0:
		ratio = clampf(boss_hp / boss_max_hp, 0.0, 1.0)
	var phase := 1
	if ratio <= 0.33:
		phase = 3
	elif ratio <= 0.66:
		phase = 2
	if phase != boss_phase:
		boss_phase = phase
		level_sim.set_boss_phase(phase)

	# 追击
	var to_player := player_pos - boss_pos
	var d2 := to_player.length_squared()
	var spd := boss_speed * (1.0 + 0.25 * float(boss_phase - 1))
	if d2 > 4.0:
		boss_pos += to_player / sqrt(d2) * spd * delta

	# 接触伤害
	if iframe_timer <= 0.0:
		var touch_r := boss_radius + Tuning.PLAYER_SIZE * 0.5
		if boss_pos.distance_squared_to(player_pos) <= touch_r * touch_r:
			player_hp -= 12.0 * contact_damage_mult
			iframe_timer = Tuning.CONTACT_IFRAMES
			last_hit_time = elapsed

	# 弹幕
	boss_attack_timer -= delta
	if boss_attack_timer <= 0.0:
		boss_attack_timer = maxf(0.8, 2.2 - 0.4 * float(boss_phase - 1))
		_spawn_boss_shots(8 + 4 * (boss_phase - 1))


func _spawn_boss_shots(count: int) -> void:
	if boss_shots_pos.size() >= 160:
		return
	for i in range(count):
		var a: float = TAU * float(i) / float(count)
		boss_shots_pos.append(boss_pos)
		boss_shots_dir.append(Vector2(cos(a), sin(a)))
		boss_shots_life.append(3.5)


func _update_boss_shots(delta: float) -> void:
	var i := boss_shots_pos.size() - 1
	var hit_r := 14.0
	while i >= 0:
		boss_shots_pos[i] = boss_shots_pos[i] + boss_shots_dir[i] * 240.0 * delta
		boss_shots_life[i] -= delta
		var remove := boss_shots_life[i] <= 0.0
		if not remove and iframe_timer <= 0.0:
			if boss_shots_pos[i].distance_squared_to(player_pos) <= hit_r * hit_r:
				player_hp -= 8.0
				iframe_timer = Tuning.CONTACT_IFRAMES
				last_hit_time = elapsed
				remove = true
		if remove:
			ProtoLogic.swap_pop(boss_shots_pos, i)
			ProtoLogic.swap_pop(boss_shots_dir, i)
			ProtoLogic.swap_pop(boss_shots_life, i)
		i -= 1


func _fire_attack() -> void:
	# Boss 战：直接打 Boss（血量由 LevelSim 统一管理，打空即推进关卡）
	if current_boss != "":
		aoe_pulses += 1
		level_sim.set_boss_hp(level_sim.boss_hp - attack_damage)
		boss_hp = level_sim.boss_hp
		damage_dealt += attack_damage
		_push_dmg_text(boss_pos, attack_damage)
		return

	if char_id == "warrior":
		# 战士：近战横扫，瞬间结算范围内目标
		_fire_cleave()
	else:
		# 法师/猎人/牧师：发射真正的弹道，穿透 = 子弹打穿几个敌人
		_fire_projectiles()


func _fire_cleave() -> void:
	var eff_r := effective_attack_radius()
	var r2 := eff_r * eff_r
	var cand: Array[int] = []
	for i in range(enemy_pos.size()):
		if enemy_pos[i].distance_squared_to(player_pos) <= r2:
			cand.append(i)
	if cand.is_empty():
		return
	cand.sort_custom(func(a: int, b: int) -> bool:
		return enemy_pos[a].distance_squared_to(player_pos) < enemy_pos[b].distance_squared_to(player_pos)
	)
	var max_hits: int = maxi(1, attack_multi * attack_pierce)
	aoe_pulses += 1
	var hit_n := 0
	var to_kill: Array[int] = []
	for i in cand:
		if hit_n >= max_hits:
			break
		_damage_enemy(i, attack_damage)
		hit_n += 1
		if enemy_hp[i] <= 0.0:
			to_kill.append(i)
	_flush_kills(to_kill)


## 发射子弹：每颗独立飞、按穿透数依次打穿敌人
func _fire_projectiles() -> void:
	var eff_r := effective_attack_radius()
	var r2 := eff_r * eff_r
	var cand: Array[int] = []
	for i in range(enemy_pos.size()):
		if enemy_pos[i].distance_squared_to(player_pos) <= r2:
			cand.append(i)
	if cand.is_empty():
		return
	cand.sort_custom(func(a: int, b: int) -> bool:
		return enemy_pos[a].distance_squared_to(player_pos) < enemy_pos[b].distance_squared_to(player_pos)
	)

	var shots := maxi(1, attack_multi)
	var flight_life: float = eff_r / shot_speed
	var pierce_n := maxi(1, attack_pierce)
	aoe_pulses += 1
	for k in range(shots):
		if shot_pos.size() >= SHOT_MAX:
			break
		var ti: int = cand[k % cand.size()]
		var aim: Vector2 = enemy_pos[ti] - player_pos
		if aim.length_squared() < 0.01:
			aim = Vector2.RIGHT
		shot_pos.append(player_pos)
		shot_dir.append(aim.normalized())
		shot_life.append(flight_life)
		shot_pierce.append(pierce_n)
		shot_hits.append(0)
		shot_hit_ids.append([])


## 每帧推进子弹：移动 + 追踪转向 + 命中判定 + 生命周期
func _update_shots(delta: float) -> void:
	if shot_pos.size() == 0:
		return
	var hit_r := (Tuning.ENEMY_SIZE + shot_radius) * 0.5
	var hit_r2 := hit_r * hit_r
	var kill_pending: Array[int] = []
	var i := shot_pos.size() - 1
	while i >= 0:
		# 追踪：朝最近敌人持续转向
		if attack_track and enemy_pos.size() > 0:
			var nearest := -1
			var nd := 9999999.0
			for j in range(enemy_pos.size()):
				var d := shot_pos[i].distance_squared_to(enemy_pos[j])
				if d < nd:
					nd = d
					nearest = j
			if nearest >= 0:
				var want: Vector2 = (enemy_pos[nearest] - shot_pos[i]).normalized()
				shot_dir[i] = shot_dir[i].lerp(want, clampf(9.0 * delta, 0.0, 1.0)).normalized()

		shot_pos[i] = shot_pos[i] + shot_dir[i] * shot_speed * delta
		shot_life[i] -= delta

		var remove := shot_life[i] <= 0.0
		if not remove:
			for j in range(enemy_pos.size()):
				if enemy_hp[j] <= 0.0:
					continue
				if shot_pos[i].distance_squared_to(enemy_pos[j]) <= hit_r2:
					var ids: Array = shot_hit_ids[i]
					var eid := enemy_id[j]
					if ids.has(eid):
						continue
					ids.append(eid)
					_damage_enemy(j, attack_damage)
					shot_hits[i] += 1
					if enemy_hp[j] <= 0.0:
						kill_pending.append(j)
					if shot_hits[i] >= shot_pierce[i]:
						remove = true
						break

		if remove:
			ProtoLogic.swap_pop(shot_pos, i)
			ProtoLogic.swap_pop(shot_dir, i)
			ProtoLogic.swap_pop(shot_life, i)
			ProtoLogic.swap_pop(shot_pierce, i)
			ProtoLogic.swap_pop(shot_hits, i)
			ProtoLogic.swap_pop(shot_hit_ids, i)
		i -= 1

	_flush_kills(kill_pending)


func _damage_enemy(idx: int, amount: float) -> void:
	if idx < 0 or idx >= enemy_hp.size():
		return
	enemy_hp[idx] -= amount
	damage_dealt += amount
	_push_dmg_text(enemy_pos[idx], amount)


func _flush_kills(indices: Array) -> void:
	if indices.is_empty():
		return
	indices.sort()
	indices.reverse()
	var seen := {}
	for idx in indices:
		if idx < 0 or idx >= enemy_hp.size():
			continue
		if seen.has(idx):
			continue
		seen[idx] = true
		if enemy_hp[idx] <= 0.0:
			_kill_enemy(idx)


func clear_shots() -> void:
	shot_pos.clear()
	shot_dir.clear()
	shot_life.clear()
	shot_pierce.clear()
	shot_hits.clear()
	shot_hit_ids.clear()


func _kill_enemy(idx: int) -> void:
	kills += 1
	# 牧师被动：击杀回复 2% 最大生命
	if lifesteal_on_kill > 0.0:
		player_hp = minf(player_max_hp, player_hp + player_max_hp * lifesteal_on_kill)
	if gem_pos.size() < Tuning.GEM_MAX:
		gem_pos.append(enemy_pos[idx])
		gem_value.append(Tuning.GEM_VALUE)
	# 有概率掉落本角色可用的指令块（通用 + 专属），掉在敌人倒下的位置
	if _rng.randf() < BlockLibrary.DROP_CHANCE and block_drop_pos.size() < 60:
		var drop_id := BlockLibrary.roll_drop(char_id, _rng)
		if drop_id != "":
			block_drop_pos.append(enemy_pos[idx])
			block_drop_id.append(drop_id)
	ProtoLogic.swap_pop(enemy_pos, idx)
	ProtoLogic.swap_pop(enemy_hp, idx)
	ProtoLogic.swap_pop(enemy_id, idx)


func _update_gems(delta: float) -> void:
	var mr2 := magnet_radius * magnet_radius
	var pr2 := Tuning.PICKUP_RADIUS * Tuning.PICKUP_RADIUS
	var i := gem_pos.size() - 1
	while i >= 0:
		var gp := gem_pos[i]
		var d2 := gp.distance_squared_to(player_pos)
		if d2 <= pr2:
			_gain_xp(gem_value[i])
			gems_collected += 1
			ProtoLogic.swap_pop(gem_pos, i)
			ProtoLogic.swap_pop(gem_value, i)
		elif d2 <= mr2:
			var d := sqrt(d2)
			var pull := Tuning.MAGNET_PULL_SPEED * delta * (1.0 + (1.0 - d / magnet_radius) * 2.0)
			gem_pos[i] = gp + (player_pos - gp) / d * pull
		i -= 1


func _gain_xp(amount: int) -> void:
	xp += float(amount)
	while xp >= xp_to_next and level < Tuning.XP_LEVEL_CAP:
		xp -= xp_to_next
		level += 1
		xp_to_next = ProtoLogic.xp_for_level(level)
		pending_levels += 1


func _spawn_wave() -> void:
	var batch := ProtoLogic.spawn_batch(elapsed)
	var hp := ProtoLogic.enemy_hp(elapsed)
	for i in range(batch):
		if enemy_pos.size() >= Tuning.ENEMY_CAP:
			break
		var ang := _rng.randf() * TAU
		var dist := 620.0 + _rng.randf() * 120.0
		var p := player_pos + Vector2(cos(ang), sin(ang)) * dist
		enemy_pos.append(p)
		enemy_hp.append(hp)
		enemy_id.append(enemy_pos.size() - 1 + int(elapsed * 10.0))
	if enemy_pos.size() > peak_enemies:
		peak_enemies = enemy_pos.size()


func _move_enemies(delta: float) -> void:
	var n := enemy_pos.size()
	if n == 0:
		return
	var skip := Tuning.ENEMY_AI_FRAME_SKIP
	var frame := Engine.get_process_frames() % skip
	var step_len := delta * skip
	var speed := Tuning.ENEMY_SPEED

	for i in range(n):
		if enemy_id[i] % skip != frame:
			continue
		var to_player := player_pos - enemy_pos[i]
		var d2 := to_player.length_squared()
		if d2 < 1.0:
			continue
		enemy_pos[i] += to_player / sqrt(d2) * speed * step_len


func _enemy_touch(delta: float) -> void:
	if iframe_timer > 0.0:
		iframe_timer -= delta
		return
	var r := (Tuning.PLAYER_SIZE + Tuning.ENEMY_SIZE) * 0.5
	var r2 := r * r
	for i in range(enemy_pos.size()):
		if enemy_pos[i].distance_squared_to(player_pos) <= r2:
			player_hp -= Tuning.CONTACT_DAMAGE * contact_damage_mult
			last_hit_time = elapsed
			iframe_timer = Tuning.CONTACT_IFRAMES
			if player_hp <= 0.0:
				player_hp = 0.0
				alive = false
			return


func _push_dmg_text(pos: Vector2, amount: float) -> void:
	if dmg_pos.size() >= Tuning.DMG_MAX:
		return
	var target := ProtoLogic.find_merge_target(dmg_pos, dmg_age, dmg_alive, pos)
	if target >= 0:
		dmg_count[target] += 1
		dmg_value[target] += amount
		dmg_age[target] = 0.0
		return
	dmg_pos.append(pos)
	dmg_age.append(0.0)
	dmg_value.append(amount)
	dmg_count.append(1)
	dmg_alive.append(true)


func _age_dmg_text(delta: float) -> void:
	var i := dmg_pos.size() - 1
	while i >= 0:
		if not dmg_alive[i]:
			ProtoLogic.swap_pop(dmg_pos, i)
			ProtoLogic.swap_pop(dmg_age, i)
			ProtoLogic.swap_pop(dmg_value, i)
			ProtoLogic.swap_pop(dmg_count, i)
			ProtoLogic.swap_pop(dmg_alive, i)
			i -= 1
			continue
		dmg_age[i] += delta
		if dmg_age[i] >= Tuning.DMG_TEXT_LIFE:
			dmg_alive[i] = false
		i -= 1


func snapshot() -> Dictionary:
	return {
		"player_pos": player_pos,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"level": 1,
		"xp": 0.0,
		"xp_to_next": 1.0,
		"elapsed": elapsed,
		"phase": ProtoLogic.phase_name(elapsed),
		"enemies": enemy_pos,
		"gems": gem_pos,
		"block_drops": block_drop_pos,
		"block_drop_ids": block_drop_id,
		"block_toast": block_toast,
		"block_toast_timer": block_toast_timer,
		"block_inventory": block_inventory,
		"dmg_pos": dmg_pos,
		"dmg_age": dmg_age,
		"dmg_value": dmg_value,
		"dmg_count": dmg_count,
		"dmg_alive": dmg_alive,
		"attack_radius": attack_radius,
		"kills": kills,
		"alive": alive,
		"char_id": char_id,
		"char_name": char_name,
		"char_weapon": char_weapon,
	}
