extends Node2D

## Stage I Color Prototype · Render Layer
## Only "see": reads ProtoSim snapshot, draws with placeholder color blocks
## All drawing uses draw_* single batch, avoids per-frame node creation (doc: object pool + draw call)


## 血条 / 蓝条：纯色块条 + 内嵌数值文本
class StatBar extends Control:
	var ratio := 1.0
	var fill_col := Color(0.85, 0.3, 0.3)
	var bg_col := Color(0.11, 0.13, 0.18)
	var text := ""

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, bg_col, true)
		var w: float = size.x * clampf(ratio, 0.0, 1.0)
		if w > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(w, size.y)), fill_col, true)
		draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(6, size.y - 5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(1, 1, 1, 0.92))


var sim

## AoE visual pulse
var pulse_t := -1.0
const PULSE_LIFE := 0.18

## Camera (world-space viewport top-left)
var camera_pos := Vector2.ZERO
@onready var cam2d: Camera2D = get_node("Camera2D")

var stat_label: Label
var hp_bar: StatBar
var mana_bar: StatBar
var boss_bar: StatBar
var safe_panel: ColorRect
var safe_title: Label
var safe_hint: Label
var safe_btn: Button
var result_label: Label
var upgrade_panel: CanvasLayer
var upgrade_buttons: Array = []

## Pause & backpack & pipeline HUD
var pause_btn: Button
var pause_hint: Label
var toast_label: Label
var slot_buttons: Array = []
var backpack
var pipeline_hud
var is_paused := false
var _current_options: Array = []

## Font (default font, prototype phase no resources)
func _ready() -> void:
	sim = ProtoSim.new()
	# 应用选人界面选择的角色（属性、武器、默认管线槽）
	sim._select_char(GameStateData.selected_char)
	camera_pos = sim.player_pos - Vector2(Tuning.VIEW_W * 0.5, Tuning.VIEW_H * 0.5)
	cam2d.global_position = sim.player_pos
	_build_ui()

	# Right-bottom mini pipeline line (battle real-time flash, let player see pipeline running)
	# 必须放进 CanvasLayer：否则 Control 挂在 Node2D 下会跟着摄像机漂到玩家旁边
	var hud_script = load("res://scripts/ui/pipeline_hud.gd")
	if hud_script != null:
		var hud_layer := CanvasLayer.new()
		add_child(hud_layer)
		pipeline_hud = hud_script.new()
		pipeline_hud.init(sim)
		pipeline_hud.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
		pipeline_hud.position = Vector2.ZERO
		hud_layer.add_child(pipeline_hud)

	# 背包最后创建 → CanvasLayer 顺序最靠上，打开时能盖住 HUD 与管线链条
	var bp_script = load("res://scripts/ui/backpack_view.gd")
	if bp_script != null:
		backpack = bp_script.new()
		backpack.init(sim)
		add_child(backpack)


