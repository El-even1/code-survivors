extends SceneTree
## 阶段①色块原型 · 纯逻辑自动化测试
## 运行：godot --headless --path . --script tests/test_proto.gd
##
## 验证文档里点名的验收点：
##  - 300 同屏不掉帧（性能预算：单帧模拟耗时）
##  - 摇杆跟手（无加速平滑）
##  - 自动攻击“我在变强”感（AoE 命中、升级后伤害提升）
##  - 绿宝石“吸尘器”感（磁吸半径内被吸走）
##  - 飘字合并（×N）
##  - 尾部交换移除正确性

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
	print("=== 幸存者 色块原型 · 阶段①验收测试 ===")

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
	test_pipeline_empty()
	test_pipeline_trigger_aoe()
	test_pipeline_condition_blocks()
	test_pipeline_modifier_chain()
	test_pipeline_slot_switch()
	test_pipeline_command_add_remove()
	test_pipeline_cooldown()
	test_300_enemy_perf_with_pipeline()

	print("")
	var summary := ""
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
	# 索引1 被尾部元素 40 覆盖，长度 3
	check(arr.size() == 3, "尾部交换移除：长度 -1")
	check(arr[1] == 40, "尾部交换移除：被移除位由尾部元素填上")
	check(arr[0] == 10 and arr[2] == 30, "尾部交换移除：其余元素保持")
	ProtoLogic.swap_pop(arr, 99)
	check(arr.size() == 3, "越界索引安全忽略")


func test_xp_curve() -> void:
	var a := ProtoLogic.xp_for_level(1)
	var b := ProtoLogic.xp_for_level(5)
	check(absf(a - Tuning.XP_BASE) < 0.001, "1级阈值 = XP_BASE")
	check(b > a, "等级越高经验需求越大")


func test_spawn_ramp() -> void:
	var s0 := ProtoLogic.spawn_interval(0.0)
	var s1 := ProtoLogic.spawn_interval(Tuning.RAMP_SECONDS)
	check(s1 < s0, "刷新间隔随时间缩短")
	check(absf(s0 - Tuning.SPAWN_INTERVAL_START) < 0.001, "起始间隔匹配配置")
	check(ProtoLogic.spawn_batch(0.0) == 1, "生存期：单次 1 只")
	check(ProtoLogic.spawn_batch(80.0) == 6, "极限期：单次 6 只")
	check(ProtoLogic.phase_name(10.0) == "生存期", "0-20s 为生存期")
	check(ProtoLogic.phase_name(30.0) == "成长期", "20-45s 为成长期")
	check(ProtoLogic.phase_name(60.0) == "压力期", "45-75s 为压力期")
	check(ProtoLogic.phase_name(90.0) == "极限期", "75s+ 为极限期")


func test_player_responsiveness() -> void:
	# 文档：摇杆跟手 → 单帧位移应恰好 = speed * dt（无加速平滑）
	var sim := ProtoSim.new(1)
	var start := sim.player_pos
	sim.step(0.016, Vector2.RIGHT)
	var moved := sim.player_pos.x - start.x
	check(absf(moved - Tuning.PLAYER_SPEED * 0.016) < 0.5, "摇杆跟手：单帧位移 = 速度 × dt（无平滑）")


func test_aoe_kills_and_gems() -> void:
	var sim := ProtoSim.new(2)
	# 手动放一只敌人在 AoE 范围内，血量调低保证一刀死
	sim.enemy_pos.append(sim.player_pos + Vector2(20, 0))
	sim.enemy_hp.append(1.0)
	sim.enemy_id.append(0)
	var kills_before := sim.kills
	sim.step(0.016, Vector2.ZERO)
	check(sim.kills > kills_before, "AoE 命中并击杀范围内敌人")
	# 掉落的宝石就在玩家脚下 → 同帧可能已被磁吸拾取，故用「掉落 or 已拾取」判定
	var dropped_or_picked := sim.gem_pos.size() >= 1 or sim.gems_collected >= 1 or sim.xp > 0.0
	check(dropped_or_picked, "击杀后掉落绿色宝石（或被磁吸立即拾取）")


func test_magnet() -> void:
	var sim := ProtoSim.new(3)
	# 宝石在磁吸半径内但拾取半径外 → 应被拉向玩家
	var gem_p := sim.player_pos + Vector2(50, 0)
	sim.gem_pos.append(gem_p)
	sim.gem_value.append(Tuning.GEM_VALUE)
	sim.step(0.016, Vector2.ZERO)
	# 宝石应朝玩家方向移动（x 坐标减小）
	check(sim.gem_pos[0].x < gem_p.x, "磁吸：宝石在磁吸半径内被拉向玩家")


