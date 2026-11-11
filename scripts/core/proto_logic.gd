class_name ProtoLogic
extends RefCounted

## 阶段①色块原型 · 纯逻辑层（不依赖场景树，便于 headless 测试）
## 文档要点：禁用物理引擎 → 自写圆形距离检测 + 空间网格；尾部交换法移除；飘字合并

# ---------- 经验曲线 ----------
## 文档要求“经验曲线要有卡点”，原型先做平滑版，卡点留在阶段③
static func xp_for_level(level: int) -> float:
	return Tuning.XP_BASE * pow(Tuning.XP_GROWTH, level - 1)

# ---------- 列表移除：尾部交换法 O(1) ----------
## 对应文档「列表移除：swap & pop 替代 RemoveAt」
static func swap_pop(arr: Array, idx: int) -> void:
	var last := arr.size() - 1
	if idx < 0 or idx > last:
		return
	if idx != last:
		arr[idx] = arr[last]
	arr.pop_back()

# ---------- 空间网格 ----------
static func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / Tuning.GRID_CELL)), int(floor(pos.y / Tuning.GRID_CELL)))

## 收集与圆相交的网格键（只查本格+邻格，对应文档「网格分桶」）
static func cells_in_radius(center: Vector2, radius: float) -> Array:
	var out: Array = []
	var c0 := cell_of(center - Vector2(radius, radius))
	var c1 := cell_of(center + Vector2(radius, radius))
	for cx in range(c0.x, c1.x + 1):
		for cy in range(c0.y, c1.y + 1):
			out.append(Vector2i(cx, cy))
	return out

## 自写圆形距离检测（替代物理引擎）
static func in_circle(a: Vector2, b: Vector2, radius: float) -> bool:
	return a.distance_squared_to(b) <= radius * radius

## 圆与方块（轴对齐）近似的重叠判定：把敌人当圆处理，半径取半边长
static func circle_overlap(a: Vector2, ra: float, b: Vector2, rb: float) -> bool:
	var r := ra + rb
	return a.distance_squared_to(b) <= r * r

# ---------- 飘字合并 ----------
## 文档：10 只怪同帧受击 → 1 个「×10」
## 返回应合并到的槽位下标；-1 表示应新开一条
static func find_merge_target(
		dmg_pos: Array, dmg_age: Array, dmg_alive: Array,
		pos: Vector2) -> int:
	var best := -1
	var best_d := Tuning.DMG_MERGE_DIST
	for i in range(dmg_pos.size()):
		if not dmg_alive[i]:
			continue
		# 只合并新鲜的飘字（没过窗口期）
		if dmg_age[i] > Tuning.DMG_MERGE_WINDOW:
			continue
		var d: float = (dmg_pos[i] as Vector2).distance_to(pos)
		if d <= best_d:
			best_d = d
			best = i
	return best

# ---------- 刷新节奏 ----------
## 从开始间隔插值到最小间隔（压缩版，让 90 秒内逼近 300 同屏）
static func spawn_interval(elapsed: float) -> float:
	var t: float = clampf(elapsed / Tuning.RAMP_SECONDS, 0.0, 1.0)
	return lerpf(Tuning.SPAWN_INTERVAL_START, Tuning.SPAWN_INTERVAL_END, t)

## 单次刷怪数量随阶段抬升
static func spawn_batch(elapsed: float) -> int:
	if elapsed < Tuning.PHASE_SURVIVE_END:
		return 1
	if elapsed < Tuning.PHASE_GROW_END:
		return 2
	if elapsed < Tuning.PHASE_PRESSURE_END:
		return 4
	return 6

## 敌人基础生命随秒数上涨
static func enemy_hp(elapsed: float) -> float:
	return Tuning.ENEMY_BASE_HP + elapsed * Tuning.ENEMY_HP_PER_SEC

## 阶段名（对应文档 gLmAj8 的四个心理期）
static func phase_name(elapsed: float) -> String:
	if elapsed < Tuning.PHASE_SURVIVE_END:
		return "生存期"
	if elapsed < Tuning.PHASE_GROW_END:
		return "成长期"
	if elapsed < Tuning.PHASE_PRESSURE_END:
		return "压力期"
	return "极限期"

# ---------- 升级三选一候选 ----------
## 返回 3 个互不重复的升级 id
static func roll_upgrades(rng: RandomNumberGenerator, owned: Dictionary, count: int) -> Array:
	var pool: Array = []
	for id in Tuning_UPGRADES.keys():
		# 已满级的项不再出现
		if int(owned.get(id, 0)) >= int(Tuning_UPGRADES[id]["max_level"]):
			continue
		pool.append(id)
	# 洗牌后取前 count 个，保证互不重复
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var out: Array = []
	for i in range(mini(count, pool.size())):
		out.append(pool[i])
	return out

# 升级池：数值型，改变手感与生存，不做“只加伤害”
const Tuning_UPGRADES := {
	"damage":    {"name": "伤害 +25%",     "max_level": 6, "kind": "damage"},
	"radius":    {"name": "范围 +18%",     "max_level": 5, "kind": "radius"},
	"cooldown":  {"name": "攻速 +14%",     "max_level": 6, "kind": "cooldown"},
	"move":      {"name": "移速 +12%",     "max_level": 4, "kind": "move"},
	"magnet":    {"name": "磁吸 +30%",     "max_level": 4, "kind": "magnet"},
	"vitality":  {"name": "生命 +20%",     "max_level": 4, "kind": "vitality"},
}
