extends CanvasLayer

## 阶段①色块原型 · 管线编辑器（节点图视图）
## 仅在暂停/安全区使用，战斗中隐藏
## 把管线画成"触发 → 条件 → 动作 → 修饰"的节点图流

var sim
var editing_slot := 0
var editor_shown := false

var panel: ColorRect
var title: Label
var slot_buttons: Array = []
var graph_container: VBoxContainer   # 节点图容器
var node_buttons: Array = []        # 每个节点对应的 Button
var delete_btns: Array = []         # 每个节点删除按钮
var palette_scroll: ScrollContainer
var palette_grid: GridContainer
var hint_label: Label
var close_btn: Button

# 布局常量
const NODE_W := 260.0
const NODE_H := 56.0
const FS_TITLE := 24
const FS_LABEL := 14
const FS_NODE := 15
const FS_BTN := 15

const COL_TRIGGER := Color(0.55, 0.85, 1.0)
const COL_COND := Color(0.75, 0.75, 0.85)
const COL_ACTION := Color(1.0, 0.62, 0.35)
const COL_MOD := Color(0.72, 0.55, 1.0)


func init(sim_ref) -> void:
	sim = sim_ref


func _ready() -> void:
	_build()
	hide_editor()


func _build() -> void:
	panel = ColorRect.new()
	panel.color = Color(0.05, 0.07, 0.12, 0.97)
	panel.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	title = Label.new()
	title.position = Vector2(48, 28)
	title.add_theme_font_size_override("font_size", FS_TITLE)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(title)

	# 槽位按钮
	var slot_row := HBoxContainer.new()
	slot_row.position = Vector2(48, 74)
	slot_row.add_theme_constant_override("separation", 10)
	panel.add_child(slot_row)
	for i in range(3):
		var btn := Button.new()
		btn.text = "槽位 %d" % (i + 1)
		btn.custom_minimum_size = Vector2(110, 38)
		btn.add_theme_font_size_override("font_size", FS_BTN)
		btn.pressed.connect(_on_select_slot.bind(i))
		slot_row.add_child(btn)
		slot_buttons.append(btn)

	# 节点图标题
	var graph_title := Label.new()
	graph_title.position = Vector2(48, 124)
	graph_title.text = "当前管线（按顺序执行，左→右）"
	graph_title.add_theme_font_size_override("font_size", FS_LABEL)
	graph_title.add_theme_color_override("font_color", Color(0.62, 0.72, 0.9))
	panel.add_child(graph_title)

	# 节点容器
	graph_container = VBoxContainer.new()
	graph_container.position = Vector2(48, 148)
	graph_container.size = Vector2(Tuning.VIEW_W - 96, 160)
	graph_container.add_theme_constant_override("separation", 8)
	panel.add_child(graph_container)

	# 提示
	hint_label = Label.new()
	hint_label.position = Vector2(48, 326)
	hint_label.text = "点击节点右上角的 × 删除；下方仓库可添加新指令块"
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.45, 0.52, 0.65))
	panel.add_child(hint_label)

	# 指令块仓库（下方）
	var pal_title := Label.new()
	pal_title.position = Vector2(48, 358)
	pal_title.text = "指令块仓库（点击添加到当前管线）"
	pal_title.add_theme_font_size_override("font_size", FS_LABEL)
	pal_title.add_theme_color_override("font_color", Color(0.62, 0.72, 0.9))
	panel.add_child(pal_title)

	palette_scroll = ScrollContainer.new()
	palette_scroll.position = Vector2(48, 388)
	palette_scroll.size = Vector2(Tuning.VIEW_W - 96, 220)
	panel.add_child(palette_scroll)

	palette_grid = GridContainer.new()
	palette_grid.columns = 4
	palette_grid.add_theme_constant_override("hseparation", 10)
	palette_grid.add_theme_constant_override("vseparation", 8)
	palette_scroll.add_child(palette_grid)

	# 关闭
	close_btn = Button.new()
	close_btn.text = "继续游戏 (Esc)"
	close_btn.position = Vector2(Tuning.VIEW_W - 210, Tuning.VIEW_H - 62)
	close_btn.custom_minimum_size = Vector2(180, 46)
	close_btn.add_theme_font_size_override("font_size", FS_BTN)
	close_btn.pressed.connect(_on_close)
	panel.add_child(close_btn)


func show_editor(slot: int) -> void:
	editing_slot = clampi(slot, 0, 2)
	editor_shown = true
	visible = true
	refresh()


func hide_editor() -> void:
	editor_shown = false
	visible = false


func _on_close() -> void:
	var main := get_parent()
	if main != null and main.has_method("resume_from_editor"):
		main.resume_from_editor()
	else:
		hide_editor()


func editor_visible() -> bool:
	return editor_shown


func refresh() -> void:
	if not editor_shown:
		return
	title.text = "管线编辑器 · 槽位 %d" % (editing_slot + 1)
	for i in range(slot_buttons.size()):
		var btn: Button = slot_buttons[i]
		btn.disabled = (i == editing_slot)
		var p = sim.get_pipeline(i)
		var cnt: int = p.blocks.size() if p != null else 0
		btn.text = "槽位 %d (%d)" % [i + 1, cnt]
	_redraw_graph()
	_rebuild_palette()


func _on_select_slot(slot: int) -> void:
	editing_slot = slot
	refresh()