## Initialize: build UI, build pipeline editor
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	stat_label = Label.new()
	stat_label.position = Vector2(18, 14)
	stat_label.add_theme_font_size_override("font_size", 20)
	stat_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	layer.add_child(stat_label)

	# 血条 / 蓝条（纯色块条）
	hp_bar = StatBar.new()
	hp_bar.position = Vector2(18, 46)
	hp_bar.size = Vector2(300, 22)
	hp_bar.fill_col = Color(0.85, 0.28, 0.28)
	layer.add_child(hp_bar)

	mana_bar = StatBar.new()
	mana_bar.position = Vector2(18, 72)
	mana_bar.size = Vector2(300, 18)
	mana_bar.fill_col = Color(0.35, 0.6, 1.0)
	layer.add_child(mana_bar)

	# Boss 血条（居中，仅 Boss 战显示）
	boss_bar = StatBar.new()
	boss_bar.position = Vector2(Tuning.VIEW_W * 0.5 - 320.0, 52.0)
	boss_bar.size = Vector2(640, 24)
	boss_bar.fill_col = Color(0.7, 0.22, 0.42)
	boss_bar.visible = false
	layer.add_child(boss_bar)

	# 安全区面板：回血 + 整理背包 + 继续
	safe_panel = ColorRect.new()
	safe_panel.color = Color(0.03, 0.05, 0.08, 0.72)
	safe_panel.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	safe_panel.visible = false
	layer.add_child(safe_panel)

	safe_title = Label.new()
	safe_title.position = Vector2(Tuning.VIEW_W * 0.5 - 80.0, 250.0)
	safe_title.add_theme_font_size_override("font_size", 44)
	safe_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	safe_title.visible = false
	layer.add_child(safe_title)

	safe_hint = Label.new()
	safe_hint.position = Vector2(Tuning.VIEW_W * 0.5 - 260.0, 320.0)
	safe_hint.add_theme_font_size_override("font_size", 20)
	safe_hint.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	safe_hint.visible = false
	layer.add_child(safe_hint)

	safe_btn = Button.new()
	safe_btn.position = Vector2(Tuning.VIEW_W * 0.5 - 120.0, 380.0)
	safe_btn.size = Vector2(240, 54)
	safe_btn.add_theme_font_size_override("font_size", 22)
	safe_btn.pressed.connect(_on_safe_continue)
	safe_btn.visible = false
	layer.add_child(safe_btn)

	var hint := Label.new()
	hint.text = I18n.ui("hud_move")
	hint.position = Vector2(18, 98)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	layer.add_child(hint)

	# 拾取指令块提示
	toast_label = Label.new()
	toast_label.position = Vector2(18, 120)
	toast_label.add_theme_font_size_override("font_size", 17)
	toast_label.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	toast_label.visible = false
	layer.add_child(toast_label)

	result_label = Label.new()
	result_label.position = Vector2(Tuning.VIEW_W * 0.5 - 120, Tuning.VIEW_H * 0.5 - 60)
	result_label.add_theme_font_size_override("font_size", 40)
	result_label.add_theme_color_override("font_color", Color(1, 0.45, 0.45))
	result_label.visible = false
	layer.add_child(result_label)

	# Upgrade three-choose-one panel
	upgrade_panel = CanvasLayer.new()
	upgrade_panel.visible = false
	add_child(upgrade_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
	upgrade_panel.add_child(dim)

	var title := Label.new()
	title.text = I18n.ui("upgrade_title")
	title.position = Vector2(Tuning.VIEW_W * 0.5 - 90, 210)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	upgrade_panel.add_child(title)

	# Three candidate button placeholders (content filled at runtime)
	var xs := [190.0, 500.0, 810.0]
	for i in range(3):
		var btn := Button.new()
		btn.position = Vector2(xs[i], 300)
		btn.size = Vector2(280, 140)
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_upgrade_picked.bind(i))
		upgrade_panel.add_child(btn)
		upgrade_buttons.append(btn)

	# Pause button (top-right, must be on CanvasLayer to follow screen)
	pause_btn = Button.new()
	pause_btn.text = I18n.ui("hud_pause")
	pause_btn.position = Vector2(Tuning.VIEW_W - 130, 18)
	pause_btn.size = Vector2(110, 36)
	pause_btn.add_theme_font_size_override("font_size", 16)
	pause_btn.pressed.connect(_toggle_pause)
	layer.add_child(pause_btn)

	# Backpack button (top-right, left of pause)
	var bag_btn := Button.new()
	bag_btn.text = I18n.ui("hud_backpack")
	bag_btn.position = Vector2(Tuning.VIEW_W - 260, 18)
	bag_btn.size = Vector2(120, 36)
	bag_btn.add_theme_font_size_override("font_size", 16)
	bag_btn.pressed.connect(toggle_backpack)
	layer.add_child(bag_btn)

	# Paused hint (center screen)
	pause_hint = Label.new()
	pause_hint.text = I18n.ui("pause_hint")
	pause_hint.position = Vector2(Tuning.VIEW_W * 0.5 - 150.0, Tuning.VIEW_H * 0.5 - 20.0)
	pause_hint.add_theme_font_size_override("font_size", 28)
	pause_hint.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	pause_hint.visible = false
	layer.add_child(pause_hint)

	# Slot switch buttons (bottom-left, usable in combat)
	var slot_y := Tuning.VIEW_H - 70
	for i in range(3):
		var btn := Button.new()
		btn.text = I18n.ui("hud_slot") % (i + 1)
		btn.position = Vector2(18 + i * 90, slot_y)
		btn.size = Vector2(76, 34)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(_on_switch_slot.bind(i))
		layer.add_child(btn)
		slot_buttons.append(btn)


