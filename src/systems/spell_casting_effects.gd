## spell_casting_effects.gd — SpellCastingEffects Autoload #9.
## Sole owner of the wave's SpellEffect payload and wave-scoped stat broker (ADR-0009).
##
## Story: SC&E Story 001 — SpellEffect Resource, Stub CR, and Autoload Skeleton
## Story: SC&E Story 002 — Cast Input, Float Accumulators, and Chain Timing
## Story: SC&E Story 003 — FP Damage Formula, Targeting, and Status Stubs
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0004 (Float Accumulator Timers),
##      ADR-0009 (Wave-Scoped Stat Broker), ADR-0011 (StatusEffectsManager API)
##
## Operative states (TR-SC-001):
##   IDLE        — No active SpellEffect; cast input blocked.
##   READY       — SpellEffect cached; awaiting player cast press.
##   CHAINING    — Within the combo-continuation window after first hit.
##   CAST_LOCKED — Post-hit lock window; movement and new casts blocked.
##
## Responsibilities (Story 001 — skeleton):
##   - Declare four-state enum and initial field values
##   - Declare the three output signals: spell_hit_element, cast_hit_started,
##     chain_index_changed
##   - Connect to GameStateManager.preparation_started, combat_started,
##     and CombinationResolution.combo_resolved in _ready()
##   - Implement phase-gating: _on_combo_resolved rejects primary_type == -1
##   - Implement get_stat_bonus() as sole stat query interface (ADR-0009)
##   - Disconnect from all signals in _exit_tree() (ADR-0003 Rule 4)
##
## Responsibilities (Story 002 — cast input and chain timing):
##   - Register "cast" action in InputMap if not already present
##   - Float accumulator timers: _cast_lock_timer, _combo_window_timer (ADR-0004)
##   - _process(delta): decrement timers, handle CAST_LOCKED → CHAINING/READY
##     transitions, poll cast input when READY or CHAINING (TR-SC-002)
##   - _trigger_cast(): advance _combo_index, emit cast_hit_started and
##     chain_index_changed (TR-SC-006, TR-SC-008)
##
## Registration: Autoload #9 in project.godot (ADR-0002).
## No class_name — Godot 4 rejects class_name matching the Autoload node name.
## Access: SpellCastingEffects.get_stat_bonus(&"ASH_DMG")
## Access in tests: preload("res://src/systems/spell_casting_effects.gd").new()
extends Node


# ── State enum ────────────────────────────────────────────────────────────────

## Operative state machine for the spell casting lifecycle.
enum SCEState {
	IDLE        = 0,  ## No active SpellEffect. Initial state; reset on preparation_started.
	READY       = 1,  ## SpellEffect cached; awaiting player cast press.
	CHAINING    = 2,  ## Combo-continuation window active after first chain attack.
	CAST_LOCKED = 3,  ## Post-hit lock window; input blocked until timer expires.
}


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted per hit — CombatHUD uses prana_type_id for damage-number coloring.
signal spell_hit_element(target: Node, prana_type_id: int)

## Emitted after each hit — PlayerController enters CAST_LOCKED movement sub-state.
signal cast_hit_started(lock_duration: float)

## Emitted when _combo_index changes — drives CombatHUD chain-dot indicator.
signal chain_index_changed(combo_index: int, combo_attack_count: int)


# ── Constants ─────────────────────────────────────────────────────────────────

## Default cast lock duration after each hit (all Prana types except Ashfire). (TR-SC-002)
const CAST_LOCK_DURATION: float = 0.12

## Extended cast lock for Ashfire — dance identity requires longer recovery. (TR-SC-002)
const ASHFIRE_CAST_LOCK_DURATION: float = 0.20

## Seconds the player has to press the next chain attack before the chain resets. (TR-SC-002)
const COMBO_CONTINUATION_WINDOW: float = 2.0


# ── Private state ─────────────────────────────────────────────────────────────

## Current operative state.
var _state: SCEState = SCEState.IDLE

## Index of the next chain attack to fire (0 = first, increments on each press).
var _combo_index: int = 0

## Cached SpellEffect for the current wave. Null between waves. (ADR-0009)
var _current_spell_effect: SpellEffect = null

## True while the GameStateManager is in COMBAT phase.
## Required so _on_combo_resolved can guard the IDLE→READY transition.
var _in_combat: bool = false

## Counts down after each hit; blocks cast input when > 0. (ADR-0004, TR-SC-002)
var _cast_lock_timer: float = 0.0

