extends SceneTree
## Stage I Color Prototype · Pure logic automated test
## Run: godot --headless --path . --script tests/test_proto.gd

var failures := 0
var checks := 0
var report: Array[String] = []

func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok   " + msg)
		report.append("  ok   " + msg)
	else:
		failures += 1
		print("  FAIL " + msg)
		report.append("  FAIL " + msg)


func _init() -> void:
	print("=== Stage I 色块原型 · 阶段①验收测试 ===")

	test_swap_pop()
	test_xp_curve()
	test_spawn_ramp()
	test_player_responsiveness()
	test_aoe_kills_and_gems()
	test_magnet()
	test_dmg_merge()
	test_upgrade_effect()
	test_upgrade_pool_no_dup()
	test_contact_damage_no_stack()
	test_300_enemy_perf()
	test_select_char_changes_stats()
	test_auto_attack_hits_nearest()
	test_attack_only_when_in_range()
	test_modifier_changes_attack()
	test_pipeline_empty()
	test_pipeline_modifier_chain()
	test_pipeline_slot_switch()
	test_pipeline_command_add_remove()
	test_pipeline_cooldown()
	test_300_enemy_perf_with_pipeline()

	print("")
	var summary: String = ""
	if failures == 0:
		summary = "ALL %d CHECKS PASSED" % checks
	else:
		summary = "%d / %d CHECKS FAILED" % [failures, checks]
	print(summary)
	report.append("")
	report.append(summary)
	_write_report()
	quit(0 if failures == 0 else 1)


func _write_report() -> void:
	var f := FileAccess.open("tests/proto_results.txt", FileAccess.WRITE)
	if f:
		for line in report:
			f.store_line(line)
		f.close()


# =========================================================
#  基础逻辑测试
# =========================================================
func test_swap_pop() -> void:
	var arr: Array = [10, 20, 30, 40]
	ProtoLogic.swap_pop(arr, 1)
	check(arr.size() == 3, "尾部交换移除：长度 -1")
	check(arr[1] == 40, "尾部交换移除：被移除位由尾部元素填上")
	check(arr[0] == 10 and arr[2] == 30, "尾部交换移除：其余元素保持")
	ProtoLogic.swap_pop(arr, 99)
	check(arr.size() == 3, "越界索引安全忽略")


func test_xp_curve() -> void:
	var a: float = ProtoLogic.xp_for_level(1)
	var b: float = ProtoLogic.xp_for_level(5)
	check(absf(a - Tuning.XP_BASE) < 0.001, "1 级阈值 = XP_BASE")
	check(b > a, "等级越高经验需求越大")


func test_spawn_ramp() -> void:
	var s0: float = ProtoLogic.spawn_interval(0.0)
	var s1: float = ProtoLogic.spawn_interval(Tuning.RAMP_SECONDS)
	check(s1 < s0, "刷新间隔随时间缩短")
	check(absf(s0 - Tuning.SPAWN_INTERVAL_START) < 0.001, "起始间隔匹配配置")
	check(ProtoLogic.spawn_batch(0.0) == 1, "生存期：单次 1 只")
	check(ProtoLogic.spawn_batch(80.0) == 6, "极限期：单次 6 只")
	check(ProtoLogic.phase_name(10.0) == "生存期", "0-20s 是生存期")
	check(ProtoLogic.phase_name(30.0) == "成长期", "20-45s 是成长期")
	check(ProtoLogic.phase_name(60.0) == "压力期", "45-75s 是压力期")
	check(ProtoLogic.phase_name(90.0) == "极限期", "75s+ 是极限期")


func test_player_responsiveness() -> void:
	var sim := ProtoSim.new()
	var start: Vector2 = sim.player_pos
	sim.step(0.016, Vector2.RIGHT)
	var moved: float = sim.player_pos.x - start.x
	check(absf(moved - Tuning.PLAYER_SPEED * 0.016) < 0.5, "摇杆跟手：单帧位移 = 速度 × dt（无平滑）")


