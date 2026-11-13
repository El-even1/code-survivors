class_name I18n
extends RefCounted

## 轻量多语言表：开始页 / 选人界面 / 战斗 HUD / 管线 UI（中 / 英）
## 语言状态存在 GameStateData.language，开始页按钮或 L 键切换

const LANGS: Array[String] = ["zh", "en"]

const UI := {
	"zh": {
		# 开始页 / 选人
		"subtitle": "色块原型 · 阶段二 · 选择你的角色",
		"start": "开 始 游 戏",
		"hint": "A / D 或 ← / → 切换角色　　 Enter 开始游戏　　 也可以直接点击卡片",
		"stat_hp": "生命",
		"stat_speed": "移速",
		"stat_cd": "攻击间隔",
		"passive": "被动",
		"lang_switch": "English",
		# 战斗 HUD
		"hud_move": "WASD / 方向键移动",
		"hud_slot": "槽位 %d",
		"hud_hp": "生命",
		"hud_lv": "等级",
		"hud_xp": "经验",
		"hud_kills": "击杀",
		"hud_onscreen": "同屏",
		"hud_phase": "阶段",
		"hud_pause": "|| 暂停",
		"hud_resume": "> 继续",
		"hud_paused": "[暂停]",
		"upgrade_title": "升级！选择一项",
		"result_killed": "阵亡　击杀 %d",
		"result_victory": "通关！击杀 %d",
		"result_restart": "按 R 重新选择角色",
		# 管线编辑器
		"editor_title": "管线编辑器 · 槽位 %d",
		"editor_current": "当前管线指令块",
		"editor_add": "+ 添加指令块",
		"editor_close": "关闭并返回",
		"editor_tip": "提示：战斗中只能切换槽位，管线需在暂停 / 安全区编辑",
		"editor_popup_title": "选择指令块模板",
		"editor_popup_close": "关闭",
		"editor_add_btn": "添加",
		"editor_empty": "（空管线，点下面按钮添加指令块）",
	},
	"en": {
		# Start / character select
		"subtitle": "Color-block prototype · Stage II · Choose your character",
		"start": "S T A R T",
		"hint": "A / D or ← / → to switch　　Enter to start　　or click a card",
		"stat_hp": "HP",
		"stat_speed": "Speed",
		"stat_cd": "Interval",
		"passive": "Passive",
		"lang_switch": "中文",
		# Battle HUD
		"hud_move": "WASD / Arrow keys to move",
		"hud_slot": "Slot %d",
		"hud_hp": "HP",
		"hud_lv": "Lv",
		"hud_xp": "XP",
		"hud_kills": "Kills",
		"hud_onscreen": "OnScreen",
		"hud_phase": "Phase",
		"hud_pause": "|| Pause",
		"hud_resume": "> Resume",
		"hud_paused": "[Paused]",
		"upgrade_title": "Upgrade! Choose one",
		"result_killed": "Killed  Kills %d",
		"result_victory": "VICTORY  Kills %d",
		"result_restart": "Press R to choose character",
		# Pipeline editor
		"editor_title": "Pipeline Editor · Slot %d",
		"editor_current": "Current pipeline command blocks",
		"editor_add": "+ Add command block",
		"editor_close": "Close & return",
		"editor_tip": "Tip: combat can only switch slots; edit pipeline in pause/safe zone",
		"editor_popup_title": "Select command block template",
		"editor_popup_close": "Close",
		"editor_add_btn": "Add",
		"editor_empty": "(Empty pipeline — add a block below)",
	},
}

const CHARS := {
	"zh": {
		"mage":    {"name": "法师", "weapon": "法杖", "tag": "远程 · 追踪弹", "passive": "法力回复：攻速 +10%"},
		"warrior": {"name": "战士", "weapon": "刀刃", "tag": "近战 · 范围横扫", "passive": "近战抗性：接触伤害 -30%"},
		"hunter":  {"name": "猎人", "weapon": "弓",   "tag": "远程 · 双发",   "passive": "移动速度 +15%"},
		"priest":  {"name": "牧师", "weapon": "法书", "tag": "范围 · 吸血",   "passive": "吸血：击杀回复 2% 最大生命"},
	},
	"en": {
		"mage":    {"name": "Mage",    "weapon": "Staff", "tag": "Ranged · Homing",    "passive": "Mana Regen: +10% attack speed"},
		"warrior": {"name": "Warrior", "weapon": "Blade", "tag": "Melee · Cleave",     "passive": "Melee Resist: -30% contact damage"},
		"hunter":  {"name": "Hunter",  "weapon": "Bow",   "tag": "Ranged · Twin Shot", "passive": "Move +15%"},
		"priest":  {"name": "Priest",  "weapon": "Tome",  "tag": "AoE · Lifesteal",    "passive": "Lifesteal: +2% max HP on kill"},
	},
}

