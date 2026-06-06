## wave_manager_kill_tracking_test.gd — Unit tests for WaveManager kill tracking and wave completion.
##
## Coverage:
##   AC-WES-07: Mid-wave kill — _enemies_alive decremented, _wave_state remains WAVE_ACTIVE
##   AC-WES-08: Last kill → _enemies_alive=0, _wave_state=WAVE_COMPLETE
##   AC-WES-09: Completion signals emitted exactly once, all_waves_cleared before boss_defeated
##   AC-WES-10: Duplicate enemy_killed after WAVE_COMPLETE — no re-emission, no decrement
##   AC-WES-11: Zero-spawn guard fires all_waves_cleared + boss_defeated → WAVE_COMPLETE (no kills)
##
## Story: WaveManager Story 003 — Kill Tracking and Wave Completion Signals
## GDD:   design/gdd/wave-encounter-system.md (TR-WES-003, TR-WES-005)
## ADR:   ADR-0014 (H&D ↔ WaveManager Integration Contract)
##
## Setup pattern:
##   - WaveManager instantiated with .new() and added to the test scene tree via add_child().
##   - _ready() fires on add_child(), connecting to Autoload signals (GameStateManager,
##     HealthAndDamage). Tests call _on_enemy_killed() directly to bypass H&D dependency.
##   - Teardown: remove_child() then free() (not queue_free()) — headless GdUnit4 has no
##     SceneTree deletion queue processing, so queue_free() would leave orphan nodes (exit 101).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const WaveManagerScript = preload("res://src/systems/wave_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a WaveManager, adds it to the test scene tree (_ready fires), returns it.
## Caller must call _teardown_wm() when done.
func _make_wm() -> WaveManager:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager
	add_child(wm)
	return wm


## Removes wm from the tree and frees it immediately.
## free() not queue_free(): headless GdUnit4 has no running SceneTree to drain
## the deletion queue — queue_free() would leave an orphan node (exit 101).
func _teardown_wm(wm: WaveManager) -> void:
	remove_child(wm)
	wm.free()


## Creates a Node container with [param count] Node2D children as spawn markers,
## adds it to the test scene tree, and returns it.
## Caller must call _teardown_container() when done.
func _make_spawn_container(count: int) -> Node:
	var container: Node = Node.new()
	container.name = "SpawnPoints"
	add_child(container)
	for i: int in range(count):
		var marker: Node2D = Node2D.new()
		marker.name = "SP_%02d" % (i + 1)
		container.add_child(marker)
	return container


## Removes container from the tree and frees it immediately.
func _teardown_container(container: Node) -> void:
	remove_child(container)
	container.free()


# ── AC-WES-07: Mid-wave kill — count decrements, state unchanged ──────────────

## GIVEN WaveManager with _wave_state=WAVE_ACTIVE and _enemies_alive=5
## WHEN _on_enemy_killed() called once with any valid args
## THEN _enemies_alive=4 and _wave_state remains WAVE_ACTIVE
func test_on_enemy_killed_mid_wave_decrements_count_and_keeps_wave_active() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 5

	wm._on_enemy_killed(999, 0, GameEnums.DamageClass.FIRE)

	assert_int(wm._enemies_alive).is_equal(4)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)

	_teardown_wm(wm)


## GIVEN WaveManager with _wave_state=WAVE_ACTIVE and _enemies_alive=5
## WHEN _on_enemy_killed() called once (not the last kill)
## THEN no completion signals emitted (wave still in progress)
func test_on_enemy_killed_mid_wave_emits_no_completion_signals() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 5

	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	wm._on_enemy_killed(999, 0, GameEnums.DamageClass.FIRE)

	assert_int(awc_count[0]).is_equal(0)
	assert_int(bd_count[0]).is_equal(0)

	_teardown_wm(wm)


# ── AC-WES-08: Last kill → WAVE_COMPLETE ─────────────────────────────────────

## GIVEN WaveManager with _wave_state=WAVE_ACTIVE and _enemies_alive=1
## WHEN _on_enemy_killed() called (the final kill)
## THEN _enemies_alive=0 and _wave_state=WAVE_COMPLETE after the handler returns (synchronous)
func test_on_enemy_killed_last_enemy_sets_wave_complete_and_zeroes_count() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 1

	wm._on_enemy_killed(1, 0, GameEnums.DamageClass.NONE)

	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)

	_teardown_wm(wm)