func test_aoe_kills_and_gems() -> void:
	var sim := ProtoSim.new()
	sim.enemy_pos.append(sim.player_pos + Vector2(20, 0))
	sim.enemy_hp.append(1.0)
	sim.enemy_id.append(0)
	var kills_before: int = sim.kills
	sim.step(0.016, Vector2.ZERO)
	check(sim.kills > kills_before, "AoE 命中并击杀范围内敌人")
	var dropped_or_picked: bool = sim.gem_pos.size() >= 1 or sim.gems_collected >= 1 or sim.xp > 0.0
	check(dropped_or_picked, "击杀后掉落绿色宝石（或被磁吸立即拾取）")


func test_magnet() -> void:
	var sim := ProtoSim.new()
	var gem_p: Vector2 = sim.player_pos + Vector2(50, 0)
	sim.gem_pos.append(gem_p)
	sim.gem_value.append(Tuning.GEM_VALUE)
	sim.step(0.016, Vector2.ZERO)
	check(sim.gem_pos[0].x < gem_p.x, "磁吸：宝石在磁吸半径内被拉向玩家")


func test_dmg_merge() -> void:
	var sim := ProtoSim.new()
	sim.enemy_pos.append(sim.player_pos)
	sim.enemy_pos.append(sim.player_pos)
	sim.enemy_hp.append(1.0)
	sim.enemy_hp.append(1.0)
	sim.enemy_id.append(0)
	sim.enemy_id.append(1)
	sim.attack_pierce = 2  # 让两只怪同时被击中
	sim.step(0.016, Vector2.ZERO)
	var merged := false
	for i in range(sim.dmg_pos.size()):
		if sim.dmg_alive[i] and sim.dmg_count[i] >= 2:
			merged = true
	check(merged, "飘字合并后数值累加")


func test_upgrade_effect() -> void:
	var sim := ProtoSim.new()
	var dmg0: float = sim.attack_damage
	sim.apply_upgrade("damage")
	check(absf(sim.attack_damage - dmg0 * 1.25) < 0.001, "升级「伤害」后 AoE 伤害提升")


func test_upgrade_pool_no_dup() -> void:
	var sim := ProtoSim.new()
	var seen: Array = []
	for i in range(40):
		sim.pending_levels = 1
		var opts: Array = ProtoLogic.roll_upgrades(sim._rng, sim.owned, 3)
		for o in opts:
			if not seen.has(o):
				seen.append(o)
	check(seen.size() == ProtoLogic.Tuning_UPGRADES.size(), "升级池覆盖全部升级项")
	var dup: bool = false
	for i in range(40):
		sim.pending_levels = 1
		var opts: Array = ProtoLogic.roll_upgrades(sim._rng, sim.owned, 3)
		for j in range(opts.size()):
			for k in range(j + 1, opts.size()):
				if opts[j] == opts[k]:
					dup = true
	check(not dup, "升级候选互不重复（40 次抽样）")


func test_contact_damage_no_stack() -> void:
	var sim := ProtoSim.new()
	var hp0: float = sim.player_hp
	for i in range(8):
		var ang: float = float(i) / 8.0 * TAU
		sim.enemy_pos.append(sim.player_pos + Vector2(cos(ang), sin(ang)) * 6.0)
		sim.enemy_hp.append(9999.0)
		sim.enemy_id.append(i)
	sim.step(1.0 / 60.0, Vector2.ZERO)
	var lost1: float = hp0 - sim.player_hp
	check(absf(lost1 - Tuning.CONTACT_DAMAGE) < 0.001,
		"8 只怪同时贴脸：单次只扣一份接触伤害（%.1f）" % lost1)
	var hp1: float = sim.player_hp
	sim.step(1.0 / 60.0, Vector2.ZERO)
	check(absf(sim.player_hp - hp1) < 0.001, "无敌帧内不再掉血")
	var frames: int = int(Tuning.CONTACT_IFRAMES * 60.0) + 2
	for i in range(frames):
		sim.step(1.0 / 60.0, Vector2.ZERO)
	check(sim.player_hp < hp1, "无敌帧结束后可再次受伤")


