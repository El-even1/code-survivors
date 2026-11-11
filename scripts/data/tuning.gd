class_name Tuning
extends RefCounted

## 阶段①色块原型 · 集中配置
## 来源：飞书知识库《幸存者类 8 阶段流水线》①立项与原型验证
## 原则：所有可调参数集中于此，策划改数值不碰代码

# ---------- 玩家（蓝方块） ----------
const PLAYER_SIZE := 26.0
const PLAYER_SPEED := 265.0          # 摇杆跟手：直接赋值速度，不做加速平滑
const PLAYER_MAX_HP := 140.0

# ---------- 武器（白圈 AoE，自动攻击） ----------
const AOE_DAMAGE := 18.0
const AOE_RADIUS := 108.0
const AOE_COOLDOWN := 0.30

# ---------- 敌人（红方块海） ----------
const ENEMY_CAP := 300               # 文档验收点：300 个同屏掉不掉帧
const ENEMY_SIZE := 16.0
const ENEMY_BASE_HP := 16.0
const ENEMY_HP_PER_SEC := 0.42       # HP 随时间缓慢上涨（指数级交给后续阶段）
const ENEMY_SPEED := 72.0
## 接触伤害：按「次」结算 + 无敌帧，避免多怪贴脸时伤害逐帧叠加导致秒死
const CONTACT_DAMAGE := 7.0
const CONTACT_IFRAMES := 0.60
const ENEMY_AI_FRAME_SKIP := 3       # 敌人 AI 不每帧跑，按 id%3 分帧轮转

# ---------- 经验（绿色小方块） ----------
const GEM_SIZE := 10.0
const GEM_VALUE := 4
const GEM_MAX := 260
const MAGNET_RADIUS := 135.0         # 磁吸半径：吸尘器感
const MAGNET_PULL_SPEED := 520.0
const PICKUP_RADIUS := 22.0

# ---------- 成长 ----------
const XP_BASE := 5.0
const XP_GROWTH := 1.28
const XP_LEVEL_CAP := 30

# ---------- 飘字 ----------
const DMG_TEXT_LIFE := 0.85
const DMG_TEXT_RISE := 52.0
const DMG_MERGE_DIST := 22.0
const DMG_MERGE_WINDOW := 0.55       # 同帧/近时受击合并成“×N”
const DMG_MAX := 320

# ---------- 节奏（压缩版时间轴，便于 90 秒内感受到怪海） ----------
const PHASE_SURVIVE_END := 20.0      # 生存期：只有直冲近战怪
const PHASE_GROW_END := 45.0         # 成长期：数量抬升
const PHASE_PRESSURE_END := 75.0     # 压力期：逼近 300 同屏
const SPAWN_INTERVAL_START := 0.40
const SPAWN_INTERVAL_END := 0.075
const RAMP_SECONDS := 110.0          # 拉长爬升期，让玩家有 Build 窗口（难度滞后于玩家强度）

# ---------- 空间网格 ----------
const GRID_CELL := 64.0

# ---------- 画布 ----------
const VIEW_W := 1280.0
const VIEW_H := 720.0

# ---------- 世界（大于视口，相机跟随玩家） ----------
const WORLD_W := 2400.0
const WORLD_H := 1440.0
const PLAYER_EDGE_MARGIN := 28.0
const CAM_FOLLOW_SPEED := 14.0       # 相机跟随插值速度
