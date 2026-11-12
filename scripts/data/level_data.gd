class_name LevelData
extends RefCounted

## Stage 2 Vertical Slice · Level Data
## Sector definitions, boss definitions, level config

## Sector data: enemy spawn config, duration
const SECTOR_DATA := {
	"sector_a": {
		"name": "Data Flood",
		"enemy_batch": 4,
		"spawn_interval": 0.15,
		"ramp_seconds": 110.0,
		"duration_sec": 180.0,
		"description": "High-frequency small enemies, tests AoE pipeline"
	},
	"sector_b": {
		"name": "Firewall Fortress",
		"enemy_batch": 2,
		"spawn_interval": 0.25,
		"ramp_seconds": 90.0,
		"duration_sec": 180.0,
		"description": "Elite enemies, fewer but tanky, tests burst/pierce pipeline"
	},
	"safe_zone": {
		"name": "Safe Zone",
		"enemy_batch": 0,
		"spawn_interval": 9999.0,
		"ramp_seconds": 0.0,
		"duration_sec": 0.0,
		"description": "Safe zone for pipeline editing between sectors"
	}
}

## Boss data: HP, phases, immunity types
const BOSS_DATA := {
	"boss_1": {
		"name": "Data Core",
		"max_hp": 5000.0,
		"phases": 3,
		"immunity": [],
		"description": "Multi-phase boss, needs pipeline switching"
	},
	"boss_2": {
		"name": "Protocol Guardian",
		"max_hp": 8000.0,
		"phases": 3,
		"immunity": ["trigger_timer"],  # Immune to timer trigger in phase 2
		"description": "Boss 2: immune to specific trigger types in phase 2"
	}
}

## Level config
const LEVEL_CONFIG := {
	"total_sectors": 2,
	"total_bosses": 2,
	"victory_condition": "defeat_all_bosses"
}


## Get sector data by sector id
static func get_sector(sector_id: String) -> Dictionary:
	var data: Dictionary = SECTOR_DATA.get(sector_id)
	if data == null:
		push_error("LevelData: unknown sector %s" % sector_id)
		return {}
	return data.duplicate()


## Get boss data by boss id
static func get_boss(boss_id: String) -> Dictionary:
	var data: Dictionary = BOSS_DATA.get(boss_id)
	if data == null:
		push_error("LevelData: unknown boss %s" % boss_id)
		return {}
	return data.duplicate()


## Get level config
static func get_level_config() -> Dictionary:
	return LEVEL_CONFIG.duplicate()
