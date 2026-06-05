## StatusEffectsManager — Autoload #6. Tick-timing authority for all persistent
## Prana-triggered combat conditions (ADR-0011, ADR-0004).
##
## Stories 001–002 scope: SEM skeleton, StatusInstance, Burn DoT, Freeze, Regen.
## Story 003 scope: Blind, Stun, Chill (Freeze-suppressed), Stagger stub effects.
## Stories 004–005 implement: kill/wave cleanup, has_status(),
## check_and_apply_shatter(), Burn Contagion.
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

## Movement speed multiplier applied to the target when Freeze is active.
## Speed is reduced to 50 % of base; restored to 1.0 on expiry or kill-cleanup (ADR-0011).
const FREEZE_SLOW_PCT: float = 0.50

## Reference only — SC&E must pass this value as [param duration]. Not read internally.
const FREEZE_DURATION: float = 2.0

## Time in seconds between Regen heal ticks (1 tick per second, 3 ticks over 3.0s default).
const REGEN_TICK_INTERVAL: float = 1.0

## Fraction of FAYDE_MAX_HP healed per Regen tick (status-effects.md Formula 2).
const REGEN_TICK_MAGNITUDE: float = 0.02

## Fayde's maximum HP used to compute the flat Regen tick heal amount (Formula 2).
## Source: Prana Data constants. Must match PlayerController.MAX_HEALTH when that value lands.
const FAYDE_MAX_HP: float = 100.0

## Movement speed multiplier applied to the target when Chill is active.
## Speed is reduced to 85 % of base; restored to 1.0 on expiry (1.0 - 0.15 = 0.85).
const CHILL_SLOW_PCT: float = 0.15

## Fixed stagger duration applied by Stagger (ignores the duration parameter).
## Source: status-effects.md Rule 4 step 8.
const STAGGER_DURATION: float = 0.3

## Damage multiplier when Shatter fires on a frozen target (Rule 10, Prana Data constants).
const SHATTER_MULTIPLIER: float = 1.25

## Pixel radius for Burn Contagion nearest-enemy scan on death (Formula 5).
const BURN_CONTAGION_RANGE: float = 200.0

## Duration in seconds applied to the Contagion recipient (Rule 8).
const BURN_CONTAGION_DURATION: float = 2.0


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
		for instance: StatusInstance in instances:
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

	# CHILL is suppressed when FREEZE is already active on the same target (Rule 4 step 7).
	if status_type == GameEnums.BaseStatus.CHILL:
		for existing_s: StatusInstance in _active_statuses[target_id]:
			if existing_s.status_type == GameEnums.BaseStatus.FREEZE:
				return  # FREEZE active — CHILL suppressed; no instance, no signal.

	# Stagger always uses a fixed 0.3s duration regardless of the caller-supplied value.
	var actual_duration: float = STAGGER_DURATION if status_type == GameEnums.BaseStatus.STAGGER else duration

	for existing: StatusInstance in _active_statuses[target_id]:
		if existing.status_type == status_type:
			existing.duration_remaining = actual_duration
			existing.tick_timer = 0.0
			existing.spell_base_damage = spell_base_damage
			status_applied.emit(target, status_type, actual_duration)
			return

	var inst: StatusInstance = StatusInstance.new()
	inst.target = target
	inst.status_type = status_type
	inst.duration_remaining = actual_duration
	inst.tick_interval = _tick_interval_for(status_type)
	inst.tick_timer = inst.tick_interval  # First tick fires after one full interval.
	inst.spell_base_damage = spell_base_damage
	_active_statuses[target_id].append(inst)
	status_applied.emit(target, status_type, actual_duration)

	match status_type:
		GameEnums.BaseStatus.FREEZE:
			target.apply_speed_modifier(1.0 - FREEZE_SLOW_PCT)
		GameEnums.BaseStatus.CHILL:
			target.apply_speed_modifier(1.0 - CHILL_SLOW_PCT)
		GameEnums.BaseStatus.STUN:
			target.apply_stun(actual_duration)
		GameEnums.BaseStatus.STAGGER:
			target.apply_stun(STAGGER_DURATION)


## Removes all active StatusInstances for [param target_id] without emitting
## status_expired. Used by both kill-cleanup and wave-clear paths to avoid
## spurious signal noise when bulk-clearing is intentional (Story 004).
##
## Restores speed modifiers for FREEZE and CHILL before discarding each instance
## so that target node state is not left in a modified condition.
func _run_expiry_cleanup(target_id: int) -> void:
	if not _active_statuses.has(target_id):
		return
	var instances: Array = _active_statuses[target_id].duplicate()
	for instance: StatusInstance in instances:
		match instance.status_type:
			GameEnums.BaseStatus.FREEZE, GameEnums.BaseStatus.CHILL:
				if is_instance_valid(instance.target):
					instance.target.apply_speed_modifier(1.0)
	_active_statuses.erase(target_id)


## Returns true if [param target] has at least one active StatusInstance of [param status_type].
## O(N) where N = statuses per target (max 7). Sole status-query interface (ADR-0011).
func has_status(target: Node, status_type: GameEnums.BaseStatus) -> bool:
	var instances: Array = _active_statuses.get(target.get_instance_id(), [])
	for instance: StatusInstance in instances:
		if instance.status_type == status_type:
			return true
	return false