func test_dmg_merge() -> void:
	var sim := ProtoSim.new(4)
	# 两次 AoE 打中同一点应合并成 ×2
	sim.enemy_pos.append(sim.player_pos)
	sim.enemy_pos.append(sim.player_pos)
	sim.enemy_hp.append(1.0)
	sim.enemy_hp.append(1.0)
	sim.enemy_id.append(0)
	sim.enemy_id.append(1)
	sim.step(0.016, Vector2.ZERO)
	# 飘字应出现一个 ×2 合并条
	var merged := false
	for i in range(sim.dmg_pos.size()):
		if sim.dmg_alive[i] and sim.dmg_count[i] >= 2:
			merged = true
	check(merged, "飘字合并后数值累加")


func test_upgrade_effect() -> void:
	var sim := ProtoSim.new(5)
	var dmg0 := sim.aoe_damage
	sim.apply_upgrade("damage")
	check(absf(sim.aoe_damage - dmg0 * 1.25) < 0.001, "升级「伤害」后 AoE 伤害提升")


func test_upgrade_pool_no_dup() -> void:
	var sim := ProtoSim.new(6)
	var seen: Array = []
	for i in range(40):
		sim.pending_levels = 1
		var opts := ProtoLogic.roll_upgrades(sim._rng, sim.owned, 3)
		for o in opts:
			if not seen.has(o):
				seen.append(o)
	check(seen.size() == ProtoLogic.Tuning_UPGRADES.size(), "升级候选池应覆盖全部升级项")
	# 候选互不重复
	var dup := false
	for i in range(40):
		sim.pending_levels = 1
		var opts := ProtoLogic.roll_upgrades(sim._rng, sim.owned, 3)
		for j in range(opts.size()):
			for k in range(j + 1, opts.size()):
				if opts[j] == opts[k]:
					dup = true
	check(not dup, "升级候选互不重复（40 次抽样）")


func test_contact_damage_no_stack() -> void:
	# 关键：多只怪同时贴脸，不应把伤害按怪数逐帧叠加（否则必秒死）
	var sim := ProtoSim.new(7)
	var hp0 := sim.player_hp
	# 放 8 只怪把玩家围住
	for i in range(8):
		var ang := float(i) / 8.0 * TAU
		sim.enemy_pos.append(sim.player_pos + Vector2(cos(ang), sin(ang)) * 6.0)
		sim.enemy_hp.append(9999.0)
		sim.enemy_id.append(i)
	sim.step(1.0 / 60.0, Vector2.ZERO)
	var lost1 := hp0 - sim.player_hp
	check(absf(lost1 - Tuning.CONTACT_DAMAGE) < 0.001,
		"8 只怪同时贴脸：单次只扣一份接触伤害（%.1f）" % lost1)
	# 无敌帧内继续贴着不掉血
	var hp1 := sim.player_hp
	sim.step(1.0 / 60.0, Vector2.ZERO)
	check(absf(sim.player_hp - hp1) < 0.001, "无敌帧内不再掉血")
	# 无敌帧结束后才会再次受伤
	var frames := int(Tuning.CONTACT_IFRAMES * 60.0) + 2
	for i in range(frames):
		sim.step(1.0 / 60.0, Vector2.ZERO)
	check(sim.player_hp < hp1, "无敌帧结束后可再次受伤")


# =========================================================
#  性能测试
# =========================================================
func test_300_enemy_perf() -> void:
	var sim := ProtoSim.new(2)
	for i in range(Tuning.ENEMY_CAP):
		sim.enemy_pos.append(sim.player_pos + Vector2(100 + i % 20 * 10, 50 + i / 20 * 10))
		sim.enemy_hp.append(999.0)
		sim.enemy_id.append(i)

	check(sim.enemy_pos.size() == Tuning.ENEMY_CAP, "同屏敌人灌满至 %d" % Tuning.ENEMY_CAP)

	# 跑 120 帧（约 2 秒 @60fps），统计模拟耗时
	var dt := 1.0 / 60.0
	var t0 := Time.get_ticks_usec()
	for i in range(120):
		sim.step(dt, Vector2.RIGHT)
	var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var per_frame := elapsed_ms / 120.0
	print("    300 敌人 × 120 帧模拟总耗时 %.2f ms，单帧 %.3f ms" % [elapsed_ms, per_frame])
	check(per_frame < 16.6, "300 同屏单帧模拟耗时 < 16.6ms（60fps 预算）")
	print("    → 单帧 %.3f ms，剩余 %.1f ms 留给渲染" % [per_frame, 16.6 - per_frame])


# =========================================================
#  管线系统测试
# =========================================================
func test_pipeline_empty() -> void:
	# 空管线不应产生事件
	var p_script := load("res://scripts/core/pipeline.gd")
	var p: RefCounted = p_script.new()
	p.name = "空管线"
	var sim := ProtoSim.new(1)
	var events: Array = p.execute(sim, 0.016)
	check(events.size() == 0, "空管线不产生事件")


