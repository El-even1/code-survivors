extends Node2D

## 开始页 + 多角色选人界面（色块风格，零美术资源）
## 键盘：A/D 或 ←/→ 切换角色，Enter/Space 开始
## 鼠标：点击卡片选择，点「开始游戏」进入
## 选定角色写入 GameState.selected_char，由 proto_view 读取

const CHAR_IDS: Array[String] = ["mage", "warrior", "hunter", "priest"]

const CHAR_COLOR := {
	"mage": Color(0.42, 0.62, 1.00),
	"warrior": Color(0.95, 0.36, 0.36),
	"hunter": Color(0.42, 0.92, 0.52),
	"priest": Color(0.96, 0.84, 0.42),
}

const CHAR_CN := {
	"mage": "法师",
	"warrior": "战士",
	"hunter": "猎人",
	"priest": "牧师",
}

const CHAR_TAG := {
	"mage": "远程 · 追踪弹",
	"warrior": "近战 · 高血量",
	"hunter": "远程 · 双发",
	"priest": "范围 · 吸血",
}

const CARD_W := 250.0
const CARD_H := 348.0
const CARD_GAP := 28.0
const CARD_Y := 196.0

var selected := 0
var hovered := -1
var _t := 0.0
var _card_buttons: Array = []
var _start_btn: Button


func _ready() -> void:
	_build_buttons()
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## ---------- 布局 ----------
func _card_x(i: int) -> float:
	var total: float = CARD_W * float(CHAR_IDS.size()) + CARD_GAP * float(CHAR_IDS.size() - 1)
	var x0: float = (Tuning.VIEW_W - total) * 0.5
	return x0 + float(i) * (CARD_W + CARD_GAP)


func _card_rect(i: int) -> Rect2:
	return Rect2(Vector2(_card_x(i), CARD_Y), Vector2(CARD_W, CARD_H))


## ---------- 交互 ----------
func _build_buttons() -> void:
	# 每张卡片上一块透明按钮，负责点击与悬停
	for i in range(CHAR_IDS.size()):
		var b := Button.new()
		b.flat = true
		b.text = ""
		b.focus_mode = Control.FOCUS_NONE
		b.position = _card_rect(i).position
		b.size = Vector2(CARD_W, CARD_H)
		b.mouse_entered.connect(_on_hover.bind(i))
		b.mouse_exited.connect(_on_unhover.bind(i))
		b.pressed.connect(_on_card_clicked.bind(i))
		add_child(b)
		_card_buttons.append(b)

	_start_btn = Button.new()
	_start_btn.text = "开 始 游 戏"
	_start_btn.focus_mode = Control.FOCUS_NONE
	_start_btn.size = Vector2(260, 56)
	_start_btn.position = Vector2((Tuning.VIEW_W - 260.0) * 0.5, 596.0)
	_start_btn.add_theme_font_size_override("font_size", 24)
	_start_btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	_start_btn.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	_start_btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.9, 1.0))
	_start_btn.pressed.connect(_start_game)
	add_child(_start_btn)


func _on_hover(i: int) -> void:
	hovered = i
	queue_redraw()


func _on_unhover(i: int) -> void:
	if hovered == i:
		hovered = -1
		queue_redraw()


func _on_card_clicked(i: int) -> void:
	if i == selected:
		# 再点一次已选中的卡片 = 直接开始
		_start_game()
		return
	selected = i
	queue_redraw()


## 切换选择（键盘与测试共用，纯逻辑不碰视图）
func cycle_selection(step: int) -> void:
	selected = (selected + step + CHAR_IDS.size()) % CHAR_IDS.size()
	queue_redraw()


## 当前选中的角色 id（供流程测试与开战使用）
func get_selected_id() -> String:
	return CHAR_IDS[selected]


## 把选择写进全局状态，返回写入的角色 id（不含场景切换，便于测试）
func commit_selection() -> String:
	GameStateData.selected_char = CHAR_IDS[selected]
	return GameStateData.selected_char


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				cycle_selection(-1)
			KEY_D, KEY_RIGHT:
				cycle_selection(1)
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_start_game()
			_:
				return
		get_viewport().set_input_as_handled()


func _start_game() -> void:
	commit_selection()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## ---------- 绘制 ----------
func _draw() -> void:
	# 背景
	draw_rect(Rect2(0, 0, Tuning.VIEW_W, Tuning.VIEW_H), Color(0.043, 0.055, 0.078), true)

	# 背景网格
	var g := 64.0
	var line_col := Color(0.075, 0.095, 0.135)
	var gx := 0.0
	while gx <= Tuning.VIEW_W:
		draw_line(Vector2(gx, 0), Vector2(gx, Tuning.VIEW_H), line_col, 1.0)
		gx += g
	var gy := 0.0
	while gy <= Tuning.VIEW_H:
		draw_line(Vector2(0, gy), Vector2(Tuning.VIEW_W, gy), line_col, 1.0)
		gy += g

	# 标题
	_draw_center_text("CODE SURVIVORS", 96.0, 64, Color(0.92, 0.96, 1.0))
	_draw_center_text("色块原型 · 阶段二 · 选择你的角色", 148.0, 20, Color(0.55, 0.66, 0.82))

	# 角色卡
	for i in range(CHAR_IDS.size()):
		_draw_card(i)

	# 底部操作提示
	_draw_center_text("A / D 或 ← / → 切换角色　　 Enter 开始游戏　　 也可以直接点击卡片", 682.0, 16, Color(0.45, 0.55, 0.70))


