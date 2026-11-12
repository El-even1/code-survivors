class_name LevelSim
extends RefCounted

## Stage 2 Vertical Slice · Level Flow Simulation
## Sector progression, boss progression, victory/defeat conditions

var sim: ProtoSim

## Current state
var current_sector: String = ""
var current_boss: String = ""
var sector_timer: float = 0.0

## State flags
var is_victory: bool = false
var is_defeat: bool = false
var is_paused: bool = false

## Sector order
var sector_order: Array = ["sector_a", "safe_zone", "sector_b", "safe_zone", "boss_1", "safe_zone", "boss_2", "victory"]
var sector_index: int = 0


func init(sim_ref: ProtoSim) -> void:
	sim = sim_ref


## Start current sector
func start_sector(sector_id: String) -> void:
	current_sector = sector_id
	sector_timer = 0.0
	current_boss = ""


## Start boss fight
func start_boss(boss_id: String) -> void:
	current_boss = boss_id
	sim.start_boss(boss_id)


## Advance to next sector/boss
func next_sector() -> void:
	sector_index += 1
	if sector_index >= sector_order.size():
		is_victory = true
		return

	var next_id := sector_order[sector_index]
	if next_id == "victory":
		is_victory = true
		return
	if next_id.begins_with("boss_"):
		start_boss(next_id)
	else:
		start_sector(next_id)


func step(delta: float) -> void:
	if is_paused or is_victory or is_defeat:
		return

	if current_sector != "" and current_boss == "":
		sector_timer += delta
		var sector_data := LevelData.get_sector(current_sector)
		var sector_dur := float(sector_data.get("duration_sec", 180.0))
		if sector_timer >= sector_dur:
			next_sector()

	if current_boss != "":
		if sim.boss_hp <= 0:
			next_sector()


## =========================================================
#  Read-only
# =========================================================
func get_current_sector() -> String:
	return current_sector


func get_current_boss() -> String:
	return current_boss


func get_boss_hp() -> float:
	return sim.boss_hp


func get_boss_max_hp() -> float:
	return sim.boss_max_hp


func get_boss_phase() -> int:
	return sim.boss_phase


func get_boss_immunity() -> Array:
	return sim.boss_immunity.duplicate()
