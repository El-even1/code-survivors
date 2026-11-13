extends CanvasLayer

## 背包 · 魔法工坊式管线编辑（拖拽）
## 约束：蓝量上限（每槽 60）、链路方向（修饰槽必须从左往右依次填）、存放区 6 格
## 左侧：主动槽 + 3 修饰槽（拖入装备，右键卸下）；左下：掉落的指令块；右侧：升级
## 打开时画面冻结；proto_view 用 B 键 / 背包按钮开关

## 拖拽源：存放区里的指令块
class BlockChip extends Panel:
	var block_id := ""
	var host

	func _get_drag_data(_pos: Vector2) -> Variant:
		if block_id == "" or host == null:
			return null
		var prev := Label.new()
		prev.text = I18n.block_name(block_id)
		prev.add_theme_font_size_override("font_size", 15)
		set_drag_preview(prev)
		return {"type": "chip", "block_id": block_id}


## 工坊格子：类型 + 链路 + 蓝量校验，右键卸下
class Socket extends Panel:
	var socket_index := 0
	var block_id := ""
	var host
	var accept_kind := "action"
	var caption := ""
	var label: Label

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		if host == null or typeof(data) != TYPE_DICTIONARY:
			return false
		if String(data.get("type", "")) != "chip":
			return false
		var bid := String(data.get("block_id", ""))
		var tpl = CommandBlock.BLOCK_TEMPLATES.get(bid)
		if tpl == null:
			return false
		return String(tpl.get("kind", "")) == accept_kind

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		host.on_drop_to_socket(socket_index, String(data.get("block_id", "")))

	func _get_drag_data(_pos: Vector2) -> Variant:
		if block_id == "" or host == null:
			return null
		var prev := Label.new()
		prev.text = I18n.block_name(block_id)
		prev.add_theme_font_size_override("font_size", 15)
		set_drag_preview(prev)
		return {"type": "socket", "socket": socket_index}

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT and block_id != "":
				host.on_unequip_socket(socket_index)

	func set_block(bid: String) -> void:
		block_id = bid
		if label == null:
			return
		if bid == "":
			label.text = caption
		else:
			label.text = I18n.ui("socket_block") % [I18n.block_name(bid), BlockLibrary.mana_cost(bid)]


## 存放区面板：接住从格子拖回来的块
class InventoryPanel extends Panel:
	var host

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		if host == null or typeof(data) != TYPE_DICTIONARY:
			return false
		return String(data.get("type", "")) == "socket"

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		host.on_unequip_socket(int(data.get("socket", 0)))


var sim

var editing_slot := 0
var _open := false
var _notice_timer := 0.0

var panel: ColorRect
var title: Label
var slot_row: HBoxContainer
var slot_buttons: Array = []
var stats_label: Label
var mana_label: Label
var board_title: Label

var board_panel: Panel
var _sockets: Array = []
var _socket_captions: Array = []
var _arrows: Array = []

var inv_title: Label
var inv_panel: InventoryPanel
var chip_grid: GridContainer
var hint_label: Label
var notice_label: Label

var up_title: Label
var up_list: VBoxContainer
var close_btn: Button


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
	_clear_notice()
	refresh()


func close() -> void:
	_open = false
	_set_main_visible(false)


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func _set_main_visible(v: bool) -> void:
	panel.visible = v
	title.visible = v
	slot_row.visible = v
	stats_label.visible = v
	mana_label.visible = v
	board_title.visible = v
	board_panel.visible = v
	inv_title.visible = v
	inv_panel.visible = v
	chip_grid.visible = v
	hint_label.visible = v
	notice_label.visible = v
	up_title.visible = v
	up_list.visible = v
	close_btn.visible = v
	for s in _sockets:
		s.visible = v
	for c in _socket_captions:
		c.visible = v
	for a in _arrows:
		a.visible = v


## ---------- 构建 ----------
func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 6.0
	sb.corner_radius_top_right = 6.0
	sb.corner_radius_bottom_left = 6.0
	sb.corner_radius_bottom_right = 6.0
	return sb