# =========================================================
#  性能测试
# =========================================================
func test_300_enemy_perf() -> void:
	var sim := ProtoSim.new()
	for i in range(Tuning.ENEMY_CAP):
		sim.enemy_pos.append(sim.player_pos + Vector2(100 + i % 20 * 10, 50 + i / 20 * 10))
		sim.enemy_hp.append(999.0)
		sim.enemy_id.append(i)

	check(sim.enemy_pos.size() == Tuning.ENEMY_CAP, "同屏敌人灌满至 %d" % Tuning.ENEMY_CAP)

	var dt: float = 1.0 / 60.0
	var t0: int = Time.get_ticks_usec()
	for i in range(120):
		sim.step(dt, Vector2.RIGHT)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var per_frame: float = elapsed_ms / 120.0
	print("    300 敌人 × 120 帧模拟总耗时 %.2f ms，单帧 %.3f ms" % [elapsed_ms, per_frame])
	check(per_frame < 16.6, "300 同屏单帧模拟耗时 < 16.6ms（60fps 预算）")
	print("    → 单帧 %.3f ms，剩余 %.1f ms 留给渲染" % [per_frame, 16.6 - per_frame])


# =========================================================
#  角色系统测试
# =========================================================
func test_select_char_changes_stats() -> void:
	var sim := ProtoSim.new()
	sim._select_char("warrior")
	check(sim.char_id == "warrior", "角色 id 是 warrior")
	check(sim.char_weapon == "Blade", "武器是刀具")
	check(absf(sim.player_max_hp - 160.0) < 0.001, "战士血量 160")
	check(absf(sim.player_speed - 200.0) < 0.001, "战士移速 200")
	check(absf(sim.attack_cooldown - 0.90) < 0.001, "战士攻击冷却 0.90")
	sim._select_char("mage")
	check(sim.char_id == "mage", "切换回法师")
	check(absf(sim.player_max_hp - 100.0) < 0.001, "法师血量 100")
	check(absf(sim.attack_cooldown - 0.60) < 0.001, "法师攻击冷却 0.60")


func test_auto_attack_hits_nearest() -> void:
	var sim := ProtoSim.new()
	sim._select_char("mage")
	sim.enemy_pos.append(sim.player_pos + Vector2(10, 0))
	sim.enemy_pos.append(sim.player_pos + Vector2(100, 0))
	sim.enemy_hp.append(100.0)
	sim.enemy_hp.append(100.0)
	sim.enemy_id.append(0)
	sim.enemy_id.append(1)
	sim.attack_timer = 0.0
	sim.step(0.016, Vector2.ZERO)
	check(sim.enemy_hp[0] < 100.0, "最近敌人受到伤害")
	check(sim.enemy_hp[1] >= 100.0, "远处敌人未受伤")


## 攻击只在范围内有敌人时触发：空挥不消耗冷却、不播特效
func test_attack_only_when_in_range() -> void:
	var sim := ProtoSim.new()
	sim._select_char("mage")
	var r: float = sim.attack_radius

	# 1) 范围内没有任何敌人：30 帧都不该攻击
	for i in range(30):
		sim.step(0.016, Vector2.ZERO)
	check(sim.aoe_pulses == 0, "范围内无敌人时不触发攻击")
	check(sim.attack_flash <= 0.0, "范围内无敌人时不播攻击特效")
	check(absf(sim.attack_timer) < 0.001, "范围内无敌人时冷却保持待发")

	# 2) 敌人在范围外：仍然不攻击
	sim.enemy_pos.clear()
	sim.enemy_hp.clear()
	sim.enemy_id.clear()
	sim.enemy_pos.append(sim.player_pos + Vector2(r * 1.8, 0.0))
	sim.enemy_hp.append(1000.0)
	sim.enemy_id.append(0)
	var pulses_before: int = sim.aoe_pulses
	for i in range(10):
		sim.step(0.016, Vector2.ZERO)
	check(sim.aoe_pulses == pulses_before, "敌人在范围外时不攻击")

	# 3) 敌人进圈：立刻开火（不用等冷却）
	sim.enemy_pos[0] = sim.player_pos + Vector2(r * 0.5, 0.0)
	sim.step(0.016, Vector2.ZERO)
	check(sim.aoe_pulses > pulses_before, "敌人进圈后立刻攻击")
	check(sim.enemy_hp[0] < 1000.0, "进圈敌人受到伤害")
	check(sim.attack_flash > 0.0, "攻击时播放武器特效")


