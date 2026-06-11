## prana_grid_confirm_logic_test.gd — Unit tests for PranaGrid confirm logic (Story 002, S4-04).
##
## Coverage:
##   AC-PG-03:  arrangement_confirmed emitted exactly once; committed_fragments[4] correct
##   AC-PG-04:  slot 4 empty → Confirm does NOT emit arrangement_confirmed; ARRANGEMENT unchanged
##   AC-PG-05:  slot 4 empty → error flash timer set; no signal
##   AC-PG-06:  slot replace — _place_token overwrites existing token
##   AC-PG-07:  slot clear — _clear_slot sets _slots[N] to null
##   AC-PG-08:  _clear_all sets all 9 slots to null; is_loadout_valid false
##   AC-PG-10:  committed_fragments does not mutate during LOCKED state
##   length invariant: committed_fragments.size() == 9 after confirm; null for empty slots
##   minimum valid: centre-only arrangement confirms correctly
##   First Playable defaults: level==1, stat_property=={}, adjacency_effects==[]
##   is_loadout_valid: returns false/true based on slot 4
##
## Isolation strategy: PranaGrid._ready() connects to GameStateManager (Autoload unavailable
## headless). All tests instantiate via .new() — _ready() is NOT called. Slots are
## initialised by _init_slots(); handlers and methods called directly.
## Teardown: node.free() — nodes never added to SceneTree (test-standards.md rule).
##
## Note: _committed_fragments, _slots, _state are accessed directly as they are non-
## private by GDScript convention (underscore = internal, but accessible for unit testing).
##
## Framework: GdUnit4 v6
extends GdUnitTestSuite

const PranaGridScript := preload("res://src/ui/prana_grid.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a PranaGrid via .new() — _ready() is NOT called (no Autoload in headless).
func _make_grid() -> PranaGrid:
	return PranaGridScript.new()


## Simulates the slot-init half of _ready(): resize + fill to null.
func _init_slots(pg: PranaGrid) -> void:
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)


## Places [param type_id] into every slot index listed in [param indices].
func _fill_slots_at(pg: PranaGrid, indices: Array, type_id: int) -> void:
	for i in indices:
		pg._slots[i] = type_id


# ── AC-PG-03: arrangement_confirmed emitted exactly once on valid confirm ──────

func test_confirm_with_centre_filled_emits_arrangement_confirmed_once() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 0  # Ashfire in centre

	var emit_count := [0]
	pg.arrangement_confirmed.connect(func() -> void: emit_count[0] += 1)
	pg._on_confirm_pressed()

	assert_int(emit_count[0]).is_equal(1)
	pg.free()


## AC-PG-03 detail: committed_fragments[4].type_id matches what was placed.
func test_confirm_committed_fragments_centre_type_id_matches_slot() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 0  # Ashfire

	pg._on_confirm_pressed()

	var cf := pg.get_committed_fragments()
	assert_object(cf[4]).is_not_null()
	assert_int((cf[4] as PranaFragment).type_id).is_equal(0)
	pg.free()


## AC-PG-03 detail: committed_fragments[4].level == 1 (First Playable scope).
func test_confirm_committed_fragments_centre_level_is_one() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 2  # Stormgold

	pg._on_confirm_pressed()

	var cf := pg.get_committed_fragments()
	assert_int((cf[4] as PranaFragment).level).is_equal(1)
	pg.free()


# ── committed_fragments length invariant ──────────────────────────────────────

func test_confirm_committed_fragments_length_is_always_nine() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	# Fill only a few slots — length must still be 9
	pg._slots[4] = 1
	pg._slots[0] = 3

	pg._on_confirm_pressed()

	assert_int(pg.get_committed_fragments().size()).is_equal(9)
	pg.free()