func _draw_center_text(text: String, y: float, fs: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((Tuning.VIEW_W - w) * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_card_center(text: String, cx: float, y: float, fs: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(cx - w * 0.5, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_card(i: int) -> void:
	var rect := _card_rect(i)
	var cid: String = CHAR_IDS[i]
	var col: Color = CHAR_COLOR[cid]
	var info: Dictionary = Tuning.CHARACTER_BASE[cid]
	var is_sel := i == selected
	var is_hov := i == hovered

	# 卡片底
	var bg := Color(0.10, 0.13, 0.18)
	if is_sel:
		bg = Color(0.15, 0.19, 0.26)
	elif is_hov:
		bg = Color(0.12, 0.15, 0.21)
	draw_rect(rect, bg, true)

	# 顶部角色色条
	draw_rect(Rect2(rect.position, Vector2(CARD_W, 6.0)), col, true)

	# 边框：选中时呼吸高亮
	if is_sel:
		var pulse: float = 0.65 + 0.35 * sin(_t * 5.0)
		draw_rect(rect, Color(col.r, col.g, col.b, pulse), false, 3.0)
	elif is_hov:
		draw_rect(rect, Color(1, 1, 1, 0.30), false, 1.5)
	else:
		draw_rect(rect, Color(1, 1, 1, 0.10), false, 1.0)

	# 武器图标（色块）
	var icon_center := Vector2(rect.position.x + CARD_W * 0.5, rect.position.y + 78.0)
	_draw_icon(cid, icon_center, 84.0, col)

	# 名字 / 武器定位
	_draw_card_center("%s  %s" % [CHAR_CN[cid], String(info["name"])],
		rect.position.x + CARD_W * 0.5, rect.position.y + 150.0, 26, Color(1, 1, 1))
	_draw_card_center("%s · %s" % [String(info["weapon"]), CHAR_TAG[cid]],
		rect.position.x + CARD_W * 0.5, rect.position.y + 178.0, 15, Color(0.62, 0.72, 0.86))

	# 分隔线
	draw_line(Vector2(rect.position.x + 22.0, rect.position.y + 198.0),
		Vector2(rect.position.x + CARD_W - 22.0, rect.position.y + 198.0),
		Color(1, 1, 1, 0.10), 1.0)

	# 数值
	var x := rect.position.x + 24.0
	var y := rect.position.y + 226.0
	_draw_stat("生命", str(int(float(info["hp"]))), x, y, col)
	_draw_stat("移速", str(int(float(info["speed"]))), x, y + 26.0, col)
	_draw_stat("攻击间隔", "%.2f s" % float(info["attack_cooldown"]), x, y + 52.0, col)

	# 被动
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x, rect.position.y + 302.0), "被动",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.50, 0.60, 0.75))
	_draw_wrapped(String(info["passive"]), Vector2(x, rect.position.y + 322.0),
		CARD_W - 48.0, 12, Color(0.72, 0.80, 0.92))


func _draw_stat(label: String, value: String, x: float, y: float, col: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.52, 0.62, 0.78))
	draw_string(font, Vector2(x + 86.0, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col.lightened(0.25))


## 按像素宽度折行（被动描述用）
func _draw_wrapped(text: String, pos: Vector2, max_w: float, fs: int, col: Color) -> void:
	var font := ThemeDB.fallback_font
	var line := ""
	var y := pos.y
	for word in text.split(" "):
		var cand := word if line == "" else line + " " + word
		var w: float = font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > max_w and line != "":
			draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			y += float(fs) + 4.0
			line = word
		else:
			line = cand
	if line != "":
		draw_string(font, Vector2(pos.x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## 每个角色一个纯色块武器图标，不用美术资源也能一眼区分
func _draw_icon(cid: String, center: Vector2, sz: float, col: Color) -> void:
	var white := Color(1, 1, 1, 0.92)
	match cid:
		"mage":
			# 法杖：斜杆 + 顶端法球
			draw_line(center + Vector2(-sz * 0.18, sz * 0.42), center + Vector2(sz * 0.10, -sz * 0.24), col, 6.0)
			draw_circle(center + Vector2(sz * 0.14, -sz * 0.34), sz * 0.15, white, true)
			draw_circle(center + Vector2(sz * 0.14, -sz * 0.34), sz * 0.15, col, false, 2.0)
		"warrior":
			# 刀刃：斜厚线 + 护手
			draw_line(center + Vector2(-sz * 0.34, sz * 0.34), center + Vector2(sz * 0.30, -sz * 0.34), white, 9.0)
			draw_line(center + Vector2(-sz * 0.26, sz * 0.04), center + Vector2(sz * 0.02, sz * 0.30), col, 7.0)
		"hunter":
			# 弓：弧 + 弦 + 箭
			draw_arc(center + Vector2(-sz * 0.06, 0), sz * 0.42, -1.15, 1.15, 22, white, 5.0)
			draw_line(center + Vector2(-sz * 0.22, -sz * 0.38), center + Vector2(-sz * 0.22, sz * 0.38), col, 2.5)
			draw_line(center + Vector2(-sz * 0.22, 0), center + Vector2(sz * 0.40, 0), white, 3.0)
		"priest":
			# 法书：书页 + 书脊 + 光点
			var book := Rect2(center + Vector2(-sz * 0.30, -sz * 0.28), Vector2(sz * 0.60, sz * 0.56))
			draw_rect(book, white, false, 3.0)
			draw_line(center + Vector2(0, -sz * 0.28), center + Vector2(0, sz * 0.28), col, 2.0)
			draw_circle(center + Vector2(0, -sz * 0.42), sz * 0.08, col, true)
		_:
			pass
