class_name CommandBlock
extends RefCounted

## 阶段①色块原型 · 指令块定义
## 指令块 = 可收集的物品，品质白/绿/蓝/紫/金，带标签用于共鸣判定

## 指令块种类
const KIND_TRIGGER := "trigger"
const KIND_CONDITION := "condition"
const KIND_ACTION := "action"
const KIND_MODIFIER := "modifier"

## 共鸣标签（Magicraft 式简化版，纯奖励）
const TAG_FIRE := "火"
const TAG_ICE := "冰"
const TAG_ELEC := "电"
const TAG_TOXIN := "毒"
const TAG_PHYS := "物理"
const TAG_LIGHT := "光"
const TAG_DARK := "暗"

var id: String          # 唯一标识，如 "action_aoe"
var kind: String        # trigger / condition / action / modifier
var params: Dictionary = {}   # 运行参数
var tag: String = ""    # 共鸣标签，空表示无标签（不参与共鸣）
var level: int = 1      # 指令块等级，影响参数数值
var quality: String = "白"    # 白/绿/蓝/紫/金


## 构造一个指令块
func _init(block_id: String, block_kind: String, block_params: Dictionary = {}, block_tag: String = "", block_level: int = 1, block_quality: String = "白"):
	id = block_id
	kind = block_kind
	params = block_params.duplicate()
	tag = block_tag
	level = block_level
	quality = block_quality


## 获取参数，缺省返回默认值
func get_param(key: String, default) -> Variant:
	return params.get(key, default)


## 设置参数
func set_param(key: String, value: Variant) -> void:
	params[key] = value


## 指令块模板库（策划改数值/新增块只需改这里）
## 返回 Dictionary<block_id, {kind, params, tag, quality}>
const BLOCK_TEMPLATES := {
	# ============ 触发器 ============
	"trigger_nearest": {
		"kind": KIND_TRIGGER,
		"params": {"range": 9999.0},
		"tag": TAG_PHYS,
		"quality": "白",
		"desc": "最近敌人",
	},
	"trigger_lowest_hp": {
		"kind": KIND_TRIGGER,
		"params": {"range": 9999.0},
		"tag": TAG_PHYS,
		"quality": "绿",
		"desc": "血量最低敌人",
	},
	"trigger_on_hit": {
		"kind": KIND_TRIGGER,
		"params": {"cooldown": 0.5},
		"tag": TAG_PHYS,
		"quality": "蓝",
		"desc": "受到攻击",
	},
	"trigger_timer": {
		"kind": KIND_TRIGGER,
		"params": {"interval": 1.0},
		"tag": TAG_LIGHT,
		"quality": "白",
		"desc": "定时器",
	},

	# ============ 条件 ============
	"cond_hp_gt_50": {
		"kind": KIND_CONDITION,
		"params": {"threshold": 0.5},
		"tag": "",
		"quality": "白",
		"desc": "生命>50%",
	},
	"cond_dist_lt_300": {
		"kind": KIND_CONDITION,
		"params": {"max_dist": 300.0},
		"tag": "",
		"quality": "白",
		"desc": "距离<300",
	},
	"cond_has_buff": {
		"kind": KIND_CONDITION,
		"params": {"buff_id": ""},
		"tag": "",
		"quality": "绿",
		"desc": "携带Buff",
	},
	"cond_random": {
		"kind": KIND_CONDITION,
		"params": {"chance": 0.5},
		"tag": "",
		"quality": "蓝",
		"desc": "随机概率",
	},

	# ============ 动作 ============
	"action_aoe": {
		"kind": KIND_ACTION,
		"params": {"damage": 18.0, "radius": 108.0},
		"tag": TAG_FIRE,
		"quality": "白",
		"desc": "发射白圈 AoE",
	},
	"action_projectile": {
		"kind": KIND_ACTION,
		"params": {"damage": 25.0, "speed": 400.0, "pierce": 1},
		"tag": TAG_PHYS,
		"quality": "绿",
		"desc": "发射投射物",
	},
	"action_summon_field": {
		"kind": KIND_ACTION,
		"params": {"damage": 10.0, "duration": 3.0, "radius": 80.0},
		"tag": TAG_ELEC,
		"quality": "蓝",
		"desc": "召唤领域",
	},
	"action_apply_status": {
		"kind": KIND_ACTION,
		"params": {"status_id": "slow", "duration": 2.0},
		"tag": TAG_ICE,
		"quality": "紫",
		"desc": "施加状态",
	},
	"action_modify_attr": {
		"kind": KIND_ACTION,
		"params": {"attr": "move_speed", "value": 1.12},
		"tag": TAG_LIGHT,
		"quality": "紫",
		"desc": "修改属性",
	},

	# ============ 修饰符（挂载在动作后，增强该动作） ============
	"mod_penetrate": {
		"kind": KIND_MODIFIER,
		"params": {"extra_pierce": 2},
		"tag": TAG_PHYS,
		"quality": "绿",
		"desc": "穿透",
	},
	"mod_split": {
		"kind": KIND_MODIFIER,
		"params": {"split_count": 1, "split_angle": 30.0},
		"tag": TAG_FIRE,
		"quality": "蓝",
		"desc": "分裂",
	},
	"mod_chain": {
		"kind": KIND_MODIFIER,
		"params": {"chain_count": 2, "chain_range": 150.0},
		"tag": TAG_ELEC,
		"quality": "蓝",
		"desc": "链弹",
	},
	"mod_dot": {
		"kind": KIND_MODIFIER,
		"params": {"dot_damage": 5.0, "dot_ticks": 3},
		"tag": TAG_TOXIN,
		"quality": "紫",
		"desc": "持续伤害",
	},
	"mod_range": {
		"kind": KIND_MODIFIER,
		"params": {"range_mult": 1.30},
		"tag": TAG_LIGHT,
		"quality": "绿",
		"desc": "范围扩大",
	},
	"mod_cooldown": {
		"kind": KIND_MODIFIER,
		"params": {"cd_mult": 0.86},
		"tag": TAG_DARK,
		"quality": "紫",
		"desc": "冷却缩减",
	},
}


## 从模板创建指令块
static func from_template(block_id: String, level: int = 1, quality: String = "白") -> CommandBlock:
	var tpl: Dictionary = BLOCK_TEMPLATES.get(block_id)
	if tpl == null:
		push_error("CommandBlock: 未知模板 %s" % block_id)
		return CommandBlock.new(block_id, KIND_ACTION, {}, "", 1, "白")
	var q := quality
	if q == "白":
		q = String(tpl.get("quality", "白"))
	var block := CommandBlock.new(
		block_id,
		tpl.get("kind", KIND_ACTION),
		tpl.get("params", {}).duplicate(),
		tpl.get("tag", ""),
		level,
		q
	)
	return block


## 共鸣判定：两个指令块标签相同且非空，则产生共鸣
static func resonates(a: CommandBlock, b: CommandBlock) -> bool:
	if a.tag == "" or b.tag == "":
		return false
	return a.tag == b.tag
