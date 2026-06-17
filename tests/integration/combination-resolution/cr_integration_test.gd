## cr_integration_test.gd — Integration tests for CombinationResolution Story 006.
##
## Coverage:
##   AC-CR-24: slot 4 null → push_error + combo_resolved emitted with primary_type == -1
##   AC-CR-25: all 9 slots null → same as AC-CR-24
##   AC-CR-26: valid arrangement → combo_resolved emitted exactly once; primary_type in [0,4]
##   AC-CR-27: preparation_started clears cache — second wave reflects new arrangement
##   AC-CR-28: ADJ_ECHO timer cancelled by preparation_started (no echo_strike_fired emitted)
##
## Setup pattern:
##   - CR added to tree via add_child() — required for get_tree().create_timer() in timer tests
##   - Teardown: remove_child(cr) + cr.free() in every test (not queue_free — no SceneTree
##     deletion queue in headless GdUnit4; orphans cause exit 101)
##   - Handlers called directly (_on_combat_started, _on_preparation_started) — avoids emitting
##     real GSM signals which would fire other connected Autoloads (AudioSystem, WaveManager, etc.)
##   - Fragment injection via set_test_fragments() — documented test seam on CR (Story 006)
##   - AC-CR-24/25 omit set_test_fragments so CR falls back to _make_empty_grid() (all nulls)
##   - PranaGrid NOT installed as a mock — test seam makes it unnecessary
##   - push_error cannot be intercepted in GdUnit4; tests assert the observable downstream
##     effect (primary_type == -1) which is the contract SC&E cares about
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

## Mirrored from CR constant — used in AC-CR-28 wait calculations.
const ADJ_ECHO_DELAY: float = 0.8


# ── Helpers ───────────────────────────────────────────────────────────────────

## Instantiates CR and adds it to the scene tree.
## Must be paired with _teardown_cr() in every test.
func _make_cr() -> Node:
	var script := load("res://src/systems/combination_resolution.gd")
	var cr: Node = script.new()
	add_child(cr)
	return cr


## Removes CR from the tree and immediately frees it.
## free() rather than queue_free() — headless tests have no SceneTree deletion queue.
func _teardown_cr(cr: Node) -> void:
	remove_child(cr)
	cr.free()


## Returns a new PranaFragment with the given type_id, level, and adjacency_effects.
func _make_frag(type_id: int, level: int = 1, adj_effects: Array = []) -> PranaFragment:
	var frag := PranaFragment.new()
	frag.type_id = type_id
	frag.level = level
	frag.adjacency_effects = adj_effects
	return frag


## Returns a 9-element Array of nulls (empty Prana grid).
func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(9)
	return grid


## Returns a 9-null grid with slot 4 set to the given fragment.
func _grid_with_centre(frag: PranaFragment) -> Array:
	var grid := _make_grid()
	grid[4] = frag
	return grid


## Builds an AdjacencyEffect for ADJ_ECHO with no required conditions (vacuously satisfied).
func _make_echo_adj_effect() -> AdjacencyEffect:
	var ae := AdjacencyEffect.new()
	ae.effect_id = &"ADJ_ECHO"
	ae.required_neighbors = []
	return ae


# ── AC-CR-24: null centre → push_error + no-op SpellEffect emitted once ───────

## GIVEN committed_fragments with slot 4 = null (no test_fragments set → _make_empty_grid())
## WHEN _on_combat_started fires
## THEN combo_resolved emitted once; spell_effect.primary_type == -1
func test_null_centre_emits_combo_resolved_with_primary_type_minus_one() -> void:
	var cr := _make_cr()

	var spy_count: Array[int] = [0]
	var spy_type: Array[int] = [-99]
	cr.combo_resolved.connect(func(se: SpellEffect) -> void:
		spy_count[0] += 1
		spy_type[0] = se.primary_type
	)

	cr._on_combat_started(false)

	assert_int(spy_count[0]).is_equal(1)
	assert_int(spy_type[0]).is_equal(-1)
	_teardown_cr(cr)


# ── AC-CR-25: all-null grid → same as AC-CR-24 ────────────────────────────────

## GIVEN all 9 slots null (explicit inject via set_test_fragments)
## WHEN _on_combat_started fires
## THEN combo_resolved emitted once; primary_type == -1
func test_all_null_grid_emits_no_op_spell_effect() -> void:
	var cr := _make_cr()
	cr.set_test_fragments(_make_grid())

	var spy_count: Array[int] = [0]
	var spy_type: Array[int] = [-99]
	cr.combo_resolved.connect(func(se: SpellEffect) -> void:
		spy_count[0] += 1
		spy_type[0] = se.primary_type
	)

	cr._on_combat_started(false)

	assert_int(spy_count[0]).is_equal(1)
	assert_int(spy_type[0]).is_equal(-1)
	_teardown_cr(cr)


# ── AC-CR-26: valid arrangement → exactly-once emission; primary_type in [0,4] ─

## GIVEN slot 4 = Ashfire lv.1 (valid)
## WHEN _on_combat_started fires
## THEN combo_resolved emitted exactly once; primary_type in [0, 4]
func test_valid_arrangement_emits_combo_resolved_exactly_once() -> void:
	var cr := _make_cr()
	cr.set_test_fragments(_grid_with_centre(_make_frag(0)))

	var spy_count: Array[int] = [0]
	var spy_type: Array[int] = [-99]
	cr.combo_resolved.connect(func(se: SpellEffect) -> void:
		spy_count[0] += 1
		spy_type[0] = se.primary_type
	)

	cr._on_combat_started(false)

	assert_int(spy_count[0]).is_equal(1)
	assert_bool(spy_type[0] >= 0 and spy_type[0] <= 4).is_true()
	_teardown_cr(cr)


