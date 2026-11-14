extends SceneTree
## Stage 2 Vertical Slice · Level Data & Flow Tests
## Run: godot --headless --path . --script tests/test_level.gd

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
	print("=== Stage 2 Vertical Slice · Level & Boss Tests ===")

	# Task 1: Level Data
	test_sector_data_loads()
	test_boss_data_loads()

	# Task 2: Level Flow
	test_level_flow()

	# Task 3: Boss Mechanics
	test_boss_mechanics()

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
	var f := FileAccess.open("tests/stage2_results.txt", FileAccess.WRITE)
	if f:
		for line in report:
			f.store_line(line)
		f.close()


# =========================================================
#  Task 1: Level Data
# =========================================================
func test_sector_data_loads() -> void:
	var data := LevelData.get_sector("sector_a")
	check(data.name == "Data Flood", "Sector A name correct")
	check(data.enemy_batch == 4, "Sector A spawn batch 4")
	check(data.spawn_interval <= 0.15, "Sector A fast spawn")


func test_boss_data_loads() -> void:
	var boss := LevelData.get_boss("boss_1")
	check(boss.name == "Data Core", "Boss 1 name correct")
	check(boss.max_hp > 0, "Boss has max HP")
	check(boss.phases >= 2, "Boss has multiple phases")


# =========================================================
#  Task 2: Level Flow
# =========================================================
func test_level_flow() -> void:
	var sim := ProtoSim.new()
	var ls := LevelSim.new()
	ls.init(sim)
	ls.start_sector("sector_a")
	check(ls.current_sector == "sector_a", "Sector A started")
	ls.next_sector()
	check(ls.current_sector == "safe_zone", "Safe zone after sector A")
	ls.next_sector()
	check(ls.current_sector == "sector_b", "Sector B after safe zone")
	ls.next_sector()
	check(ls.current_sector == "safe_zone", "Safe zone after sector B")
	ls.next_sector()
	check(ls.current_boss == "boss_1", "Boss 1 started")
	ls.set_boss_hp(0.0)
	check(ls.current_sector == "safe_zone", "Safe zone after Boss 1")
	ls.next_sector()
	check(ls.current_boss == "boss_2", "Boss 2 after safe zone")
	ls.set_boss_hp(0.0)
	check(ls.is_victory, "Victory after all bosses")


# =========================================================
#  Task 3: Boss Mechanics
# =========================================================
func test_boss_mechanics() -> void:
	var sim := ProtoSim.new()
	sim._select_char("mage")
	sim.start_boss("boss_1")
	sim.step(0.016, Vector2.ZERO)
	check(sim.current_boss == "boss_1", "Boss 1 started")
	check(sim.boss_hp > 0, "Boss has HP")
	check(sim.enemy_pos.size() == 0, "No minions during boss fight")
	sim.level_sim.set_boss_hp(sim.level_sim.boss_hp - 1000.0)
	sim.step(0.016, Vector2.ZERO)
	check(sim.boss_hp < sim.boss_max_hp, "Boss takes damage")
	sim.level_sim.set_boss_hp(sim.boss_max_hp * 0.5)
	sim.step(0.016, Vector2.ZERO)
	check(sim.boss_phase == 2, "Boss phase 2 active")
