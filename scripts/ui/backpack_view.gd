extends CanvasLayer

## 背包（Backpack）：游戏内随时可打开，集中做「管线编辑 + 升级查看」
## 打开时画面冻结；proto_view 通过 B 键 / 背包按钮开关
## 用 sim.get_pipeline / add_command / remove_command 改管线，改完立刻刷新「当前攻击数值」让效果可见

var sim

var editing_slot := 0
var _open := false

var panel: ColorRect
var title: Label
var pipeline_title: Label
var slot_row: HBoxContainer
var slot_buttons: Array = []
var stats_label: Label
var block_list: VBoxContainer
var add_btn: Button
var up_title: Label
var up_list: VBoxContainer
var close_btn: Button

var template_popup: ColorRect
var popup_title: Label
var template_scroll: ScrollContainer
var template_grid: GridContainer
var popup_close: Button


func init(sim_ref) -> void:
	sim = sim_ref


func _ready() -> void:
	_build()
	close()


## ---------- 开关 ----------
func is_open() -> bool:
	return _open


func open() -> void:
	_open = true
	_set_main_visible(true)
	refresh()


func close() -> void:
	_open = false
	_set_main_visible(false)
	if template_popup != null:
		template_popup.visible = false


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func _set_main_visible(v: bool) -> void:
	panel.visible = v
	title.visible = v
	pipeline_title.visible = v
	slot_row.visible = v
	stats_label.visible = v
	block_list.visible = v
	add_btn.visible = v
	up_title.visible = v
	up_list.visible = v
	close_btn.visible = v


## ---------- 构建 ----------
func _build() -> void:
	panel = ColorRect.new()
	panel.color = Color(0.045, 0.06, 0.09, 0.985)
	panel.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	add_child(panel)

	title = Label.new()
	title.position = Vector2(40, 22)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(title)

	# ---- 左栏：管线 ----
	pipeline_title = Label.new()
	pipeline_title.position = Vector2(40, 84)
	pipeline_title.add_theme_font_size_override("font_size", 20)
	pipeline_title.add_theme_color_override("font_color", Color(0.72, 0.83, 1.0))
	add_child(pipeline_title)

	slot_row = HBoxContainer.new()
	slot_row.position = Vector2(40, 116)
	slot_row.size = Vector2(400, 40)
	slot_row.add_theme_constant_override("separation", 10)
	add_child(slot_row)
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_select_slot.bind(i))
		slot_row.add_child(b)
		slot_buttons.append(b)

	stats_label = Label.new()
	stats_label.position = Vector2(40, 168)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.55))
	add_child(stats_label)

	block_list = VBoxContainer.new()
	block_list.position = Vector2(40, 200)
	block_list.size = Vector2(580, 380)
	block_list.add_theme_constant_override("separation", 8)
	add_child(block_list)

	add_btn = Button.new()
	add_btn.position = Vector2(40, 592)
	add_btn.size = Vector2(210, 44)
	add_btn.add_theme_font_size_override("font_size", 17)
	add_btn.pressed.connect(_open_templates)
	add_child(add_btn)

	# ---- 右栏：升级 ----
	up_title = Label.new()
	up_title.position = Vector2(680, 84)
	up_title.add_theme_font_size_override("font_size", 20)
	up_title.add_theme_color_override("font_color", Color(0.72, 0.83, 1.0))
	add_child(up_title)

	up_list = VBoxContainer.new()
	up_list.position = Vector2(680, 116)
	up_list.size = Vector2(560, 480)
	up_list.add_theme_constant_override("separation", 8)
	add_child(up_list)

	close_btn = Button.new()
	close_btn.position = Vector2(Tuning.VIEW_W - 240, Tuning.VIEW_H - 70)
	close_btn.size = Vector2(200, 50)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(close)
	add_child(close_btn)

	_build_template_popup()


func _build_template_popup() -> void:
	template_popup = ColorRect.new()
	template_popup.color = Color(0, 0, 0, 0.75)
	template_popup.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	template_popup.visible = false
	add_child(template_popup)

	popup_title = Label.new()
	popup_title.position = Vector2(Tuning.VIEW_W * 0.5 - 220.0, 96)
	popup_title.add_theme_font_size_override("font_size", 28)
	popup_title.add_theme_color_override("font_color", Color(1, 1, 1))
	template_popup.add_child(popup_title)

	template_scroll = ScrollContainer.new()
	template_scroll.position = Vector2(Tuning.VIEW_W * 0.5 - 300.0, 150)
	template_scroll.size = Vector2(600, 430)
	template_popup.add_child(template_scroll)

	template_grid = GridContainer.new()
	template_grid.columns = 1
	template_grid.add_theme_constant_override("hseparation", 8)
	template_grid.add_theme_constant_override("vseparation", 8)
	template_scroll.add_child(template_grid)

	popup_close = Button.new()
	popup_close.position = Vector2(Tuning.VIEW_W * 0.5 - 100.0, Tuning.VIEW_H - 90)
	popup_close.size = Vector2(200, 50)
	popup_close.add_theme_font_size_override("font_size", 18)
	popup_close.pressed.connect(_close_templates)
	template_popup.add_child(popup_close)


