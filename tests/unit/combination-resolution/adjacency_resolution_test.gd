## adjacency_resolution_test.gd — Unit tests for CombinationResolution Story 005.
##
## Covers ACs: CR-16 through CR-23 (adjacency effect resolution).
##
## Adjacency resolution is pure data — no PranaCatalog or SceneTree access needed.
## All tests use standalone _make_cr() instances freed with cr.free().
##
## CombinationResolution has no class_name (Autoload naming constraint), so it is
## loaded via load() rather than referenced as a global class name.
##
## AdjacencyEffect and NeighborCondition are class_name Resources — instantiated
## directly. PranaFragment, SpellEffect are RefCounted — do NOT call .free() on them.
##
## Standalone CombinationResolution instances (not added to tree) are freed with
## node.free() (not queue_free()) — avoids GdUnit4 orphan warnings and exit code 101.
##
## Direction integer constants (NeighborCondition.Direction enum):
##   ABOVE = 0, BELOW = 1, LEFT = 2, RIGHT = 3
##
## Prana type ID constants:
##   Ashfire = 0, Voidblue = 1, Stormgold = 2, Deepfrost = 3, Verdant = 4
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Loads and instantiates a standalone CombinationResolution for direct method testing.
## NOT added to the scene tree — free with node.free() after each test.
func _make_cr() -> Node:
	var script := load("res://src/systems/combination_resolution.gd")
	return script.new()


## Returns a new PranaFragment with the given type_id and level.
## adjacency_effects defaults to empty — add effects explicitly per test.
func _make_frag(type_id: int, level: int = 1) -> PranaFragment:
	var frag := PranaFragment.new()
	frag.type_id = type_id
	frag.level = level
	return frag


## Returns a 9-element Array of nulls (empty Prana grid).
func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(9)
	return grid


## Builds an AdjacencyEffect Resource with the given effect_id and optional conditions.
## conditions: Array of NeighborCondition — empty = vacuously satisfied (always fires).
func _make_adj_effect(effect_id: StringName, conditions: Array = []) -> AdjacencyEffect:
	var ae := AdjacencyEffect.new()
	ae.effect_id = effect_id
	ae.required_neighbors = conditions
	return ae


## Builds a NeighborCondition Resource.
## direction: 0=ABOVE, 1=BELOW, 2=LEFT, 3=RIGHT (NeighborCondition.Direction values).
## required_type_id: -1 = wildcard; 0–4 = specific Prana type must match.
func _make_condition(direction: int, required_type_id: int = -1) -> NeighborCondition:
	var cond := NeighborCondition.new()
	cond.direction = direction
	cond.required_type_id = required_type_id
	return cond


# ── AC-CR-16: No-condition effect always fires ────────────────────────────────
#
# slot 4 fragment with required_neighbors = [] (ADJ_DOUBLE_HIT); all other slots null.
# active_adjacency_effects must contain &"ADJ_DOUBLE_HIT".

func test_no_condition_adjacency_effect_always_fires() -> void:
	# Arrange
	var cr := _make_cr()
	var fragments := _make_grid()
	var frag := _make_frag(0)  # Ashfire at slot 4
	frag.adjacency_effects = [_make_adj_effect(&"ADJ_DOUBLE_HIT")]
	fragments[4] = frag

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_DOUBLE_HIT")).is_true()

	cr.free()


func test_no_condition_effect_fires_regardless_of_neighbor_content() -> void:
	# Arrange — same as CR-16 but with a non-null neighbor present; still must fire.
	var cr := _make_cr()
	var fragments := _make_grid()
	var frag := _make_frag(0)  # Ashfire at slot 4
	frag.adjacency_effects = [_make_adj_effect(&"ADJ_DOUBLE_HIT")]
	fragments[4] = frag
	fragments[1] = _make_frag(3)  # Deepfrost above — irrelevant to no-condition effect

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_DOUBLE_HIT")).is_true()

	cr.free()


# ── AC-CR-17: AND conditions — all satisfied → effect fires ──────────────────
#
# slot 4 requires ABOVE=Ashfire(0) AND BELOW=Ashfire(0).
# slot 1 (ABOVE slot 4) = Ashfire; slot 7 (BELOW slot 4) = Ashfire → effect present.

func test_and_conditions_all_satisfied_effect_fires() -> void:
	# Arrange
	var cr := _make_cr()
	var fragments := _make_grid()

	var conditions: Array = [
		_make_condition(NeighborCondition.Direction.ABOVE, 0),  # ABOVE = Ashfire
		_make_condition(NeighborCondition.Direction.BELOW, 0),  # BELOW = Ashfire
	]
	var frag := _make_frag(0)  # Ashfire at slot 4
	frag.adjacency_effects = [_make_adj_effect(&"ADJ_BURN_INTENSIFY", conditions)]
	fragments[4] = frag
	fragments[1] = _make_frag(0)  # Ashfire at slot 1 (ABOVE slot 4)
	fragments[7] = _make_frag(0)  # Ashfire at slot 7 (BELOW slot 4)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_BURN_INTENSIFY")).is_true()

	cr.free()


