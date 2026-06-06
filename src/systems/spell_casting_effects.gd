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


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
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


## Marks SC&E as in-combat so the next combo_resolved can transition to READY.
func _on_combat_started(_is_boss: bool) -> void:
	_in_combat = true


## Caches the wave SpellEffect and transitions to READY (when in combat).
## Rejects payloads with primary_type == -1 via push_error — stays IDLE.
func _on_combo_resolved(spell_effect: SpellEffect) -> void:
	if spell_effect == null:
		push_error("SpellCastingEffects: combo_resolved received null SpellEffect. Staying IDLE.")
		return
	if spell_effect.primary_type == -1:
		push_error("SpellCastingEffects: combo_resolved received invalid SpellEffect (primary_type == -1). Staying IDLE.")
		return
	if not _in_combat:
		return
	_current_spell_effect = spell_effect
	_state = SCEState.READY
	_combo_index = 0
