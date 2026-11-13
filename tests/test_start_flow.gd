extends SceneTree
## 开始页 → 选人 → 战斗 全流程测试
## Run: godot --headless --path . --script tests/test_start_flow.gd

var failures := 0
var checks := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   " + msg)
	else:
		failures += 1
		print("  FAIL " + msg)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Start / Character Select Flow Tests ===")

	# 1. 选人界面：默认选中与左右循环
	var start_scene: PackedScene = load("res://scenes/start.tscn")
	check(start_scene != null, "start.tscn 可加载")
	var start_view = start_scene.instantiate()
	root.add_child(start_view)
	await process_frame

	check(start_view.get_selected_id() == "mage", "默认选中法师")
	start_view.cycle_selection(1)
	check(start_view.get_selected_id() == "warrior", "右移选中战士")
	start_view.cycle_selection(-1)
	check(start_view.get_selected_id() == "mage", "左移回到法师")
	start_view.cycle_selection(-1)
	check(start_view.get_selected_id() == "priest", "左移越界回绕到牧师")
	start_view.cycle_selection(1)
	check(start_view.get_selected_id() == "mage", "右移越界回绕到法师")

	# 2. 提交选择写入全局状态
	check(start_view.commit_selection() == "mage", "commit_selection 返回选中角色")
	check(GameStateData.selected_char == "mage", "全局状态记录法师")
	start_view.cycle_selection(1)
	check(start_view.commit_selection() == "warrior", "重新提交为战士")
	check(GameStateData.selected_char == "warrior", "全局状态更新为战士")
	start_view.queue_free()
	await process_frame

	# 3. 战斗场景读取全局状态并应用角色属性
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	check(main_scene != null, "main.tscn 可加载")
	var battle = main_scene.instantiate()
	root.add_child(battle)
	await process_frame

	check(battle.sim.char_id == "warrior", "战斗场景使用战士")
	check(absf(battle.sim.player_max_hp - 160.0) < 0.001, "战士血量 160")
	check(battle.sim.char_weapon == "Blade", "战士武器 Blade")
	var p0: Array = battle.sim.get_pipeline(0)
	check(p0.size() == 1, "战士默认管线 1 个指令块")
	check(p0[0].id == "action_melee", "战士默认指令块是近战")

	# 4. 换法师再开一局，确认角色切换生效
	battle.queue_free()
	await process_frame
	GameStateData.selected_char = "mage"
	var battle2 = main_scene.instantiate()
	root.add_child(battle2)
	await process_frame
	check(battle2.sim.char_id == "mage", "第二局使用法师")
	check(absf(battle2.sim.player_max_hp - 100.0) < 0.001, "法师血量 100")
	var p0m: Array = battle2.sim.get_pipeline(0)
	check(p0m.size() == 1 and p0m[0].id == "action_projectile", "法师默认指令块是投射物")
	battle2.queue_free()
	await process_frame

	print("")
	if failures == 0:
		print("ALL %d CHECKS PASSED" % checks)
	else:
		print("%d / %d CHECKS FAILED" % [failures, checks])
	quit(0 if failures == 0 else 1)