## Pick upgrade
func _on_upgrade_picked(slot: int) -> void:
	if slot < 0 or slot >= _current_options.size():
		return
	var id: String = _current_options[slot]
	sim.apply_upgrade(id)
	upgrade_panel.visible = false
	_current_options = []
	# 剩余 pending_levels 由 _process 下一帧处理，避免连续弹面板


## Toggle pause（只管暂停，不再打开管线编辑）
func _toggle_pause() -> void:
	is_paused = not is_paused
	pause_btn.text = I18n.ui("hud_resume") if is_paused else I18n.ui("hud_pause")
	if pause_hint != null:
		pause_hint.visible = is_paused


## 打开 / 关闭背包（管线编辑 + 升级查看）
func toggle_backpack() -> void:
	if backpack == null:
		return
	# 背包与暂停互斥：开背包自动取消暂停状态
	if not backpack.is_open() and is_paused:
		_toggle_pause()
	backpack.toggle()
	if backpack.is_open():
		pause_hint.visible = false


## 兼容旧调用（截图脚本用）：回到战斗
func resume_from_editor() -> void:
	is_paused = false
	pause_btn.text = I18n.ui("hud_pause")
	if pause_hint != null:
		pause_hint.visible = false
	if backpack != null:
		backpack.close()


func _on_switch_slot(slot: int) -> void:
	# 战斗中切换生效槽位（背包打开时用背包里的槽位按钮编辑）
	if backpack != null and backpack.is_open():
		return
	if sim.switch_slot(slot):
		_update_stat()


## Keyboard: Esc 暂停 / B 背包 / R 结算后回选人
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			# 背包优先关闭，其次才切暂停
			if backpack != null and backpack.is_open():
				backpack.close()
			else:
				_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_B:
			if sim.alive and not upgrade_panel.visible:
				toggle_backpack()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			# 安全区：Enter 继续下一阶段
			if sim.is_safe_zone() and sim.alive:
				sim.continue_from_safe_zone()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R and (not sim.alive or sim.level_sim.is_victory):
			# 死亡 / 通关后按 R 回到选人界面
			get_tree().change_scene_to_file("res://scenes/start.tscn")
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Freeze world when upgrade panel or backpack open
	if upgrade_panel.visible or (backpack != null and backpack.is_open()):
		queue_redraw()
		return

	if sim.alive and not is_paused:
		var input_dir := _read_move()
		sim.step(delta, input_dir)
		if sim.pending_levels > 0:
			_open_upgrade()
	else:
		if sim.alive and is_paused:
			# Pause state: freeze world, just refresh UI
			pass
		elif not sim.alive:
			result_label.visible = true
			result_label.text = (I18n.ui("result_killed") % sim.kills) + "\n" + I18n.ui("result_restart")
		elif sim.level_sim.is_victory:
			result_label.visible = true
			result_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.65))
			result_label.text = (I18n.ui("result_victory") % sim.kills) + "\n" + I18n.ui("result_restart")

	# AoE pulse decay
	if pulse_t >= 0.0:
		pulse_t += delta
		if pulse_t >= PULSE_LIFE:
			pulse_t = -1.0

	# AoE pulse triggered (judge by pulse count change)
	if sim.aoe_pulses != _last_pulses:
		_last_pulses = sim.aoe_pulses
		pulse_t = 0.0

	_update_camera(delta)
	_update_stat()
	_update_toast()
	queue_redraw()


