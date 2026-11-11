class_name ProtoSim
extends RefCounted

## 阶段①色块原型 · 世界模拟（纯数据，不依赖场景树，可 headless 压测）
## 文档铁律：禁用物理引擎，自写圆形检测 + 空间网格；对象池预暖；尾部交换移除；飘字合并

# ---------- 玩家 ----------
var player_pos := Vector2(Tuning.WORLD_W * 0.5, Tuning.WORLD_H * 0.5)
var player_hp := Tuning.PLAYER_MAX_HP
var player_max_hp := Tuning.PLAYER_MAX_HP
var player_speed := Tuning.PLAYER_SPEED
var alive := true
var iframe_timer := 0.0       # 受击无敌帧

# ---------- 武器 ----------
var aoe_damage := Tuning.AOE_DAMAGE
var aoe_radius := Tuning.AOE_RADIUS
var aoe_cooldown := Tuning.AOE_COOLDOWN
var aoe_timer := 0.0
var aoe_pulses := 0          # 本局触发了多少次 AoE

# ---------- 成长 ----------
var level := 1
var xp := 0.0
var xp_to_next := Tuning.XP_BASE
var pending_levels := 0
var owned: Dictionary = {}
var magnet_radius := Tuning.MAGNET_RADIUS

# ---------- 时间与节奏 ----------
var elapsed := 0.0
var spawn_timer := 0.0

# ---------- 管线槽位系统（2-3 槽位，战斗中可切，不可修改） ----------
var slots: Array = []        # 2-3 个管线槽位
var active_slot := 0         # 当前生效的槽位下标
var slot_switch_cooldown := 0.0  # 槽位切换冷却（防误触）
var last_hit_time := -999.0         # 最近一次受击时间，供 trigger_on_hit 使用
var persist_store: Dictionary = {} # 持久化键值，供 timer 触发器使用

# ---------- 实体（数组即池：尾部交换移除，无每帧 new） ----------
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

# ---------- 统计 ----------
var kills := 0
var gems_collected := 0
var peak_enemies := 0
var damage_dealt := 0.0

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 20261111) -> void:
	_rng.seed = seed_value
	# 初始化 3 个空槽位
	var pipeline_script = load("res://scripts/core/pipeline.gd")
	for i in range(3):
		var p: RefCounted = pipeline_script.new() as RefCounted
		p.name = "槽位 %d" % (i + 1)
		slots.append(p)

	# 给槽位1一套默认管线：最近敌人 → 白圈 AoE
	var trig := CommandBlock.from_template("trigger_nearest", 1, "白")
	var act := CommandBlock.from_template("action_aoe", 1, "白")
	slots[0].blocks.append(trig)
	slots[0].blocks.append(act)


# =========================================================
#  主推进
# =========================================================
## input_dir: 归一化移动方向；返回本帧是否有升级待处理
func step(delta: float, input_dir: Vector2) -> void:
	if not alive:
		return
	elapsed += delta

	# 玩家移动：直接赋值速度，保证“摇杆跟手”
	if input_dir.length_squared() > 0.0001:
		player_pos += input_dir.normalized() * player_speed * delta
		_clamp_player()

	# 刷怪
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = ProtoLogic.spawn_interval(elapsed)
		_spawn_wave()

	# 敌人：分帧轮转 AI（id%3），只对本格+邻格做检测
	_move_enemies(delta)

	# 武器：白圈 AoE 自动攻击（玩家固定武器，与管线并行）
	aoe_timer -= delta
	if aoe_timer <= 0.0:
		aoe_timer = aoe_cooldown
		_fire_aoe()

	# 管线执行：仅当前激活槽位的管线运行
	var pipeline_events := _execute_pipeline(delta)
	_apply_pipeline_events(pipeline_events)

	# 磁吸拾取
	_update_gems(delta)

	# 接触伤害
	_enemy_touch(delta)

	# 飘字老化
	_age_dmg_text(delta)

	if player_hp <= 0.0:
		player_hp = 0.0
		alive = false


func _clamp_player() -> void:
	var m := Tuning.PLAYER_EDGE_MARGIN
	player_pos.x = clampf(player_pos.x, m, Tuning.WORLD_W - m)
	player_pos.y = clampf(player_pos.y, m, Tuning.WORLD_H - m)


# =========================================================
#  管线槽位系统
# =========================================================
func _execute_pipeline(delta: float) -> Array:
	if active_slot < 0 or active_slot >= slots.size():
		return []
	# 所有槽位的视觉闪光都要衰减（切走的那条也在淡出）
	for p in slots:
		p.tick_visual(delta)
	return slots[active_slot].execute(self, delta)


func _apply_pipeline_events(events: Array) -> void:
	for ev in events:
		var etype: String = ev.get("type", "")
		match etype:
			"aoe":
				_apply_aoe_event(ev)
			"projectile":
				_apply_projectile_event(ev)
			"field":
				_apply_field_event(ev)
			"status":
				_apply_status_event(ev)
			"attr":
				_apply_attr_event(ev)
			_:
				pass


