class_name Tuning
extends RefCounted

## Character Pipeline Prototype · Central Configuration
## Source: Survivor 8-Phase Pipeline doc · Stage I Project Validation
## Principle: All adjustable params here. Designers edit values, not code.

## ---------- Character Base Attributes ----------
## Each character's base HP, speed, attack cooldown, weapon, passive
const CHARACTER_BASE := {
	"mage":    {"name": "Mage",    "hp": 100.0, "speed": 240.0, "attack_cooldown": 0.60, "weapon": "Staff",   "passive": "Mana Regen: +10% attack speed"},
	"warrior": {"name": "Warrior", "hp": 160.0, "speed": 200.0, "attack_cooldown": 0.90, "weapon": "Blade",   "passive": "Melee Resist: -30% contact damage"},
	"hunter":  {"name": "Hunter",  "hp": 120.0, "speed": 250.0, "attack_cooldown": 0.70, "weapon": "Bow",     "passive": "Move +15%"},
	"priest":  {"name": "Priest",  "hp": 130.0, "speed": 210.0, "attack_cooldown": 0.80, "weapon": "Tome",    "passive": "Lifesteal: +2% max HP on kill"},
}

## ---------- Player (current character) ----------
## Overridden after character selection
const PLAYER_SIZE := 26.0
const PLAYER_SPEED := 265.0
const PLAYER_MAX_HP := 140.0

## ---------- Weapon Attack Cooldown (fixed per weapon, modified by modifiers) ----------
var AOE_COOLDOWN := 0.60        # Staff: white circle AoE
var PROJECTILE_COOLDOWN := 0.50 # Bow/Fireball: projectile
var MELEE_COOLDOWN := 0.80      # Blade: melee range
var FIELD_COOLDOWN := 1.00      # Tome: field

## ---------- Enemies (red square horde) ----------
const ENEMY_CAP := 300               # Acceptance: 300 on-screen no lag
const ENEMY_SIZE := 16.0
const ENEMY_BASE_HP := 16.0
const ENEMY_HP_PER_SEC := 0.42       # HP slowly rises over time (exponential later)
const ENEMY_SPEED := 72.0
const CONTACT_DAMAGE := 7.0          # Contact damage per hit (not per frame)
const CONTACT_IFRAMES := 0.60        # Invulnerability frames
const ENEMY_AI_FRAME_SKIP := 3       # Enemy AI skips frames, id % 3 rotation

## ---------- EXP (green small squares) ----------
const GEM_SIZE := 10.0
const GEM_VALUE := 4
const GEM_MAX := 260
const MAGNET_RADIUS := 135.0         # Magnet radius: vacuum feel
const MAGNET_PULL_SPEED := 520.0
const PICKUP_RADIUS := 22.0

## ---------- Growth ----------
const XP_BASE := 5.0
const XP_GROWTH := 1.28
const XP_LEVEL_CAP := 30

## ---------- Floating Damage Text ----------
const DMG_TEXT_LIFE := 0.85
const DMG_TEXT_RISE := 52.0
const DMG_MERGE_DIST := 22.0
const DMG_MERGE_WINDOW := 0.55       # Nearby hits merge into "×N"
const DMG_MAX := 320

## ---------- Pacing (compressed timeline: feel monster horde within 90s) ----------
const PHASE_SURVIVE_END := 20.0      # Survival: melee only
const PHASE_GROW_END := 45.0         # Growth: numbers rise
const PHASE_PRESSURE_END := 75.0     # Pressure: approach 300 on-screen
const SPAWN_INTERVAL_START := 0.40
const SPAWN_INTERVAL_END := 0.075
const RAMP_SECONDS := 110.0          # Long ramp: player gets build window

## ---------- Spatial Grid ----------
const GRID_CELL := 64.0

## ---------- Canvas ----------
const VIEW_W := 1280.0
const VIEW_H := 720.0

## ---------- World (larger than viewport, camera follows player) ----------
const WORLD_W := 2400.0
const WORLD_H := 1440.0
const PLAYER_EDGE_MARGIN := 28.0
const CAM_FOLLOW_SPEED := 14.0       # Camera follow lerp speed
