## stage_hazard.gd — Base for environmental room hazards (ADR-0020).
##
## A hazard is built by IsometricRoom from a HazardSpec. It stays idle while the
## player prepares and runs only during combat: combat_started switches it on;
## preparation_started, wave_ended, room_cleared and death_started switch it off.
## Subclasses implement _hazard_tick() and _on_activated() / _on_deactivated().
##
## Damage uses the CONTACT source, so dash i-frames and post-hit grace apply the
## same way they do for enemy lasers.
## GDD: design/gdd/stage-layout.md
class_name StageHazard
extends Node2D

## Group every hazard joins, for tests and wave-clear cleanup.
const GROUP: StringName = &"stage_hazard"
const TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")

## The data this hazard was built from.
var spec: HazardSpec = null

var _active: bool = false
## Seconds since the hazard was last switched on.
var _active_time: float = 0.0
var _player: Node2D = null


## Builds the right hazard node for [param hazard_spec]. Returns null for null input.
static func create(hazard_spec: HazardSpec) -> StageHazard:
	if hazard_spec == null:
		return null
	var h: StageHazard = null
	match hazard_spec.kind:
		HazardSpec.Kind.TURRET:
			h = HazardTurret.new()
		HazardSpec.Kind.SWEEP_LASER:
			h = HazardSweepLaser.new()
		HazardSpec.Kind.FLOOR_ZONE:
			h = HazardFloorZone.new()
		HazardSpec.Kind.CLOSING_RING:
			h = HazardClosingRing.new()
	if h != null:
		h.spec = hazard_spec
	return h


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group(GROUP)
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.wave_ended.connect(set_active.bind(false))
	GameStateManager.room_cleared.connect(set_active.bind(false))
	GameStateManager.death_started.connect(set_active.bind(false))
	if GameStateManager.get_active_state() == GameEnums.GameState.COMBAT_PHASE:
		set_active(true)
	# Connections to the GameStateManager autoload drop automatically when the room
	# (and this hazard with it) is freed on the next room change.


func _physics_process(delta: float) -> void:
	if not _active or spec == null:
		return
	_active_time += delta
	_hazard_tick(delta)
	queue_redraw()


## Switches the hazard on or off. Switching on restarts its timers.
func set_active(on: bool) -> void:
	if on == _active:
		return
	_active = on
	if on:
		_active_time = 0.0
		_on_activated()
	else:
		_on_deactivated()
	queue_redraw()


## True while the hazard is running.
func is_active() -> bool:
	return _active


## Test hook: overrides the player node the hazard targets.
func set_player(p: Node2D) -> void:
	_player = p


# ── Subclass hooks ───────────────────────────────────────────────────────────

## Per-frame logic while active.
func _hazard_tick(_delta: float) -> void:
	pass


func _on_activated() -> void:
	pass


func _on_deactivated() -> void:
	pass


# ── Shared helpers ───────────────────────────────────────────────────────────

## Deals spec.damage to Fayde (CONTACT source). When [param dodgeable] and she is
## dashing through it, it also counts as a Perfect Dodge (ADR-0019).
func _hit_player(dodgeable: bool) -> void:
	if not is_instance_valid(_player):
		return
	if dodgeable and _player.has_method(&"register_perfect_dodge"):
		_player.register_perfect_dodge(_player.global_position)
	HealthAndDamage.apply_damage(
		_player, spec.damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)


func _on_combat_started(_is_boss: bool = false) -> void:
	set_active(true)


func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	set_active(false)


## Pure: iso-ellipse test. A floor circle of [param radius] in screen space is
## drawn with half the height, so the vertical offset counts double.
static func in_iso_radius(offset: Vector2, radius: float) -> bool:
	return Vector2(offset.x, offset.y * 2.0).length() <= radius
