## FinalBossDirector — turns the Cipher Keeper fight into a set piece (ADR-0026).
##
## The Keeper's bullet layers switch on by HP like any boss (ADR-0018). This node
## listens to its phase_changed signal and changes the arena on top of that:
##   phase 1 — a rotating beam pylon rises in the centre of the room
##   phase 2 — the vault closes in (closing ring hazard)
##   phase 3 — every bullet is wiped for one breath, then the last stand begins
## Each phase also shows a named banner and kicks the camera.
##
## Run-scoped, created by debug_game_loop; attach() is called from
## WaveManager.boss_spawned and ignores every other boss. The phase → hazard table
## is static so it is unit-tested headless. Data: assets/data/final_boss/.
class_name FinalBossDirector
extends Node

## Emitted after a phase's arena change has been applied.
signal phase_applied(phase: int)

const CONFIG: FinalBossConfig = preload("res://assets/data/final_boss/final_boss_config.tres")
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Shows phase banners. Set by the parent; optional.
var hud: CombatHUD = null

var _boss: Node2D = null
var _room: Node2D = null


## True when [param type_id] is the final boss.
static func is_final_boss(type_id: int, cfg: FinalBossConfig = CONFIG) -> bool:
	return type_id == cfg.boss_type_id


## Hazard specs that appear when the boss enters [param phase].
static func hazards_for_phase(phase: int, cfg: FinalBossConfig = CONFIG) -> Array[HazardSpec]:
	var out: Array[HazardSpec] = []
	if phase == cfg.sweep_phase and cfg.sweep_spec != null:
		out.append(cfg.sweep_spec)
	if phase == cfg.ring_phase and cfg.ring_spec != null:
		out.append(cfg.ring_spec)
	return out


## Banner text for [param phase], or "" when there is none.
static func banner_for_phase(phase: int) -> String:
	var banners: Array[String] = _COPY.keeper_phase_banners
	return banners[phase - 1] if phase >= 1 and phase <= banners.size() else ""


## Starts directing [param boss] inside [param room]. Returns false (and does
## nothing) unless it is the final boss.
func attach(boss: Node, room: Node2D) -> bool:
	if not is_instance_valid(boss) or not boss.has_method(&"get_type_id") \
			or not is_final_boss(int(boss.get_type_id())):
		return false
	_boss = boss as Node2D
	_room = room
	if boss.has_signal(&"phase_changed"):
		boss.connect(&"phase_changed", _on_phase_changed)
	return true


func _on_phase_changed(phase: int) -> void:
	for spec: HazardSpec in hazards_for_phase(phase):
		_spawn_hazard(spec)
	if phase == CONFIG.breather_phase and is_inside_tree():
		Projectile.cancel_in_radius(get_tree(), _boss.global_position if is_instance_valid(_boss) \
			else Vector2.ZERO, 100000.0)
	var text: String = banner_for_phase(phase)
	if text != "" and is_instance_valid(hud):
		hud.show_room_banner(text, Color(0.85, 0.65, 1.0))
	var player: Node = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	if player != null and player.has_method(&"add_camera_trauma"):
		player.add_camera_trauma(CONFIG.phase_trauma)
	phase_applied.emit(phase)


func _spawn_hazard(spec: HazardSpec) -> void:
	if not is_instance_valid(_room):
		return
	var hazard: StageHazard = StageHazard.create(spec)
	if hazard == null:
		return
	if hazard is HazardClosingRing and _room.has_method(&"_floor_half_extents"):
		(hazard as HazardClosingRing).half_extents = _room.call(&"_floor_half_extents")
	hazard.position = Vector2.ZERO
	_room.add_child(hazard)