## ---------- 刷新 ----------
func refresh() -> void:
	if not _open:
		return
	title.text = I18n.ui("backpack_title")
	pipeline_title.text = I18n.ui("backpack_pipeline")
	up_title.text = I18n.ui("backpack_upgrades")
	add_btn.text = I18n.ui("editor_add")
	close_btn.text = I18n.ui("backpack_close")
	popup_title.text = I18n.ui("editor_popup_title")
	popup_close.text = I18n.ui("editor_popup_close")
	for i in range(slot_buttons.size()):
		var b: Button = slot_buttons[i]
		b.text = I18n.ui("hud_slot") % (i + 1)
		b.disabled = (i == editing_slot)
	_refresh_stats()
	_refresh_blocks()
	_refresh_upgrades()


## 当前攻击数值：让玩家直接看到管线改动带来的变化
func _refresh_stats() -> void:
	stats_label.text = I18n.ui("backpack_stats") % [
		int(sim.attack_damage),
		int(sim.attack_radius),
		sim.attack_cooldown,
		sim.attack_pierce,
	]


func _refresh_blocks() -> void:
	for child in block_list.get_children():
		child.queue_free()

	var pipeline: Array = sim.get_pipeline(editing_slot)
	if pipeline == null:
		return
	if pipeline.is_empty():
		var empty := Label.new()
		empty.text = I18n.ui("editor_empty")
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.55, 0.62, 0.75))
		block_list.add_child(empty)
		return

	for i in range(pipeline.size()):
		var block: CommandBlock = pipeline[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)

		var name_lbl := Label.new()
		name_lbl.text = "%s (Lv%d)" % [I18n.block_name(block.id), block.level]
		name_lbl.custom_minimum_size = Vector2(260, 36)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		row.add_child(name_lbl)

		var kind_lbl := Label.new()
		kind_lbl.text = I18n.kind_label(block.kind)
		kind_lbl.custom_minimum_size = Vector2(110, 36)
		kind_lbl.add_theme_font_size_override("font_size", 16)
		kind_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		row.add_child(kind_lbl)

		var tag_lbl := Label.new()
		tag_lbl.text = I18n.tag_label(block.tag)
		tag_lbl.custom_minimum_size = Vector2(80, 36)
		tag_lbl.add_theme_font_size_override("font_size", 15)
		tag_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
		row.add_child(tag_lbl)

		# 这块是干什么的：直接写在行尾，避免玩家看不懂管线作用
		var desc_lbl := Label.new()
		desc_lbl.text = I18n.block_desc(block.id)
		desc_lbl.custom_minimum_size = Vector2(230, 36)
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", Color(0.6, 0.66, 0.78))
		row.add_child(desc_lbl)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.custom_minimum_size = Vector2(44, 36)
		del_btn.add_theme_font_size_override("font_size", 18)
		del_btn.pressed.connect(_on_remove_block.bind(i))
		row.add_child(del_btn)

		block_list.add_child(row)

		# 指令链之间画一个向下箭头，读成「依次生效」
		if i < pipeline.size() - 1:
			var arrow := Label.new()
			arrow.text = "↓"
			arrow.add_theme_font_size_override("font_size", 16)
			arrow.add_theme_color_override("font_color", Color(0.45, 0.52, 0.65))
			block_list.add_child(arrow)


func _refresh_upgrades() -> void:
	for child in up_list.get_children():
		child.queue_free()

	if sim.owned.is_empty():
		var empty := Label.new()
		empty.text = I18n.ui("backpack_no_upgrades")
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(0.55, 0.62, 0.75))
		up_list.add_child(empty)
		return

	for uid in sim.owned.keys():
		var info: Dictionary = ProtoLogic.Tuning_UPGRADES.get(uid, {})
		if info.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)

		var name_lbl := Label.new()
		name_lbl.text = I18n.upgrade_name(String(uid))
		name_lbl.custom_minimum_size = Vector2(240, 34)
		name_lbl.add_theme_font_size_override("font_size", 17)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		row.add_child(name_lbl)

		var lv_lbl := Label.new()
		lv_lbl.text = "Lv %d / %d" % [int(sim.owned[uid]), int(info.get("max_level", 1))]
		lv_lbl.add_theme_font_size_override("font_size", 16)
		lv_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.45))
		row.add_child(lv_lbl)

		up_list.add_child(row)


## ---------- 操作 ----------
func _on_select_slot(slot: int) -> void:
	editing_slot = slot
	refresh()


func _on_remove_block(idx: int) -> void:
	sim.remove_command(editing_slot, idx)
	refresh()


## 加指令块（公开给模板弹窗与测试用）
func add_block(block_id: String) -> void:
	var block := CommandBlock.from_template(block_id, 1, "white")
	sim.add_command(editing_slot, block)
	refresh()


func _open_templates() -> void:
	for child in template_grid.get_children():
		child.queue_free()

	var templates: Dictionary = CommandBlock.BLOCK_TEMPLATES
	var keys: Array = templates.keys()
	keys.sort()

	for key in keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = I18n.block_name(String(key))
		name_lbl.custom_minimum_size = Vector2(360, 38)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		row.add_child(name_lbl)

		var add_tpl := Button.new()
		add_tpl.text = I18n.ui("editor_add_btn")
		add_tpl.custom_minimum_size = Vector2(110, 38)
		add_tpl.add_theme_font_size_override("font_size", 15)
		add_tpl.pressed.connect(_on_add_template.bind(String(key)))
		row.add_child(add_tpl)

		template_grid.add_child(row)

	template_popup.visible = true


func _on_add_template(block_id: String) -> void:
	add_block(block_id)
	_close_templates()


func _close_templates() -> void:
	template_popup.visible = false
