extends SceneTree

## 阶段二截图：跑 main.tscn 若干帧，关掉管线编辑/暂停后抓 viewport 存 PNG。
## 用法：godot --path . --script tests/screenshot.gd

const OUT_DIR := "res://screenshots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("main.tscn 加载失败")
		quit(1)
		return
	var inst := scene.instantiate()
	root.add_child(inst)

	# 把可能打开的管线编辑器关掉，恢复战斗（main.tscn 根节点挂了 proto_view.gd）
	if inst.has_method("resume_from_editor"):
		inst.resume_from_editor()

	# 跑约 3 秒（180 帧 @60fps），让敌人成批刷出、AoE 打起来、宝石掉落
	for i in range(180):
		await process_frame

	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := OUT_DIR + "/stage2_battle.png"
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("截图保存失败: %d" % err)
		quit(1)
		return
	print("screenshot saved: ", path)
	quit(0)