## 拾取指令块提示（左上角）
func _update_toast() -> void:
	if toast_label == null:
		return
	if sim.block_toast != "" and sim.block_toast_timer > 0.0:
		toast_label.visible = true
		if sim.block_toast == "storage_full":
			toast_label.text = I18n.ui("toast_storage_full")
		else:
			toast_label.text = I18n.ui("toast_block") % I18n.block_name(sim.block_toast)
	else:
		toast_label.visible = false


var _last_pulses := 0

## Read move input: 1) prefer InputMap (WASD+arrows configured)
##               2) fallback direct physical key read, works in any env
func _read_move() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length_squared() > 0.0001:
		return v
	## Physical key fallback (not dependent on InputMap config)
	var x := 0.0
	var y := 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		y += 1.0
	var out := Vector2(x, y)
	if out.length_squared() > 0.0001:
		return out.normalized()
	return Vector2.ZERO


func _update_stat() -> void:
	var slot_tag := I18n.ui("hud_slot") % (sim.get_active_slot() + 1)
	if is_paused:
		slot_tag += " " + I18n.ui("hud_paused")
	var sector_tag := ""
	if sim.is_boss_fight():
		sector_tag = I18n.ui("hud_boss") % I18n.sector_name(sim.current_boss)
	elif sim.is_safe_zone():
		sector_tag = I18n.ui("hud_safe")
	else:
		sector_tag = I18n.ui("hud_sector") % [
			I18n.sector_name(sim.current_sector),
			sim.sector_time_left(),
		]
	stat_label.text = "%s   %s   %s %d   %s %d/%d   %s %d   %s %d   %s %s   %.1fs   %s" % [
		slot_tag,
		sector_tag,
		I18n.ui("hud_lv"), sim.level,
		I18n.ui("hud_xp"), int(sim.xp), int(sim.xp_to_next),
		I18n.ui("hud_kills"), sim.kills,
		I18n.ui("hud_onscreen"), sim.enemy_pos.size(),
		I18n.ui("hud_phase"), I18n.phase_name(sim.elapsed),
		sim.elapsed,
		I18n.ui("hud_storage") % [sim.storage_used(), BlockLibrary.STORAGE_CAP],
	]

	# 血条 / 蓝条数值与比例
	var hp_ratio: float = 0.0
	if sim.player_max_hp > 0.0:
		hp_ratio = clampf(sim.player_hp / sim.player_max_hp, 0.0, 1.0)
	hp_bar.ratio = hp_ratio
	hp_bar.fill_col = Color(0.85, 0.28, 0.28).lerp(Color(0.35, 0.85, 0.4), hp_ratio)
	hp_bar.text = I18n.ui("bar_hp") % [int(sim.player_hp), int(sim.player_max_hp)]
	hp_bar.queue_redraw()

	var mana_ratio: float = 0.0
	if sim.mana_max > 0.0:
		mana_ratio = clampf(sim.mana / sim.mana_max, 0.0, 1.0)
	mana_bar.ratio = mana_ratio
	mana_bar.text = I18n.ui("bar_mana") % [int(sim.mana), int(sim.mana_max)]
	mana_bar.queue_redraw()

	# Boss 血条
	var boss_on: bool = sim.is_boss_fight()
	boss_bar.visible = boss_on
	if boss_on:
		var boss_ratio: float = 0.0
		if sim.boss_max_hp > 0.0:
			boss_ratio = clampf(sim.boss_hp / sim.boss_max_hp, 0.0, 1.0)
		boss_bar.ratio = boss_ratio
		boss_bar.fill_col = Color(0.7, 0.22, 0.42).lerp(Color(0.95, 0.35, 0.2), 1.0 - boss_ratio)
		boss_bar.text = I18n.ui("boss_bar") % [
			I18n.sector_name(sim.current_boss), sim.boss_phase,
			int(maxf(0.0, sim.boss_hp)), int(sim.boss_max_hp),
		]
		boss_bar.queue_redraw()

	# 安全区面板
	var safe_on: bool = sim.is_safe_zone() and sim.alive
	if safe_panel != null:
		safe_panel.visible = safe_on
		safe_title.visible = safe_on
		safe_hint.visible = safe_on
		safe_btn.visible = safe_on
		if safe_on:
			safe_title.text = I18n.ui("safe_title")
			safe_hint.text = I18n.ui("safe_hint")
			safe_btn.text = I18n.ui("safe_continue")


