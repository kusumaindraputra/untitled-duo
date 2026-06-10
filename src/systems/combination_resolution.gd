## combination_resolution.gd — CombinationResolution Autoload #8.
##
## Implements the primary Prana type and tier resolution algorithm.
## Reads committed fragments from PranaGrid after combat_started fires,
## resolves primary_type from slot 4, computes effective primary count by
## summing levels of matching fragments, then maps count to a tier (1/2/3).
##
## Registration: Autoload #8 in project.godot (ADR-0002).
## No class_name — Godot 4 rejects class_name matching the Autoload node name
## ("hides autoload singleton" parse error).
## Access: CombinationResolution.combo_resolved.connect(...)
extends Node


# ── Constants ─────────────────────────────────────────────────────────────────

## Maximum effective primary count for Tier 1. Counts above this enter Tier 2.
## Tuning knob — see GDD combination-resolution.md Formula 2.
const PRIMARY_T1_MAX: int = 2

## Maximum effective primary count for Tier 2. Counts above this enter Tier 3.
## Tuning knob — see GDD combination-resolution.md Formula 2.
const PRIMARY_T2_MAX: int = 5


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted once per wave when the spell payload is resolved.
## SpellCastingEffects is the sole authorised subscriber (ADR-0009).
signal combo_resolved(spell_effect: SpellEffect)


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)


func _exit_tree() -> void:
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)


# ── Signal handlers ───────────────────────────────────────────────────────────

## Wave reset hook — state clear belongs to Story 006.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	pass


## Reads committed fragments from PranaGrid (or an empty grid if PranaGrid is
## not yet available), resolves the SpellEffect, and emits combo_resolved.
##
## PranaGrid is looked up dynamically via get_node_or_null so that this script
## parses and compiles even before PranaGrid is registered as an Autoload.
func _on_combat_started(_is_boss: bool) -> void:
	var fragments: Array
	var prana_grid: Node = get_node_or_null("/root/PranaGrid")
	if is_instance_valid(prana_grid):
		fragments = prana_grid.get_committed_fragments()
	else:
		fragments = _make_empty_grid()
	var effect: SpellEffect = _resolve(fragments)
	combo_resolved.emit(effect)


# ── Public resolution API ─────────────────────────────────────────────────────

## Resolves a SpellEffect from a 9-element fragments array.
##
## Slot 4 (centre) determines primary_type. If slot 4 is null, logs an error
## and returns an invalid SpellEffect with primary_type = -1.
## Effective primary count is the sum of levels across all fragments whose
## type_id matches primary_type. That count is mapped to a tier (1/2/3).
## combo_attack_count mirrors primary_tier at FP scope (1:1).
##
## fragments: Array of length 9; null entries represent empty slots.
## Returns a populated SpellEffect (caller owns it).
func _resolve(fragments: Array) -> SpellEffect:
	var effect: SpellEffect = SpellEffect.new()

	# Determine primary type from centre slot.
	var centre: PranaFragment = fragments[4] if fragments.size() > 4 else null
	if centre == null:
		push_error("CombinationResolution: slot 4 is null — cannot resolve primary type")
		effect.primary_type = -1
		return effect

	var primary_type: int = centre.type_id
	effect.primary_type = primary_type

	# Compute tier from effective count.
	var count: int = _compute_effective_primary_count(fragments, primary_type)
	var tier: int = _compute_primary_tier(count)
	effect.primary_tier = tier
	effect.combo_attack_count = tier

	# Fields populated by later stories — leave at Resource defaults.
	# base_damage_modifier = 1.0 (Story 004)
	# aggregate_stat_bonus = {} (Story 003)
	# primary_base_status = -1 (Story 004)
	# non_primary_modifiers = [] (Story 003)
	# active_adjacency_effects = [] (Story 005)

	return effect


# ── Private helpers ───────────────────────────────────────────────────────────

## Returns an Array of 9 nulls representing an empty Prana grid.
## Used when PranaGrid is not yet available (FP scope).
func _make_empty_grid() -> Array:
	var grid: Array = []
	grid.resize(9)
	return grid


## Sums the levels of all fragments in the grid whose type_id matches
## primary_type. Null slots and fragments of other types are ignored.
##
## fragments: Array of length 9 (nulls allowed).
## primary_type: type_id of the centre fragment.
## Returns the effective primary count (int >= 0).
func _compute_effective_primary_count(fragments: Array, primary_type: int) -> int:
	var count: int = 0
	for frag in fragments:
		if frag != null and frag.type_id == primary_type:
			count += frag.level
	return count


## Maps an effective primary count to a tier (1, 2, or 3).
## Tier boundaries are controlled by PRIMARY_T1_MAX and PRIMARY_T2_MAX.
##
## effective_count: result of _compute_effective_primary_count.
## Returns 1, 2, or 3.
func _compute_primary_tier(effective_count: int) -> int:
	if effective_count <= PRIMARY_T1_MAX:
		return 1
	elif effective_count <= PRIMARY_T2_MAX:
		return 2
	else:
		return 3
