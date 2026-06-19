## memory_fragment_modal_test.gd — Unit tests for the MemoryFragmentModal placeholder.
##
## Story: LD-23 — Memory Fragment Trigger System (placeholder)
extends GdUnitTestSuite


func test_modal_canvas_layer_is_above_game() -> void:
	var modal := MemoryFragmentModal.new()
	auto_free(modal)
	modal.setup(&"mem_worn_journal")
	add_child(modal)
	assert_int(modal.layer).is_greater_equal(10)


func test_setup_stores_memory_id() -> void:
	var modal := MemoryFragmentModal.new()
	auto_free(modal)
	modal.setup(&"mem_carved_toy")
	add_child(modal)
	assert_bool(is_instance_valid(modal)).is_true()


func test_modal_is_canvas_layer() -> void:
	var modal := MemoryFragmentModal.new()
	assert_bool(modal is CanvasLayer).is_true()
	modal.free()


func test_setup_with_empty_id_does_not_crash() -> void:
	var modal := MemoryFragmentModal.new()
	auto_free(modal)
	modal.setup(&"")
	add_child(modal)
	assert_bool(is_instance_valid(modal)).is_true()