func test_confirm_empty_slots_are_null_not_sentinel() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 1  # only centre filled

	pg._on_confirm_pressed()

	var cf := pg.get_committed_fragments()
	# Slots 0–3 and 5–8 must be null, not 0 or -1
	for i in [0, 1, 2, 3, 5, 6, 7, 8]:
		assert_object(cf[i]).is_null()
	pg.free()


# ── AC-PG-04/05: centre-slot guard — no emission when slot 4 empty ─────────────

func test_confirm_with_centre_empty_does_not_emit_signal() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	# All slots null (including slot 4)

	var emit_count := [0]
	pg.arrangement_confirmed.connect(func() -> void: emit_count[0] += 1)
	pg._on_confirm_pressed()

	assert_int(emit_count[0]).is_equal(0)
	pg.free()


func test_confirm_with_centre_empty_leaves_state_unchanged() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_confirm_pressed()

	assert_int(pg._state).is_equal(PranaGrid.State.ARRANGEMENT)
	pg.free()


## Edge case: all 8 non-centre slots filled, slot 4 still null — must be rejected.
func test_confirm_with_ring_filled_but_centre_empty_does_not_emit() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	_fill_slots_at(pg, [0, 1, 2, 3, 5, 6, 7, 8], 0)
	# slot 4 remains null

	var emit_count := [0]
	pg.arrangement_confirmed.connect(func() -> void: emit_count[0] += 1)
	pg._on_confirm_pressed()

	assert_int(emit_count[0]).is_equal(0)
	pg.free()


## AC-PG-05: error flash timer is set to ERROR_FLASH_DURATION on failed confirm.
func test_confirm_with_centre_empty_sets_error_flash_timer() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT

	pg._on_confirm_pressed()

	assert_float(pg._error_flash_timer).is_greater(0.0)
	pg.free()


# ── AC-PG-06: slot replace ────────────────────────────────────────────────────

func test_place_token_overwrites_existing_token_in_slot() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[3] = 0  # Ashfire already in slot 3

	pg._place_token(3, 1)  # Replace with Voidblue

	assert_int(pg._slots[3]).is_equal(1)
	pg.free()


func test_confirm_after_replace_uses_new_type_id() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 0  # Ashfire in centre
	pg._place_token(4, 1)  # Replace centre with Voidblue

	pg._on_confirm_pressed()

	assert_int((pg.get_committed_fragments()[4] as PranaFragment).type_id).is_equal(1)
	pg.free()


# ── AC-PG-07: slot clear ──────────────────────────────────────────────────────

func test_clear_slot_sets_slot_to_null() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[2] = 3  # Deepfrost in slot 2

	pg._clear_slot(2)

	assert_object(pg._slots[2]).is_null()
	pg.free()


func test_clear_slot_then_confirm_slot_is_null_in_committed() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 0  # Centre filled
	pg._slots[2] = 3  # Deepfrost in slot 2
	pg._clear_slot(2)

	pg._on_confirm_pressed()

	assert_object(pg.get_committed_fragments()[2]).is_null()
	pg.free()


# ── AC-PG-08: Clear All ───────────────────────────────────────────────────────

func test_clear_all_sets_all_slots_to_null() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	_fill_slots_at(pg, [0, 1, 2, 3, 4, 5, 6, 7, 8], 0)

	pg._clear_all()

	for i in pg._slots.size():
		assert_object(pg._slots[i]).is_null()
	pg.free()


func test_clear_all_makes_loadout_invalid() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 2

	pg._clear_all()

	assert_bool(pg.is_loadout_valid()).is_false()
	pg.free()


# ── AC-PG-10: committed_fragments immutability during LOCKED ──────────────────

func test_committed_fragments_unchanged_after_grid_locked() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 0  # Ashfire centre
	pg._slots[0] = 2  # Stormgold slot 0
	pg._on_confirm_pressed()
	# Transition to LOCKED
	pg._on_grid_locked()

	var cf_first := pg.get_committed_fragments()
	var centre_type := (cf_first[4] as PranaFragment).type_id
	var slot0_type := (cf_first[0] as PranaFragment).type_id

	# Read again — values must be identical
	var cf_second := pg.get_committed_fragments()
	assert_int((cf_second[4] as PranaFragment).type_id).is_equal(centre_type)
	assert_int((cf_second[0] as PranaFragment).type_id).is_equal(slot0_type)
	assert_int(cf_second.size()).is_equal(9)
	pg.free()


