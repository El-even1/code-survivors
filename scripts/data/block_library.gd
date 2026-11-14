class_name BlockLibrary
extends RefCounted

## 指令块库：通用块 + 角色专属块
## 玩家不能自由挑选：击杀敌人有概率掉落本角色可用块，捡到后在背包里装备

## 通用块：任何角色都能用
const UNIVERSAL: Array[String] = ["mod_penetrate", "mod_cooldown"]

## 角色专属块（第一个是角色主动技能块，其余是特色修饰）
const CHAR_SPECIFIC := {
	"mage": ["action_aoe", "mod_track"],
	"warrior": ["action_melee", "mod_range"],
	"hunter": ["action_projectile", "mod_multi"],
	"priest": ["action_field", "mod_dot"],
}

## 每次击杀掉落指令块的概率
const DROP_CHANCE := 0.08

## 建造约束：背包存放区格子上限
const STORAGE_CAP := 6

## 每次施法耗蓝：主动块 + 各个修饰块叠加（块越多每次施法越贵）
const CAST_COST := {
	"action_projectile": 6,
	"action_melee": 6,
	"action_field": 8,
	"action_aoe": 8,
	"mod_penetrate": 2,
	"mod_multi": 4,
	"mod_track": 3,
	"mod_range": 3,
	"mod_cooldown": 2,
	"mod_dot": 3,
}


static func cast_cost(block_id: String) -> int:
	return int(CAST_COST.get(block_id, 3))

## 本角色可用的全部指令块（通用 + 专属）
static func for_char(cid: String) -> Array[String]:
	var out: Array[String] = []
	for id in UNIVERSAL:
		out.append(String(id))
	var specific: Array = CHAR_SPECIFIC.get(cid, [])
	for id in specific:
		var sid := String(id)
		if not out.has(sid):
			out.append(sid)
	return out


## 该角色能否使用这个块
static func is_allowed(cid: String, block_id: String) -> bool:
	return for_char(cid).has(block_id)


static func is_universal(block_id: String) -> bool:
	return UNIVERSAL.has(block_id)


static func is_char_specific(cid: String, block_id: String) -> bool:
	var specific: Array = CHAR_SPECIFIC.get(cid, [])
	return specific.has(block_id)


## 随机掉落一个本角色可用块
static func roll_drop(cid: String, rng: RandomNumberGenerator) -> String:
	var pool := for_char(cid)
	if pool.is_empty():
		return ""
	return pool[rng.randi_range(0, pool.size() - 1)]
