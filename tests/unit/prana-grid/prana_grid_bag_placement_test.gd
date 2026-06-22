## prana_grid_bag_placement_test.gd — Unit tests for bag-sourced placement (Stage 2,
## grid-as-build). Exercises PranaGrid placement logic headlessly: the grid is created
## via .new() and NOT added to the tree, so _ready()/UI creation is skipped and
## _get_bag() resolves to null (placement is allowed so slot logic is testable in
## isolation; bag consumption + confirm-clears-bag are covered by the integration test).
##
## Coverage:
##   AC-BP-01: _place_from_bag fills an empty slot and returns true
##   AC-BP-02: _place_from_bag on a filled slot is rejected (returns false, no change)
##   AC-BP-03: _place_from_bag outside ARRANGEMENT is rejected
##   AC-BP-04: _select_bag_type sets the selection; re-selecting toggles it off
##   AC-BP-05: _place_selected_bag_into places the selected type; no-op when unselected
##   AC-BP-06: _is_grid_full reflects whether every slot is occupied (Stage 4)
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PranaGridScript = preload("res://src/ui/prana_grid.gd")


func _make_grid() -> PranaGrid:
	var pg: PranaGrid = PranaGridScript.new()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	pg._state = PranaGrid.State.ARRANGEMENT
	return pg


# ── AC-BP-01: place into empty slot ──────────────────────────────────────────

func test_place_from_bag_fills_empty_slot_returns_true() -> void:
	var pg: PranaGrid = _make_grid()

	var ok: bool = pg._place_from_bag(0, 2)

	assert_bool(ok).is_true()
	assert_int(pg._slots[0]).is_equal(2)

	pg.free()


# ── AC-BP-02: reject filled slot ─────────────────────────────────────────────

func test_place_from_bag_rejects_filled_slot() -> void:
	var pg: PranaGrid = _make_grid()
	pg._slots[4] = 1  # already occupied (e.g. the core)

	var ok: bool = pg._place_from_bag(4, 3)

	assert_bool(ok).is_false()
	assert_int(pg._slots[4]).is_equal(1)  # unchanged

	pg.free()


# ── AC-BP-03: reject outside ARRANGEMENT ─────────────────────────────────────

func test_place_from_bag_rejected_outside_arrangement() -> void:
	var pg: PranaGrid = _make_grid()
	pg._state = PranaGrid.State.LOCKED

	var ok: bool = pg._place_from_bag(0, 2)

	assert_bool(ok).is_false()
	assert_object(pg._slots[0]).is_null()

	pg.free()


# ── AC-BP-04: select toggles ─────────────────────────────────────────────────

func test_select_bag_type_sets_and_toggles_selection() -> void:
	var pg: PranaGrid = _make_grid()

	pg._select_bag_type(3)
	assert_int(pg._selected_bag_type).is_equal(3)

	pg._select_bag_type(3)  # re-select same type clears it
	assert_int(pg._selected_bag_type).is_equal(-1)

	pg.free()


# ── AC-BP-05: click-to-place uses the selection ──────────────────────────────

func test_place_selected_bag_into_places_when_selected() -> void:
	var pg: PranaGrid = _make_grid()

	# No selection → no-op.
	pg._place_selected_bag_into(1)
	assert_object(pg._slots[1]).is_null()

	# With a selection → places that type.
	pg._select_bag_type(0)
	pg._place_selected_bag_into(1)
	assert_int(pg._slots[1]).is_equal(0)

	pg.free()


# ── AC-BP-06: _is_grid_full ──────────────────────────────────────────────────

func test_is_grid_full_true_only_when_all_slots_filled() -> void:
	var pg: PranaGrid = _make_grid()

	assert_bool(pg._is_grid_full()).is_false()  # all empty

	for i in PranaGrid.GRID_SIZE:
		pg._slots[i] = 0
	assert_bool(pg._is_grid_full()).is_true()  # all filled

	pg._slots[5] = null  # free one
	assert_bool(pg._is_grid_full()).is_false()

	pg.free()