func _build() -> void:
	panel = ColorRect.new()
	panel.color = Color(0.045, 0.06, 0.09, 1.0)
	panel.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	add_child(panel)

	title = Label.new()
	title.position = Vector2(40, 16)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	add_child(title)

	# 槽位切换
	slot_row = HBoxContainer.new()
	slot_row.position = Vector2(40, 60)
	slot_row.size = Vector2(400, 38)
	slot_row.add_theme_constant_override("separation", 10)
	add_child(slot_row)
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 38)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_select_slot.bind(i))
		slot_row.add_child(b)
		slot_buttons.append(b)

	# 当前攻击数值 / 蓝量 / 存放区
	stats_label = Label.new()
	stats_label.position = Vector2(40, 104)
	stats_label.add_theme_font_size_override("font_size", 15)
	stats_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.55))
	add_child(stats_label)

	mana_label = Label.new()
	mana_label.position = Vector2(40, 126)
	mana_label.add_theme_font_size_override("font_size", 15)
	mana_label.add_theme_color_override("font_color", Color(0.6, 0.78, 1.0))
	add_child(mana_label)

	# 工坊板
	board_title = Label.new()
	board_title.position = Vector2(40, 152)
	board_title.add_theme_font_size_override("font_size", 16)
	board_title.add_theme_color_override("font_color", Color(0.72, 0.83, 1.0))
	add_child(board_title)

	board_panel = Panel.new()
	board_panel.position = Vector2(40, 178)
	board_panel.size = Vector2(600, 214)
	board_panel.add_theme_stylebox_override("panel",
		_panel_style(Color(0.07, 0.09, 0.13), Color(0.24, 0.3, 0.42)))
	add_child(board_panel)

	var xs := [60.0, 200.0, 340.0, 480.0]
	for i in range(4):
		var cap := Label.new()
		cap.position = Vector2(xs[i], 186)
		cap.add_theme_font_size_override("font_size", 13)
		cap.add_theme_color_override("font_color", Color(0.55, 0.63, 0.78))
		add_child(cap)
		_socket_captions.append(cap)

		var sock := Socket.new()
		sock.socket_index = i
		sock.accept_kind = CommandBlock.KIND_ACTION if i == 0 else CommandBlock.KIND_MODIFIER
		sock.host = self
		sock.position = Vector2(xs[i], 206)
		sock.size = Vector2(120, 112)
		sock.add_theme_stylebox_override("panel",
			_panel_style(Color(0.11, 0.14, 0.2), Color(0.35, 0.42, 0.58)))
		var lbl := Label.new()
		lbl.position = Vector2(8, 8)
		lbl.size = Vector2(104, 96)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sock.add_child(lbl)
		sock.label = lbl
		add_child(sock)
		_sockets.append(sock)

	# 链路方向箭头（槽与槽之间）
	for i in range(3):
		var arrow := Label.new()
		arrow.text = "→"
		arrow.position = Vector2(xs[i] + 124.0, 244)
		arrow.add_theme_font_size_override("font_size", 22)
		arrow.add_theme_color_override("font_color", Color(0.95, 0.78, 0.4))
		add_child(arrow)
		_arrows.append(arrow)

	# 存放区
	inv_title = Label.new()
	inv_title.position = Vector2(40, 402)
	inv_title.add_theme_font_size_override("font_size", 18)
	inv_title.add_theme_color_override("font_color", Color(0.72, 0.83, 1.0))
	add_child(inv_title)

	inv_panel = InventoryPanel.new()
	inv_panel.host = self
	inv_panel.position = Vector2(40, 432)
	inv_panel.size = Vector2(600, 160)
	inv_panel.add_theme_stylebox_override("panel",
		_panel_style(Color(0.07, 0.09, 0.13), Color(0.24, 0.3, 0.42)))
	add_child(inv_panel)

	chip_grid = GridContainer.new()
	chip_grid.position = Vector2(16, 14)
	chip_grid.size = Vector2(568, 132)
	chip_grid.columns = 4
	chip_grid.add_theme_constant_override("hseparation", 8)
	chip_grid.add_theme_constant_override("vseparation", 8)
	inv_panel.add_child(chip_grid)

	hint_label = Label.new()
	hint_label.position = Vector2(40, 600)
	hint_label.add_theme_font_size_override("font_size", 13)
	hint_label.add_theme_color_override("font_color", Color(0.5, 0.58, 0.72))
	add_child(hint_label)

	notice_label = Label.new()
	notice_label.position = Vector2(40, 622)
	notice_label.add_theme_font_size_override("font_size", 16)
	notice_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	notice_label.visible = false
	add_child(notice_label)

	# 升级
	up_title = Label.new()
	up_title.position = Vector2(680, 104)
	up_title.add_theme_font_size_override("font_size", 18)
	up_title.add_theme_color_override("font_color", Color(0.72, 0.83, 1.0))
	add_child(up_title)

	up_list = VBoxContainer.new()
	up_list.position = Vector2(680, 136)
	up_list.size = Vector2(560, 450)
	up_list.add_theme_constant_override("separation", 8)
	add_child(up_list)

	close_btn = Button.new()
	close_btn.position = Vector2(Tuning.VIEW_W - 240, Tuning.VIEW_H - 70)
	close_btn.size = Vector2(200, 50)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(close)
	add_child(close_btn)


