## StatusEffectsManager — Autoload #6. Tick-timing authority for all persistent
## Prana-triggered combat conditions (ADR-0011, ADR-0004).
##
## Story 001 scope: SEM skeleton, StatusInstance, Burn DoT (apply/tick/expire/guards).
## Stories 002–005 implement: Freeze, Regen, Blind/Stun stubs, cleanup callbacks,
## has_status(), check_and_apply_shatter(), Burn Contagion.
##
## Registration: Autoload #6 in project.godot (ADR-0002).
##   Node name in Project Settings: "StatusEffectsManager". No class_name — Godot 4
##   rejects class_name matching the Autoload node name ("hides autoload singleton").
##   Access in game code: StatusEffectsManager.apply_status(...)
##   Access in tests: preload("res://src/systems/status_effects_manager.gd").new()
extends Node


# ── Inner class: StatusInstance ───────────────────────────────────────────────

## A single active status on a specific target node.
## GDScript class (not a Node) — stored in the _active_statuses registry.
class StatusInstance:
	## The node this status is applied to.
	var target: Node
	## The status type (GameEnums.BaseStatus).
	var status_type: GameEnums.BaseStatus
	## Seconds remaining before expiry; decremented each frame by delta.
	var duration_remaining: float
	## Seconds between ticks. 0.0 = no-tick status (Freeze, Blind, Stun, etc.).
	var tick_interval: float
	## Accumulator counting down to the next tick. Decremented by delta; += tick_interval on fire.
	var tick_timer: float
	## Base spell damage captured at application time. Used by Burn for tick damage.
	## 0.0 for non-DoT statuses (Freeze, Blind, Stun, Regen, Chill, Stagger).
	var spell_base_damage: float


# ── Constants ─────────────────────────────────────────────────────────────────

## Fraction of spell_base_damage dealt per Burn tick (status-effects.md Formula 1).
const BURN_TICK_MAGNITUDE: float = 0.08

## Time in seconds between Burn damage ticks (4 ticks across BURN_DURATION = 2.0s).
const BURN_TICK_INTERVAL: float = 0.5


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted on every apply_status() call that creates or re-applies a StatusInstance.
signal status_applied(target: Node, status_type: GameEnums.BaseStatus, duration: float)

## Emitted when a StatusInstance's duration_remaining reaches 0 and is removed.
## NOT emitted during wave-clear (preparation_started) or enemy death cleanup.
signal status_expired(target: Node, status_type: GameEnums.BaseStatus)

## Emitted when Burn Contagion transfers from a dying enemy to a living one. (Story 005)
signal burn_contagion_triggered(dying_enemy_position: Vector2, to_target: Node)

## Emitted when check_and_apply_shatter() fires the Shatter bonus. (Story 005)
signal shatter_triggered(target: Node)


# ── Private state ─────────────────────────────────────────────────────────────

## Registry of all active StatusInstances, keyed by target.get_instance_id().
## Typed dictionary requires Godot 4.4+ (ADR-0011 AC-0011-01; project pinned to 4.6).
## Value type is Array (untyped) — nested typed collections (Array[StatusInstance]) are not
## supported as Dictionary value type parameters in Godot 4.6.
var _active_statuses: Dictionary[int, Array] = {}

## HealthAndDamage Autoload reference. Variant intentional — allows MockHealthAndDamage
## injection in tests without Node inheritance (same pattern as PlayerController.audio_system).
var _health_and_damage: Variant = null


# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	if _health_and_damage == null:
		_health_and_damage = HealthAndDamage
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
	GameStateManager.preparation_started.connect(_on_preparation_started)


## Drives all tick timers and duration counters (ADR-0004 float accumulator pattern).
## Iterates a duplicate of each array to safely handle mid-loop expiry.
func _process(delta: float) -> void:
	if _active_statuses.is_empty():
		return
	var target_ids: Array = _active_statuses.keys()
	for target_id: int in target_ids:
		if not _active_statuses.has(target_id):
			continue
		var instances: Array = _active_statuses[target_id].duplicate()
		for instance in instances:
			instance.duration_remaining -= delta
			if instance.tick_interval > 0.0:
				instance.tick_timer -= delta
				if instance.tick_timer <= 0.0:
					_fire_tick(instance)
					instance.tick_timer += instance.tick_interval  # ADR-0004: += not reset
			if instance.duration_remaining <= 0.0:
				_expire_status(instance)