# ── AC-WES-09: Completion signals emitted once, in order ─────────────────────

## GIVEN WaveManager with _wave_state=WAVE_ACTIVE and _enemies_alive=1
## WHEN _on_enemy_killed() called (the final kill)
## THEN all_waves_cleared emitted exactly 1 time AND boss_defeated emitted exactly 1 time
func test_on_enemy_killed_last_enemy_emits_all_waves_cleared_and_boss_defeated_once_each() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 1

	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	wm._on_enemy_killed(1, 0, GameEnums.DamageClass.NONE)

	assert_int(awc_count[0]).is_equal(1)
	assert_int(bd_count[0]).is_equal(1)

	_teardown_wm(wm)


## GIVEN WaveManager with _wave_state=WAVE_ACTIVE and _enemies_alive=1
## WHEN _on_enemy_killed() called (the final kill)
## THEN all_waves_cleared fires BEFORE boss_defeated (synchronous, same frame — ADR-0014)
func test_on_enemy_killed_all_waves_cleared_fires_before_boss_defeated() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 1

	var emission_order: Array[String] = []
	wm.all_waves_cleared.connect(func() -> void: emission_order.append("all_waves_cleared"))
	wm.boss_defeated.connect(func() -> void: emission_order.append("boss_defeated"))

	wm._on_enemy_killed(1, 0, GameEnums.DamageClass.NONE)

	assert_int(emission_order.size()).is_equal(2)
	assert_str(emission_order[0]).is_equal("all_waves_cleared")
	assert_str(emission_order[1]).is_equal("boss_defeated")

	_teardown_wm(wm)


# ── AC-WES-10: Duplicate signal after WAVE_COMPLETE — no re-emission ──────────

## GIVEN WaveManager that transitioned to WAVE_COMPLETE after the first kill
## WHEN _on_enemy_killed() called again (late/duplicate signal)
## THEN _wave_state remains WAVE_COMPLETE; signals not re-emitted; _enemies_alive unchanged
func test_on_enemy_killed_duplicate_after_wave_complete_does_not_re_emit_or_decrement() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 1

	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	# First call: transitions to WAVE_COMPLETE, emits signals.
	wm._on_enemy_killed(1, 0, GameEnums.DamageClass.NONE)
	assert_int(awc_count[0]).is_equal(1)
	assert_int(bd_count[0]).is_equal(1)

	var enemies_alive_after_first: int = wm._enemies_alive

	# Duplicate call: must be a no-op — WAVE_COMPLETE guard fires before decrement.
	wm._on_enemy_killed(2, 0, GameEnums.DamageClass.NONE)

	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)
	assert_int(awc_count[0]).is_equal(1)  # still 1, not 2
	assert_int(bd_count[0]).is_equal(1)   # still 1, not 2
	assert_int(wm._enemies_alive).is_equal(enemies_alive_after_first)  # not decremented further

	_teardown_wm(wm)


## GIVEN WaveManager already in WAVE_COMPLETE with _enemies_alive=0
## WHEN _on_enemy_killed() called (simulating a late signal after WAVE_COMPLETE was set externally)
## THEN _enemies_alive remains 0 — guard fires before decrement, so value cannot go negative
func test_on_enemy_killed_duplicate_does_not_make_enemies_alive_negative() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_COMPLETE
	wm._enemies_alive = 0

	wm._on_enemy_killed(99, 0, GameEnums.DamageClass.NONE)

	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)

	_teardown_wm(wm)


# ── AC-WES-11: Zero-spawn guard fires completion without kills ────────────────

## GIVEN WaveManager with a spawn container having 0 markers (all spawns fail)
## WHEN _spawn_wave() runs via _on_combat_started(false)
## THEN all_waves_cleared emitted once, boss_defeated emitted once, _wave_state=WAVE_COMPLETE
## without any enemy_killed signals — run does not hang (TR-WES-003, ADR-0014)
func test_zero_spawn_guard_emits_completion_signals_and_sets_wave_complete_without_kills() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(0)
	wm.spawn_points_container = spawn_container
	# Non-empty composition so the spawn loop enters and the "fewer markers" break fires.
	wm._wave_composition = [{ "type_id": 0, "scene": null }]

	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	wm._on_combat_started(false)

	assert_int(wm._enemies_total).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)
	assert_int(awc_count[0]).is_equal(1)
	assert_int(bd_count[0]).is_equal(1)

	_teardown_container(spawn_container)
	_teardown_wm(wm)
