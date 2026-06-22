## prana_grid_bag_flow_test.gd — Integration: PranaGrid ↔ PranaBag (Stage 2, grid-as-build).
##
## Exercises the real bag-consumption path with both nodes in the SceneTree so
## PranaGrid._get_bag() resolves the PranaBag via group (the headless unit test runs
## without a bag and so cannot cover consumption or the confirm-clear).
##
## Coverage:
##   bag-consume:   _place_from_bag removes exactly one matching fragment from the bag
##   bag-reject:    _place_from_bag is rejected when the bag holds no such fragment
##   confirm-clear: _on_confirm_pressed discards all un-placed bag fragments
##
## Setup pattern mirrors prana_grid_cr_integration_test: PranaGrid added to tree,
## arrangement_confirmed disconnected from GSM to prevent a combat cascade, and
## _on_preparation_started() called directly to enter ARRANGEMENT. Teardown uses
## remove_child + free() (no SceneTree deletion queue in headless GdUnit4).
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PranaBagScript = preload("res://src/systems/prana_bag.gd")


func _make_bag() -> Node:
	var bag: Node = PranaBagScript.new()
	add_child(bag)  # _ready() registers it in the "prana_bag" group
	return bag


func _make_pg() -> PranaGrid:
	var pg := PranaGrid.new()
	add_child(pg)
	if pg.arrangement_confirmed.is_connected(GameStateManager.receive_arrangement_confirmed):
		pg.arrangement_confirmed.disconnect(GameStateManager.receive_arrangement_confirmed)
	pg._on_preparation_started()
	return pg


func _teardown(pg: PranaGrid, bag: Node) -> void:
	remove_child(pg)
	pg.free()
	remove_child(bag)
	bag.free()


# ── bag-consume: placement removes one fragment ──────────────────────────────

func test_place_from_bag_consumes_one_matching_fragment() -> void:
	var bag: Node = _make_bag()
	var pg: PranaGrid = _make_pg()
	bag.add(2)
	bag.add(2)  # two of the same type

	var ok: bool = pg._place_from_bag(0, 2)

	assert_bool(ok).is_true()
	assert_int(pg._slots[0]).is_equal(2)
	assert_int(bag.size()).is_equal(1)  # only one consumed

	_teardown(pg, bag)


# ── bag-reject: placement fails when the bag lacks the type ───────────────────

func test_place_from_bag_rejected_when_bag_lacks_type() -> void:
	var bag: Node = _make_bag()
	var pg: PranaGrid = _make_pg()
	bag.add(0)  # bag has Ashfire only

	var ok: bool = pg._place_from_bag(1, 4)  # try to place Verdant

	assert_bool(ok).is_false()
	assert_object(pg._slots[1]).is_null()
	assert_int(bag.size()).is_equal(1)  # nothing consumed

	_teardown(pg, bag)


# ── confirm-clear: un-placed fragments are discarded on confirm ───────────────

func test_confirm_clears_unplaced_bag_fragments() -> void:
	var bag: Node = _make_bag()
	var pg: PranaGrid = _make_pg()
	pg._slots[4] = 1  # core in centre so confirm is valid
	bag.add(3)
	bag.add(3)  # left un-placed

	pg._on_confirm_pressed()

	assert_bool(bag.is_empty()).is_true()

	_teardown(pg, bag)
