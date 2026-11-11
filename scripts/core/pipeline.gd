class_name Pipeline
extends RefCounted

## 阶段①色块原型 · 管线执行引擎
## 执行模型：线性四元组，按块顺序执行
##   trigger 触发后，后续直到下一个 trigger 的 condition/action/modifier 属于同一条执行链
##   任何条件不通过，整条链中断

var blocks: Array[CommandBlock] = []
var active := true
var name := "管线"

## 内部运行状态（每帧重置）
var _pending := false          # 当前是否有激活的执行链
var _chain_start := -1         # 当前执行链的起始下标

## 运行可视化：每个指令块最近一次被"点亮"的时间（-1 表示从未）
## 供渲染层画节点高亮，让玩家看见"我的管线在跑"
var block_flash: Array[float] = []
const FLASH_LIFE := 0.45


func _init(p_name: String = "管线") -> void:
	name = p_name


## 让某个指令块闪一下
func _flash(idx: int) -> void:
	if idx < 0 or idx >= block_flash.size():
		return
	block_flash[idx] = 0.0


## 每帧推进闪光衰减
func tick_visual(delta: float) -> void:
	for i in range(block_flash.size()):
		if block_flash[i] >= 0.0:
			block_flash[i] += delta
			if block_flash[i] >= FLASH_LIFE:
				block_flash[i] = -1.0


## 增删块时同步 flash 数组
func sync_flash() -> void:
	while block_flash.size() < blocks.size():
		block_flash.append(-1.0)
	while block_flash.size() > blocks.size():
		block_flash.pop_back()


## 归一化闪光强度 0..1（1 = 刚点亮）
func flash_strength(idx: int) -> float:
	if idx < 0 or idx >= block_flash.size():
		return 0.0
	var t: float = block_flash[idx]
	if t < 0.0:
		return 0.0
	return clampf(1.0 - t / FLASH_LIFE, 0.0, 1.0)


## 执行管线，返回本帧产生的效果事件
## 每个事件：Dictionary {type, pos, value, ...}
func execute(sim, delta: float) -> Array:
	if not active or blocks.size() == 0:
		return []
	sync_flash()

	var events: Array = []
	var i := 0
	while i < blocks.size():
		var block := blocks[i]

		if block.kind == CommandBlock.KIND_TRIGGER:
			if _check_trigger(block, sim, delta):
				_flash(i)                    # 触发器点亮
				# 触发新链：后续非 trigger 块属于同一条链
				_pending = true
				_chain_start = i
				i += 1
				# 处理链内的 condition/action/modifier
				while i < blocks.size() and blocks[i].kind != CommandBlock.KIND_TRIGGER:
					var next := blocks[i]
					if next.kind == CommandBlock.KIND_CONDITION:
						if not _check_condition(next, sim):
							_pending = false
							break  # 链中断，跳到下一个 trigger
						_flash(i)                # 条件通过，点亮
					elif next.kind == CommandBlock.KIND_ACTION:
						if _pending:
							var action_events := _execute_action(next, sim)
							if action_events.size() > 0:
								_flash(i)        # 动作点亮
								events.append_array(action_events)
								# 应用该动作后紧跟的 modifier
								i += 1
								while i < blocks.size() and blocks[i].kind == CommandBlock.KIND_MODIFIER:
									var mod := blocks[i]
									_apply_modifier(mod, events[-1])
									_flash(i)    # 修饰符点亮
									i += 1
								continue
					elif next.kind == CommandBlock.KIND_MODIFIER:
						# 独立 modifier（无前置动作），跳过
						pass
					i += 1
				continue
		i += 1

	return events


## 切换管线激活状态
func set_active(active_flag: bool) -> void:
	active = active_flag
	_pending = false


# =========================================================
#  私有：触发器判定
# =========================================================
func _check_trigger(block: CommandBlock, sim, delta: float) -> bool:
	var id := block.id
	match id:
		"trigger_nearest":
			return sim.enemy_pos.size() > 0
		"trigger_lowest_hp":
			return sim.enemy_pos.size() > 0
		"trigger_on_hit":
			return sim.get_last_hit() if sim.has_method("get_last_hit") else false
		"trigger_timer":
			var interval: float = float(block.get_param("interval", 1.0))
			var now: float = float(sim.get_elapsed()) if sim.has_method("get_elapsed") else 0.0
			var key := "timer_" + block.id
			var last: float = float(sim.get_persist(key, 0.0)) if sim.has_method("get_persist") else 0.0
			if now - last >= interval:
				if sim.has_method("set_persist"):
					sim.set_persist(key, now)
				return true
			return false
		_:
			return false