# ── minimum valid arrangement: centre-only ────────────────────────────────────

func test_confirm_centre_only_arrangement_emits_and_has_correct_centre() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 2  # Stormgold — only slot filled

	var emit_count := [0]
	pg.arrangement_confirmed.connect(func() -> void: emit_count[0] += 1)
	pg._on_confirm_pressed()

	assert_int(emit_count[0]).is_equal(1)
	var cf := pg.get_committed_fragments()
	assert_int((cf[4] as PranaFragment).type_id).is_equal(2)
	# All non-centre slots must be null
	for i in [0, 1, 2, 3, 5, 6, 7, 8]:
		assert_object(cf[i]).is_null()
	pg.free()


# ── First Playable fragment defaults ──────────────────────────────────────────

func test_committed_fragments_non_null_entries_have_level_one() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 1
	pg._slots[0] = 4
	pg._slots[8] = 2

	pg._on_confirm_pressed()

	for i in [0, 4, 8]:
		var f := pg.get_committed_fragments()[i] as PranaFragment
		assert_int(f.level).is_equal(1)
	pg.free()


## stat_property must be {} (empty Dictionary), not null — PranaFragment.stat_property
## is typed Dictionary; assigning null crashes at runtime (specialist fix applied).
func test_committed_fragments_non_null_entries_have_empty_stat_property() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 0

	pg._on_confirm_pressed()

	var f := pg.get_committed_fragments()[4] as PranaFragment
	assert_bool(f.stat_property == {}).is_true()
	pg.free()


func test_committed_fragments_non_null_entries_have_empty_adjacency_effects() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 3

	pg._on_confirm_pressed()

	var f := pg.get_committed_fragments()[4] as PranaFragment
	assert_int(f.adjacency_effects.size()).is_equal(0)
	pg.free()


# ── is_loadout_valid ──────────────────────────────────────────────────────────

func test_is_loadout_valid_returns_false_when_centre_null() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	# slot 4 is null

	assert_bool(pg.is_loadout_valid()).is_false()
	pg.free()


func test_is_loadout_valid_returns_true_when_centre_filled() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	pg._slots[4] = 3  # Deepfrost

	assert_bool(pg.is_loadout_valid()).is_true()
	pg.free()


## is_loadout_valid uses slot 4 contents only — other slots have no bearing.
func test_is_loadout_valid_false_when_all_non_centre_filled_but_centre_null() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.ARRANGEMENT
	_fill_slots_at(pg, [0, 1, 2, 3, 5, 6, 7, 8], 0)
	# slot 4 remains null

	assert_bool(pg.is_loadout_valid()).is_false()
	pg.free()


# ── _place_token / _clear_slot no-ops outside ARRANGEMENT ─────────────────────

func test_place_token_is_noop_in_locked_state() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._state = PranaGrid.State.LOCKED

	pg._place_token(0, 2)

	assert_object(pg._slots[0]).is_null()
	pg.free()


func test_clear_slot_is_noop_in_locked_state() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._slots[0] = 1
	pg._state = PranaGrid.State.LOCKED

	pg._clear_slot(0)

	assert_int(pg._slots[0]).is_equal(1)
	pg.free()


func test_clear_all_is_noop_in_locked_state() -> void:
	var pg := _make_grid()
	_init_slots(pg)
	pg._slots[4] = 0
	pg._slots[0] = 1
	pg._state = PranaGrid.State.LOCKED

	pg._clear_all()

	assert_int(pg._slots[4]).is_equal(0)
	assert_int(pg._slots[0]).is_equal(1)
	pg.free()
