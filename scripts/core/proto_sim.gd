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

## Boss state
var boss_id := ""
var boss_hp := 0.0
var boss_max_hp := 0.0
var boss_phase := 1
var boss_immunity: Array = []

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

## ---------- Attack System ----------
var attack_cooldown := 0.60
var attack_timer := 0.0
var attack_damage := 18.0
var attack_radius := 108.0
var attack_pierce := 1
var attack_multi := 1
var attack_track := false

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


func _init(seed_value: int = 20261111) -> void:
	_rng.seed = seed_value
	for i in range(3):
		slots.append([])


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

	if cid == "mage":
		base_attack_damage = 25.0
		base_attack_radius = 60.0
		base_attack_pierce = 1
		base_attack_multi = 1
		attack_track = true
	elif cid == "warrior":
		base_attack_damage = 35.0
		base_attack_radius = 55.0
		base_attack_pierce = 1
		base_attack_multi = 1
		attack_track = false
	elif cid == "hunter":
		base_attack_damage = 20.0
		base_attack_radius = 50.0
		base_attack_pierce = 1
		base_attack_multi = 2
		attack_track = true
	elif cid == "priest":
		base_attack_damage = 12.0
		base_attack_radius = 90.0
		base_attack_pierce = 1
		base_attack_multi = 1
		attack_track = false

	_recalc_attack_stats()
	_reset_slots_for_char(cid)


func start_boss(boss_id: String) -> void:
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


func _apply_all_modifiers() -> void:
	_recalc_attack_stats()
	for slot_idx in range(slots.size()):
		var block_arr: Array = slots[slot_idx]
		for block_val in block_arr:
			var block: CommandBlock = block_val
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
					_:
						pass


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
	slots[slot_idx].remove_at(block_idx)
	_apply_all_modifiers()
	return true


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

	if input_dir.length_squared() > 0.0001:
		player_pos += input_dir.normalized() * player_speed * delta
		_clamp_player()

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = ProtoLogic.spawn_interval(elapsed)
		_spawn_wave()

	_move_enemies(delta)

	aoe_timer -= delta
	if aoe_timer <= 0.0:
		aoe_timer = aoe_cooldown
		_fire_attack()

	var pipeline_events := _execute_pipeline(delta)
	_apply_pipeline_events(pipeline_events)

	_update_gems(delta)
	_enemy_touch(delta)
	_age_dmg_text(delta)

	if player_hp <= 0.0:
		player_hp = 0.0
		alive = false


func _execute_pipeline(delta: float) -> Array:
	if active_slot < 0 or active_slot >= slots.size():
		return []
	var pipeline: Array = slots[active_slot]
	var events: Array = []
	for block in pipeline:
		if block.kind == CommandBlock.KIND_MODIFIER:
			pass  # modifiers applied in _apply_all_modifiers()
	return events


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


func _fire_attack() -> void:
	if enemy_pos.size() == 0:
		return
	var nearest_idx := -1
	var nearest_d2 := 999999.0
	for i in range(enemy_pos.size()):
		var d2 := enemy_pos[i].distance_squared_to(player_pos)
		if d2 < nearest_d2:
			nearest_d2 = d2
			nearest_idx = i
	if nearest_idx < 0:
		return

	var m := attack_multi
	for k in range(m):
		var damage := attack_damage
		var hit := false
		var hit_count := 0
		var i := enemy_pos.size() - 1
		while i >= 0 and hit_count < attack_pierce:
			var ep := enemy_pos[i]
			var d2 := ep.distance_squared_to(player_pos)
			if d2 <= attack_radius * attack_radius:
				enemy_hp[i] -= damage
				damage_dealt += damage
				_push_dmg_text(ep, damage)
				hit_count += 1
				if enemy_hp[i] <= 0.0:
					_kill_enemy(i)
				hit = true
			i -= 1
		if hit:
			break


func _kill_enemy(idx: int) -> void:
	kills += 1
	if gem_pos.size() < Tuning.GEM_MAX:
		gem_pos.append(enemy_pos[idx])
		gem_value.append(Tuning.GEM_VALUE)
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
			player_hp -= Tuning.CONTACT_DAMAGE
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
