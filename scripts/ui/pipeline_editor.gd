extends CanvasLayer

## Stage I Color Prototype · Pipeline Editor UI
## Only used in pause/safe zone, hidden in combat
## Draws pipeline as node graph flow: trigger -> condition -> action -> modifier

var sim
var editing_slot := 0
var editor_shown := false

var panel: ColorRect
var title: Label
var slot_row: HBoxContainer
var slot_buttons: Array = []
var list_title: Label
var block_list: VBoxContainer
var add_btn: Button
var close_btn: Button
var hint: Label
var template_scroll: ScrollContainer
var template_grid: GridContainer

## Template selection popup
var template_popup: ColorRect
var template_list: VBoxContainer

## Font sizes
const FS_TITLE := 24
const FS_LABEL := 16
const FS_BTN := 16


func init(sim_ref) -> void:
	sim = sim_ref


func _ready() -> void:
	_build_panel()
	_build_template_popup()
	hide_editor()


func _build_panel() -> void:
	panel = ColorRect.new()
	panel.color = Color(0.05, 0.07, 0.12, 0.95)
	panel.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	add_child(panel)

	title = Label.new()
	title.position = Vector2(40, 40)
	title.add_theme_font_size_override("font_size", FS_TITLE)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(title)

	## Slot switch buttons
	var slot_row := HBoxContainer.new()
	self.slot_row = slot_row
	slot_row.position = Vector2(40, 90)
	slot_row.size = Vector2(400, 40)
	add_child(slot_row)
	for i in range(3):
		var btn := Button.new()
		btn.text = I18n.ui("hud_slot") % (i + 1)
		btn.size = Vector2(120, 40)
		btn.add_theme_font_size_override("font_size", FS_BTN)
		btn.pressed.connect(_on_select_slot.bind(i))
		slot_row.add_child(btn)
		slot_buttons.append(btn)

	## Command block list title
	var list_title := Label.new()
	self.list_title = list_title
	list_title.position = Vector2(40, 150)
	list_title.text = I18n.ui("editor_current")
	list_title.add_theme_font_size_override("font_size", FS_LABEL)
	list_title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	add_child(list_title)

	block_list = VBoxContainer.new()
	block_list.position = Vector2(40, 180)
	block_list.size = Vector2(520, 340)
	add_child(block_list)

	## Add button
	add_btn = Button.new()
	add_btn.text = I18n.ui("editor_add")
	add_btn.position = Vector2(40, 540)
	add_btn.size = Vector2(180, 44)
	add_btn.add_theme_font_size_override("font_size", FS_BTN)
	add_btn.pressed.connect(_open_template_popup)
	add_child(add_btn)

	## Close button
	close_btn = Button.new()
	close_btn.text = I18n.ui("editor_close")
	close_btn.position = Vector2(Tuning.VIEW_W - 240, Tuning.VIEW_H - 70)
	close_btn.size = Vector2(200, 50)
	close_btn.add_theme_font_size_override("font_size", FS_BTN)
	close_btn.pressed.connect(hide_editor)
	add_child(close_btn)

	## Slot hint
	var hint := Label.new()
	self.hint = hint
	hint.position = Vector2(40, Tuning.VIEW_H - 40)
	hint.text = I18n.ui("editor_tip")
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	add_child(hint)


func _build_template_popup() -> void:
	template_popup = ColorRect.new()
	template_popup.color = Color(0, 0, 0, 0.7)
	template_popup.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	template_popup.visible = false
	add_child(template_popup)

	var popup_title := Label.new()
	popup_title.position = Vector2(40, 40)
	popup_title.text = I18n.ui("editor_popup_title")
	popup_title.add_theme_font_size_override("font_size", FS_TITLE)
	popup_title.add_theme_color_override("font_color", Color(1, 1, 1))
	template_popup.add_child(popup_title)

	template_scroll = ScrollContainer.new()
	template_scroll.position = Vector2(40, 100)
	template_scroll.size = Vector2(500, 380)
	template_popup.add_child(template_scroll)

	template_grid = GridContainer.new()
	template_grid.columns = 1
	template_grid.add_theme_constant_override("hseparation", 8)
	template_grid.add_theme_constant_override("vseparation", 8)
	template_scroll.add_child(template_grid)

	var close_popup := Button.new()
	close_popup.text = I18n.ui("editor_popup_close")
	close_popup.position = Vector2(Tuning.VIEW_W - 240, Tuning.VIEW_H - 70)
	close_popup.size = Vector2(200, 50)
	close_popup.add_theme_font_size_override("font_size", FS_BTN)
	close_popup.pressed.connect(_close_template_popup)
	template_popup.add_child(close_popup)


