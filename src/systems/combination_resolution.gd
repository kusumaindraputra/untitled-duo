## combination_resolution.gd — CombinationResolution Autoload #8.
##
## Implements the primary Prana type and tier resolution algorithm.
## Reads committed fragments from PranaGrid after combat_started fires,
## resolves primary_type from slot 4, computes effective primary count by
## summing levels of matching fragments, then maps count to a tier (1/2/3).
##
## Story 006 additions: _in_combat guard (exactly-once emission per wave),
## _on_preparation_started state clear, ADJ_ECHO delay timer with cancellation.
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

## Non-centre slot indices — slot 4 (centre) excluded. Tuning knob: NON_CENTRE_SLOTS.
const NON_CENTRE_SLOTS: Array[int] = [0, 1, 2, 3, 5, 6, 7, 8]

## All valid Prana type IDs. Iterate to build non-primary modifiers.
const ALL_TYPES: Array[int] = [0, 1, 2, 3, 4]

## Minimum effective count to reach non-primary Tier 2. Tuning knob — GDD Formula 4.
const NP_TIER2_MIN: int = 3

## Ashfire non-primary Tier 2 burn bonus added to base_damage_modifier.
## Tuning knob — GDD combination-resolution.md Formula 6.
const ASHFIRE_NP_BONUS: float = 0.15

## Stormgold non-primary Tier 1 combo window extension in seconds.
## Tuning knob — GDD combination-resolution.md Formula 6.
const STORMGOLD_NP_WINDOW_T1: float = 0.3

## Deepfrost non-primary Tier 1/2 chill slow fraction (0.0–1.0).
## Tuning knob — GDD combination-resolution.md Formula 6.
const CHILL_SLOW_PCT: float = 0.15

## Deepfrost non-primary Tier 2 freeze duration in seconds.
## Tuning knob — GDD combination-resolution.md Formula 6.
const NONPRIMARY_FREEZE_DURATION: float = 1.0

## Verdant non-primary Tier 2 heal amplifier multiplier.
## Tuning knob — GDD combination-resolution.md Formula 6.
const VERDANT_NP_HEAL_AMP: float = 1.25

## Cardinal direction constants for adjacency neighbor lookup (GDD Rule 9).
## Values match NeighborCondition.Direction enum entries.
const DIRECTION_ABOVE: int = 0
const DIRECTION_BELOW: int = 1
const DIRECTION_LEFT: int = 2
const DIRECTION_RIGHT: int = 3

## Delay in seconds before the Echo Strike fires after the full chain resolves.
## Tuning knob — GDD combination-resolution.md Tuning Knobs table (ADJ_ECHO_DELAY).
const ADJ_ECHO_DELAY: float = 0.8

## StringName identifier for the Echo Strike adjacency effect (GDD adjacency pool).
const ADJ_ECHO_EFFECT_ID: StringName = &"ADJ_ECHO"


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted once per wave when the spell payload is resolved.
## SpellCastingEffects is the sole authorised subscriber (ADR-0009).
signal combo_resolved(spell_effect: SpellEffect)

## Emitted after ADJ_ECHO_DELAY seconds when ADJ_ECHO is active this wave.
## Carries the resolved SpellEffect so the subscriber can execute the echo hit.
## Cancelled (never emitted) if preparation_started fires before the delay elapses.
signal echo_strike_fired(spell_effect: SpellEffect)


# ── Private state ─────────────────────────────────────────────────────────────

## Guards against duplicate combat_started signals in a single combat phase.
## Reset to false by _on_preparation_started.
var _in_combat: bool = false

## Float accumulator for the pending ADJ_ECHO delay (ADR-0004).
## Negative = no echo pending. Counts up in _process(); fires at ADJ_ECHO_DELAY.
var _echo_elapsed: float = -1.0

## SpellEffect resolved this wave. Held so _fire_echo_strike can emit it.
## Cleared on preparation_started.
var _cached_spell_effect: SpellEffect = null

## Test seam — overrides PranaGrid lookup when size == 9.
## Set via set_test_fragments() before triggering _on_combat_started in tests.
## Never set from production game code.
## Untyped Array — slots hold mixed null/PranaFragment; typed Array cannot hold null.
var _test_fragments: Array = []


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)


