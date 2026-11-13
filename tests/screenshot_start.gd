extends SceneTree

## 开始页 / 选人界面截图
## 用法：godot --path . --script tests/screenshot_start.gd

const OUT_PATH := "res://screenshots/start_select.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))

	var scene: PackedScene = load("res://scenes/start.tscn")
	if scene == null:
		push_error("start.tscn 加载失败")
		quit(1)
		return
	var inst := scene.instantiate()
	root.add_child(inst)

	# 等几帧让布局与绘制稳定（选中态呼吸动画也走一两帧）
	for i in range(20):
		await process_frame

	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var err := img.save_png(ProjectSettings.globalize_path(OUT_PATH))
	if err != OK:
		push_error("截图保存失败: %d" % err)
		quit(1)
		return
	print("screenshot saved: ", OUT_PATH)
	quit(0)
