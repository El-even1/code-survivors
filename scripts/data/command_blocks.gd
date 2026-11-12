class_name CommandBlock
extends RefCounted

## Stage I Color Prototype · Command Block Definition (Simplified)
## Command Block = collectible item / modifier, quality white/green/blue/purple/gold, tag for resonance

## Command Block kinds (simplified: only action and modifier, removed trigger/condition)
const KIND_ACTION := "action"
const KIND_MODIFIER := "modifier"

## Resonance tags
const TAG_FIRE := "fire"
const TAG_ICE := "ice"
const TAG_ELEC := "elec"
const TAG_TOXIN := "toxin"
const TAG_PHYS := "phys"
const TAG_LIGHT := "light"
const TAG_DARK := "dark"

var id: String          # unique id, e.g. "action_projectile"
var kind: String        # action / modifier
var params: Dictionary = {}   # runtime params
var tag: String = ""    # resonance tag
var level: int = 1      # command block level
var quality: String = "white"    # white/green/blue/purple/gold


func _init(block_id: String, block_kind: String, block_params: Dictionary = {}, block_tag: String = "", block_level: int = 1, block_quality: String = "white"):
	id = block_id
	kind = block_kind
	params = block_params.duplicate()
	tag = block_tag
	level = block_level
	quality = block_quality


func get_param(key: String, default) -> Variant:
	return params.get(key, default)


func set_param(key: String, value: Variant) -> void:
	params[key] = value


## Command block template library (designers edit values/new blocks here only)
## Returns Dictionary<block_id, {kind, params, tag, quality}>
const BLOCK_TEMPLATES := {
	# ============ Actions (core attack, determined by character weapon) ============
	"action_projectile": {
		"kind": KIND_ACTION,
		"params": {"damage": 25.0, "speed": 400.0, "pierce": 1, "range": 500.0},
		"tag": TAG_PHYS,
		"quality": "white",
		"desc": "Fire projectile",
	},
	"action_melee": {
		"kind": KIND_ACTION,
		"params": {"damage": 35.0, "radius": 60.0},
		"tag": TAG_PHYS,
		"quality": "white",
		"desc": "Melee range damage",
	},
	"action_field": {
		"kind": KIND_ACTION,
		"params": {"damage": 10.0, "duration": 3.0, "radius": 80.0},
		"tag": TAG_ELEC,
		"quality": "blue",
		"desc": "Summon field",
	},
	"action_aoe": {
		"kind": KIND_ACTION,
		"params": {"damage": 18.0, "radius": 108.0},
		"tag": TAG_FIRE,
		"quality": "white",
		"desc": "White circle AoE",
	},

	# ============ Modifiers (chained after action, enhance that attack) ============
	"mod_penetrate": {
		"kind": KIND_MODIFIER,
		"params": {"extra_pierce": 2},
		"tag": TAG_PHYS,
		"quality": "green",
		"desc": "Pierce",
	},
	"mod_multi": {
		"kind": KIND_MODIFIER,
		"params": {"extra_count": 1, "spread_angle": 15.0},
		"tag": TAG_FIRE,
		"quality": "blue",
		"desc": "Multi-shot",
	},
	"mod_track": {
		"kind": KIND_MODIFIER,
		"params": {},
		"tag": TAG_LIGHT,
		"quality": "blue",
		"desc": "Track",
	},
	"mod_range": {
		"kind": KIND_MODIFIER,
		"params": {"range_mult": 1.30},
		"tag": TAG_LIGHT,
		"quality": "green",
		"desc": "Range expand",
	},
	"mod_cooldown": {
		"kind": KIND_MODIFIER,
		"params": {"cd_mult": 0.86},
		"tag": TAG_DARK,
		"quality": "purple",
		"desc": "Attack speed",
	},
	"mod_dot": {
		"kind": KIND_MODIFIER,
		"params": {"dot_damage": 5.0, "dot_ticks": 3},
		"tag": TAG_TOXIN,
		"quality": "purple",
		"desc": "Damage over time",
	},
}


static func from_template(block_id: String, level: int = 1, quality: String = "white") -> CommandBlock:
	var tpl: Dictionary = BLOCK_TEMPLATES.get(block_id)
	if tpl == null:
		push_error("CommandBlock: unknown template %s" % block_id)
		return CommandBlock.new(block_id, KIND_ACTION, {}, "", 1, "white")
	var q := quality
	if q == "white":
		q = String(tpl.get("quality", "white"))
	var block := CommandBlock.new(
		block_id,
		tpl.get("kind", KIND_ACTION),
		tpl.get("params", {}).duplicate(),
		tpl.get("tag", ""),
		level,
		q
	)
	return block


static func resonates(a: CommandBlock, b: CommandBlock) -> bool:
	if a.tag == "" or b.tag == "":
		return false
	return a.tag == b.tag