# =========================================================
#  节点图：用实际 UI 节点（Button + Label）代替手动绘图
# =========================================================
func _redraw_graph() -> void:
	# 清空旧节点
	for c in graph_container.get_children():
		c.queue_free()
	node_buttons.clear()
	delete_btns.clear()

	var p = sim.get_pipeline(editing_slot)
	if p == null or p.blocks.size() == 0:
		var empty := Label.new()
		empty.text = "空管线 —— 从下方仓库点击指令块添加"
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
		graph_container.add_child(empty)
		return

	var stage_hint := Label.new()
	stage_hint.text = _stage_seq(p.blocks)
	stage_hint.add_theme_font_size_override("font_size", 12)
	stage_hint.add_theme_color_override("font_color", Color(0.5, 0.58, 0.72))
	graph_container.add_child(stage_hint)

	for i in range(p.blocks.size()):
		var block: CommandBlock = p.blocks[i]
		var base := _kind_color(block.kind)

		# 节点卡片（Button）
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, NODE_H)
		row.add_theme_constant_override("separation", 6)

		var name_lbl := Label.new()
		name_lbl.text = "%s" % [_desc(block.id)]
		name_lbl.add_theme_font_size_override("font_size", FS_NODE)
		name_lbl.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
		name_lbl.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_lbl)

		var kind_lbl := Label.new()
		kind_lbl.text = "[%s]" % [_kind_label(block.kind)]
		kind_lbl.add_theme_font_size_override("font_size", 12)
		kind_lbl.add_theme_color_override("font_color", base)
		row.add_child(kind_lbl)

		# 标签（共鸣）
		if block.tag != "":
			var tag_lbl := Label.new()
			tag_lbl.text = "[%s]" % block.tag
			tag_lbl.add_theme_font_size_override("font_size", 11)
			tag_lbl.add_theme_color_override("font_color", Color(0.55, 0.7, 0.55))
			row.add_child(tag_lbl)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size = Vector2(24, 24)
		del_btn.add_theme_font_size_override("font_size", 16)
		del_btn.pressed.connect(_on_delete_block.bind(i))
		row.add_child(del_btn)

		# 节点背景色
		var sb := StyleBoxFlat.new()
		sb.bg_color = base.darkened(0.75)
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_color = base
		sb.corner_radius_top_left = 6.0
		sb.corner_radius_top_right = 6.0
		sb.corner_radius_bottom_left = 6.0
		sb.corner_radius_bottom_right = 6.0
		row.add_theme_stylebox_override("normal", sb)

		graph_container.add_child(row)
		node_buttons.append(row)
		delete_btns.append(del_btn)

		# 箭头
		if i < p.blocks.size() - 1:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 18)
			arrow.add_theme_color_override("font_color", Color(0.42, 0.5, 0.64))
			graph_container.add_child(arrow)


func _stage_seq(blocks: Array) -> String:
	var parts := []
	for b in blocks:
		if b.kind == CommandBlock.KIND_TRIGGER:
			parts.append("触发")
		elif b.kind == CommandBlock.KIND_CONDITION:
			parts.append("条件")
		elif b.kind == CommandBlock.KIND_ACTION:
			parts.append("动作")
		elif b.kind == CommandBlock.KIND_MODIFIER:
			parts.append("修饰")
	return " → ".join(parts)


func _on_delete_block(idx: int) -> void:
	sim.remove_command(editing_slot, idx)
	refresh()


# =========================================================
#  指令块仓库
# =========================================================
func _rebuild_palette() -> void:
	for c in palette_grid.get_children():
		c.queue_free()

	var keys := CommandBlock.BLOCK_TEMPLATES.keys()
	keys.sort()

	var order := {
		CommandBlock.KIND_TRIGGER: 0,
		CommandBlock.KIND_CONDITION: 1,
		CommandBlock.KIND_ACTION: 2,
		CommandBlock.KIND_MODIFIER: 3,
	}
	keys.sort_custom(func(a, b):
		var ka: int = order.get(CommandBlock.BLOCK_TEMPLATES[a]["kind"], 9)
		var kb: int = order.get(CommandBlock.BLOCK_TEMPLATES[b]["kind"], 9)
		if ka != kb:
			return ka < kb
		return a < b)

	for key in keys:
		var tpl: Dictionary = CommandBlock.BLOCK_TEMPLATES[key]
		var kind: String = tpl["kind"]
		var base := _kind_color(kind)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(280, 52)
		btn.text = "%s\n[%s]" % [_desc(key), _kind_label(kind)]
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", base)
		btn.pressed.connect(_on_add_block.bind(key))
		palette_grid.add_child(btn)


func _on_add_block(block_id: String) -> void:
	var block := CommandBlock.from_template(block_id, 1, "白")
	sim.add_command(editing_slot, block)
	refresh()


# =========================================================
#  工具
# =========================================================
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
		return "触发"
	elif kind == CommandBlock.KIND_CONDITION:
		return "条件"
	elif kind == CommandBlock.KIND_ACTION:
		return "动作"
	elif kind == CommandBlock.KIND_MODIFIER:
		return "修饰"
	return "?"


func _desc(block_id: String) -> String:
	var tpl = CommandBlock.BLOCK_TEMPLATES.get(block_id)
	if tpl != null:
		return String(tpl.get("desc", block_id))
	return block_id