# ── Public API ────────────────────────────────────────────────────────────────

## Applies or re-applies a status effect to [param target].
##
## Validates via [method _is_apply_valid], then finds an existing StatusInstance
## (re-apply: reset fields) or creates a new one. Emits [signal status_applied] on
## both paths. [param spell_base_damage] defaults to 0.0 for non-DoT statuses.
func apply_status(
	target: Node,
	status_type: GameEnums.BaseStatus,
	duration: float,
	spell_base_damage: float = 0.0
) -> void:
	if not _is_apply_valid(target, status_type, duration):
		return

	var target_id: int = target.get_instance_id()
	if not _active_statuses.has(target_id):
		_active_statuses[target_id] = []

	for existing in _active_statuses[target_id]:
		if existing.status_type == status_type:
			existing.duration_remaining = duration
			existing.tick_timer = 0.0
			existing.spell_base_damage = spell_base_damage
			status_applied.emit(target, status_type, duration)
			return

	var inst: StatusInstance = StatusInstance.new()
	inst.target = target
	inst.status_type = status_type
	inst.duration_remaining = duration
	inst.tick_interval = _tick_interval_for(status_type)
	inst.tick_timer = inst.tick_interval  # First tick fires after one full interval.
	inst.spell_base_damage = spell_base_damage
	_active_statuses[target_id].append(inst)
	status_applied.emit(target, status_type, duration)


## Returns true if [param target] has an active StatusInstance of [param status_type].
## Sole status query interface — no per-status helpers (ADR-0011). (Story 005)
func has_status(_target: Node, _status_type: GameEnums.BaseStatus) -> bool:
	return false  # Story 005


## Called by SC&E before every DIRECT apply_damage() call.
## Returns base_damage × 1.25 when target has active FREEZE; base_damage otherwise. (Story 005)
func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
	return base_damage  # Story 005


# ── Private — validation ──────────────────────────────────────────────────────

## Returns false and logs errors for invalid apply_status() calls (Rule 4 steps 1–3).
## Guard order: duration → scope → liveness. Liveness returns false silently.
func _is_apply_valid(target: Node, status_type: GameEnums.BaseStatus, duration: float) -> bool:
	if duration <= 0.0:
		push_error(
			"StatusEffectsManager.apply_status(): duration must be > 0.0 (got %f). "
			% duration
			+ "Zero or negative duration is a caller error (status-effects.md AC-SE-20)."
		)
		return false

	var required_group: StringName = &"enemy"
	if status_type == GameEnums.BaseStatus.REGENERATE:
		required_group = &"player"
	if not target.is_in_group(required_group):
		push_error(
			"StatusEffectsManager.apply_status(): invalid target scope — status %d requires "
			% [status_type]
			+ "group '%s' but target '%s' is not in that group. " % [required_group, target.name]
			+ "(status-effects.md AC-SE-09)"
		)
		return false

	if not target.is_alive():
		return false

	return true


# ── Private — tick ────────────────────────────────────────────────────────────

func _fire_tick(instance) -> void:
	match instance.status_type:
		GameEnums.BaseStatus.BURN:
			var tick_dmg: float = maxf(0.0, instance.spell_base_damage) * BURN_TICK_MAGNITUDE
			_health_and_damage.apply_damage(
				instance.target, tick_dmg, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DOT
			)


# ── Private — expiry ──────────────────────────────────────────────────────────

func _expire_status(instance) -> void:
	var target_id: int = instance.target.get_instance_id()
	if not _active_statuses.has(target_id):
		return
	_active_statuses[target_id].erase(instance)
	if _active_statuses[target_id].is_empty():
		_active_statuses.erase(target_id)
	status_expired.emit(instance.target, instance.status_type)


# ── Private — helpers ─────────────────────────────────────────────────────────

func _tick_interval_for(status_type: GameEnums.BaseStatus) -> float:
	match status_type:
		GameEnums.BaseStatus.BURN:
			return BURN_TICK_INTERVAL
		_:
			return 0.0


# ── Signal callbacks (stubs — implementations in Stories 004 and 005) ─────────

func _on_enemy_killed(_instance_id: int, _type_id: int, _affiliation: GameEnums.DamageClass) -> void:
	pass  # Story 004


func _on_preparation_started(_wave_index: int, _waves_remaining: int) -> void:
	pass  # Story 004