func _apply_aoe_event(ev: Dictionary) -> void:
	var radius: float = float(ev.get("radius", Tuning.AOE_RADIUS))
	var dmg: float = float(ev.get("damage", Tuning.AOE_DAMAGE))
	var r2 := radius * radius
	var hit_any := false
	var i := enemy_pos.size() - 1
	while i >= 0:
		var ep := enemy_pos[i]
		if ep.distance_squared_to(sim_player_pos()) <= r2:
			enemy_hp[i] -= dmg
			damage_dealt += dmg
			hit_any = true
			_push_dmg_text(ep, dmg)
			if enemy_hp[i] <= 0.0:
				_kill_enemy(i)
		i -= 1


func _apply_projectile_event(ev: Dictionary) -> void:
	# 原型阶段：投射物简化为瞬时范围伤害（后续阶段可做真投射物）
	var dmg: float = float(ev.get("damage", 25.0))
	var radius: float = float(ev.get("radius", 60.0))
	var r2 := radius * radius
	var i := enemy_pos.size() - 1
	while i >= 0:
		var ep := enemy_pos[i]
		if ep.distance_squared_to(sim_player_pos()) <= r2:
			enemy_hp[i] -= dmg
			damage_dealt += dmg
			_push_dmg_text(ep, dmg)
			if enemy_hp[i] <= 0.0:
				_kill_enemy(i)
		i -= 1


func _apply_field_event(ev: Dictionary) -> void:
	# 领域：在玩家位置生成持续伤害区域，原型简化为即时 AoE
	var dmg: float = float(ev.get("damage", 10.0))
	var radius: float = float(ev.get("radius", 80.0))
	var r2 := radius * radius
	var i := enemy_pos.size() - 1
	while i >= 0:
		var ep := enemy_pos[i]
		if ep.distance_squared_to(sim_player_pos()) <= r2:
			enemy_hp[i] -= dmg
			damage_dealt += dmg
			_push_dmg_text(ep, dmg)
			if enemy_hp[i] <= 0.0:
				_kill_enemy(i)
		i -= 1


func _apply_status_event(ev: Dictionary) -> void:
	# 状态效果：原型阶段记录，后续阶段实现具体 buff
	var status_id: String = ev.get("status_id", "slow")
	var duration: float = float(ev.get("duration", 2.0))
	# TODO: 实现 buff 系统
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
			aoe_damage *= value
		"radius":
			aoe_radius *= value
		"cooldown":
			aoe_cooldown = maxf(0.05, aoe_cooldown * value)
		"magnet":
			magnet_radius *= value
		_:
			pass


func switch_slot(idx: int) -> bool:
	if idx < 0 or idx >= slots.size():
		return false
	if slot_switch_cooldown > 0.0:
		return false
	active_slot = idx
	slot_switch_cooldown = 0.5  # 0.5秒切换冷却
	return true


func add_command(slot_idx: int, block: CommandBlock) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	slots[slot_idx].blocks.append(block)
	slots[slot_idx].sync_flash()
	return true