## GIVEN valid arrangement; _on_combat_started called twice before preparation_started
## THEN combo_resolved still emitted only once (_in_combat guard)
func test_duplicate_combat_started_emits_only_once() -> void:
	var cr := _make_cr()
	cr.set_test_fragments(_grid_with_centre(_make_frag(0)))

	var spy_count: Array[int] = [0]
	cr.combo_resolved.connect(func(_se: SpellEffect) -> void: spy_count[0] += 1)

	cr._on_combat_started(false)
	cr._on_combat_started(false)  # must be ignored by _in_combat guard

	assert_int(spy_count[0]).is_equal(1)
	_teardown_cr(cr)


# ── AC-CR-27: preparation_started clears state — second wave reflects new data ─

## GIVEN wave 1 resolves Ashfire (type 0); preparation_started; wave 2 = Stormgold (type 2)
## THEN second combo_resolved carries primary_type == 2, not 0
func test_second_wave_reflects_new_arrangement_after_preparation_started() -> void:
	var cr := _make_cr()

	var received: Array[int] = []
	cr.combo_resolved.connect(func(se: SpellEffect) -> void:
		received.append(se.primary_type)
	)

	# Wave 1 — Ashfire
	cr.set_test_fragments(_grid_with_centre(_make_frag(0)))
	cr._on_combat_started(false)

	# Phase reset
	cr._on_preparation_started(0, 1)

	# Wave 2 — Stormgold
	cr.set_test_fragments(_grid_with_centre(_make_frag(2)))
	cr._on_combat_started(false)

	assert_int(received.size()).is_equal(2)
	assert_int(received[0]).is_equal(0)  # Ashfire
	assert_int(received[1]).is_equal(2)  # Stormgold
	_teardown_cr(cr)


## GIVEN wave 1 completes; preparation_started fires
## THEN _in_combat is false; _cached_spell_effect is null; second combat emits again
func test_preparation_started_clears_in_combat_flag_and_cache() -> void:
	var cr := _make_cr()

	var spy_count: Array[int] = [0]
	cr.combo_resolved.connect(func(_se: SpellEffect) -> void: spy_count[0] += 1)

	cr.set_test_fragments(_grid_with_centre(_make_frag(1)))
	cr._on_combat_started(false)

	# Verify state was set
	assert_bool(cr._in_combat).is_true()
	assert_bool(cr._cached_spell_effect != null).is_true()

	cr._on_preparation_started(0, 1)

	# Verify state cleared
	assert_bool(cr._in_combat).is_false()
	assert_bool(cr._cached_spell_effect == null).is_true()

	# Second combat must emit again (flag was cleared)
	cr.set_test_fragments(_grid_with_centre(_make_frag(1)))
	cr._on_combat_started(false)
	assert_int(spy_count[0]).is_equal(2)

	_teardown_cr(cr)


# ── AC-CR-28: ADJ_ECHO timer cancelled by preparation_started ─────────────────

## GIVEN slot 4 has ADJ_ECHO (vacuously satisfied); _on_combat_started fires → timer starts
## WHEN _on_preparation_started fires before ADJ_ECHO_DELAY elapses
## THEN echo_strike_fired is NOT emitted even after the full delay window passes
func test_echo_timer_cancelled_by_preparation_started_no_echo_fires() -> void:
	var cr := _make_cr()

	var frag := _make_frag(0, 1, [_make_echo_adj_effect()])
	cr.set_test_fragments(_grid_with_centre(frag))

	var echo_count: Array[int] = [0]
	cr.echo_strike_fired.connect(func(_se: SpellEffect) -> void: echo_count[0] += 1)

	# Start the echo timer
	cr._on_combat_started(false)
	assert_bool(cr._echo_elapsed >= 0.0).is_true()

	# Cancel via preparation_started before the delay elapses
	cr._on_preparation_started(0, 1)
	assert_bool(cr._echo_elapsed < 0.0).is_true()

	# Wait past the full delay window — echo must not fire
	await get_tree().create_timer(ADJ_ECHO_DELAY + 0.1).timeout

	assert_int(echo_count[0]).is_equal(0)
	_teardown_cr(cr)


## GIVEN slot 4 has ADJ_ECHO; _on_combat_started fires; preparation_started does NOT fire
## WHEN ADJ_ECHO_DELAY elapses
## THEN echo_strike_fired is emitted exactly once with the resolved SpellEffect
func test_echo_fires_when_not_cancelled() -> void:
	var cr := _make_cr()

	var frag := _make_frag(0, 1, [_make_echo_adj_effect()])
	cr.set_test_fragments(_grid_with_centre(frag))

	var echo_count: Array[int] = [0]
	var echo_type: Array[int] = [-99]
	cr.echo_strike_fired.connect(func(se: SpellEffect) -> void:
		echo_count[0] += 1
		echo_type[0] = se.primary_type
	)

	cr._on_combat_started(false)

	# Wait for the full delay to elapse
	await get_tree().create_timer(ADJ_ECHO_DELAY + 0.1).timeout

	assert_int(echo_count[0]).is_equal(1)
	assert_int(echo_type[0]).is_equal(0)  # Ashfire primary

	# Reset state before teardown
	cr._on_preparation_started(0, 0)
	_teardown_cr(cr)