# ── AC-CR-18: AND conditions — partial satisfaction → effect does NOT fire ────
#
# Same fragment as CR-17 but one condition is unmet.

func test_and_conditions_below_null_effect_absent() -> void:
	# Arrange — slot 7 is null (BELOW unsatisfied)
	var cr := _make_cr()
	var fragments := _make_grid()

	var conditions: Array = [
		_make_condition(NeighborCondition.Direction.ABOVE, 0),
		_make_condition(NeighborCondition.Direction.BELOW, 0),
	]
	var frag := _make_frag(0)
	frag.adjacency_effects = [_make_adj_effect(&"ADJ_BURN_INTENSIFY", conditions)]
	fragments[4] = frag
	fragments[1] = _make_frag(0)  # ABOVE satisfied
	# slot 7 remains null — BELOW unsatisfied

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_BURN_INTENSIFY")).is_false()

	cr.free()


func test_and_conditions_below_wrong_type_effect_absent() -> void:
	# Arrange — slot 7 = Deepfrost (wrong type for BELOW=Ashfire condition)
	var cr := _make_cr()
	var fragments := _make_grid()

	var conditions: Array = [
		_make_condition(NeighborCondition.Direction.ABOVE, 0),
		_make_condition(NeighborCondition.Direction.BELOW, 0),
	]
	var frag := _make_frag(0)
	frag.adjacency_effects = [_make_adj_effect(&"ADJ_BURN_INTENSIFY", conditions)]
	fragments[4] = frag
	fragments[1] = _make_frag(0)   # ABOVE satisfied (Ashfire)
	fragments[7] = _make_frag(3)   # BELOW has Deepfrost — wrong type, unsatisfied

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_BURN_INTENSIFY")).is_false()

	cr.free()


# ── AC-CR-19: Out-of-bounds direction → unsatisfied, no error ─────────────────
#
# slot 0 is in row 0 — ABOVE is out of bounds → condition unsatisfied, effect absent.
# No push_error should fire (guardrail: OOB = unsatisfied, not an error).

func test_out_of_bounds_above_from_slot_0_effect_absent() -> void:
	# Arrange — slot 0 (row=0, col=0): ABOVE has no row above it → -1
	var cr := _make_cr()
	var fragments := _make_grid()

	var frag := _make_frag(3)  # Deepfrost at slot 0
	frag.adjacency_effects = [
		_make_adj_effect(&"ADJ_OOB_TEST", [_make_condition(NeighborCondition.Direction.ABOVE, -1)])
	]
	fragments[4] = _make_frag(3)  # slot 4 must be non-null for _resolve to proceed
	fragments[0] = frag

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — effect absent; no error thrown (test completes cleanly)
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_OOB_TEST")).is_false()

	cr.free()


func test_get_neighbor_slot_above_from_row_0_returns_minus_one() -> void:
	# Directly tests the helper: slot 0 ABOVE → -1; slot 2 ABOVE → -1; slot 1 ABOVE → -1.
	var cr := _make_cr()

	assert_int(cr._get_neighbor_slot(0, 0)).is_equal(-1)  # slot 0, ABOVE
	assert_int(cr._get_neighbor_slot(1, 0)).is_equal(-1)  # slot 1, ABOVE
	assert_int(cr._get_neighbor_slot(2, 0)).is_equal(-1)  # slot 2, ABOVE

	cr.free()


# ── AC-CR-20: Null neighbor does not satisfy any condition ────────────────────
#
# slot 4 with LEFT condition; slot 3 is null → effect absent.

func test_null_neighbor_does_not_satisfy_wildcard_condition() -> void:
	# Arrange — slot 3 (LEFT of slot 4) is null
	var cr := _make_cr()
	var fragments := _make_grid()

	var frag := _make_frag(0)
	frag.adjacency_effects = [
		_make_adj_effect(&"ADJ_NULL_TEST", [_make_condition(NeighborCondition.Direction.LEFT, -1)])
	]
	fragments[4] = frag
	# slot 3 remains null

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_NULL_TEST")).is_false()

	cr.free()


# ── AC-CR-21: Wrong type does not satisfy typed condition ─────────────────────
#
# slot 4 with RIGHT condition requiring Stormgold (type 2); slot 5 = Deepfrost (type 3).

func test_wrong_type_neighbor_does_not_satisfy_typed_condition() -> void:
	# Arrange
	var cr := _make_cr()
	var fragments := _make_grid()

	var frag := _make_frag(0)
	frag.adjacency_effects = [
		_make_adj_effect(&"ADJ_TYPE_TEST", [_make_condition(NeighborCondition.Direction.RIGHT, 2)])
	]
	fragments[4] = frag
	fragments[5] = _make_frag(3)  # Deepfrost at RIGHT — wrong type (requires Stormgold=2)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_TYPE_TEST")).is_false()

	cr.free()