func show_editor(slot: int) -> void:
	editing_slot = clampf(slot, 0, 2)
	editor_shown = true
	panel.visible = true
	title.visible = true
	slot_row.visible = true
	list_title.visible = true
	block_list.visible = true
	add_btn.visible = true
	close_btn.visible = true
	hint.visible = true
	refresh_ui()


func hide_editor() -> void:
	editor_shown = false
	_close_template_popup()
	panel.visible = false
	title.visible = false
	slot_row.visible = false
	list_title.visible = false
	block_list.visible = false
	add_btn.visible = false
	close_btn.visible = false
	hint.visible = false


func refresh_ui() -> void:
	if not editor_shown:
		return
	title.text = I18n.ui("editor_title") % (editing_slot + 1)

	## Update slot button states
	for i in range(slot_buttons.size()):
		var btn: Button = slot_buttons[i]
		btn.disabled = (i == editing_slot)

	## Clear and redraw command block list
	for child in block_list.get_children():
		child.queue_free()

	var pipeline: Array = sim.get_pipeline(editing_slot)
	if pipeline == null:
		return

	for i in range(pipeline.size()):
		var block: CommandBlock = pipeline[i]
		var row := HBoxContainer.new()
		row.size = Vector2(500, 44)
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = "%s (Lv%d)" % [I18n.block_name(block.id), block.level]
		name_lbl.add_theme_font_size_override("font_size", FS_LABEL)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		name_lbl.custom_minimum_size = Vector2(300, 0)
		row.add_child(name_lbl)

		var kind_lbl := Label.new()
		kind_lbl.text = I18n.kind_label(block.kind)
		kind_lbl.add_theme_font_size_override("font_size", 13)
		kind_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		row.add_child(kind_lbl)

		var tag_lbl := Label.new()
		tag_lbl.text = I18n.tag_label(block.tag)
		tag_lbl.add_theme_font_size_override("font_size", 13)
		tag_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.7))
		row.add_child(tag_lbl)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.size = Vector2(36, 36)
		del_btn.add_theme_font_size_override("font_size", 18)
		del_btn.pressed.connect(_on_remove_block.bind(i))
		row.add_child(del_btn)

		block_list.add_child(row)


func _on_select_slot(slot: int) -> void:
	editing_slot = slot
	refresh_ui()


func _on_remove_block(idx: int) -> void:
	sim.remove_command(editing_slot, idx)
	refresh_ui()


func _open_template_popup() -> void:
	## Clear and rebuild template list
	for child in template_grid.get_children():
		child.queue_free()

	var templates := CommandBlock.BLOCK_TEMPLATES
	var keys := []
	for k in templates.keys():
		keys.append(k)
	keys.sort()

	for key in keys:
		var row := HBoxContainer.new()
		row.size = Vector2(460, 40)
		row.add_theme_constant_override("separation", 8)

		var name_lbl := Label.new()
		name_lbl.text = I18n.block_name(key)
		name_lbl.add_theme_font_size_override("font_size", FS_LABEL)
		name_lbl.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		name_lbl.custom_minimum_size = Vector2(320, 0)
		row.add_child(name_lbl)

		var add_tpl_btn := Button.new()
		add_tpl_btn.text = I18n.ui("editor_add_btn")
		add_tpl_btn.size = Vector2(80, 36)
		add_tpl_btn.add_theme_font_size_override("font_size", 14)
		add_tpl_btn.pressed.connect(_on_add_template.bind(key))
		row.add_child(add_tpl_btn)

		template_grid.add_child(row)

	template_popup.visible = true


func _close_template_popup() -> void:
	template_popup.visible = false


func _on_add_template(block_id: String) -> void:
	var block := CommandBlock.from_template(block_id, 1, "white")
	sim.add_command(editing_slot, block)
	_close_template_popup()
	refresh_ui()


## Exposed to outside: pause/resume
func editor_visible() -> bool:
	return editor_shown