## Counts down between chain presses; resets to COMBO_CONTINUATION_WINDOW on each cast. (ADR-0004, TR-SC-002)
var _combo_window_timer: float = 0.0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	if not InputMap.has_action(&"cast"):
		InputMap.add_action(&"cast")
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		InputMap.action_add_event(&"cast", ev)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	CombinationResolution.combo_resolved.connect(_on_combo_resolved)


func _exit_tree() -> void:
	# ADR-0003 Rule 4: Autoloads must disconnect from all signals in _exit_tree().
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if CombinationResolution.combo_resolved.is_connected(_on_combo_resolved):
		CombinationResolution.combo_resolved.disconnect(_on_combo_resolved)


# ── Frame update ──────────────────────────────────────────────────────────────

## Drives all SC&E float accumulator timers per ADR-0004.
## Handles CAST_LOCKED expiry, combo window expiry, and cast input polling. (TR-SC-002)
func _process(delta: float) -> void:
	if _cast_lock_timer > 0.0:
		_cast_lock_timer -= delta
		if _cast_lock_timer <= 0.0:
			_cast_lock_timer = 0.0
			if _state == SCEState.CAST_LOCKED:
				_state = SCEState.CHAINING if _combo_index > 0 else SCEState.READY

	if _state == SCEState.CHAINING:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			# Combo window expired — reset chain to READY
			_combo_index = 0
			_state = SCEState.READY
			chain_index_changed.emit(0, _current_spell_effect.combo_attack_count if _current_spell_effect else 0)

	if (_state == SCEState.READY or _state == SCEState.CHAINING) and _cast_lock_timer <= 0.0:
		if Input.is_action_just_pressed(&"cast"):
			_trigger_cast()


## Fires a single chain attack: advances _combo_index, emits signals, sets timers. (TR-SC-006, TR-SC-008)
## Story 003 will inject _fire_attack() here — for Story 002 this is state advancement only.
func _trigger_cast() -> void:
	if _current_spell_effect == null:
		return
	var combo_count: int = _current_spell_effect.combo_attack_count
	# Story 003 will implement _fire_attack() here
	# For Story 002: advance state only; no apply_damage yet
	_combo_index += 1
	chain_index_changed.emit(_combo_index, combo_count)

	var lock_dur: float = ASHFIRE_CAST_LOCK_DURATION if _current_spell_effect.primary_type == GameEnums.DamageClass.FIRE \
		else CAST_LOCK_DURATION
	cast_hit_started.emit(lock_dur)
	_cast_lock_timer = lock_dur
	_state = SCEState.CAST_LOCKED
	_combo_window_timer = COMBO_CONTINUATION_WINDOW
	# Final hit in chain — combo reset handled in Story 003


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the additive stat delta for [param stat_id] from the current wave's SpellEffect.
## Returns 0.0 when no SpellEffect is cached (between waves or preparation_started).
## Callers: HealthAndDamage (VER_HEAL_FLAT), StatusEffectsManager (duration bonuses).
## No other system may read aggregate_stat_bonus directly (ADR-0009).
func get_stat_bonus(stat_id: StringName) -> float:
	if _current_spell_effect == null:
		return 0.0
	return _current_spell_effect.aggregate_stat_bonus.get(stat_id, 0.0)


# ── Signal handlers ───────────────────────────────────────────────────────────

## Resets all wave state when a new preparation phase begins.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	_state = SCEState.IDLE
	_combo_index = 0
	_in_combat = false
	_current_spell_effect = null
	_cast_lock_timer = 0.0
	_combo_window_timer = 0.0


## Marks SC&E as in-combat so the next combo_resolved can transition to READY.
func _on_combat_started(_is_boss: bool) -> void:
	_in_combat = true


## Caches the wave SpellEffect and transitions to READY (when in combat).
## Rejects payloads with primary_type == -1 via push_error — stays IDLE.
func _on_combo_resolved(spell_effect: SpellEffect) -> void:
	if spell_effect == null:
		push_error("SpellCastingEffects: combo_resolved received null SpellEffect. Staying IDLE.")
		return
	if spell_effect.primary_type == GameEnums.DamageClass.NONE:
		push_error("SpellCastingEffects: combo_resolved received invalid SpellEffect (primary_type == NONE). Staying IDLE.")
		return
	if not _in_combat:
		return
	_current_spell_effect = spell_effect
	_state = SCEState.READY
	_combo_index = 0