func _on_safe_continue() -> void:
	sim.continue_from_safe_zone()
	_update_stat()


## Camera follow: keep player at viewport center, smooth lerp
func _update_camera(delta: float) -> void:
	var target: Vector2 = sim.player_pos
	cam2d.global_position = cam2d.global_position.lerp(target, clampf(delta * Tuning.CAM_FOLLOW_SPEED, 0.0, 1.0))
	camera_pos = cam2d.global_position - Vector2(Tuning.VIEW_W * 0.5, Tuning.VIEW_H * 0.5)


func _open_upgrade() -> void:
	_current_options = ProtoLogic.roll_upgrades(sim._rng, sim.owned, 3)
	for i in range(upgrade_buttons.size()):
		var btn: Button = upgrade_buttons[i]
		if i < _current_options.size():
			var id: String = _current_options[i]
			var info: Dictionary = ProtoLogic.Tuning_UPGRADES[id]
			var lv: int = int(sim.owned.get(id, 0))
			var maxlv: int = int(info["max_level"])
			btn.text = "%s\nLv %d -> %d" % [I18n.upgrade_name(id), lv, lv + 1]
			btn.disabled = false
			btn.visible = true
		else:
			btn.visible = false
	upgrade_panel.visible = true


func _draw() -> void:
	var vp := Rect2(camera_pos, Vector2(Tuning.VIEW_W, Tuning.VIEW_H))
	var pad := 40.0

	# Grid bottom pattern (camera-follow, draw viewport only)
	var g := 64.0
	var col := Color(0.09, 0.11, 0.15)
	var gx := floorf(vp.position.x / g) * g
	while gx <= vp.end.x:
		draw_line(Vector2(gx, vp.position.y), Vector2(gx, vp.end.y), col, 1.0)
		gx += g
	var gy := floorf(vp.position.y / g) * g
	while gy <= vp.end.y:
		draw_line(Vector2(vp.position.x, gy), Vector2(vp.end.x, gy), col, 1.0)
		gy += g

	# World boundary
	draw_rect(Rect2(0, 0, Tuning.WORLD_W, Tuning.WORLD_H), Color(0.3, 0.35, 0.45), false, 2.0)

	# White circle AoE (pulse diffusion)
	if pulse_t >= 0.0:
		var k := pulse_t / PULSE_LIFE
		var r: float = sim.attack_radius * (0.72 + 0.28 * k)
		draw_circle(sim.player_pos, r, Color(1, 1, 1, 0.16 * (1.0 - k)))
		draw_arc(sim.player_pos, r, 0.0, TAU, 48, Color(1, 1, 1, 0.85 * (1.0 - k)), 2.5)
	else:
		# Silent state: faint white circle shows attack range
		draw_arc(sim.player_pos, sim.attack_radius, 0.0, TAU, 40, Color(1, 1, 1, 0.10), 1.5)

	# Green gems
	var half_gem := Tuning.GEM_SIZE * 0.5
	var gem_col := Color(0.42, 1.0, 0.35)
	for i in range(sim.gem_pos.size()):
		var gp: Vector2 = sim.gem_pos[i]
		if not vp.grow(pad).has_point(gp):
			continue
		draw_rect(Rect2(gp - Vector2(half_gem, half_gem), Vector2(Tuning.GEM_SIZE, Tuning.GEM_SIZE)),
			gem_col, true)

	# Dropped command blocks (diamond): orange = action, purple = modifier
	for i in range(sim.block_drop_pos.size()):
		var bp: Vector2 = sim.block_drop_pos[i]
		if not vp.grow(pad).has_point(bp):
			continue
		var bid: String = sim.block_drop_id[i]
		var tpl = CommandBlock.BLOCK_TEMPLATES.get(bid)
		var is_action := tpl != null and String(tpl.get("kind", "")) == CommandBlock.KIND_ACTION
		var drop_col := Color(1.0, 0.62, 0.35) if is_action else Color(0.72, 0.55, 1.0)
		var ds := 9.0
		var pts := PackedVector2Array([
			bp + Vector2(0.0, -ds), bp + Vector2(ds, 0.0),
			bp + Vector2(0.0, ds), bp + Vector2(-ds, 0.0),
		])
		draw_colored_polygon(pts, drop_col)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
			Color(1, 1, 1, 0.75), 1.2)

	# Red square horde (draw viewport only, skip off-screen)
	_raster_enemies(vp.grow(pad))

	# Boss：大色块 + 阶段换色
	if sim.is_boss_fight():
		var br: float = sim.boss_radius
		var bp: Vector2 = sim.boss_pos
		var bcol := Color(0.72, 0.2, 0.3)
		if sim.boss_phase == 2:
			bcol = Color(0.85, 0.25, 0.55)
		elif sim.boss_phase >= 3:
			bcol = Color(1.0, 0.3, 0.2)
		draw_rect(Rect2(bp - Vector2(br, br), Vector2(br * 2.0, br * 2.0)), bcol, true)
		draw_rect(Rect2(bp - Vector2(br, br), Vector2(br * 2.0, br * 2.0)),
			Color(1, 1, 1, 0.9), false, 3.0)

	# Boss 弹幕
	for i in range(sim.boss_shots_pos.size()):
		var sp: Vector2 = sim.boss_shots_pos[i]
		if not vp.grow(pad).has_point(sp):
			continue
		draw_circle(sp, 7.0, Color(1, 0.55, 0.55, 0.95))

	# 玩家子弹：小圆点 + 拖尾（穿透/追踪在飞行中体现）
	for i in range(sim.shot_pos.size()):
		var bp: Vector2 = sim.shot_pos[i]
		if not vp.grow(pad).has_point(bp):
			continue
		var bd: Vector2 = sim.shot_dir[i]
		var bcol := Color(0.72, 0.88, 1.0)
		if sim.char_id == "hunter":
			bcol = Color(0.82, 1.0, 0.86)
		elif sim.char_id == "priest":
			bcol = Color(1.0, 0.9, 0.55)
		draw_line(bp - bd * 20.0, bp, Color(bcol.r, bcol.g, bcol.b, 0.45), 3.0)
		draw_circle(bp, 5.5, bcol)
		draw_circle(bp, 5.5, Color(1, 1, 1, 0.85), false, 1.2)

	# Blue square player (invulnerable frame flash)
	var half_p := Tuning.PLAYER_SIZE * 0.5
	var pcol := Color(0.28, 0.55, 1.0)
	if sim.iframe_timer > 0.0 and int(sim.iframe_timer * 20.0) % 2 == 0:
		pcol = Color(0.75, 0.85, 1.0)
	draw_rect(Rect2(sim.player_pos - Vector2(half_p, half_p),
		Vector2(Tuning.PLAYER_SIZE, Tuning.PLAYER_SIZE)), pcol, true)
	draw_rect(Rect2(sim.player_pos - Vector2(half_p, half_p),
		Vector2(Tuning.PLAYER_SIZE, Tuning.PLAYER_SIZE)), Color(0.7, 0.85, 1.0), false, 1.5)

	# Weapon attack visual (flash right after attack)
	if sim.attack_flash > 0.0:
		_draw_weapon_attack(sim.attack_flash)

	# Floating damage text
	_draw_dmg_text()