## Ticks the ADJ_ECHO float accumulator (ADR-0004 — no SceneTreeTimer on Autoloads).
## Early-exits when no echo is pending (_echo_elapsed < 0).
func _process(delta: float) -> void:
	if _echo_elapsed < 0.0:
		return
	_echo_elapsed += delta
	if _echo_elapsed >= ADJ_ECHO_DELAY:
		_echo_elapsed = -1.0
		_fire_echo_strike()


func _exit_tree() -> void:
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)


# ── Signal handlers ───────────────────────────────────────────────────────────

## Clears wave-scoped state and cancels any pending ADJ_ECHO timer.
## Ensures the next wave resolves fresh with no stale data.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	_clear_echo_timer()
	_in_combat = false
	_cached_spell_effect = null


## Reads committed fragments from PranaGrid (or an empty grid if PranaGrid is
## not yet available), resolves the SpellEffect, and emits combo_resolved.
##
## Guarded by _in_combat to prevent duplicate emissions if combat_started fires
## more than once in the same combat phase (AC-CR-26).
##
## PranaGrid is looked up dynamically via get_node_or_null so that this script
## parses and compiles even before PranaGrid is registered as an Autoload.
func _on_combat_started(_is_boss: bool) -> void:
	if _in_combat:
		return
	_in_combat = true

	var fragments: Array
	if _test_fragments.size() == 9:
		fragments = _test_fragments
	else:
		var prana_grid: Node = get_tree().get_first_node_in_group(&"prana_grid")
		if is_instance_valid(prana_grid):
			fragments = prana_grid.get_committed_fragments()
		else:
			fragments = _make_empty_grid()

	var effect: SpellEffect = _resolve(fragments)
	_cached_spell_effect = effect
	combo_resolved.emit(effect)

	if effect.active_adjacency_effects.has(ADJ_ECHO_EFFECT_ID):
		_start_echo_timer()


# ── Public resolution API ─────────────────────────────────────────────────────

## Resolves a SpellEffect from a 9-element fragments array.
##
## Slot 4 (centre) determines primary_type. If slot 4 is null, logs an error
## and returns an invalid SpellEffect with primary_type = -1.
## Effective primary count is the sum of levels across all fragments whose
## type_id matches primary_type. That count is mapped to a tier (1/2/3).
## combo_attack_count mirrors primary_tier at FP scope (1:1).
## base_damage_modifier and primary_base_status are read from PranaCatalog.
## aggregate_stat_bonus is the additive sum of all fragment stat_property dicts.
## Non-primary modifier fields are filled per GDD Formula 6 constants.
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

	# Populate non-primary modifiers (Story 003) and fill their type fields (Story 004).
	effect.non_primary_modifiers = _build_nonprimary_modifiers(fragments, primary_type)
	for mod in effect.non_primary_modifiers:
		_fill_nonprimary_modifier_fields(mod)

	# Populate catalog-driven fields: base_damage_modifier and primary_base_status (Story 004).
	_populate_from_catalog(effect, primary_type)

	# Aggregate stat bonuses from all placed fragments (Story 004).
	effect.aggregate_stat_bonus = _aggregate_stat_bonus(fragments)

	# Collect adjacency effects from all placed fragments (Story 005).
	effect.active_adjacency_effects = _collect_adjacency_effects(fragments)

	return effect


## Test seam — injects fragment data for integration tests, bypassing PranaGrid.
## Call with a 9-element Array before triggering _on_combat_started.
## Pass an empty Array to restore live PranaGrid lookup.
## Never call from production game code (see TR-HD-008 precedent).
func set_test_fragments(fragments: Array) -> void:
	_test_fragments = fragments


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


## Returns the effective non-primary count for Prana type `type_t`.
## Sums levels of all non-centre fragments whose type_id == type_t,
## excluding fragments of the primary type (primary fragments never count as non-primary).
##
## fragments: Array of length 9 (nulls allowed).
## type_t: Prana type ID being evaluated.
## primary_type: type_id of the centre fragment (excluded from counting).
## Returns effective count (int >= 0).
func _compute_nonprimary_count(fragments: Array, type_t: int, primary_type: int) -> int:
	if type_t == primary_type:
		return 0
	var count: int = 0
	for i in NON_CENTRE_SLOTS:
		var frag = fragments[i]
		if frag != null and frag.type_id == type_t:
			count += frag.level
	return count


