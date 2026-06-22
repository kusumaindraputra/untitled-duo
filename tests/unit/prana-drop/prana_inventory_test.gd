## prana_inventory_test.gd — Unit tests for PranaInventory (Prana drop pool).
##
## Coverage:
##   AC-PI-01: add() increments the count and emits prana_collected(type, total)
##   AC-PI-02: add() accumulates repeated picks of the same type
##   AC-PI-03: get_count() returns 0 for an uncollected type
##   AC-PI-04: get_total() sums counts across all types
##   AC-PI-05: get_counts() returns a copy (mutation does not affect internal state)
##   AC-PI-06: run_started resets the pool to empty
##   AC-PI-07: reset() clears all counts
##
## Setup: PranaInventory has no Autoload constraint but connects to GameStateManager
## in _ready(), so it must be added to the tree. Teardown frees it (headless: free()).
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PranaInventoryScript = preload("res://src/systems/prana_inventory.gd")


func _make_inv() -> Node:
	var inv: Node = PranaInventoryScript.new()
	add_child(inv)
	return inv


func _teardown_inv(inv: Node) -> void:
	remove_child(inv)
	inv.free()


# ── AC-PI-01: add increments and emits ───────────────────────────────────────

func test_prana_inventory_add_increments_and_emits() -> void:
	var inv: Node = _make_inv()
	var received: Array = []
	inv.prana_collected.connect(func(type_id: int, count: int) -> void:
		received.append([type_id, count]))

	inv.add(2)

	assert_int(inv.get_count(2)).is_equal(1)
	assert_int(received.size()).is_equal(1)
	assert_int(received[0][0]).is_equal(2)
	assert_int(received[0][1]).is_equal(1)

	_teardown_inv(inv)


# ── AC-PI-02: add accumulates same type ──────────────────────────────────────

func test_prana_inventory_add_accumulates_same_type() -> void:
	var inv: Node = _make_inv()

	inv.add(3)
	inv.add(3, 2)

	assert_int(inv.get_count(3)).is_equal(3)

	_teardown_inv(inv)


# ── AC-PI-03: get_count returns 0 for uncollected type ───────────────────────

func test_prana_inventory_get_count_zero_for_uncollected() -> void:
	var inv: Node = _make_inv()

	assert_int(inv.get_count(4)).is_equal(0)

	_teardown_inv(inv)


# ── AC-PI-04: get_total sums across types ────────────────────────────────────

func test_prana_inventory_get_total_sums_all_types() -> void:
	var inv: Node = _make_inv()

	inv.add(1, 2)
	inv.add(3, 1)
	inv.add(4, 4)

	assert_int(inv.get_total()).is_equal(7)

	_teardown_inv(inv)


# ── AC-PI-05: get_counts returns a copy ──────────────────────────────────────

func test_prana_inventory_get_counts_returns_copy() -> void:
	var inv: Node = _make_inv()
	inv.add(1, 5)

	var snapshot: Dictionary = inv.get_counts()
	snapshot[1] = 999

	assert_int(inv.get_count(1)).is_equal(5)

	_teardown_inv(inv)


# ── AC-PI-06: run_started resets the pool ────────────────────────────────────

func test_prana_inventory_run_started_resets_pool() -> void:
	var inv: Node = _make_inv()
	inv.add(2, 3)

	GameStateManager.run_started.emit()

	assert_int(inv.get_total()).is_equal(0)

	_teardown_inv(inv)


# ── AC-PI-07: reset clears all counts ────────────────────────────────────────

func test_prana_inventory_reset_clears_counts() -> void:
	var inv: Node = _make_inv()
	inv.add(0, 2)
	inv.add(1, 2)

	inv.reset()

	assert_int(inv.get_total()).is_equal(0)

	_teardown_inv(inv)