## 指令块短名（管线 HUD / 编辑器显示）
const BLOCKS := {
	"zh": {
		"action_projectile": "投射物",
		"action_melee": "近战横扫",
		"action_field": "能量场",
		"action_aoe": "白圈 AoE",
		"mod_penetrate": "穿透",
		"mod_multi": "多重",
		"mod_track": "追踪",
		"mod_range": "范围",
		"mod_cooldown": "攻速",
		"mod_dot": "持续伤害",
	},
	"en": {
		"action_projectile": "Projectile",
		"action_melee": "Melee Cleave",
		"action_field": "Energy Field",
		"action_aoe": "White Circle AoE",
		"mod_penetrate": "Pierce",
		"mod_multi": "Multi-shot",
		"mod_track": "Homing",
		"mod_range": "Range",
		"mod_cooldown": "Attack Speed",
		"mod_dot": "Damage over Time",
	},
}

## 指令块类别
const KINDS := {
	"zh": {"action": "主动", "modifier": "修饰"},
	"en": {"action": "Action", "modifier": "Modifier"},
}

## 升级项名称
const UPGRADES := {
	"zh": {
		"damage": "伤害 +25%",
		"radius": "范围 +18%",
		"cooldown": "攻速 +14%",
		"move": "移速 +12%",
		"magnet": "磁吸 +30%",
		"vitality": "生命 +20%",
	},
	"en": {
		"damage": "Damage +25%",
		"radius": "Area +18%",
		"cooldown": "Attack Speed +14%",
		"move": "Move Speed +12%",
		"magnet": "Magnet +30%",
		"vitality": "Vitality +20%",
	},
}

## 战斗阶段名
const PHASES := {
	"zh": {"survive": "生存期", "grow": "成长期", "pressure": "压力期", "limit": "极限期"},
	"en": {"survive": "Survival", "grow": "Growth", "pressure": "Pressure", "limit": "Limit"},
}

## 指令块共鸣标签
const TAGS := {
	"zh": {
		"phys": "物理",
		"fire": "火",
		"ice": "冰",
		"elec": "电",
		"toxin": "毒",
		"light": "光",
		"dark": "暗",
	},
	"en": {
		"phys": "Physical",
		"fire": "Fire",
		"ice": "Ice",
		"elec": "Electric",
		"toxin": "Toxic",
		"light": "Light",
		"dark": "Dark",
	},
}


## ---------- 取词 ----------
static func ui(key: String) -> String:
	var table: Dictionary = UI.get(_lang(), UI["zh"])
	return String(table.get(key, key))


static func char_info(cid: String, key: String) -> String:
	var table: Dictionary = CHARS.get(_lang(), CHARS["zh"])
	var entry: Dictionary = table.get(cid, {})
	return String(entry.get(key, ""))


static func block_name(block_id: String) -> String:
	var table: Dictionary = BLOCKS.get(_lang(), BLOCKS["zh"])
	if table.has(block_id):
		return String(table[block_id])
	# 未知 id 兜底：模板英文描述，再兜底 id 本身
	var tpl = CommandBlock.BLOCK_TEMPLATES.get(block_id)
	if tpl != null:
		return String(tpl.get("desc", block_id))
	return block_id


static func kind_label(kind: String) -> String:
	var table: Dictionary = KINDS.get(_lang(), KINDS["zh"])
	return String(table.get(kind, kind))


static func upgrade_name(uid: String) -> String:
	var table: Dictionary = UPGRADES.get(_lang(), UPGRADES["zh"])
	return String(table.get(uid, uid))


static func tag_label(tag: String) -> String:
	if tag == "":
		return "—"
	var table: Dictionary = TAGS.get(_lang(), TAGS["zh"])
	return String(table.get(tag, tag))


## 按时间返回当前阶段名（本地化）
static func phase_name(elapsed: float) -> String:
	var key := "limit"
	if elapsed < Tuning.PHASE_SURVIVE_END:
		key = "survive"
	elif elapsed < Tuning.PHASE_GROW_END:
		key = "grow"
	elif elapsed < Tuning.PHASE_PRESSURE_END:
		key = "pressure"
	var table: Dictionary = PHASES.get(_lang(), PHASES["zh"])
	return String(table.get(key, key))


static func _lang() -> String:
	var lang := GameStateData.language
	if lang != "zh" and lang != "en":
		return "zh"
	return lang


## 切换到另一种语言，返回切换后的语言
static func toggle() -> String:
	GameStateData.language = "en" if _lang() == "zh" else "zh"
	return GameStateData.language
