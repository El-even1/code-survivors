extends Control

## Stage I Color Prototype · Mini Pipeline HUD (real-time visualization in combat)
## Drawn on CanvasLayer, fixed at bottom-right, does not follow camera
## Let player "see my pipeline running" while fighting: nodes flash when executed

var sim: ProtoSim

const NODE_W := 90.0
const NODE_H := 32.0
const GAP := 18.0
const PAD := 14.0

## Colors per block kind
const COL_TRIGGER := Color(0.55, 0.85, 1.0)
const COL_COND := Color(0.75, 0.75, 0.85)
const COL_ACTION := Color(1.0, 0.62, 0.35)
const COL_MOD := Color(0.72, 0.55, 1.0)
const COL_FLASH := Color(1, 1, 1)

var _node_labels: Array = []      # per-node label
var _arrow_labels: Array = []     # per-node arrow label

func init(sim_ref: ProtoSim) -> void:
	sim = sim_ref


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	_rebuild()


func _rebuild() -> void:
	if sim == null:
		_clear_all()
		return

	var pipeline = sim.get_pipeline(sim.get_active_slot())
	if pipeline == null:
		_clear_all()
		return

	var blocks: Array = pipeline.blocks
	var n: int = blocks.size()

	## Ensure enough node labels
	while _node_labels.size() < n:
		var lbl := Label.new()
		lbl.custom_minimum_size = Vector2(NODE_W, NODE_H)
		lbl.add_theme_font_size_override("font_size", 13)
		add_child(lbl)
		_node_labels.append(lbl)

	while _node_labels.size() > n:
		var lbl = _node_labels.pop_back()
		lbl.queue_free()

	## Ensure enough arrow labels
	while _arrow_labels.size() < n - 1:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 14)
		add_child(lbl)
		_arrow_labels.append(lbl)

	while _arrow_labels.size() > n - 1:
		var lbl = _arrow_labels.pop_back()
		lbl.queue_free()

	## Layout: bottom-right anchored
	var total_w := n * NODE_W + (n - 1) * GAP
	var x0 := size.x - total_w - PAD
	var y0 := size.y - NODE_H - PAD

	for i in range(n):
		var block = blocks[i]
		var lbl: Label = _node_labels[i]
		lbl.position = Vector2(x0 + i * (NODE_W + GAP), y0)
		lbl.size = Vector2(NODE_W, NODE_H)
		lbl.text = "%s\n%s" % [_short_name(block.id), _kind_label(block.kind)]

		var base := _kind_color(block.kind)
		var f: float = pipeline.flash_strength(i)

		## Background color (flash makes it brighter)
		var bg := base.darkened(0.75)
		if f > 0.0:
			bg = bg.lerp(COL_FLASH, f)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))

		## Custom style box: Label has no gradient bg, use add_theme_stylebox_override
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_color = base.lerp(COL_FLASH, f) if f > 0.0 else base
		sb.corner_radius_top_left = 4.0
		sb.corner_radius_top_right = 4.0
		sb.corner_radius_bottom_left = 4.0
		sb.corner_radius_bottom_right = 4.0
		lbl.add_theme_stylebox_override("normal", sb)

	## Arrows
	for i in range(n - 1):
		var lbl: Label = _arrow_labels[i]
		lbl.position = Vector2(x0 + i * (NODE_W + GAP) + NODE_W + 4, y0 + NODE_H * 0.5 - 8)
		lbl.text = "→"
		lbl.add_theme_color_override("font_color", Color(0.45, 0.52, 0.65))

	if n == 0:
		pass


func _clear_all() -> void:
	for lbl in _node_labels:
		lbl.queue_free()
	_node_labels.clear()
	for lbl in _arrow_labels:
		lbl.queue_free()
	_arrow_labels.clear()


func _kind_color(kind: String) -> Color:
	if kind == CommandBlock.KIND_TRIGGER:
		return COL_TRIGGER
	elif kind == CommandBlock.KIND_CONDITION:
		return COL_COND
	elif kind == CommandBlock.KIND_ACTION:
		return COL_ACTION
	elif kind == CommandBlock.KIND_MODIFIER:
		return COL_MOD
	return Color(0.7, 0.7, 0.7)


func _kind_label(kind: String) -> String:
	if kind == CommandBlock.KIND_TRIGGER:
		return "Trigger"
	elif kind == CommandBlock.KIND_CONDITION:
		return "Condition"
	elif kind == CommandBlock.KIND_ACTION:
		return "Action"
	elif kind == CommandBlock.KIND_MODIFIER:
		return "Modifier"
	return "?"


## "action_aoe" → "White Circle AoE", look up template desc
func _short_name(block_id: String) -> String:
	var tpl = CommandBlock.BLOCK_TEMPLATES.get(block_id)
	if tpl != null:
		return String(tpl.get("desc", block_id))
	return block_id