## Enemies drawn in one batch draw_rect, avoid 300 node overhead; skip off-screen
func _raster_enemies(vp: Rect2) -> void:
	var hs := Tuning.ENEMY_SIZE * 0.5
	var red := Color(0.92, 0.24, 0.24)
	var red_hot := Color(1.0, 0.45, 0.35)
	var base_hp: float = ProtoLogic.enemy_hp(sim.elapsed)
	var n: int = sim.enemy_pos.size()
	for i in range(n):
		var p: Vector2 = sim.enemy_pos[i]
		if not vp.has_point(p):
			continue
		var hp_ratio: float = clampf(sim.enemy_hp[i] / base_hp, 0.0, 1.0)
		var c := red.lerp(red_hot, 1.0 - hp_ratio)
		draw_rect(Rect2(p - Vector2(hs, hs), Vector2(Tuning.ENEMY_SIZE, Tuning.ENEMY_SIZE)), c, true)


func _draw_dmg_text() -> void:
	var font := ThemeDB.fallback_font
	var n: int = sim.dmg_pos.size()
	for i in range(n):
		if not sim.dmg_alive[i]:
			continue
		var k: float = clampf(sim.dmg_age[i] / Tuning.DMG_TEXT_LIFE, 0.0, 1.0)
		var p: Vector2 = sim.dmg_pos[i] - Vector2(0, Tuning.DMG_TEXT_RISE * k)
		var a: float = 1.0 - k * k
		var cnt: int = sim.dmg_count[i]
		var txt: String
		if cnt > 1:
			txt = "×%d" % cnt
		else:
			txt = str(int(sim.dmg_value[i]))
		var fs := 18 if cnt <= 1 else 22
		draw_string(font, p - Vector2(txt.length() * fs * 0.3, 0), txt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.93, 0.55, a))


