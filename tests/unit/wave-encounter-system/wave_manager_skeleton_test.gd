## wave_manager_skeleton_test.gd — Unit tests for WaveManager skeleton and phase gating.
##
## Coverage:
##   AC-WES-SKEL: Initial state invariant — _wave_state, _enemies_alive, _enemies_total,
##                and signal declarations after _ready() (and by variable defaults before it)
##   AC-WES-12:   combat_started(is_boss:true) guard — state unchanged, warning logged
##   AC-WES-13:   preparation_started resets all state to IDLE
##
## Story: WaveManager Story 001 — Skeleton, Signals, and Phase Gating
## GDD:   design/gdd/wave-encounter-system.md
## ADR:   ADR-0003 (Signal-Driven Architecture), ADR-0014 (H&D ↔ WaveManager Contract)
##
## Setup pattern:
##   - WaveManager instantiated with .new() and added to the test scene tree via add_child().
##   - _ready() fires on add_child(), connecting to Autoload signals (GameStateManager,
##     HealthAndDamage). Tests call handler methods directly to avoid Autoload coupling.
##   - Teardown: remove_child() then free() (not queue_free()) — headless GdUnit4 has no
##     SceneTree deletion queue processing, so queue_free() would leave orphan nodes.
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
extends GdUnitTestSuite

const WaveManagerScript = preload("res://src/systems/wave_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a WaveManager, adds it to the test scene tree (triggers _ready),
## and returns it. Caller is responsible for teardown via _teardown_wm().
func _make_wm() -> WaveManager:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager
	add_child(wm)
	return wm


## Removes wm from the tree and frees it immediately.
## Uses free() not queue_free(): headless GdUnit4 tests have no running SceneTree
## to drain the deletion queue — queue_free() would leave an orphan node (exit 101).
func _teardown_wm(wm: WaveManager) -> void:
	remove_child(wm)
	wm.free()


# ── AC-WES-SKEL: Initial state invariant ────────────────────────────────────

## GIVEN WaveManager variable declarations (before _ready)
## WHEN the node is constructed
## THEN _wave_state, _enemies_alive, and _enemies_total are at their expected defaults
## (verifies defaults live on variable declarations, not only in _ready).
func test_wave_manager_initial_defaults_set_by_variable_declarations() -> void:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager

	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)
	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._enemies_total).is_equal(0)
	assert_int(wm._wave_composition.size()).is_equal(0)

	# Not added to tree — free() immediately (no queue_free — no SceneTree in headless).
	wm.free()


## GIVEN WaveManager added to the scene tree (_ready fires)
## WHEN _ready() completes
## THEN _wave_state == IDLE, _enemies_alive == 0, _enemies_total == 0
func test_wave_manager_ready_state_is_idle_with_zero_counts() -> void:
	var wm: WaveManager = _make_wm()

	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)
	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._enemies_total).is_equal(0)

	_teardown_wm(wm)


## GIVEN WaveManager added to the scene tree
## WHEN inspecting its declared signals
## THEN wave_cleared, all_waves_cleared, and boss_defeated are all connectable
## (TR-WES-001: WaveManager is the sole authoritative emitter of these three signals)
func test_wave_manager_declares_wave_cleared_signal() -> void:
	var wm: WaveManager = _make_wm()

	assert_bool(wm.has_signal("wave_cleared")).is_true()

	_teardown_wm(wm)


func test_wave_manager_declares_all_waves_cleared_signal() -> void:
	var wm: WaveManager = _make_wm()

	assert_bool(wm.has_signal("all_waves_cleared")).is_true()

	_teardown_wm(wm)


func test_wave_manager_declares_boss_defeated_signal() -> void:
	var wm: WaveManager = _make_wm()

	assert_bool(wm.has_signal("boss_defeated")).is_true()

	_teardown_wm(wm)


## GIVEN WaveManager signals are declared
## WHEN a consumer connects a lambda to each signal
## THEN no error occurs — signals are connectable at runtime
func test_wave_manager_signals_are_connectable_at_runtime() -> void:
	var wm: WaveManager = _make_wm()

	var wc_count: Array[int] = [0]
	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]

	wm.wave_cleared.connect(func() -> void: wc_count[0] += 1)
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	# Emit each signal manually to verify the connections are live.
	wm.wave_cleared.emit()
	wm.all_waves_cleared.emit()
	wm.boss_defeated.emit()

	assert_int(wc_count[0]).is_equal(1)
	assert_int(awc_count[0]).is_equal(1)
	assert_int(bd_count[0]).is_equal(1)

	_teardown_wm(wm)


# ── AC-WES-12: combat_started(is_boss:true) guard ────────────────────────────

