# Stage 2: Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Stage 2 Vertical Slice — 1 complete sector (Data Flood) + Safe Zone pipeline editing + 2 Bosses. Player can play one complete loop: Character Select → Safe Zone → Sector A → Safe Zone → Sector B → Boss Fight → Victory.

**Architecture:** Add level data layer (level_data.gd), level flow simulation (level_sim.gd), level UI (level_view.gd + level_select.gd), integrate into proto_view.gd, extend proto_sim.gd with Boss mechanics. Keep 300 on-screen performance < 16.6ms/frame.

**Tech Stack:** Godot 4.7.2 / GDScript 4

**Spec:** Stage 2 design discussed in conversation (3 sectors: Data Flood / Firewall / Core Protocol; Safe Zone pipeline editing; 2 Bosses with phase mechanics; weapon pipeline as core combat).

## Global Constraints

- Godot 4.7.2, GDScript 4 (no C-style ternary, dict keys quoted, no runtime constants in @export)
- No physics engine, custom circle distance + spatial grid
- Object pool: tail-swap removal, O(1), no per-frame new
- Enemy AI frame-skip: id % 3
- Floating text pool + merge (×N)
- 300 on-screen single-frame sim time < 16.6ms
- Character system: 3 roles (mage/warrior/hunter), auto-attack nearest enemy at fixed interval
- Pipeline: modifier chain only, no triggers/conditions

## Review Focus

