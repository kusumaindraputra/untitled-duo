## prana_loadout_test.gd — Unit tests for PranaLoadout (persistent build holder).
##
## Coverage:
##   AC-PL-01: seed_core clears the build and places the core in the centre slot
##   AC-PL-02: set_slots / get_slots round-trip with copy semantics
##   AC-PL-03: filled_count counts non-null slots
##   AC-PL-04: is_full true only when all 9 slots filled
##   AC-PL-05: first_empty_slot returns the first null index, -1 when full
##   AC-PL-06: clear empties the build
##   AC-PL-07: seed_core / set_slots / clear emit loadout_changed
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PranaLoadoutScript = preload("res://src/systems/prana_loadout.gd")


func _make_loadout() -> PranaLoadout:
	var pl: PranaLoadout = PranaLoadoutScript.new()
	add_child(pl)  # _ready() initialises the empty slot array
	return pl


func _teardown(pl: PranaLoadout) -> void:
	remove_child(pl)
	pl.free()


# ── AC-PL-01: seed_core ──────────────────────────────────────────────────────

func test_prana_loadout_seed_core_places_core_in_centre() -> void:
	var pl: PranaLoadout = _make_loadout()

	pl.seed_core(3)

	var slots: Array = pl.get_slots()
	assert_int(slots.size()).is_equal(9)
	assert_int(slots[4]).is_equal(3)
	assert_int(pl.filled_count()).is_equal(1)

	_teardown(pl)


# ── AC-PL-02: set_slots / get_slots copy semantics ───────────────────────────

func test_prana_loadout_set_get_slots_round_trip_is_a_copy() -> void:
	var pl: PranaLoadout = _make_loadout()

	pl.set_slots([0, null, 2, null, 4, null, null, null, null])
	var got: Array = pl.get_slots()
	got[0] = 99  # mutate the returned copy

	assert_int(pl.get_slots()[0]).is_equal(0)  # internal state unchanged
	assert_int(pl.get_slots()[2]).is_equal(2)

	_teardown(pl)


# ── AC-PL-03: filled_count ───────────────────────────────────────────────────

func test_prana_loadout_filled_count_counts_non_null() -> void:
	var pl: PranaLoadout = _make_loadout()

	pl.set_slots([0, 1, null, null, 4, null, null, null, null])

	assert_int(pl.filled_count()).is_equal(3)

	_teardown(pl)


# ── AC-PL-04: is_full ────────────────────────────────────────────────────────

func test_prana_loadout_is_full_only_when_all_filled() -> void:
	var pl: PranaLoadout = _make_loadout()

	pl.set_slots([0, 1, null, 3, 4, 0, 1, 2, 3])
	assert_bool(pl.is_full()).is_false()

	pl.set_slots([0, 1, 2, 3, 4, 0, 1, 2, 3])
	assert_bool(pl.is_full()).is_true()

	_teardown(pl)


# ── AC-PL-05: first_empty_slot ───────────────────────────────────────────────

func test_prana_loadout_first_empty_slot() -> void:
	var pl: PranaLoadout = _make_loadout()

	pl.set_slots([0, 1, null, 3, 4, null, null, null, null])
	assert_int(pl.first_empty_slot()).is_equal(2)

	pl.set_slots([0, 1, 2, 3, 4, 0, 1, 2, 3])
	assert_int(pl.first_empty_slot()).is_equal(-1)

	_teardown(pl)


# ── AC-PL-06: clear ──────────────────────────────────────────────────────────

func test_prana_loadout_clear_empties_build() -> void:
	var pl: PranaLoadout = _make_loadout()
	pl.seed_core(2)

	pl.clear()

	assert_int(pl.filled_count()).is_equal(0)

	_teardown(pl)


# ── AC-PL-07: loadout_changed emits ──────────────────────────────────────────

func test_prana_loadout_mutators_emit_loadout_changed() -> void:
	var pl: PranaLoadout = _make_loadout()
	var emits: Array = []  # reference type — lambda mutations persist (ints don't)
	pl.loadout_changed.connect(func(_slots: Array) -> void: emits.append(1))

	pl.seed_core(1)
	pl.set_slots([0, 1, 2, 3, 4, 0, 1, 2, 3])
	pl.clear()

	assert_int(emits.size()).is_equal(3)

	_teardown(pl)
