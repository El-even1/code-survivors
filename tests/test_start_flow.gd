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

	# 3. 多语言切换（中 / 英）
	start_view.set_language("zh")
	check(GameStateData.language == "zh", "语言设置为中文")
	check(I18n.ui("start") == "开 始 游 戏", "中文开始按钮文案")
	check(I18n.ui("lang_switch") == "English", "中文界面显示 English 切换按钮")
	check(I18n.char_info("mage", "name") == "法师", "中文角色名")
	check(I18n.char_info("mage", "tag") == "远程 · 追踪弹", "中文角色定位")
	start_view.toggle_language()
	check(GameStateData.language == "en", "切换后语言为英文")
	check(I18n.ui("start") == "S T A R T", "英文开始按钮文案")
	check(I18n.ui("lang_switch") == "中文", "英文界面显示中文切换按钮")
	check(I18n.char_info("mage", "name") == "Mage", "英文角色名")
	check(I18n.char_info("warrior", "passive").begins_with("Melee Resist"), "英文被动文案")
	# 管线 / 战斗 HUD 文案也要跟随语言
	check(I18n.ui("hud_pause") == "|| Pause", "英文暂停按钮")
	check(I18n.block_name("action_melee") == "Melee Cleave", "英文指令块名")
	check(I18n.kind_label("action") == "Action", "英文类别名")
	check(I18n.upgrade_name("damage") == "Damage +25%", "英文升级名")
	check(I18n.phase_name(10.0) == "Survival", "英文阶段名")
	start_view.toggle_language()
	check(GameStateData.language == "zh", "再切换回中文")
	check(I18n.ui("hud_pause") == "|| 暂停", "中文暂停按钮")
	check(I18n.block_name("action_melee") == "近战横扫", "中文指令块名")
	check(I18n.kind_label("action") == "主动", "中文类别名")
	check(I18n.upgrade_name("damage") == "伤害 +25%", "中文升级名")
	check(I18n.phase_name(10.0) == "生存期", "中文阶段名")
	start_view.set_language("xx")
	check(GameStateData.language == "zh", "非法语言值被忽略")

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

	# 5. 背包：管线编辑入口；暂停只暂停、不再改管线
	check(battle2.backpack != null, "战斗场景有背包")
	check(battle2.backpack.is_open() == false, "背包默认关闭")
	battle2._toggle_pause()
	check(battle2.is_paused == true, "Esc 暂停生效")
	check(battle2.backpack.is_open() == false, "暂停不再打开管线编辑")
	battle2._toggle_pause()
	check(battle2.is_paused == false, "再按 Esc 恢复")

	battle2.toggle_backpack()
	check(battle2.backpack.is_open() == true, "B 打开背包")
	battle2.backpack.editing_slot = 0
	check(battle2.backpack.add_block("mod_range") == false, "没有掉落不能装备指令块")
	battle2.sim.grant_block("mod_range")
	check(battle2.backpack.add_block("mod_range") == false, "角色专属块不能跨角色装备")
	battle2.sim.grant_block("mod_penetrate")
	var mods_before: int = battle2.sim.slot_modifier_ids(0).size()
	check(battle2.backpack.add_block("mod_penetrate") == true, "拾取后可以装备通用块")
	check(battle2.sim.slot_modifier_ids(0).size() == mods_before + 1, "修饰槽多了一个块")
	check(battle2.sim.attack_pierce >= 2, "装备穿透块后攻击数值变化（效果可见）")
	battle2.backpack.on_unequip_socket(mods_before + 1)
	check(battle2.sim.slot_modifier_ids(0).size() == mods_before, "卸下后修饰槽恢复")
	battle2.toggle_backpack()
	check(battle2.backpack.is_open() == false, "再按 B 关闭背包")

	battle2.queue_free()
	await process_frame

	print("")
	if failures == 0:
		print("ALL %d CHECKS PASSED" % checks)
	else:
		print("%d / %d CHECKS FAILED" % [failures, checks])
	quit(0 if failures == 0 else 1)
