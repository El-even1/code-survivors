extends SceneTree

## 开始页 / 选人界面截图（中英文各一张）
## 用法：godot --path . --script tests/screenshot_start.gd

const OUT_DIR := "res://screenshots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var scene: PackedScene = load("res://scenes/start.tscn")
	if scene == null:
		push_error("start.tscn 加载失败")
		quit(1)
		return
	var inst := scene.instantiate()
	root.add_child(inst)
	await process_frame

	# 中文
	inst.set_language("zh")
	for i in range(10):
		await process_frame
	await _capture(OUT_DIR + "/start_select_zh.png")

	# English
	inst.set_language("en")
	for i in range(10):
		await process_frame
	await _capture(OUT_DIR + "/start_select_en.png")

	quit(0)


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("截图保存失败: %s (%d)" % [path, err])
		quit(1)
		return
	print("screenshot saved: ", path)
