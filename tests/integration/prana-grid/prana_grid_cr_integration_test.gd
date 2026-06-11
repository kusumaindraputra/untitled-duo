## prana_grid_cr_integration_test.gd — Integration: PranaGrid → CR + SCE (Story 003, S4-05).
##
## Coverage (see story QA Test Cases section):
##   getter-length: get_committed_fragments() always returns 9 elements after confirm
##   getter-centre-invariant: slot 4 non-null after confirm; CR reads correct type_id via group
##   full-loop: fresh CR + SCE wired; combo_resolved fires; SCE enters READY state
##   AC-CR-26: combo_resolved emitted exactly once per combat_started (test seam path)
##   AC-CR-27: second wave uses new arrangement — preparation_started clears stale data
##   null-slots safety: only slot 4 filled; CR resolves cleanly; no null-pointer errors
##
## Setup pattern:
##   - PranaGrid added to tree when group-based CR lookup is under test.
##     arrangement_confirmed is immediately disconnected from GSM to prevent cascading
##     real combat transitions (avoids triggering AudioSystem, WaveManager, etc.).
##     _on_preparation_started() called directly to enter ARRANGEMENT state.
##   - CR and SCE use fresh script instances (not the Autoload singletons) for isolation.
##   - CR handlers called directly (_on_combat_started, _on_preparation_started) — avoids
##     emitting real GameStateManager signals.
##   - CR test seam (set_test_fragments) used in tests that do not exercise the group path.
##   - Fresh SCE requires manual _in_combat = true to pass its guard (normally set by
##     its own _on_combat_started handler).
##   - Teardown: remove_child + .free() in every test (not queue_free — no SceneTree
##     deletion queue in headless GdUnit4; orphans cause exit 101).
##
## Framework: GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates PranaGrid, adds it to the tree, disconnects arrangement_confirmed → GSM
## to prevent combat cascade, then transitions to ARRANGEMENT state.
## Pair with _teardown_pg().
func _make_pg() -> PranaGrid:
	var pg := PranaGrid.new()
	add_child(pg)
	# Disconnect arrangement_confirmed → GSM so _on_confirm_pressed() does not cascade
	# real combat transitions (grid_locked, combat_started, etc.) during tests.
	if pg.arrangement_confirmed.is_connected(GameStateManager._on_arrangement_confirmed):
		pg.arrangement_confirmed.disconnect(GameStateManager._on_arrangement_confirmed)
	# Transition to ARRANGEMENT state directly (bypasses GSM.preparation_started signal).
	pg._on_preparation_started()
	return pg


func _teardown_pg(pg: PranaGrid) -> void:
	remove_child(pg)
	pg.free()


## Creates a fresh CR node (not the Autoload singleton) and adds it to the tree.
## Pair with _teardown_cr().
func _make_cr() -> Node:
	var script := load("res://src/systems/combination_resolution.gd")
	var cr: Node = script.new()
	add_child(cr)
	return cr


func _teardown_cr(cr: Node) -> void:
	remove_child(cr)
	cr.free()


## Creates a fresh SCE node (not the Autoload singleton) and adds it to the tree.
## Caller must set sce._in_combat = true before triggering combo_resolved to bypass
## the READY-state guard (guard normally set by SCE's own _on_combat_started handler).
## Pair with _teardown_sce().
func _make_sce() -> Node:
	var script := load("res://src/systems/spell_casting_effects.gd")
	var sce: Node = script.new()
	add_child(sce)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


## Returns a new PranaFragment with the given type_id and First Playable defaults.
func _make_frag(type_id: int) -> PranaFragment:
	var frag := PranaFragment.new()
	frag.type_id = type_id
	frag.level = 1
	frag.stat_property = {}
	frag.adjacency_effects = []
	return frag


## Returns a 9-element Array of nulls (empty grid).
## Untyped Array (not Array[PranaFragment]) — slots hold mixed null/PranaFragment;
## GDScript 4.6 typed arrays cannot hold null for reference types.
func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(9)
	return grid


## Returns a grid with only slot 4 set to the given fragment.
## Untyped Array for the same reason as _make_grid().
func _grid_with_centre(frag: PranaFragment) -> Array:
	var grid := _make_grid()
	grid[4] = frag
	return grid


# ── getter-length: committed_fragments always length 9 ────────────────────────