## GIVEN WaveManager with _wave_state manually set to WAVE_ACTIVE
## WHEN _on_combat_started(true) is called
## THEN _wave_state remains WAVE_ACTIVE; _enemies_alive is unchanged
## (AC-WES-12: boss self-transition guard — push_warning emitted, no spawn)
## Note: push_warning() writes to stdout only — GdUnit4 v6.1.3 has no assert_warning()
## API. The warning's presence is confirmed by manual output review; what is tested here
## is the observable contract (no state mutation, no signal emission, no spawn).
func test_wave_manager_combat_started_boss_true_preserves_wave_active_state() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 5

	wm._on_combat_started(true)

	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)
	assert_int(wm._enemies_alive).is_equal(5)

	_teardown_wm(wm)


## GIVEN WaveManager with _wave_state = WAVE_ACTIVE
## WHEN _on_combat_started(true) is called
## THEN no signals are emitted (wave_cleared, all_waves_cleared, boss_defeated all silent)
func test_wave_manager_combat_started_boss_true_emits_no_completion_signals() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE

	var wc_count: Array[int] = [0]
	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.wave_cleared.connect(func() -> void: wc_count[0] += 1)
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	wm._on_combat_started(true)

	assert_int(wc_count[0]).is_equal(0)
	assert_int(awc_count[0]).is_equal(0)
	assert_int(bd_count[0]).is_equal(0)

	_teardown_wm(wm)


## Edge case: is_boss = false while _wave_state = IDLE and no spawn_points_container set
## WHEN _on_combat_started(false) is called
## THEN _spawn_wave() runs; no markers → vacuous-complete guard fires → WAVE_COMPLETE
## (Story 002 filled _spawn_wave(); null spawn_points_container + empty composition → 0 spawned)
func test_wave_manager_combat_started_boss_false_calls_spawn_wave_no_crash() -> void:
	var wm: WaveManager = _make_wm()
	# No spawn_points_container set (null) and no composition built → vacuous-complete fires.

	wm._on_combat_started(false)

	# Vacuous-complete guard: 0 enemies spawned → WAVE_COMPLETE, not IDLE.
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)
	assert_int(wm._enemies_total).is_equal(0)

	_teardown_wm(wm)


# ── AC-WES-13: preparation_started resets state ──────────────────────────────

## GIVEN WaveManager with _wave_state = WAVE_COMPLETE, _enemies_alive = 3, _enemies_total = 10
## WHEN _on_preparation_started(0, 0) is called
## THEN _enemies_alive == 0, _enemies_total == 0, _wave_state == IDLE
## (ADR-0014 — Wave Reset Contract)
func test_wave_manager_preparation_started_resets_complete_wave_state() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_COMPLETE
	wm._enemies_alive = 3
	wm._enemies_total = 10

	wm._on_preparation_started(0, 0)

	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._enemies_total).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)

	_teardown_wm(wm)


## GIVEN WaveManager with _wave_state = WAVE_ACTIVE and non-zero counts
## WHEN _on_preparation_started is called (run abandoned mid-wave)
## THEN all state resets to IDLE (ADR-0014 run-end contract — remaining enemies freed
## by scene unload; WaveManager resets for the next run)
func test_wave_manager_preparation_started_resets_active_wave_state() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 7
	wm._enemies_total = 10

	wm._on_preparation_started(0, 0)

	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._enemies_total).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)

	_teardown_wm(wm)


## Edge case: preparation_started called when already IDLE
## THEN no crash; state remains IDLE with zero counts
func test_wave_manager_preparation_started_already_idle_is_no_op() -> void:
	var wm: WaveManager = _make_wm()
	# Default state is already IDLE, 0, 0.

	wm._on_preparation_started(0, 0)

	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)
	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._enemies_total).is_equal(0)

	_teardown_wm(wm)


## Crash-guard: _on_enemy_killed stub (Story 003) must not crash when called with live args.
## The signal is connected in _ready() — H&D will fire it before Story 003 lands.
## This test ensures the pass-stub survives a real-parameter call.
func test_wave_manager_on_enemy_killed_stub_does_not_crash() -> void:
	var wm: WaveManager = _make_wm()

	# Call with real-looking args — should be a no-op (pass body in Story 001).
	wm._on_enemy_killed(12345, 0, GameEnums.DamageClass.NONE)

	# State is unchanged (stub does nothing yet).
	assert_int(wm._enemies_alive).is_equal(0)

	_teardown_wm(wm)


## Edge case: preparation_started called with non-zero wave_index and waves_remaining
## THEN all state still resets correctly (parameters are metadata for future use only)
func test_wave_manager_preparation_started_non_zero_params_resets_correctly() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_COMPLETE
	wm._enemies_alive = 2
	wm._enemies_total = 10

	wm._on_preparation_started(3, 2)

	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._enemies_total).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)

	_teardown_wm(wm)