## Weapon attack visual: shows what weapon is attacking right after each hit
## mage=Staff beam, warrior=Blade swing arc, hunter=Bow double shot, priest=Tome pulse ring
func _draw_weapon_attack(flash: float) -> void:
	var pct: float = clampf(flash / 0.15, 0.0, 1.0)   # 1.0 at hit, fading to 0
	var alpha: float = 0.9 * pct
	var width: float = 2.5 + 2.0 * pct
	var r: float = sim.attack_radius
	var p: Vector2 = sim.player_pos

	# Facing direction: toward nearest enemy (or boss), fallback +X
	var face: Vector2 = Vector2(1, 0)
	if sim.is_boss_fight():
		var to_boss: Vector2 = sim.boss_pos - p
		if to_boss.length_squared() > 0.01:
			face = to_boss.normalized()
	else:
		var best_d2: float = 999999.0
		for ep in sim.enemy_pos:
			var d2: float = ep.distance_squared_to(p)
			if d2 < best_d2:
				best_d2 = d2
				face = (ep - p).normalized()

	if sim.char_id == "warrior":
		# Blade: 360° 横扫（逻辑就是整圈命中）——淡红整圈 + 扫过的一道光弧
		var arc_col := Color(1, 0.35, 0.35, alpha)
		draw_circle(p, r, Color(1, 0.35, 0.35, 0.12 * pct), true)
		draw_arc(p, r, 0.0, TAU, 48, Color(1, 0.4, 0.4, 0.55 * pct), width)
		# 扫击光弧随闪现推进，读成「转了一圈」
		var sweep_end: float = -PI * 0.5 + TAU * (1.0 - pct)
		draw_arc(p, r - 2.0, sweep_end - 1.1, sweep_end, 24, arc_col, width + 2.0)
		draw_circle(p, 4.0 * pct, arc_col, true)
	else:
		# 远程角色：枪口闪光（真正的攻击表现由飞行的子弹承担）
		var muzzle_col := Color(0.75, 0.9, 1.0, alpha)
		if sim.char_id == "hunter":
			muzzle_col = Color(0.85, 1.0, 0.9, alpha)
		elif sim.char_id == "priest":
			muzzle_col = Color(1.0, 0.9, 0.55, alpha)
		var muzzle: Vector2 = p + face * 18.0
		draw_circle(muzzle, 8.0 * pct, muzzle_col, true)
		draw_line(p + face * 10.0, p + face * 34.0, muzzle_col, width)