## Maps an effective non-primary count to a tier (0 = inactive, 1 = Tier 1, 2 = Tier 2).
## Boundary: count 0 → 0 (inactive); 1–(NP_TIER2_MIN-1) → 1; NP_TIER2_MIN+ → 2.
##
## effective_count: result of _compute_nonprimary_count.
## Returns 0, 1, or 2.
func _compute_nonprimary_tier(effective_count: int) -> int:
	if effective_count <= 0:
		return 0
	elif effective_count < NP_TIER2_MIN:
		return 1
	else:
		return 2


## Builds the non_primary_modifiers array for the SpellEffect payload.
## Iterates ALL_TYPES, skips the primary type, computes effective count and tier
## for each, and appends a NonPrimaryModifier only when tier > 0 (i.e., active).
## type_id and tier fields are populated; type-specific fields are left at defaults
## and filled by _fill_nonprimary_modifier_fields() in Story 004.
##
## fragments: Array of length 9 (nulls allowed).
## primary_type: type_id of the centre fragment.
## Returns Array of NonPrimaryModifier (may be empty).
func _build_nonprimary_modifiers(fragments: Array, primary_type: int) -> Array:
	var modifiers: Array = []
	for t in ALL_TYPES:
		if t == primary_type:
			continue
		var count: int = _compute_nonprimary_count(fragments, t, primary_type)
		var tier: int = _compute_nonprimary_tier(count)
		if tier == 0:
			continue
		var mod: NonPrimaryModifier = NonPrimaryModifier.new()
		mod.type_id = t
		mod.tier = tier
		modifiers.append(mod)
	return modifiers


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


## Reads base_damage_modifier and primary_base_status from PranaCatalog
## and writes them to the SpellEffect payload (GDD Rule 11).
##
## Uses PranaCatalog.get_type() which returns duplicate_deep() — mutations to
## the returned PranaType do not affect the catalog (ADR-0008).
## If PranaCatalog returns null (not initialized or invalid id), logs an error
## and leaves effect fields at their Resource defaults.
##
## effect: SpellEffect being assembled.
## primary_type: type_id of the centre fragment.
func _populate_from_catalog(effect: SpellEffect, primary_type: int) -> void:
	var prana_catalog: Node = get_node_or_null("/root/PranaCatalog")
	if not is_instance_valid(prana_catalog):
		push_error(
			"CombinationResolution._populate_from_catalog(): PranaCatalog Autoload not found"
		)
		return
	var prana_type: PranaType = prana_catalog.get_type(primary_type)
	if prana_type == null:
		push_error(
			"CombinationResolution._populate_from_catalog(): get_type(%d) returned null"
			% primary_type
		)
		return
	effect.base_damage_modifier = prana_type.base_damage_modifier
	effect.primary_base_status = prana_type.base_status


## Builds the aggregate_stat_bonus Dictionary by additively summing all
## stat_property entries from every placed (non-null) fragment.
##
## Uses manual has()/+= loop — Dictionary.merge() overwrites existing keys
## and is NOT additive (ADR note, story-004 implementation notes).
## Keys are StringName stat IDs (e.g. &"ASH_DMG"); values are float deltas.
##
## fragments: Array of length 9 (nulls allowed).
## Returns a Dictionary mapping StringName → float (may be empty).
func _aggregate_stat_bonus(fragments: Array) -> Dictionary:
	var bonus: Dictionary = {}
	for frag in fragments:
		if frag == null:
			continue
		for key in frag.stat_property:
			if bonus.has(key):
				bonus[key] += frag.stat_property[key]
			else:
				bonus[key] = frag.stat_property[key]
	return bonus


## Fills type-specific fields on a NonPrimaryModifier according to its
## type_id and tier (GDD Formula 6).
##
## All values come from named constants — no magic numbers.
## Fields not relevant to a given type/tier are left at NonPrimaryModifier defaults.
##
## Prana type ID mapping:
##   0 = Ashfire   — T2: burn_bonus
##   1 = Voidblue  — no non-primary modifier fields in this story's scope
##   2 = Stormgold — T1+: window_extension; T2+: final_attack_stun
##   3 = Deepfrost — T1+: chill_slow_pct; T2+: freeze_duration
##   4 = Verdant   — T2+: heal_amplifier
##
## mod: NonPrimaryModifier with type_id and tier already set (by _build_nonprimary_modifiers).
func _fill_nonprimary_modifier_fields(mod: NonPrimaryModifier) -> void:
	match mod.type_id:
		0:  # Ashfire
			if mod.tier >= 2:
				mod.burn_bonus = ASHFIRE_NP_BONUS
		2:  # Stormgold
			mod.window_extension = STORMGOLD_NP_WINDOW_T1
			if mod.tier >= 2:
				mod.final_attack_stun = true
		3:  # Deepfrost
			mod.chill_slow_pct = CHILL_SLOW_PCT
			if mod.tier >= 2:
				mod.freeze_duration = NONPRIMARY_FREEZE_DURATION
		4:  # Verdant
			if mod.tier >= 2:
				mod.heal_amplifier = VERDANT_NP_HEAL_AMP


