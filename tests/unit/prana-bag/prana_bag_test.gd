## prana_bag_test.gd — Unit tests for PranaBag (transient reward bag, grid-as-build).
##
## Coverage:
##   AC-PB-01: add() appends and emits bag_changed with a copy of the items
##   AC-PB-02: add() allows duplicates (two of the same type)
##   AC-PB-03: remove_one() removes the first occurrence and returns true
##   AC-PB-04: remove_one() returns false (no emit) when the type is absent
##   AC-PB-05: get_items() returns a copy (mutation does not affect internal state)
##   AC-PB-06: size()/is_empty()/has_type() report contents correctly
##   AC-PB-07: clear() empties the bag and emits bag_changed
##   AC-PB-08: run_started resets the bag to empty
##
## Setup: PranaBag connects to GameStateManager in _ready(), so it must be added to
## the tree. Teardown frees it (headless: free()).
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const PranaBagScript = preload("res://src/systems/prana_bag.gd")


func _make_bag() -> Node:
	var bag: Node = PranaBagScript.new()
	add_child(bag)
	return bag


func _teardown_bag(bag: Node) -> void:
	remove_child(bag)
	bag.free()


# ── AC-PB-01: add appends and emits ──────────────────────────────────────────

func test_prana_bag_add_appends_and_emits() -> void:
	var bag: Node = _make_bag()
	var received: Array = []
	bag.bag_changed.connect(func(items: Array) -> void: received.append(items))

	bag.add(2)

	assert_int(bag.size()).is_equal(1)
	assert_int(received.size()).is_equal(1)
	assert_array(received[0]).is_equal([2])

	_teardown_bag(bag)


# ── AC-PB-02: add allows duplicates ──────────────────────────────────────────

func test_prana_bag_add_allows_duplicates() -> void:
	var bag: Node = _make_bag()

	bag.add(3)
	bag.add(3)

	assert_array(bag.get_items()).is_equal([3, 3])

	_teardown_bag(bag)


# ── AC-PB-03: remove_one removes first occurrence ────────────────────────────

func test_prana_bag_remove_one_removes_first_occurrence() -> void:
	var bag: Node = _make_bag()
	bag.add(1)
	bag.add(2)
	bag.add(1)

	var removed: bool = bag.remove_one(1)

	assert_bool(removed).is_true()
	assert_array(bag.get_items()).is_equal([2, 1])

	_teardown_bag(bag)


# ── AC-PB-04: remove_one absent returns false, no emit ───────────────────────

func test_prana_bag_remove_one_absent_returns_false_no_emit() -> void:
	var bag: Node = _make_bag()
	bag.add(0)
	var received: Array = []
	bag.bag_changed.connect(func(_items: Array) -> void: received.append(true))

	var removed: bool = bag.remove_one(4)

	assert_bool(removed).is_false()
	assert_int(received.size()).is_equal(0)
	assert_int(bag.size()).is_equal(1)

	_teardown_bag(bag)


# ── AC-PB-05: get_items returns a copy ───────────────────────────────────────

func test_prana_bag_get_items_returns_copy() -> void:
	var bag: Node = _make_bag()
	bag.add(1)

	var snapshot: Array = bag.get_items()
	snapshot.append(999)

	assert_int(bag.size()).is_equal(1)

	_teardown_bag(bag)


# ── AC-PB-06: size/is_empty/has_type ─────────────────────────────────────────

func test_prana_bag_size_empty_has_type_report_contents() -> void:
	var bag: Node = _make_bag()
	assert_bool(bag.is_empty()).is_true()

	bag.add(2)
	bag.add(4)

	assert_int(bag.size()).is_equal(2)
	assert_bool(bag.is_empty()).is_false()
	assert_bool(bag.has_type(2)).is_true()
	assert_bool(bag.has_type(0)).is_false()

	_teardown_bag(bag)


# ── AC-PB-07: clear empties and emits ────────────────────────────────────────

func test_prana_bag_clear_empties_and_emits() -> void:
	var bag: Node = _make_bag()
	bag.add(0)
	bag.add(1)
	var received: Array = []
	bag.bag_changed.connect(func(items: Array) -> void: received.append(items))

	bag.clear()

	assert_bool(bag.is_empty()).is_true()
	assert_int(received.size()).is_equal(1)
	assert_array(received[0]).is_equal([])

	_teardown_bag(bag)


# ── AC-PB-08: run_started resets the bag ─────────────────────────────────────

func test_prana_bag_run_started_resets_bag() -> void:
	var bag: Node = _make_bag()
	bag.add(2)
	bag.add(3)

	GameStateManager.run_started.emit()

	assert_bool(bag.is_empty()).is_true()

	_teardown_bag(bag)