# ── AC-CR-22: Wildcard accepts any present non-null type ──────────────────────
#
# slot 4 with RIGHT condition type -1 (wildcard); slot 5 = Deepfrost lv.1 → effect present.

func test_wildcard_condition_satisfied_by_any_non_null_neighbor() -> void:
	# Arrange
	var cr := _make_cr()
	var fragments := _make_grid()

	var frag := _make_frag(0)
	frag.adjacency_effects = [
		_make_adj_effect(&"ADJ_WILDCARD_TEST", [_make_condition(NeighborCondition.Direction.RIGHT, -1)])
	]
	fragments[4] = frag
	fragments[5] = _make_frag(3, 1)  # Deepfrost lv.1 — any type satisfies wildcard

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_WILDCARD_TEST")).is_true()

	cr.free()


# ── AC-CR-23: Multiple fragments, multiple effects collected ──────────────────
#
# slot 4 = ADJ_DOUBLE_HIT (no conditions) + slot 0 = ADJ_STATUS_EXTEND requiring
# BELOW=any, satisfied by slot 3 = Ashfire lv.1.
# active_adjacency_effects.size() == 2, both effects present.

func test_multiple_fragments_multiple_effects_all_collected() -> void:
	# Arrange
	# slot 4: Ashfire with ADJ_DOUBLE_HIT (no conditions — always fires)
	var cr := _make_cr()
	var fragments := _make_grid()

	var frag4 := _make_frag(0)  # Ashfire at slot 4
	frag4.adjacency_effects = [_make_adj_effect(&"ADJ_DOUBLE_HIT")]
	fragments[4] = frag4

	# slot 0: Deepfrost with ADJ_STATUS_EXTEND requiring BELOW=any (slot 3 = Ashfire)
	# BELOW from slot 0 (row=0, col=0) → slot 3 (row=1, col=0)
	var frag0 := _make_frag(3)  # Deepfrost at slot 0
	frag0.adjacency_effects = [
		_make_adj_effect(&"ADJ_STATUS_EXTEND", [_make_condition(NeighborCondition.Direction.BELOW, -1)])
	]
	fragments[0] = frag0
	fragments[3] = _make_frag(0, 1)  # Ashfire lv.1 at slot 3 — satisfies BELOW wildcard

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — both effects collected, no deduplication
	assert_int(effect.active_adjacency_effects.size()).is_equal(2)
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_DOUBLE_HIT")).is_true()
	assert_bool(effect.active_adjacency_effects.has(&"ADJ_STATUS_EXTEND")).is_true()

	cr.free()


# ── Helper unit tests: _get_neighbor_slot ────────────────────────────────────

func test_get_neighbor_slot_above_returns_slot_minus_3() -> void:
	# slot 4 (row=1) ABOVE → slot 1
	var cr := _make_cr()
	assert_int(cr._get_neighbor_slot(4, 0)).is_equal(1)
	cr.free()


func test_get_neighbor_slot_below_returns_slot_plus_3() -> void:
	# slot 4 (row=1) BELOW → slot 7
	var cr := _make_cr()
	assert_int(cr._get_neighbor_slot(4, 1)).is_equal(7)
	cr.free()


func test_get_neighbor_slot_left_returns_slot_minus_1() -> void:
	# slot 4 (col=1) LEFT → slot 3
	var cr := _make_cr()
	assert_int(cr._get_neighbor_slot(4, 2)).is_equal(3)
	cr.free()


func test_get_neighbor_slot_right_returns_slot_plus_1() -> void:
	# slot 4 (col=1) RIGHT → slot 5
	var cr := _make_cr()
	assert_int(cr._get_neighbor_slot(4, 3)).is_equal(5)
	cr.free()


func test_get_neighbor_slot_below_from_row_2_returns_minus_one() -> void:
	# slot 6, 7, 8 are in row 2 — BELOW is OOB
	var cr := _make_cr()
	assert_int(cr._get_neighbor_slot(6, 1)).is_equal(-1)
	assert_int(cr._get_neighbor_slot(7, 1)).is_equal(-1)
	assert_int(cr._get_neighbor_slot(8, 1)).is_equal(-1)
	cr.free()


func test_get_neighbor_slot_left_from_col_0_returns_minus_one() -> void:
	# slots 0, 3, 6 are in col 0 — LEFT is OOB
	var cr := _make_cr()
	assert_int(cr._get_neighbor_slot(0, 2)).is_equal(-1)
	assert_int(cr._get_neighbor_slot(3, 2)).is_equal(-1)
	assert_int(cr._get_neighbor_slot(6, 2)).is_equal(-1)
	cr.free()


func test_get_neighbor_slot_right_from_col_2_returns_minus_one() -> void:
	# slots 2, 5, 8 are in col 2 — RIGHT is OOB
	var cr := _make_cr()
	assert_int(cr._get_neighbor_slot(2, 3)).is_equal(-1)
	assert_int(cr._get_neighbor_slot(5, 3)).is_equal(-1)
	assert_int(cr._get_neighbor_slot(8, 3)).is_equal(-1)
	cr.free()