func _check_condition(block: CommandBlock, sim) -> bool:
	var id := block.id
	match id:
		"cond_hp_gt_50":
			return sim.player_hp / sim.player_max_hp > block.get_param("threshold", 0.5)
		"cond_dist_lt_300":
			if sim.enemy_pos.size() == 0:
				return false
			var nearest: float = float(sim.get_nearest_enemy_dist()) if sim.has_method("get_nearest_enemy_dist") else 9999.0
			return nearest < block.get_param("max_dist", 300.0)
		"cond_has_buff":
			var buff_id: String = block.get_param("buff_id", "")
			return sim.has_buff(buff_id) if sim.has_method("has_buff") else false
		"cond_random":
			var rng := RandomNumberGenerator.new()
			return rng.randf() < block.get_param("chance", 0.5)
		_:
			return true


# =========================================================
#  私有：动作执行
# =========================================================
func _execute_action(block: CommandBlock, sim) -> Array:
	var events: Array = []
	var id := block.id
	match id:
		"action_aoe":
			var dmg: float = float(block.get_param("damage", 18.0))
			var radius: float = float(block.get_param("radius", 108.0))
			events.append({
				"type": "aoe",
				"pos": sim.player_pos,
				"radius": radius,
				"damage": dmg,
				"source": block.id,
			})
		"action_projectile":
			var dmg: float = float(block.get_param("damage", 25.0))
			var speed: float = float(block.get_param("speed", 400.0))
			var pierce: int = int(block.get_param("pierce", 1))
			events.append({
				"type": "projectile",
				"pos": sim.player_pos,
				"damage": dmg,
				"speed": speed,
				"pierce": pierce,
				"source": block.id,
			})
		"action_summon_field":
			var dmg: float = float(block.get_param("damage", 10.0))
			var duration: float = float(block.get_param("duration", 3.0))
			var radius: float = float(block.get_param("radius", 80.0))
			events.append({
				"type": "field",
				"pos": sim.player_pos,
				"damage": dmg,
				"duration": duration,
				"radius": radius,
				"source": block.id,
			})
		"action_apply_status":
			var status_id: String = block.get_param("status_id", "slow")
			var duration: float = float(block.get_param("duration", 2.0))
			events.append({
				"type": "status",
				"status_id": status_id,
				"duration": duration,
				"source": block.id,
			})
		"action_modify_attr":
			var attr: String = block.get_param("attr", "move_speed")
			var value: float = float(block.get_param("value", 1.0))
			events.append({
				"type": "attr",
				"attr": attr,
				"value": value,
				"source": block.id,
			})
		_:
			pass
	return events


func _apply_modifier(block: CommandBlock, event: Dictionary) -> void:
	if event == null:
		return
	var id := block.id
	match id:
		"mod_penetrate":
			event["pierce"] = int(event.get("pierce", 0)) + int(block.get_param("extra_pierce", 2))
		"mod_split":
			event["split_count"] = int(block.get_param("split_count", 1))
			event["split_angle"] = block.get_param("split_angle", 30.0)
		"mod_chain":
			event["chain_count"] = int(block.get_param("chain_count", 2))
			event["chain_range"] = block.get_param("chain_range", 150.0)
		"mod_dot":
			event["dot_damage"] = block.get_param("dot_damage", 5.0)
			event["dot_ticks"] = int(block.get_param("dot_ticks", 3))
		"mod_range":
			if event.has("radius"):
				event["radius"] = float(event["radius"]) * block.get_param("range_mult", 1.30)
		"mod_cooldown":
			event["cd_mult"] = block.get_param("cd_mult", 0.86)
		_:
			pass


# =========================================================
#  只读快照（调试/渲染用）
# =========================================================
func summary() -> String:
	var n := blocks.size()
	var kinds := {}
	for b in blocks:
		kinds[b.kind] = int(kinds.get(b.kind, 0)) + 1
	return "Pipeline[%s] blocks=%d active=%s" % [name, n, str(active)]