## ---------- 刷新 ----------
func refresh() -> void:
	if not _open:
		return
	title.text = I18n.ui("backpack_title")
	board_title.text = I18n.ui("backpack_workshop")
	inv_title.text = I18n.ui("backpack_inventory_title")
	hint_label.text = I18n.ui("backpack_drag_hint")
	up_title.text = I18n.ui("backpack_upgrades")
	close_btn.text = I18n.ui("backpack_close")
	for i in range(slot_buttons.size()):
		var b: Button = slot_buttons[i]
		b.text = I18n.ui("hud_slot") % (i + 1)
		b.disabled = (i == editing_slot)

	stats_label.text = I18n.ui("backpack_stats") % [
		int(sim.attack_damage),
		int(sim.attack_radius),
		sim.attack_cooldown,
		sim.attack_pierce,
	]
	mana_label.text = I18n.ui("backpack_mana") % [
		sim.slot_mana_used(editing_slot),
		BlockLibrary.MANA_MAX,
		sim.storage_used(),
		BlockLibrary.STORAGE_CAP,
	]

	var action_id: String = sim.slot_action_id(editing_slot)
	var mods: Array = sim.slot_modifier_ids(editing_slot)
	for s in _sockets:
		if s.socket_index == 0:
			s.set_block(action_id)
		else:
			var mi: int = s.socket_index - 1
			if mi < mods.size():
				s.set_block(String(mods[mi]))
			else:
				s.set_block("")
	for i in range(_socket_captions.size()):
		var cap: Label = _socket_captions[i]
		cap.text = I18n.ui("socket_action") if i == 0 else "%s %d" % [I18n.ui("socket_modifier"), i]

	_refresh_inventory()
	_refresh_upgrades()


func _refresh_inventory() -> void:
	for child in chip_grid.get_children():
		child.queue_free()

	if sim.storage_used() == 0:
		var empty := Label.new()
		empty.text = I18n.ui("backpack_no_blocks")
		empty.add_theme_font_size_override("font_size", 15)
		empty.add_theme_color_override("font_color", Color(0.55, 0.62, 0.75))
		chip_grid.add_child(empty)
		return

	var ids: Array = sim.block_inventory.keys()
	ids.sort()
	for raw_id in ids:
		var bid := String(raw_id)
		var count: int = sim.block_stock(bid)
		if count <= 0:
			continue
		var chip := BlockChip.new()
		chip.block_id = bid
		chip.host = self
		chip.custom_minimum_size = Vector2(134, 44)
		chip.add_theme_stylebox_override("panel",
			_panel_style(Color(0.15, 0.19, 0.27), Color(0.4, 0.5, 0.68)))
		var lbl := Label.new()
		lbl.text = "%s ×%d\n%s" % [
			I18n.block_name(bid), count,
			I18n.ui("chip_mana") % BlockLibrary.mana_cost(bid),
		]
		lbl.position = Vector2(8, 4)
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(lbl)
		chip_grid.add_child(chip)


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


## ---------- 拖拽 / 操作回调 ----------
func on_drop_to_socket(socket_index: int, block_id: String) -> void:
	var reason: String = sim.can_equip_socket(editing_slot, socket_index, block_id)
	if reason != "":
		_show_reason(reason)
		return
	sim.equip_socket(editing_slot, socket_index, block_id)
	_clear_notice()
	refresh()


func on_unequip_socket(socket_index: int) -> void:
	sim.unequip_socket(editing_slot, socket_index)
	_clear_notice()
	refresh()


func _on_select_slot(slot: int) -> void:
	editing_slot = slot
	_clear_notice()
	refresh()


func _show_reason(reason_key: String) -> void:
	if notice_label == null:
		return
	notice_label.text = I18n.ui("reason_" + reason_key)
	notice_label.visible = true
	_notice_timer = 2.5


func _clear_notice() -> void:
	_notice_timer = 0.0
	if notice_label != null:
		notice_label.visible = false


func _process(delta: float) -> void:
	if _notice_timer > 0.0:
		_notice_timer -= delta
		if _notice_timer <= 0.0 and notice_label != null:
			notice_label.visible = false


## 自动放进合适的空槽（测试用）：主动块→主动槽，修饰块→下一个修饰槽
func add_block(block_id: String) -> bool:
	var tpl = CommandBlock.BLOCK_TEMPLATES.get(block_id)
	if tpl == null:
		return false
	var socket := 0
	if String(tpl.get("kind", "")) != CommandBlock.KIND_ACTION:
		socket = sim.slot_modifier_ids(editing_slot).size() + 1
	var reason: String = sim.can_equip_socket(editing_slot, socket, block_id)
	if reason != "":
		_show_reason(reason)
		return false
	var ok: bool = sim.equip_socket(editing_slot, socket, block_id)
	_clear_notice()
	refresh()
	return ok
