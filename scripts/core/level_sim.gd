class_name LevelSim
extends RefCounted

## Stage 2 Vertical Slice · Level Flow Simulation
## Manages sector progression, boss progression, and victory/defeat conditions.

var sim

## Current state
var current_sector: String = ""
var current_boss: String = ""
var sector_timer: float = 0.0
var boss_hp: float = 0.0
var boss_max_hp: float = 0.0
var boss_phase: int = 1
var boss_immunity: Array = []

## State flags
var is_victory: bool = false
var is_defeat: bool = false
var is_paused: bool = false

## Sector order: sector_a -> safe_zone -> sector_b -> safe_zone -> boss_1 -> safe_zone -> boss_2 -> victory
var sector_order: Array = ["sector_a", "safe_zone", "sector_b", "safe_zone", "boss_1", "safe_zone", "boss_2", "victory"]
var sector_index: int = 0


func init(sim_ref: ProtoSim) -> void:
	sim = sim_ref


func start_sector(sector_id: String) -> void:
	# 注意：safe_zone 在流程里出现两次，不能用 find 反推下标，否则会倒退
	if sector_id != "safe_zone":
		var idx := sector_order.find(sector_id)
		if idx >= 0:
			sector_index = idx
	current_sector = sector_id
	current_boss = ""
	sector_timer = 0.0
	boss_hp = 0.0
	boss_max_hp = 0.0
	boss_phase = 1


func start_boss(boss_id: String) -> void:
	var idx := sector_order.find(boss_id)
	if idx >= 0:
		sector_index = idx
	current_sector = boss_id
	current_boss = boss_id
	var data: Dictionary = LevelData.get_boss(boss_id)
	boss_max_hp = float(data.get("max_hp", 1000.0))
	boss_hp = boss_max_hp
	boss_phase = 1


func next_sector() -> void:
	# 统一按下标推进：sector_a → safe_zone → sector_b → safe_zone → boss_1 → safe_zone → boss_2 → victory
	sector_index += 1
	if sector_index >= sector_order.size():
		is_victory = true
		return
	var next_id: String = sector_order[sector_index]
	if next_id == "victory":
		is_victory = true
		return
	if next_id.begins_with("boss_"):
		start_boss(next_id)
	else:
		start_sector(next_id)


func _update_sector(delta: float) -> void:
	if current_sector == "" or current_boss != "":
		return
	sector_timer += delta
	var sector_data: Dictionary = LevelData.get_sector(current_sector)
	if sector_data.is_empty():
		return
	var sector_dur: float = float(sector_data.get("duration_sec", 180.0))
	if sector_timer >= sector_dur:
		next_sector()


func _update_boss(delta: float) -> void:
	if current_boss == "":
		return
	if boss_hp <= 0:
		next_sector()


func step(delta: float) -> void:
	if is_paused or is_victory or is_defeat:
		return
	_update_sector(delta)
	_update_boss(delta)


func set_boss_hp(hp: float) -> void:
	boss_hp = hp
	if boss_hp <= 0:
		next_sector()


func set_boss_phase(phase: int) -> void:
	boss_phase = phase


func get_current_sector() -> String:
	return current_sector


func get_current_boss() -> String:
	return current_boss


func get_boss_hp() -> float:
	return boss_hp


func get_boss_max_hp() -> float:
	return boss_max_hp


func get_boss_phase() -> int:
	return boss_phase


func get_boss_immunity() -> Array:
	return boss_immunity.duplicate()
