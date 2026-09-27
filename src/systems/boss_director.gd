## BossDirector — turns every floor boss into a set piece (ADR-0028, was
## FinalBossDirector in ADR-0026).
##
## A boss's bullet layers switch on by HP like any enemy (ADR-0018). This node
## listens to the boss's phase_changed signal and changes the arena on top of that,
## as listed in the boss's BossProfile plus the run's BossVariant:
##   hazards   — stage hazards placed in the boss room
##   clear     — every enemy bullet wiped for one breath
## Each phase also shows the boss's own banner and kicks the camera.
##
## Run-scoped, created by debug_game_loop; attach() is called from
## WaveManager.boss_spawned and ignores bosses the roster does not list. The
## phase → event lookup is static so it is unit-tested headless.
## Data: assets/data/bosses/boss_roster.tres.
class_name BossDirector
extends Node

## Emitted after a phase's arena change has been applied.
signal phase_applied(phase: int)

const ROSTER: BossRoster = preload("res://assets/data/bosses/boss_roster.tres")
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Shows phase banners. Set by the parent; optional.
var hud: CombatHUD = null

var _boss: Node2D = null
var _room: Node2D = null
var _profile: BossProfile = null
var _variant: BossVariant = null
## Highest phase already applied. A big hit can cross two thresholds in one frame,
## so every phase in between is applied too.
var _applied_phase: int = 0


## Hazard specs that appear when a boss with [param profile] (playing
## [param variant]) enters [param phase].
static func hazards_for_phase(profile: BossProfile, phase: int,
		variant: BossVariant = null) -> Array[HazardSpec]:
	var out: Array[HazardSpec] = []
	if profile == null:
		return out
	for ev: BossPhaseEvent in profile.events_for_phase(phase, variant):
		for spec: HazardSpec in ev.hazards:
			if spec != null:
				out.append(spec)
	return out


## True when entering [param phase] wipes every enemy bullet.
static func clears_bullets(profile: BossProfile, phase: int, variant: BossVariant = null) -> bool:
	if profile == null:
		return false
	for ev: BossPhaseEvent in profile.events_for_phase(phase, variant):
		if ev.clear_bullets:
			return true
	return false


## Banner text for [param phase] of [param profile], or "" when there is none.
static func banner_for_phase(profile: BossProfile, phase: int) -> String:
	if profile == null or profile.banner_copy_key == &"":
		return ""
	var banners: Variant = _COPY.get(profile.banner_copy_key)
	if not banners is Array:
		return ""
	var list: Array = banners
	return String(list[phase - 1]) if phase >= 1 and phase <= list.size() else ""


## Starts directing [param boss] inside [param room]. Returns false (and does
## nothing) when the roster has no profile for it.
func attach(boss: Node, room: Node2D, roster: BossRoster = ROSTER) -> bool:
	if not is_instance_valid(boss) or not boss.has_method(&"get_type_id"):
		return false
	var profile: BossProfile = roster.profile_for(int(boss.get_type_id()))
	if profile == null:
		return false
	_detach()
	_boss = boss as Node2D
	_room = room
	_profile = profile
	_variant = boss.get_boss_variant() if boss.has_method(&"get_boss_variant") else null
	_applied_phase = 0
	if boss.has_signal(&"phase_changed"):
		boss.connect(&"phase_changed", _on_phase_changed)
	# ADR-0039: the boss's reserved colour bleeds into the arena, and drains on defeat.
	if room != null and room.has_method(&"set_ambience"):
		room.set_ambience(profile.reserved_color, profile.ambience_strength, profile.ambience_fade_sec)
		boss.tree_exiting.connect(_clear_ambience.bind(room, profile.ambience_fade_sec))
	return true


func _clear_ambience(room: Node2D, seconds: float) -> void:
	if is_instance_valid(room) and room.is_inside_tree():
		room.set_ambience(Color.WHITE, 0.0, seconds)


func _detach() -> void:
	if is_instance_valid(_boss) and _boss.has_signal(&"phase_changed") \
			and _boss.is_connected(&"phase_changed", _on_phase_changed):
		_boss.disconnect(&"phase_changed", _on_phase_changed)
	_boss = null


func _on_phase_changed(phase: int) -> void:
	while _applied_phase < phase:
		_applied_phase += 1
		_apply_phase(_applied_phase)


func _apply_phase(phase: int) -> void:
	for spec: HazardSpec in hazards_for_phase(_profile, phase, _variant):
		_spawn_hazard(spec)
	if clears_bullets(_profile, phase, _variant) and is_inside_tree():
		Projectile.cancel_in_radius(get_tree(), _boss.global_position if is_instance_valid(_boss) \
			else Vector2.ZERO, 100000.0)
	var text: String = banner_for_phase(_profile, phase)
	if text != "" and is_instance_valid(hud):
		hud.show_room_banner(text, _profile.banner_color)
	var player: Node = get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	if player != null and player.has_method(&"add_camera_trauma"):
		player.add_camera_trauma(_profile.phase_trauma)
	phase_applied.emit(phase)


func _spawn_hazard(spec: HazardSpec) -> void:
	if not is_instance_valid(_room):
		return
	var hazard: StageHazard = StageHazard.create(spec)
	if hazard == null:
		return
	if hazard is HazardClosingRing and _room.has_method(&"_floor_half_extents"):
		(hazard as HazardClosingRing).half_extents = _room.call(&"_floor_half_extents")
	hazard.position = spec.position
	_room.add_child(hazard)