## GIVEN slot 4 = Ashfire (type_id 0), all others empty
## WHEN arrangement confirmed
## THEN get_committed_fragments().size() == 9; slot 4 non-null; other slots null
func test_prana_grid_getter_returns_length_9_with_only_centre_filled() -> void:
	var pg := _make_pg()
	pg._place_token(4, 0)
	pg._on_confirm_pressed()

	var result := pg.get_committed_fragments()
	assert_int(result.size()).is_equal(9)
	assert_bool(result[4] != null).is_true()
	assert_int(result[4].type_id).is_equal(0)
	for i in 9:
		if i != 4:
			assert_bool(result[i] == null).is_true()

	_teardown_pg(pg)


## GIVEN all 9 slots filled with distinct types
## WHEN arrangement confirmed
## THEN get_committed_fragments().size() == 9; all non-null
func test_prana_grid_getter_returns_length_9_all_slots_filled() -> void:
	var pg := _make_pg()
	for i in 9:
		pg._place_token(i, i % 5)
	pg._on_confirm_pressed()

	var result := pg.get_committed_fragments()
	assert_int(result.size()).is_equal(9)
	for i in 9:
		assert_bool(result[i] != null).is_true()
		assert_int(result[i].type_id).is_equal(i % 5)

	_teardown_pg(pg)


# ── getter-centre-invariant: CR discovers PranaGrid via prana_grid group ──────

## GIVEN slot 4 = Stormgold (type_id 2) confirmed; PranaGrid registered in scene tree
## WHEN CR._on_combat_started() resolves via get_tree().get_first_node_in_group(&"prana_grid")
## THEN combo_resolved.primary_type == 2 (CR read committed_fragments[4].type_id correctly)
func test_cr_reads_primary_type_from_prana_grid_via_group_lookup() -> void:
	var pg := _make_pg()
	pg._place_token(4, 2)  # Stormgold
	pg._on_confirm_pressed()

	var cr := _make_cr()

	var spy_type: Array[int] = [-99]
	cr.combo_resolved.connect(func(se: SpellEffect) -> void: spy_type[0] = se.primary_type)

	cr._on_combat_started(false)

	assert_int(spy_type[0]).is_equal(2)

	_teardown_cr(cr)
	_teardown_pg(pg)


## GIVEN slot 4 = Deepfrost (type_id 3) centre + slot 0 = Ashfire (type_id 0) ring
## WHEN CR reads via group lookup after confirmation
## THEN primary_type == 3; slot 0 non-null in committed_fragments
func test_cr_reads_multi_slot_arrangement_via_group_lookup() -> void:
	var pg := _make_pg()
	pg._place_token(4, 3)  # Deepfrost centre
	pg._place_token(0, 0)  # Ashfire ring
	pg._on_confirm_pressed()

	var cr := _make_cr()

	var spy_type: Array[int] = [-99]
	cr.combo_resolved.connect(func(se: SpellEffect) -> void: spy_type[0] = se.primary_type)

	cr._on_combat_started(false)

	assert_int(spy_type[0]).is_equal(3)

	# Verify committed_fragments[0] was accessible (non-null, type 0)
	var frags := pg.get_committed_fragments()
	assert_bool(frags[0] != null).is_true()
	assert_int(frags[0].type_id).is_equal(0)

	_teardown_cr(cr)
	_teardown_pg(pg)


# ── AC-CR-26: combo_resolved emitted exactly once per combat_started ──────────

## GIVEN valid arrangement (slot 4 = Ashfire type_id 0) via test seam
## WHEN _on_combat_started fires
## THEN combo_resolved emitted exactly once; primary_type == 0
func test_cr_combo_resolved_emitted_exactly_once() -> void:
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
	assert_int(spy_type[0]).is_equal(0)

	_teardown_cr(cr)


## GIVEN _on_combat_started called twice before preparation_started
## THEN combo_resolved still emitted only once (_in_combat guard)
func test_cr_duplicate_combat_started_emits_only_once() -> void:
	var cr := _make_cr()
	cr.set_test_fragments(_grid_with_centre(_make_frag(1)))

	var spy_count: Array[int] = [0]
	cr.combo_resolved.connect(func(_se: SpellEffect) -> void: spy_count[0] += 1)

	cr._on_combat_started(false)
	cr._on_combat_started(false)  # guard must prevent second emission

	assert_int(spy_count[0]).is_equal(1)

	_teardown_cr(cr)


# ── full-loop: fresh CR + SCE wired together ──────────────────────────────────

