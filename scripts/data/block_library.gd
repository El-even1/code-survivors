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

## 建造约束：每条管线槽的蓝量上限 / 背包存放区格子上限
const MANA_MAX := 60
const STORAGE_CAP := 6

## 每块占用的蓝量（主动块贵，修饰块便宜）
const MANA_COST := {
	"action_projectile": 25,
	"action_melee": 25,
	"action_field": 30,
	"action_aoe": 30,
	"mod_penetrate": 15,
	"mod_multi": 20,
	"mod_track": 15,
	"mod_range": 20,
	"mod_cooldown": 15,
	"mod_dot": 20,
}


static func mana_cost(block_id: String) -> int:
	return int(MANA_COST.get(block_id, 15))

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