## Returns the slot index of the cardinal neighbor in the given direction,
## or -1 if the neighbor is out of grid bounds (GDD Rule 9).
##
## Uses integer division and modulo to convert a flat slot index to row/column:
##   row = slot / 3,  col = slot % 3
## Grid is 3×3; valid slot range is 0–8.
##
## slot: source slot index (0–8).
## direction: one of DIRECTION_ABOVE / DIRECTION_BELOW / DIRECTION_LEFT / DIRECTION_RIGHT.
## Returns neighbor slot index (0–8), or -1 when the direction leaves the grid.
func _get_neighbor_slot(slot: int, direction: int) -> int:
	var r: int = slot / 3
	var c: int = slot % 3
	match direction:
		DIRECTION_ABOVE:
			if r <= 0:
				return -1
			return slot - 3
		DIRECTION_BELOW:
			if r >= 2:
				return -1
			return slot + 3
		DIRECTION_LEFT:
			if c <= 0:
				return -1
			return slot - 1
		DIRECTION_RIGHT:
			if c >= 2:
				return -1
			return slot + 1
	return -1


## Returns true when the neighbor condition is satisfied for a fragment at slot.
##
## Out-of-bounds neighbor → false (condition unsatisfied, not an error).
## Null neighbor slot → false (empty slot cannot satisfy any condition).
## required_type_id == -1 → wildcard: any non-null fragment satisfies the condition.
## Otherwise: neighbor.type_id must equal required_type_id.
##
## fragments: Array of length 9 (nulls allowed).
## slot: index of the fragment whose condition is being checked (0–8).
## condition: NeighborCondition describing direction and required type.
## Returns true if the condition is satisfied, false otherwise.
func _is_condition_satisfied(fragments: Array, slot: int, condition: NeighborCondition) -> bool:
	var neighbor_slot: int = _get_neighbor_slot(slot, condition.direction)
	if neighbor_slot == -1:
		return false
	var neighbor = fragments[neighbor_slot]
	if neighbor == null:
		return false
	if condition.required_type_id != -1:
		if neighbor.type_id != condition.required_type_id:
			return false
	return true


## Iterates every placed fragment in the grid and collects the effect_id of each
## AdjacencyEffect whose required_neighbors conditions are all satisfied (AND logic).
##
## Empty required_neighbors is vacuously satisfied — the effect always fires.
## No deduplication: two fragments that each produce the same effect_id both
## append to the collected array independently.
##
## fragments: Array of length 9 (nulls allowed).
## Returns an Array of StringName effect IDs (may be empty).
func _collect_adjacency_effects(fragments: Array) -> Array:
	var collected: Array = []
	for i in range(9):
		var frag = fragments[i]
		if frag == null:
			continue
		for adj_effect in frag.adjacency_effects:
			var satisfied: bool = true
			for condition in adj_effect.required_neighbors:
				if not _is_condition_satisfied(fragments, i, condition):
					satisfied = false
					break
			if satisfied:
				collected.append(adj_effect.effect_id)
	return collected


## Arms the ADJ_ECHO accumulator (ADR-0004 float accumulator pattern).
## _process() will fire _fire_echo_strike() after ADJ_ECHO_DELAY seconds.
func _start_echo_timer() -> void:
	_echo_elapsed = 0.0


## Disarms the ADJ_ECHO accumulator. Safe to call when no echo is pending.
func _clear_echo_timer() -> void:
	_echo_elapsed = -1.0


## Fires echo_strike_fired with the cached SpellEffect after ADJ_ECHO_DELAY elapses.
## Only reached if _clear_echo_timer() was not called first (i.e., preparation_started
## did not fire before the delay expired).
func _fire_echo_strike() -> void:
	if _cached_spell_effect != null:
		echo_strike_fired.emit(_cached_spell_effect)
