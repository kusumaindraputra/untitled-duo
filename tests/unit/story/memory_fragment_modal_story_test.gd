## memory_fragment_modal_story_test.gd — the fragment / ending card (ADR-0027).
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")


func after_test() -> void:
	get_tree().paused = false


func _fragment() -> MemoryFragment:
	var f := MemoryFragment.new()
	f.id = &"frag_test"
	f.title = "Test Title"
	f.voice = "Memo"
	f.body = "Body"
	return f


func test_modal_fragment_shows_title_and_count() -> void:
	var modal := MemoryFragmentModal.new()
	modal.setup_fragment(_fragment(), 2, 10)
	assert_str(modal.get_title()).is_equal("Test Title")
	assert_str(modal.get_footnote()).is_equal(_COPY.memory_count_format % [3, 10])
	modal.free()


func test_modal_partial_ending_shows_missing_count() -> void:
	var modal := MemoryFragmentModal.new()
	modal.setup_ending(_fragment(), false, 7, 10)
	assert_str(modal.get_footnote()).is_equal(_COPY.ending_partial_hint_format % [7, 10])
	modal.free()


func test_modal_true_ending_has_no_footnote() -> void:
	var modal := MemoryFragmentModal.new()
	modal.setup_ending(_fragment(), true, 10, 10)
	assert_str(modal.get_footnote()).is_empty()
	modal.free()


func test_modal_story_anchor_id_shows_story_fragment() -> void:
	var modal := MemoryFragmentModal.new()
	var first: MemoryFragment = StoryRules.fragment_at(0)
	modal.setup(first.id)
	assert_str(modal.get_title()).is_equal(first.title)
	modal.free()


func test_modal_unknown_anchor_id_shows_placeholder_copy() -> void:
	var modal := MemoryFragmentModal.new()
	modal.setup(&"mem_worn_journal")
	assert_str(modal.get_title()).is_equal(_COPY.memory_unknown_title)
	assert_str(String(modal.get_memory_id())).is_equal("mem_worn_journal")
	modal.free()


func test_modal_pauses_tree_and_close_restores_it() -> void:
	get_tree().paused = false
	var modal := MemoryFragmentModal.new()
	modal.setup_fragment(_fragment(), 0, 10)
	add_child(modal)
	assert_bool(get_tree().paused).is_true()
	var count: Array[int] = [0]
	modal.closed.connect(func() -> void: count[0] += 1)
	modal.close()
	modal.close()
	assert_bool(get_tree().paused).is_false()
	assert_int(count[0]).is_equal(1)


func test_modal_freed_without_close_unpauses_tree() -> void:
	get_tree().paused = false
	var modal := MemoryFragmentModal.new()
	modal.setup_fragment(_fragment(), 0, 10)
	add_child(modal)
	modal.free()
	assert_bool(get_tree().paused).is_false()


func test_modal_ignores_input_during_grace_period() -> void:
	var modal := MemoryFragmentModal.new()
	modal.setup_fragment(_fragment(), 0, 10)
	add_child(modal)
	assert_bool(modal.can_dismiss()).is_false()
	modal._process(MemoryFragmentModal.INPUT_GRACE_SEC)
	assert_bool(modal.can_dismiss()).is_true()
	modal.free()