func test_pipeline_trigger_aoe() -> void:
	# 触发器：最近敌人 → 动作：白圈AoE，应产生 aoe 事件
	var p_script := load("res://scripts/core/pipeline.gd")
	var p: RefCounted = p_script.new()
	var trig := CommandBlock.from_template("trigger_nearest", 1, "白")
	var act := CommandBlock.from_template("action_aoe", 1, "白")
	p.blocks.append(trig)
	p.blocks.append(act)

	var sim := ProtoSim.new(1)
	sim.enemy_pos.append(sim.player_pos + Vector2(10, 0))
	sim.enemy_hp.append(999.0)
	sim.enemy_id.append(0)

	var events: Array = p.execute(sim, 0.016)
	check(events.size() >= 1, "管线触发应产生至少1个事件")
	var ev0: Dictionary = events[0]
	check(ev0.has("type") and ev0["type"] == "aoe", "事件类型应为 aoe")


func test_pipeline_condition_blocks() -> void:
	# 条件不通过时，整条执行链中断
	var p_script := load("res://scripts/core/pipeline.gd")
	var p: RefCounted = p_script.new()
	var trig := CommandBlock.from_template("trigger_nearest", 1, "白")
	var cond := CommandBlock.from_template("cond_dist_lt_300", 1, "白")
	var act := CommandBlock.from_template("action_aoe", 1, "白")
	p.blocks.append(trig)
	p.blocks.append(cond)
	p.blocks.append(act)

	var sim := ProtoSim.new(1)
	sim.enemy_pos.append(sim.player_pos + Vector2(1000, 0))
	sim.enemy_hp.append(999.0)
	sim.enemy_id.append(0)

	var events: Array = p.execute(sim, 0.016)
	check(events.size() == 0, "条件不通过时执行链中断，不应产生事件")


func test_pipeline_modifier_chain() -> void:
	# 修饰符应作用于前置动作事件
	var p_script := load("res://scripts/core/pipeline.gd")
	var p: RefCounted = p_script.new()
	var trig := CommandBlock.from_template("trigger_nearest", 1, "白")
	var act := CommandBlock.from_template("action_aoe", 1, "白")
	var mod := CommandBlock.from_template("mod_range", 1, "白")
	mod.set_param("range_mult", 2.0)
	p.blocks.append(trig)
	p.blocks.append(act)
	p.blocks.append(mod)

	var sim := ProtoSim.new(1)
	sim.enemy_pos.append(sim.player_pos + Vector2(10, 0))
	sim.enemy_hp.append(999.0)
	sim.enemy_id.append(0)

	var events: Array = p.execute(sim, 0.016)
	check(events.size() >= 1, "应产生事件")
	var ev: Dictionary = events[0]
	check(absf(float(ev["radius"]) - 216.0) < 0.01, "mod_range 修饰符应将范围乘以 2.0")


func test_pipeline_slot_switch() -> void:
	# 槽位切换：初始槽位0，切换到槽位1后 active_slot 应变
	var sim := ProtoSim.new(1)
	check(sim.get_active_slot() == 0, "初始槽位应为0")
	check(sim.switch_slot(1) == true, "切换到槽位1应成功")
	check(sim.get_active_slot() == 1, "切换后活跃槽位应为1")
	check(sim.switch_slot(5) == false, "越界槽位切换应失败")


func test_pipeline_command_add_remove() -> void:
	# 指令块增删（槽位0自带默认管线2块）
	var sim := ProtoSim.new(1)
	var p: RefCounted = sim.get_pipeline(0)
	var before: int = p.blocks.size()
	check(before >= 2, "槽位0自带默认管线（%d 块）" % before)
	var block := CommandBlock.from_template("action_projectile", 1, "白")
	check(sim.add_command(0, block) == true, "添加指令块到槽位0应成功")
	check(p.blocks.size() == before + 1, "添加后指令块数 +1")
	check(sim.remove_command(0, 0) == true, "移除指令块应成功")
	check(p.blocks.size() == before, "移除后恢复原数量")


func test_pipeline_cooldown() -> void:
	# 槽位切换有冷却
	var sim := ProtoSim.new(1)
	check(sim.switch_slot(1) == true, "第一次切换应成功")
	check(sim.switch_slot(0) == false, "冷却期内再次切换应失败")


func test_300_enemy_perf_with_pipeline() -> void:
	# 300同屏下管线执行不应显著增加帧耗时
	var sim := ProtoSim.new(2)
	for i in range(300):
		sim.enemy_pos.append(sim.player_pos + Vector2(100 + i % 20 * 10, 50 + i / 20 * 10))
		sim.enemy_hp.append(999.0)
		sim.enemy_id.append(i)

	var block := CommandBlock.from_template("trigger_nearest", 1, "白")
	var act := CommandBlock.from_template("action_aoe", 1, "白")
	sim.add_command(0, block)
	sim.add_command(0, act)

	var t0 := Time.get_ticks_usec()
	for i in range(120):
		sim.step(1.0 / 60.0, Vector2.ZERO)
	var elapsed_ms := float(Time.get_ticks_usec() - t0) / 1000.0
	var per_frame := elapsed_ms / 120.0
	print("    300同屏+管线：120帧总耗时 %.2f ms，单帧 %.3f ms" % [elapsed_ms, per_frame])
	check(per_frame < 16.6, "300同屏+管线单帧耗时 < 16.6ms")