## Called by SC&E before every DIRECT apply_damage() call (ADR-0011 Required).
## Returns [param base_damage] × SHATTER_MULTIPLIER when [param target] has active FREEZE.
## Emits [signal shatter_triggered]. Freeze is NOT consumed — non-consuming (AC-SE-18).
func check_and_apply_shatter(target: Node, base_damage: float) -> float:
	if has_status(target, GameEnums.BaseStatus.FREEZE):
		shatter_triggered.emit(target)
		return base_damage * SHATTER_MULTIPLIER
	return base_damage


# ── Private — validation ──────────────────────────────────────────────────────

## Returns false and logs errors for invalid apply_status() calls (Rule 4 steps 1–3).
## Guard order: duration → validity → scope → liveness. Liveness returns false silently.
func _is_apply_valid(target: Node, status_type: GameEnums.BaseStatus, duration: float) -> bool:
	if duration <= 0.0:
		push_error(
			"StatusEffectsManager.apply_status(): duration must be > 0.0 (got %f). "
			% duration
			+ "Zero or negative duration is a caller error (status-effects.md AC-SE-20)."
		)
		return false

	if not is_instance_valid(target):
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

func _fire_tick(instance: StatusInstance) -> void:
	match instance.status_type:
		GameEnums.BaseStatus.BURN:
			var tick_dmg: float = maxf(0.0, instance.spell_base_damage) * BURN_TICK_MAGNITUDE
			_health_and_damage.apply_damage(
				instance.target, tick_dmg, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DOT
			)
		GameEnums.BaseStatus.REGENERATE:
			var tick_heal: float = FAYDE_MAX_HP * REGEN_TICK_MAGNITUDE
			_health_and_damage.apply_heal(instance.target, tick_heal)


# ── Private — expiry ──────────────────────────────────────────────────────────

func _expire_status(instance: StatusInstance) -> void:
	var target_id: int = instance.target.get_instance_id()
	if not _active_statuses.has(target_id):
		return
	_active_statuses[target_id].erase(instance)
	if _active_statuses[target_id].is_empty():
		_active_statuses.erase(target_id)
	status_expired.emit(instance.target, instance.status_type)
	match instance.status_type:
		GameEnums.BaseStatus.FREEZE:
			# When Freeze expires, restore to Chill speed if Chill is still active,
			# otherwise restore full speed. Story 003 pre-condition fix (story-003 notes).
			var has_chill: bool = false
			var remaining: Array = _active_statuses.get(target_id, [])
			for s: StatusInstance in remaining:
				if s.status_type == GameEnums.BaseStatus.CHILL:
					has_chill = true
					break
			if is_instance_valid(instance.target):
				instance.target.apply_speed_modifier(
					1.0 - CHILL_SLOW_PCT if has_chill else 1.0
				)
		GameEnums.BaseStatus.CHILL:
			if is_instance_valid(instance.target):
				instance.target.apply_speed_modifier(1.0)


# ── Private — helpers ─────────────────────────────────────────────────────────

func _tick_interval_for(status_type: GameEnums.BaseStatus) -> float:
	match status_type:
		GameEnums.BaseStatus.BURN:
			return BURN_TICK_INTERVAL
		GameEnums.BaseStatus.REGENERATE:
			return REGEN_TICK_INTERVAL
		_:
			return 0.0


# ── Signal callbacks ─────────────────────────────────────────────────────────

func _on_enemy_killed(instance_id: int, _type_id: int, _affiliation: GameEnums.DamageClass) -> void:
	# Burn Contagion fires BEFORE cleanup so StatusInstances are still readable (Rule 8).
	if _active_statuses.has(instance_id):
		for instance: StatusInstance in _active_statuses[instance_id]:
			if instance.status_type == GameEnums.BaseStatus.BURN:
				_try_burn_contagion(instance.target.global_position, instance.spell_base_damage)
				break  # Only one Burn instance per target is possible.
	_run_expiry_cleanup(instance_id)


## Scans the scene for the nearest alive enemy within BURN_CONTAGION_RANGE and
## applies Burn Contagion. Only alive candidates are considered to prevent
## self-contagion onto the dying enemy (AC-SE-13).
## Duck-typed calls on candidates: `global_position` (Node2D) and `is_alive()` (EnemyInstance API).
func _try_burn_contagion(dying_pos: Vector2, original_spell_base: float) -> void:
	var nearest_node: Node = null
	var nearest_dist: float = INF
	var candidates: Array = get_tree().get_nodes_in_group(&"enemy")
	for candidate: Node in candidates:
		if not is_instance_valid(candidate):
			continue
		if not candidate.is_alive():
			continue
		var dist: float = candidate.global_position.distance_to(dying_pos)
		if dist <= BURN_CONTAGION_RANGE and dist < nearest_dist:
			nearest_dist = dist
			nearest_node = candidate
	if nearest_node != null:
		apply_status(nearest_node, GameEnums.BaseStatus.BURN,
				BURN_CONTAGION_DURATION, original_spell_base)
		burn_contagion_triggered.emit(dying_pos, nearest_node)


func _on_preparation_started(_wave_index: int, _waves_remaining: int) -> void:
	var target_ids: Array = _active_statuses.keys()
	for target_id: int in target_ids:
		_run_expiry_cleanup(target_id)
