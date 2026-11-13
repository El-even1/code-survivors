class_name I18n
extends RefCounted

## 轻量多语言表：目前覆盖开始页 / 选人界面（中 / 英）
## 语言状态存在 GameStateData.language，按钮或 L 键切换

const LANGS: Array[String] = ["zh", "en"]

const UI := {
	"zh": {
		"subtitle": "色块原型 · 阶段二 · 选择你的角色",
		"start": "开 始 游 戏",
		"hint": "A / D 或 ← / → 切换角色　　 Enter 开始游戏　　 也可以直接点击卡片",
		"stat_hp": "生命",
		"stat_speed": "移速",
		"stat_cd": "攻击间隔",
		"passive": "被动",
		"lang_switch": "English",
	},
	"en": {
		"subtitle": "Color-block prototype · Stage II · Choose your character",
		"start": "S T A R T",
		"hint": "A / D or ← / → to switch　　Enter to start　　or click a card",
		"stat_hp": "HP",
		"stat_speed": "Speed",
		"stat_cd": "Interval",
		"passive": "Passive",
		"lang_switch": "中文",
	},
}

const CHARS := {
	"zh": {
		"mage":    {"name": "法师", "weapon": "法杖", "tag": "远程 · 追踪弹", "passive": "法力回复：攻速 +10%"},
		"warrior": {"name": "战士", "weapon": "刀刃", "tag": "近战 · 高血量", "passive": "近战抗性：接触伤害 -30%"},
		"hunter":  {"name": "猎人", "weapon": "弓",   "tag": "远程 · 双发",   "passive": "移动速度 +15%"},
		"priest":  {"name": "牧师", "weapon": "法书", "tag": "范围 · 吸血",   "passive": "吸血：击杀回复 2% 最大生命"},
	},
	"en": {
		"mage":    {"name": "Mage",    "weapon": "Staff", "tag": "Ranged · Homing",    "passive": "Mana Regen: +10% attack speed"},
		"warrior": {"name": "Warrior", "weapon": "Blade", "tag": "Melee · Tanky",      "passive": "Melee Resist: -30% contact damage"},
		"hunter":  {"name": "Hunter",  "weapon": "Bow",   "tag": "Ranged · Twin Shot", "passive": "Move +15%"},
		"priest":  {"name": "Priest",  "weapon": "Tome",  "tag": "AoE · Lifesteal",    "passive": "Lifesteal: +2% max HP on kill"},
	},
}


## 当前语言的 UI 文案
static func ui(key: String) -> String:
	var lang := _lang()
	var table: Dictionary = UI.get(lang, UI["zh"])
	return String(table.get(key, key))


## 当前语言的角色文案：name / weapon / tag / passive
static func char_info(cid: String, key: String) -> String:
	var lang := _lang()
	var table: Dictionary = CHARS.get(lang, CHARS["zh"])
	var entry: Dictionary = table.get(cid, {})
	return String(entry.get(key, ""))


static func _lang() -> String:
	var lang := GameStateData.language
	if lang != "zh" and lang != "en":
		return "zh"
	return lang


## 切换到另一种语言，返回切换后的语言
static func toggle() -> String:
	GameStateData.language = "en" if _lang() == "zh" else "zh"
	return GameStateData.language
