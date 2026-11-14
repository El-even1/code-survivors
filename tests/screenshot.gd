extends SceneTree

## 阶段二截图：跑 main.tscn 若干帧后抓 viewport 存 PNG。
## 用法：
##   godot --path . --script tests/screenshot.gd -- --char=warrior --lang=zh
##   godot --path . --script tests/screenshot.gd -- --char=warrior --lang=zh --backpack
##   godot --path . --script tests/screenshot.gd -- --char=warrior --lang=zh --boss
##   godot --path . --script tests/screenshot.gd -- --char=warrior --lang=zh --safe

const OUT_DIR := "res://screenshots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var mode := "battle"   # battle / backpack / boss / safe
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--char="):
			GameStateData.selected_char = arg.substr(7)
		elif arg.begins_with("--lang="):
			GameStateData.language = arg.substr(7)
		elif arg == "--backpack":
			mode = "backpack"
		elif arg == "--boss":
			mode = "boss"
		elif arg == "--safe":
			mode = "safe"

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

	if mode == "backpack":
		inst.sim.grant_block("mod_range")
		inst.sim.grant_block("mod_penetrate")
		inst.toggle_backpack()
		inst.backpack.editing_slot = 0
		inst.backpack.add_block("mod_range")
		for i in range(10):
			await process_frame
		suffix += "_backpack"
	elif mode == "boss":
		# 直接进 Boss 战：验证 Boss 实体、血条、阶段弹幕
		inst.sim.level_sim.start_boss("boss_1")
		for i in range(90):
			await process_frame
		suffix += "_boss"
	elif mode == "safe":
		# 直接进安全区：验证回血面板 + 继续按钮
		inst.sim.level_sim.start_sector("safe_zone")
		inst.sim.safe_zone_healed = false
		for i in range(20):
			await process_frame
		suffix += "_safe"
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