func remove_command(slot_idx: int, block_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	if block_idx < 0 or block_idx >= slots[slot_idx].blocks.size():
		return false
	slots[slot_idx].blocks.remove_at(block_idx)
	slots[slot_idx].sync_flash()
	return true


func get_pipeline(slot_idx: int):
	if slot_idx < 0 or slot_idx >= slots.size():
		return null
	return slots[slot_idx]


func get_active_slot() -> int:
	return active_slot


func get_pipelines() -> Array:
	return slots.duplicate()


# ---------- 供管线触发器/条件调用的只读方法 ----------
func sim_player_pos() -> Vector2:
	return player_pos

func get_last_hit() -> bool:
	# 最近 0.1 秒内受击则返回 true
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
	# 原型阶段：无 buff 系统，始终返回 false
	return false


# =========================================================
#  刷怪
# =========================================================
func _spawn_wave() -> void:
	var batch := ProtoLogic.spawn_batch(elapsed)
	var hp := ProtoLogic.enemy_hp(elapsed)
	for i in range(batch):
		if enemy_pos.size() >= Tuning.ENEMY_CAP:
			break
		# 从屏幕外环形生成（略偏向玩家前方，制造包围感）
		var ang := _rng.randf() * TAU
		var dist := 620.0 + _rng.randf() * 120.0
		var p := player_pos + Vector2(cos(ang), sin(ang)) * dist
		enemy_pos.append(p)
		enemy_hp.append(hp)
		enemy_id.append(enemy_pos.size() - 1 + int(elapsed * 10.0))
	if enemy_pos.size() > peak_enemies:
		peak_enemies = enemy_pos.size()


# =========================================================
#  敌人移动（分帧轮转 + 网格邻域）
# =========================================================
func _move_enemies(delta: float) -> void:
	var n := enemy_pos.size()
	if n == 0:
		return
	# 文档：按 id%3 分帧轮转，3 帧跑一次寻路，屏外只更新位置
	var skip := Tuning.ENEMY_AI_FRAME_SKIP
	var frame := Engine.get_process_frames() % skip
	var step_len := delta * skip  # 补偿跳帧的时间
	var speed := Tuning.ENEMY_SPEED

	for i in range(n):
		if enemy_id[i] % skip != frame:
			continue
		var to_player := player_pos - enemy_pos[i]
		var d2 := to_player.length_squared()
		if d2 < 1.0:
			continue
		enemy_pos[i] += to_player / sqrt(d2) * speed * step_len


# =========================================================
#  武器：白圈 AoE
# =========================================================
func _fire_aoe() -> void:
	aoe_pulses += 1
	var r2 := aoe_radius * aoe_radius
	# 只遍历本格+邻格，避免 O(N) 全扫
	var cells := ProtoLogic.cells_in_radius(player_pos, aoe_radius)
	var hit_any := false

	var i := enemy_pos.size() - 1
	while i >= 0:
		var ep := enemy_pos[i]
		# 粗筛：网格内才做精确距离
		if ProtoLogic.cell_of(ep) in cells and ep.distance_squared_to(player_pos) <= r2:
			enemy_hp[i] -= aoe_damage
			damage_dealt += aoe_damage
			hit_any = true
			_push_dmg_text(ep, aoe_damage)
			if enemy_hp[i] <= 0.0:
				_kill_enemy(i)
		i -= 1

	if not hit_any:
		# 空砍也给一点反馈（白圈闪一下），由渲染层处理
		pass


func _kill_enemy(idx: int) -> void:
	kills += 1
	# 掉经验
	if gem_pos.size() < Tuning.GEM_MAX:
		gem_pos.append(enemy_pos[idx])
		gem_value.append(Tuning.GEM_VALUE)
	# 尾部交换法移除
	ProtoLogic.swap_pop(enemy_pos, idx)
	ProtoLogic.swap_pop(enemy_hp, idx)
	ProtoLogic.swap_pop(enemy_id, idx)


# =========================================================
#  经验磁吸
# =========================================================
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
			# 磁吸拉力，越近越快
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


## 渲染层弹完三选一后调用
func apply_upgrade(id: String) -> void:
	if pending_levels > 0:
		pending_levels -= 1
	owned[id] = int(owned.get(id, 0)) + 1
	match id:
		"damage":
			aoe_damage *= 1.25
		"radius":
			aoe_radius *= 1.18
		"cooldown":
			aoe_cooldown = maxf(0.08, aoe_cooldown * 0.86)
		"move":
			player_speed *= 1.12
		"magnet":
			magnet_radius *= 1.30
		"vitality":
			player_max_hp *= 1.20
			player_hp = player_max_hp


# =========================================================
#  接触伤害
# =========================================================
func _enemy_touch(delta: float) -> void:
	if iframe_timer > 0.0:
		iframe_timer -= delta
		return
	var r := (Tuning.PLAYER_SIZE + Tuning.ENEMY_SIZE) * 0.5
	var r2 := r * r
	# 只判断是否被贴到，不按怪的数量叠加伤害
	for i in range(enemy_pos.size()):
		if enemy_pos[i].distance_squared_to(player_pos) <= r2:
			player_hp -= Tuning.CONTACT_DAMAGE
			last_hit_time = elapsed
			iframe_timer = Tuning.CONTACT_IFRAMES
			if player_hp <= 0.0:
				player_hp = 0.0
				alive = false
			return


# =========================================================
#  飘字（合并 + 池化）
# =========================================================
func _push_dmg_text(pos: Vector2, amount: float) -> void:
	if dmg_pos.size() >= Tuning.DMG_MAX:
		return
	var target := ProtoLogic.find_merge_target(dmg_pos, dmg_age, dmg_alive, pos)
	if target >= 0:
		# 合并成一个「×N」，数值累加
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


# =========================================================
#  只读快照（渲染层用）
# =========================================================
func snapshot() -> Dictionary:
	return {
		"player_pos": player_pos,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"level": level,
		"xp": xp,
		"xp_to_next": xp_to_next,
		"elapsed": elapsed,
		"phase": ProtoLogic.phase_name(elapsed),
		"enemies": enemy_pos,
		"gems": gem_pos,
		"dmg_pos": dmg_pos,
		"dmg_age": dmg_age,
		"dmg_value": dmg_value,
		"dmg_count": dmg_count,
		"dmg_alive": dmg_alive,
		"aoe_radius": aoe_radius,
		"kills": kills,
		"alive": alive,
	}