1. **Sector transition state**: When switching between Safe Zone → Sector A → Safe Zone → Sector B → Boss, sim state must reset correctly (enemy list cleared, timer reset, player HP carried over)
2. **Boss HP bar**: Boss health must persist across phases and display correctly in UI
3. **Pipeline state persistence**: Pipeline slots must persist across sector transitions (player's build carries over)
4. **Boss immunity switching**: Boss 2's immunity to trigger types must swap correctly and UI must reflect current immunity
5. **Victory condition**: After Boss 2 dies, game must show victory screen and not crash
6. **Performance**: 300 on-screen + Boss mechanics + pipeline execution < 16.6ms/frame

---

### Task 1: Level Data Layer (level_data.gd)

**Files:**
- Create: `scripts/data/level_data.gd`

**Interfaces:**
- Consumes: None (pure data)
- Produces: `SECTOR_DATA` dictionary (sector name, enemy spawn config, duration), `BOSS_DATA` dictionary (Boss name, HP, phases, immunity types), `LEVEL_CONFIG` (total sectors, victory condition)

- [ ] **Step 1: Write sector data test**

```python
func test_sector_data_loads() -> void:
    var data := LevelData.get_sector("sector_a")
    check(data.name == "Data Flood", "Sector A name correct")
    check(data.enemy_batch == 4, "Sector A spawn batch 4")
    check(data.spawn_interval <= 0.15, "Sector A fast spawn")
```

- [ ] **Step 2: Run test, verify fail (file missing)**
- [ ] **Step 3: Implement `LevelData` class with `get_sector()`, `get_boss()` static methods**
- [ ] **Step 4: Run test, verify pass**
- [ ] **Step 5: Commit**

```bash
git add scripts/data/level_data.gd tests/test_level.gd
git commit -m "feat: level data layer - sectors and boss definitions"
```

---

### Task 2: Level Flow Simulation (level_sim.gd)

**Files:**
- Create: `scripts/core/level_sim.gd`

**Interfaces:**
- Consumes: `LevelData.get_sector()`, `LevelData.get_boss()`, `ProtoSim` instance
- Produces: `LevelSim` class with `current_sector`, `current_boss`, `sector_timer`, `boss_hp`, `is_victory`, `is_defeat`, `start_sector()`, `start_boss()`, `next_sector()`, `step(delta)` methods

- [ ] **Step 1: Write level flow test**

```python
func test_level_flow() -> void:
    var sim := ProtoSim.new()
    var ls := LevelSim.new(sim)
    ls.start_sector("sector_a")
    check(ls.current_sector == "sector_a", "Sector A started")
    ls.next_sector()
    check(ls.current_sector == "safe_zone", "Safe zone after sector A")
    ls.start_boss("boss_1")
    check(ls.current_boss == "boss_1", "Boss 1 started")
    ls.boss_hp = 0
    ls.next_sector()
    check(ls.current_boss == "boss_2", "Boss 2 after Boss 1")
    ls.boss_hp = 0
    ls.next_sector()
    check(ls.is_victory, "Victory after all bosses")
```

- [ ] **Step 2: Run test, verify fail**
- [ ] **Step 3: Implement `LevelSim` class**
- [ ] **Step 4: Run test, verify pass**
- [ ] **Step 5: Commit**

```bash
git add scripts/core/level_sim.gd tests/test_level.gd
git commit -m "feat: level flow simulation - sector and boss progression"
```

---

### Task 3: Boss Mechanics (proto_sim.gd)

**Files:**
- Modify: `scripts/core/proto_sim.gd`

**Interfaces:**
- Consumes: `LevelSim.current_boss`, `LevelSim.boss_hp`
- Produces: `sim.boss_id`, `sim.boss_hp`, `sim.boss_max_hp`, `sim.boss_phase`, `sim.boss_immunity`, `sim.step()` applies Boss attack patterns

- [ ] **Step 1: Write Boss test**

```python
func test_boss_mechanics() -> void:
    var sim := ProtoSim.new()
    sim._select_char("mage")
    sim.start_boss("boss_1")
    check(sim.boss_id == "boss_1", "Boss 1 started")
    check(sim.boss_hp > 0, "Boss has HP")
    sim.boss_hp -= 1000
    check(sim.boss_hp < sim.boss_max_hp, "Boss takes damage")
    sim.boss_phase = 2
    check(sim.boss_phase == 2, "Boss phase 2 active")
```

- [ ] **Step 2: Run test, verify fail**
- [ ] **Step 3: Implement Boss ID, HP, phase, immunity in `ProtoSim`**
- [ ] **Step 4: Run test, verify pass**
- [ ] **Step 5: Commit**

```bash
git add scripts/core/proto_sim.gd tests/test_level.gd
git commit -m "feat: boss mechanics - ID, HP, phase, immunity"
```

---

### Task 4: Level View UI (level_view.gd)

**Files:**
- Create: `scripts/ui/level_view.gd`

**Interfaces:**
- Consumes: `sim`, `LevelSim`
- Produces: Boss HP bar at top, sector name, wave timer, victory/defeat overlay

- [ ] **Step 1: Write level view test (UI presence)**

```python
func test_level_view_exists() -> void:
    # UI nodes exist after _ready
    check(level_view != null, "LevelView node exists")
    check(level_view.boss_bar != null, "Boss HP bar node exists")
```

- [ ] **Step 2: Run test, verify fail**
- [ ] **Step 3: Implement `LevelView` class with boss HP bar, sector name, timer**
- [ ] **Step 4: Run test, verify pass**
- [ ] **Step 5: Commit**

```bash
git add scripts/ui/level_view.gd tests/test_level.gd
git commit -m "feat: level view - boss HP bar, sector name, timer"
```

---

### Task 5: Main Menu + Character Select (level_select.gd)

**Files:**
- Create: `scripts/ui/level_select.gd`

**Interfaces:**
- Consumes: None
- Produces: `LevelSelect` class with `start_game(char_id)` method, character selection buttons

- [ ] **Step 1: Write main menu test**

```python
func test_main_menu_starts_game() -> void:
    var ls := LevelSelect.new()
    ls.start_game("mage")
    check(ls.selected_char == "mage", "Mage selected")
    check(ls.game_started, "Game started")
```

- [ ] **Step 2: Run test, verify fail**
- [ ] **Step 3: Implement `LevelSelect` class**
- [ ] **Step 4: Run test, verify pass**
- [ ] **Step 5: Commit**

```bash
git add scripts/ui/level_select.gd tests/test_level.gd
git commit -m "feat: main menu - character select + start game"
```

---

### Task 6: Integrate Level Flow into Main View (proto_view.gd)

**Files:**
- Modify: `scripts/ui/proto_view.gd`

**Interfaces:**
- Consumes: `LevelSim`, `LevelView`, `LevelSelect`, `ProtoSim`
- Produces: Full game loop: main menu → character select → sector → safe zone → sector → boss → victory

- [ ] **Step 1: Replace infinite survival loop with level flow**
- [ ] **Step 2: Add Safe Zone UI (pipeline editing between sectors)**
- [ ] **Step 3: Add Boss HP bar rendering**
- [ ] **Step 4: Add Victory/Defeat overlay**
- [ ] **Step 5: Manual playtest: complete one full run**
- [ ] **Step 6: Commit**

```bash
git add scripts/ui/proto_view.gd
git commit -m "feat: main view - level flow integration + victory/defeat"
```

---

### Task 6.5: Safe Zone Pipeline Editing

**Files:**
- Modify: `scripts/ui/proto_view.gd`, `scripts/ui/pipeline_editor.gd`

**Interfaces:**
- Consumes: `sim`, `pipeline_editor`
- Produces: Safe zone UI where player can edit pipeline between sectors

- [ ] **Step 1: Safe zone UI appears between sectors**
- [ ] **Step 2: Pipeline edits persist into next sector**
- [ ] **Step 3: Manual playtest: edit pipeline in safe zone, enter next sector with new pipeline**
- [ ] **Step 4: Commit**

```bash
git add scripts/ui/proto_view.gd scripts/ui/pipeline_editor.gd
git commit -m "feat: safe zone - pipeline editing between sectors"
```

---

### Task 7: Full Test Suite + Push

**Files:**
- Create: `tests/test_level.gd` (level flow, boss mechanics tests)
- Modify: `tests/test_proto.gd` (ensure existing tests still pass)

**Interfaces:**
- None

- [ ] **Step 1: Write level tests (sector flow, boss HP, immunity switching)**
- [ ] **Step 2: Run all tests: `godot --headless --path . --script tests/test_proto.gd` and `tests/test_level.gd`**
- [ ] **Step 3: Expect ALL CHECKS PASSED**
- [ ] **Step 4: Manual playtest: complete one full run from menu to victory**
- [ ] **Step 5: Commit all changes**
- [ ] **Step 6: Push to remote `git@github.com:El-even1/code-survivors.git`**

```bash
git add -A
git commit -m "feat: stage 2 vertical slice - sectors, boss, safe zone, full loop"
git push origin master
```

---

**Execution Order:** Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 6.5 → Task 7

**Estimated effort:** Medium (6-8 hours)

---

**Plan complete and saved to `docs/superpowers/plans/2026-11-12-stage2-vertical-slice.md`.** Please review the plan. Does it capture what you want?

Which execution approach would you prefer?
- **Subagent-driven** - A fresh subagent implements each task and a fresh reviewer checks it before the next one starts, then a whole-branch review at the end. Most thorough; costs a fresh context per task and per review.
- **Native** - I implement every task myself in this session, then one fresh reviewer on the most capable model checks the whole branch. Cheapest and fastest; no independent review until the end.

Given the tasks have strong dependencies (level data → level sim → boss mechanics → UI → integration), **I recommend subagent-driven** because each task depends on the previous task's interfaces, and a fresh reviewer per task catches interface mismatches early. Does the plan capture what you want, and which approach should we use?
