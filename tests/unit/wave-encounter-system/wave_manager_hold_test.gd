## wave_manager_hold_test.gd — WaveManager.hold_wave / release_wave (ADR-0055).
## The guided first room keeps the room's wave back until its lessons end.
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite


func _make_wm() -> WaveManager:
	var wm := WaveManager.new()
	add_child(wm)
	return wm


func _teardown_wm(wm: WaveManager) -> void:
	remove_child(wm)
	wm.free()


func test_wave_manager_hold_keeps_the_wave_back_on_combat_start() -> void:
	var wm := _make_wm()
	wm.hold_wave = true
	wm._on_combat_started(false)
	assert_bool(wm._wave_held).is_true()
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)
	assert_int(wm._enemies_total).is_equal(0)
	_teardown_wm(wm)


func test_wave_manager_release_spawns_the_held_wave() -> void:
	var wm := _make_wm()
	wm.hold_wave = true
	wm._on_combat_started(false)
	var markers := Node.new()
	add_child(markers)
	wm.spawn_points_container = markers
	wm._wave_composition = [{ "type_id": 0, "scene": null }]
	var cleared: Array[int] = [0]
	wm.wave_cleared.connect(func() -> void: cleared[0] += 1)
	wm.release_wave()  # no markers: the zero-spawn guard clears the wave
	assert_bool(wm.hold_wave).is_false()
	assert_bool(wm._wave_held).is_false()
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)
	assert_int(cleared[0]).is_equal(1)
	wm.release_wave()  # nothing held any more: no second spawn
	assert_int(cleared[0]).is_equal(1)
	_teardown_wm(wm)
	remove_child(markers)
	markers.free()


func test_wave_manager_release_without_hold_is_a_no_op() -> void:
	var wm := _make_wm()
	wm.release_wave()
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)
	_teardown_wm(wm)


func test_wave_manager_new_preparation_clears_a_stale_hold() -> void:
	var wm := _make_wm()
	wm.hold_wave = true
	wm._on_combat_started(false)
	wm.room_type = DungeonGraph.ROOM_TYPE_REST  # skips composition building
	wm._on_preparation_started(0, 0)
	assert_bool(wm._wave_held).is_false()
	_teardown_wm(wm)