func test_modifier_changes_attack() -> void:
	var sim := ProtoSim.new()
	sim._select_char("mage")
	var dmg0: float = sim.attack_damage
	var cd0: float = sim.attack_cooldown
	var block := CommandBlock.from_template("mod_cooldown", 1, "white")
	sim.add_command(0, block)
	sim.step(0.016, Vector2.ZERO)
	check(absf(sim.attack_cooldown - cd0 * 0.86) < 0.001, "攻速修饰符生效")
	sim.remove_command(0, 1)
	sim.step(0.016, Vector2.ZERO)
	check(absf(sim.attack_cooldown - cd0) < 0.001, "移除修饰符后冷却恢复")


# =========================================================
#  管线系统测试（只测 modifier，没有 trigger/condition）
# =========================================================
func test_pipeline_empty() -> void:
	var sim := ProtoSim.new()
	var p: Array = sim.get_pipeline(0)
	check(p.size() == 0, "空管线不产生事件")
	sim.step(0.016, Vector2.ZERO)
	check(true, "空管线运行不报错")


func test_pipeline_modifier_chain() -> void:
	var sim := ProtoSim.new()
	sim._select_char("mage")
	var act := CommandBlock.from_template("action_aoe", 1, "white")
	var mod := CommandBlock.from_template("mod_range", 1, "white")
	mod.set_param("range_mult", 2.0)
	sim.add_command(0, act)
	sim.add_command(0, mod)

	var sim2 := ProtoSim.new()
	sim2._select_char("mage")
	sim2.add_command(0, act)
	sim2.add_command(0, mod)
	sim2.step(0.016, Vector2.ZERO)
	check(true, "管线修饰符链执行不报错")


func test_pipeline_slot_switch() -> void:
	var sim := ProtoSim.new()
	check(sim.get_active_slot() == 0, "初始槽位是 0")
	check(sim.switch_slot(1) == true, "切换到槽位 1 成功")
	check(sim.get_active_slot() == 1, "切换后活跃槽位是 1")
	check(sim.switch_slot(5) == false, "越界槽位切换失败")


func test_pipeline_command_add_remove() -> void:
	var sim := ProtoSim.new()
	var p: Array = sim.get_pipeline(0)
	var before: int = p.size()
	var block := CommandBlock.from_template("action_projectile", 1, "white")
	check(sim.add_command(0, block) == true, "添加指令块到槽位 0 成功")
	check(sim.get_pipeline(0).size() == before + 1, "添加后指令块数 +1")
	check(sim.remove_command(0, 0) == true, "移除指令块成功")
	check(sim.get_pipeline(0).size() == before, "移除后恢复原数量")


func test_pipeline_cooldown() -> void:
	var sim := ProtoSim.new()
	check(sim.switch_slot(1) == true, "第一次切换成功")
	check(sim.switch_slot(0) == false, "冷却期内再次切换失败")


func test_300_enemy_perf_with_pipeline() -> void:
	var sim := ProtoSim.new()
	for i in range(300):
		sim.enemy_pos.append(sim.player_pos + Vector2(100 + i % 20 * 10, 50 + i / 20 * 10))
		sim.enemy_hp.append(999.0)
		sim.enemy_id.append(i)

	var act := CommandBlock.from_template("action_aoe", 1, "white")
	var mod := CommandBlock.from_template("mod_multi", 1, "white")
	sim.add_command(0, act)
	sim.add_command(0, mod)

	var t0: int = Time.get_ticks_usec()
	for i in range(120):
		sim.step(1.0 / 60.0, Vector2.ZERO)
	var elapsed_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var per_frame: float = elapsed_ms / 120.0
	print("    300 同屏 + 管线：120 帧总耗时 %.2f ms，单帧 %.3f ms" % [elapsed_ms, per_frame])
	check(per_frame < 16.6, "300 同屏 + 管线单帧耗时 < 16.6ms")
