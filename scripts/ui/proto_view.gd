extends Node2D

## Stage I Color Prototype · Render Layer
## Only "see": reads ProtoSim snapshot, draws with placeholder color blocks
## All drawing uses draw_* single batch, avoids per-frame node creation (doc: object pool + draw call)

var sim

## AoE visual pulse
var pulse_t := -1.0
const PULSE_LIFE := 0.18

## Camera (world-space viewport top-left)
var camera_pos := Vector2.ZERO
@onready var cam2d: Camera2D = get_node("Camera2D")

var stat_label: Label
var result_label: Label
var upgrade_panel: CanvasLayer
var upgrade_buttons: Array = []

## Pause & pipeline editor
var pause_btn: Button
var slot_buttons: Array = []
var pipeline_editor
var pipeline_hud
var is_paused := false
var _current_options: Array = []

## Font (default font, prototype phase no resources)
func _ready() -> void:
	sim = ProtoSim.new()
	camera_pos = sim.player_pos - Vector2(Tuning.VIEW_W * 0.5, Tuning.VIEW_H * 0.5)
	cam2d.global_position = sim.player_pos
	_build_ui()

	# Pipeline editor (pause/safe zone opens)
	var pipeline_script = load("res://scripts/ui/pipeline_editor.gd")
	if pipeline_script != null:
		pipeline_editor = pipeline_script.new()
		pipeline_editor.init(sim)
		add_child(pipeline_editor)

	# Right-bottom mini pipeline line (battle real-time flash, let player see pipeline running)
	var hud_script = load("res://scripts/ui/pipeline_hud.gd")
	if hud_script != null:
		pipeline_hud = hud_script.new()
		pipeline_hud.init(sim)
		pipeline_hud.size = Vector2(Tuning.VIEW_W, Tuning.VIEW_H)
		pipeline_hud.position = Vector2.ZERO
		add_child(pipeline_hud)


## Initialize: build UI, build pipeline editor
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	stat_label = Label.new()
	stat_label.position = Vector2(18, 14)
	stat_label.add_theme_font_size_override("font_size", 20)
	stat_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	layer.add_child(stat_label)

	var hint := Label.new()
	hint.text = "WASD / Arrow keys to move"
	hint.position = Vector2(18, 46)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.6))
	layer.add_child(hint)

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
	title.text = "Upgrade! Choose one"
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
	pause_btn.text = "|| Pause"
	pause_btn.position = Vector2(Tuning.VIEW_W - 130, 18)
	pause_btn.size = Vector2(110, 36)
	pause_btn.add_theme_font_size_override("font_size", 16)
	pause_btn.pressed.connect(_toggle_pause)
	layer.add_child(pause_btn)

	# Slot switch buttons (bottom-left, usable in combat)
	var slot_y := Tuning.VIEW_H - 70
	for i in range(3):
		var btn := Button.new()
		btn.text = "Slot %d" % (i + 1)
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


## Toggle pause
func _toggle_pause() -> void:
	is_paused = not is_paused
	if is_paused:
		pause_btn.text = "> Resume"
		pipeline_editor.show_editor(sim.get_active_slot())
	else:
		pause_btn.text = "|| Pause"
		pipeline_editor.hide_editor()


## Edit button clicked in editor resumes
func resume_from_editor() -> void:
	is_paused = false
	pause_btn.text = "|| Pause"
	pipeline_editor.hide_editor()


func _on_switch_slot(slot: int) -> void:
	if is_paused:
		# Pause: switch edit slot
		pipeline_editor.show_editor(slot)
	else:
		# Combat: switch active slot
		if sim.switch_slot(slot):
			_update_stat()


## Keyboard pause: Esc
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# Freeze world when upgrade panel or pipeline editor open
	if upgrade_panel.visible or pipeline_editor.editor_visible():
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
			result_label.text = "Killed  Kills %d" % sim.kills

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
	queue_redraw()


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
	var slot_tag := "Slot %d" % (sim.get_active_slot() + 1)
	if is_paused:
		slot_tag += " [Pause]"
	stat_label.text = "%s  HP %d/%d   Lv%d   XP %d/%d   Kills %d   OnScreen %d   Phase %s   %.1fs" % [
		slot_tag,
		int(sim.player_hp), int(sim.player_max_hp),
		sim.level, int(sim.xp), int(sim.xp_to_next),
		sim.kills, sim.enemy_pos.size(), ProtoLogic.phase_name(sim.elapsed), sim.elapsed
	]


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
			btn.text = "%s\nLv %d -> %d" % [info["name"], lv, lv + 1]
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

	# Red square horde (draw viewport only, skip off-screen)
	_raster_enemies(vp.grow(pad))

	# Blue square player (invulnerable frame flash)
	var half_p := Tuning.PLAYER_SIZE * 0.5
	var pcol := Color(0.28, 0.55, 1.0)
	if sim.iframe_timer > 0.0 and int(sim.iframe_timer * 20.0) % 2 == 0:
		pcol = Color(0.75, 0.85, 1.0)
	draw_rect(Rect2(sim.player_pos - Vector2(half_p, half_p),
		Vector2(Tuning.PLAYER_SIZE, Tuning.PLAYER_SIZE)), pcol, true)
	draw_rect(Rect2(sim.player_pos - Vector2(half_p, half_p),
		Vector2(Tuning.PLAYER_SIZE, Tuning.PLAYER_SIZE)), Color(0.7, 0.85, 1.0), false, 1.5)

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
