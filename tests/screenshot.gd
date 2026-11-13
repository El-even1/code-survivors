extends SceneTree

## 阶段二截图：跑 main.tscn 若干帧后抓 viewport 存 PNG。
## 用法：
##   godot --path . --script tests/screenshot.gd -- --char=warrior --lang=zh
##   godot --path . --script tests/screenshot.gd -- --char=warrior --lang=zh --editor

const OUT_DIR := "res://screenshots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var want_editor := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--char="):
			GameStateData.selected_char = arg.substr(7)
		elif arg.begins_with("--lang="):
			GameStateData.language = arg.substr(7)
		elif arg == "--editor":
			want_editor = true

	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("main.tscn 加载失败")
		quit(1)
		return
	var inst := scene.instantiate()
	root.add_child(inst)

	if inst.has_method("resume_from_editor"):
		inst.resume_from_editor()

	# 跑约 2 秒让敌人生成逻辑跑起来
	for i in range(120):
		await process_frame

	# 截图专用：玩家周围注入一圈敌人，保证能抓到攻击瞬间（不改游戏逻辑）
	for i in range(8):
		var ang: float = TAU * float(i) / 8.0
		inst.sim.enemy_pos.append(inst.sim.player_pos + Vector2(cos(ang), sin(ang)) * 50.0)
		inst.sim.enemy_hp.append(2000.0)
		inst.sim.enemy_id.append(9000 + i)

	var suffix := "%s_%s" % [GameStateData.selected_char, GameStateData.language]

	if want_editor:
		# 打开管线编辑器（暂停态）验证编辑器 UI 文案
		inst._toggle_pause()
		for i in range(10):
			await process_frame
		suffix += "_editor"
	else:
		# 等到攻击瞬间再抓图，确保武器特效出现在画面里
		var got_flash := false
		for i in range(240):
			await process_frame
			if inst.sim.attack_flash > 0.10:
				got_flash = true
				break
		if not got_flash:
			push_warning("未捕捉到攻击瞬间，仍保存当前帧")

	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := OUT_DIR + "/stage2_battle_%s.png" % suffix
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("截图保存失败: %d" % err)
		quit(1)
		return
	print("screenshot saved: ", path)
	quit(0)