## GIVEN fresh CR + SCE instances wired; slot 4 = Ashfire (type_id 0)
## WHEN CR._on_combat_started fires
## THEN combo_resolved emitted once; SCE._state transitions to READY (== 1)
func test_full_loop_cr_resolves_and_sce_enters_ready() -> void:
	var cr := _make_cr()
	var sce := _make_sce()

	# Wire fresh CR → fresh SCE manually (mirroring Autoload order CR=#8, SCE=#9).
	# Fresh SCE's _ready() connected to Autoload CR only — fresh CR needs explicit wiring.
	cr.combo_resolved.connect(sce._on_combo_resolved)
	# Bypass SCE's READY-state guard: set _in_combat = true (normally done by _on_combat_started).
	sce._in_combat = true

	cr.set_test_fragments(_grid_with_centre(_make_frag(0)))

	var spy_count: Array[int] = [0]
	cr.combo_resolved.connect(func(_se: SpellEffect) -> void: spy_count[0] += 1)

	cr._on_combat_started(false)

	assert_int(spy_count[0]).is_equal(1)
	# SCEState.READY == 1
	assert_int(sce._state).is_equal(1)
	assert_bool(sce._current_spell_effect != null).is_true()
	assert_int(sce._current_spell_effect.primary_type).is_equal(0)

	_teardown_sce(sce)
	_teardown_cr(cr)


# ── AC-CR-27: wave cycle — second wave uses new arrangement ───────────────────

## GIVEN wave 1 = Ashfire (0); preparation_started resets; wave 2 = Deepfrost (3)
## WHEN second combat_started fires
## THEN second combo_resolved.primary_type == 3, not 0 (no stale data)
func test_cr_second_wave_reflects_new_arrangement() -> void:
	var cr := _make_cr()

	var received: Array[int] = []
	cr.combo_resolved.connect(func(se: SpellEffect) -> void:
		received.append(se.primary_type)
	)

	# Wave 1 — Ashfire
	cr.set_test_fragments(_grid_with_centre(_make_frag(0)))
	cr._on_combat_started(false)

	# Phase reset — clears _in_combat + _cached_spell_effect
	cr._on_preparation_started(0, 1)

	# Wave 2 — Deepfrost
	cr.set_test_fragments(_grid_with_centre(_make_frag(3)))
	cr._on_combat_started(false)

	assert_int(received.size()).is_equal(2)
	assert_int(received[0]).is_equal(0)  # Ashfire wave 1
	assert_int(received[1]).is_equal(3)  # Deepfrost wave 2

	_teardown_cr(cr)


# ── null-slots safety: only slot 4 filled ────────────────────────────────────

## GIVEN PranaGrid confirmed with only slot 4 = Voidblue (type_id 1); 8 null slots
## WHEN CR resolves via committed_fragments
## THEN no crash; primary_type == 1; null slots are skipped cleanly
func test_null_slots_do_not_crash_cr_resolution() -> void:
	var pg := _make_pg()
	pg._place_token(4, 1)  # Voidblue centre only
	pg._on_confirm_pressed()

	var frags := pg.get_committed_fragments()
	assert_int(frags.size()).is_equal(9)
	assert_bool(frags[4] != null).is_true()
	for i in 9:
		if i != 4:
			assert_bool(frags[i] == null).is_true()

	# CR resolves with only-centre arrangement — no error for null adjacency_effects etc.
	var cr := _make_cr()
	cr.set_test_fragments(frags)

	var spy_type: Array[int] = [-99]
	cr.combo_resolved.connect(func(se: SpellEffect) -> void: spy_type[0] = se.primary_type)

	cr._on_combat_started(false)

	assert_int(spy_type[0]).is_equal(1)

	_teardown_cr(cr)
	_teardown_pg(pg)


## GIVEN preparation_started fires after a wave
## THEN PranaGrid _slots + _committed_fragments both reset to null
## (guards against stale data being served to CR on wave 2)
func test_prana_grid_preparation_started_resets_fragments() -> void:
	var pg := _make_pg()
	pg._place_token(4, 2)
	pg._place_token(0, 1)
	pg._on_confirm_pressed()

	# Verify data is populated
	var before := pg.get_committed_fragments()
	assert_bool(before[4] != null).is_true()
	assert_bool(before[0] != null).is_true()

	# Reset
	pg._on_preparation_started()

	var after := pg.get_committed_fragments()
	assert_int(after.size()).is_equal(9)
	for i in 9:
		assert_bool(after[i] == null).is_true()

	_teardown_pg(pg)
