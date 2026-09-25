## memories_panel_test.gd — the Memories archive on the main menu (ADR-0027).
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")


func _panel(found: int, ending: bool, true_ending: bool) -> MemoriesPanel:
	var p := MetaProgress.new()
	p.fragments_found = found
	p.ending_seen = ending
	p.true_ending_seen = true_ending
	var panel := MemoriesPanel.new()
	panel.progress = p
	add_child(panel)
	return panel


func test_memories_lists_every_fragment_with_locked_ones_hidden() -> void:
	var panel := _panel(2, false, false)
	assert_int(panel.entry_count()).is_equal(StoryRules.total())
	assert_str(panel.entry_text(0)).contains(StoryRules.fragment_at(0).title)
	assert_str(panel.entry_text(2)).contains(_COPY.memories_locked)
	panel.free()


func test_memories_locked_entry_shows_locked_text() -> void:
	var panel := _panel(1, false, false)
	panel.select_entry(5)
	assert_str(panel.detail_title()).is_equal(_COPY.memories_locked)
	panel.free()


func test_memories_unlocked_entry_shows_fragment() -> void:
	var panel := _panel(3, false, false)
	panel.select_entry(2)
	assert_str(panel.detail_title()).is_equal(StoryRules.fragment_at(2).title)
	panel.free()


func test_memories_seen_endings_are_listed() -> void:
	var panel := _panel(10, true, true)
	assert_int(panel.entry_count()).is_equal(StoryRules.total() + 2)
	panel.select_entry(StoryRules.total() + 1)
	assert_str(panel.detail_title()).is_equal(StoryRules.CONFIG.ending_true.title)
	panel.free()


func test_memories_close_emits_closed() -> void:
	var panel := _panel(0, false, false)
	var count: Array[int] = [0]
	panel.closed.connect(func() -> void: count[0] += 1)
	panel.close()
	assert_int(count[0]).is_equal(1)
