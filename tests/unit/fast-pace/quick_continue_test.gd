## quick_continue_test.gd — PranaGrid one-press continue (ADR-0019).
##
## PranaGrid is .new() (not in the tree), so _get_bag() is null (treated as empty).
extends GdUnitTestSuite

const PranaGridScript := preload("res://src/ui/prana_grid.gd")


func _grid(center: Variant) -> PranaGrid:
	var pg: PranaGrid = PranaGridScript.new()
	pg._slots.resize(PranaGrid.GRID_SIZE)
	pg._slots.fill(null)
	pg._slots[4] = center
	pg._state = PranaGrid.State.ARRANGEMENT
	return pg


func test_quick_continue_available_with_core_and_empty_bag() -> void:
	var pg := _grid(0)
	assert_bool(pg.is_quick_continue_available()).is_true()
	pg.free()


func test_quick_continue_needs_centre_slot() -> void:
	var pg := _grid(null)
	assert_bool(pg.is_quick_continue_available()).is_false()
	pg.free()


func test_quick_continue_only_in_arrangement() -> void:
	var pg := _grid(0)
	pg._state = PranaGrid.State.LOCKED
	assert_bool(pg.is_quick_continue_available()).is_false()
	pg.free()
