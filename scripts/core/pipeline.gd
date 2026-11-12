class_name Pipeline
extends RefCounted

## Stage I Color Prototype · Pipeline Execution Engine (Simplified)
## Execution Model: Linear modifier chain, applied in order to attack parameters
##   No triggers/conditions: attack is auto-triggered by ProtoSim at fixed interval
##   Pipeline only applies modifiers before the attack fires

var blocks: Array[CommandBlock] = []
var active := true
var name := "Pipeline"

## Runtime visualization: last flash time of each command block (-1 = never)
## Render layer uses this to highlight nodes, letting player see "my pipeline is running"
var block_flash: Array[float] = []
const FLASH_LIFE := 0.45


func _init(p_name: String = "Pipeline") -> void:
	name = p_name


## Flash a command block
func _flash(idx: int) -> void:
	if idx < 0 or idx >= block_flash.size():
		return
	block_flash[idx] = 0.0


## Advance flash decay each frame
func tick_visual(delta: float) -> void:
	for i in range(block_flash.size()):
		if block_flash[i] >= 0.0:
			block_flash[i] += delta
			if block_flash[i] >= FLASH_LIFE:
				block_flash[i] = -1.0


## Sync flash array on add/remove
func sync_flash() -> void:
	while block_flash.size() < blocks.size():
		block_flash.append(-1.0)
	while block_flash.size() > blocks.size():
		block_flash.pop_back()


## Normalized flash intensity 0..1 (1 = just lit)
func flash_strength(idx: int) -> float:
	if idx < 0 or idx >= block_flash.size():
		return 0.0
	var t: float = block_flash[idx]
	if t < 0.0:
		return 0.0
	return clampf(1.0 - t / FLASH_LIFE, 0.0, 1.0)


## Execute pipeline: apply modifiers to sim's attack params
## Returns visual events this frame (for render layer to highlight nodes)
func execute(sim, delta: float) -> Array:
	if not active or blocks.size() == 0:
		return []
	sync_flash()

	var events: Array = []
	var i := 0
	while i < blocks.size():
		var block := blocks[i]
		if block == null:
			i += 1
			continue
		if block.kind == CommandBlock.KIND_MODIFIER:
			_flash(i)                    # modifier lit
			var ev := _apply_modifier(block, sim)
			if ev != null:
				events.append(ev)
		i += 1
	return events


func set_active(active_flag: bool) -> void:
	active = active_flag


## Private: apply modifier
func _apply_modifier(block: CommandBlock, sim) -> Dictionary:
	var id := block.id
	match id:
		"mod_penetrate":
			return {"type": "attr", "attr": "pierce", "value": float(block.get_param("extra_pierce", 2))}
		"mod_multi":
			return {"type": "attr", "attr": "multi", "value": float(block.get_param("extra_count", 1))}
		"mod_range":
			return {"type": "attr", "attr": "radius", "value": float(block.get_param("range_mult", 1.30))}
		"mod_cooldown":
			return {"type": "attr", "attr": "cooldown", "value": float(block.get_param("cd_mult", 0.86))}
		"mod_dot":
			return {"type": "attr", "attr": "dot_damage", "value": block.get_param("dot_damage", 5.0)}
		"mod_track":
			return {"type": "attr", "attr": "track", "value": 1.0}
		_:
			pass
	return null


## Read-only snapshot (debug/render use)
func summary() -> String:
	var n := blocks.size()
	return "Pipeline[%s] blocks=%d active=%s" % [name, n, str(active)]
