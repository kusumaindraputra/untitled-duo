## run_manager_test.gd — Unit tests for RunManager (Story 001).
##
## Coverage:
##   AC-RM-01: run_started resets all fields (active=true, outcome=NONE, waves=0)
##   AC-RM-02: run_started while active → reset + push_error (state observable; error logged)
##   AC-RM-03: wave_ended ×3 → waves_completed=3; get_run_data() reflects it
##   AC-RM-04: room_cleared → WIN; idempotent second call stays WIN
##   AC-RM-05: run_ended(true) after room_cleared → active=false, outcome=WIN
##   AC-RM-06: run_ended(false) with NONE outcome → active=false, outcome=LOSS
##   AC-RM-07: run_ended(false) after WIN does NOT overwrite to LOSS
##   AC-RM-08: run_ended with no active run → push_error; active stays false
##   AC-RM-09: get_run_data() post-run has correct keys and final values
##   AC-RM-10: get_run_data() mid-run → active=true, outcome=NONE
##   AC-RM-11: get_run_data() returns a copy — mutation doesn't affect internal state
##   AC-RM-12: wave_ended while inactive → increment + push_error (state observable)
##
## Note on push_error() assertions:
##   GdUnit4 v6.1.3 has no API to capture or assert push_error() output. Tests that cover
##   ACs requiring push_error() verify the OBSERVABLE CONTRACT (state) instead. The error
##   message is confirmed via manual run. This is documented as known gap G4.
##
## Setup pattern:
##   - RunManager has no class_name (Autoload constraint). Use preload() + new().
##   - add_child(rm) to trigger _ready() and connect to GameStateManager signals.
##   - Emit real GameStateManager signals (NOT mocked) — GSM is a live Autoload in tests.
##   - Teardown: remove_child(rm) + rm.free() (not queue_free — headless, exit 101).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const RunManagerScript = preload("res://src/systems/run_manager.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a RunManager, adds it to the test scene tree (_ready fires, signals connected).
## Caller must call _teardown_rm() when done.
func _make_rm() -> Node:
	var rm: Node = RunManagerScript.new()
	add_child(rm)
	return rm


## Removes rm from the tree and frees it immediately.
## free() not queue_free(): headless GdUnit4 has no running SceneTree to drain
## the deletion queue — queue_free() would leave an orphan node (exit 101).
func _teardown_rm(rm: Node) -> void:
	remove_child(rm)
	rm.free()


# ── AC-RM-01: run_started resets all fields ───────────────────────────────────

## GIVEN RunManager freshly added to tree (initial: active=false, outcome=NONE, waves=0)
## WHEN GameStateManager.run_started emitted
## THEN _run_active=true, _run_outcome=NONE, _waves_completed=0
func test_run_manager_run_started_sets_active_true_and_resets_outcome_and_waves() -> void:
	var rm: Node = _make_rm()

	GameStateManager.run_started.emit()

	assert_bool(rm._run_active).is_true()
	assert_int(rm._run_outcome).is_equal(GameEnums.RunOutcome.NONE)
	assert_int(rm._waves_completed).is_equal(0)

	_teardown_rm(rm)


# ── AC-RM-02: run_started while active → reset + push_error ──────────────────

## GIVEN _run_active=true with dirty state (waves_completed=2)
## WHEN run_started emitted
## THEN fields reset (active=true, outcome=NONE, waves=0); push_error logged
## Note: push_error() is not assertable in GdUnit4 v6.1.3 (known gap G4).
##       The state reset is the observable contract tested here.
func test_run_manager_run_started_while_active_resets_state() -> void:
	var rm: Node = _make_rm()
	rm._run_active = true
	rm._waves_completed = 2
	rm._run_outcome = GameEnums.RunOutcome.NONE

	GameStateManager.run_started.emit()

	assert_bool(rm._run_active).is_true()
	assert_int(rm._run_outcome).is_equal(GameEnums.RunOutcome.NONE)
	assert_int(rm._waves_completed).is_equal(0)

	_teardown_rm(rm)


# ── AC-RM-03: wave_ended ×3 → waves_completed=3 ──────────────────────────────

## GIVEN run is active (run_started fired)
## WHEN wave_ended emitted 3 times
## THEN _waves_completed=3 AND get_run_data()["waves_completed"]==3
func test_run_manager_wave_ended_three_times_increments_waves_completed_to_three() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()

	GameStateManager.wave_ended.emit()
	GameStateManager.wave_ended.emit()
	GameStateManager.wave_ended.emit()

	assert_int(rm._waves_completed).is_equal(3)
	assert_int(rm.get_run_data()["waves_completed"]).is_equal(3)

	_teardown_rm(rm)


# ── AC-RM-04: room_cleared → WIN; idempotent second call ─────────────────────

## GIVEN run is active with outcome=NONE
## WHEN room_cleared emitted
## THEN _run_outcome=WIN and _run_active remains true
func test_run_manager_room_cleared_sets_outcome_to_win_and_run_stays_active() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()

	GameStateManager.room_cleared.emit()

	assert_int(rm._run_outcome).is_equal(GameEnums.RunOutcome.WIN)
	assert_bool(rm._run_active).is_true()

	_teardown_rm(rm)


## GIVEN room_cleared already fired (outcome=WIN)
## WHEN room_cleared emitted a second time
## THEN _run_outcome remains WIN (idempotent)
func test_run_manager_room_cleared_twice_stays_win_idempotent() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()
	GameStateManager.room_cleared.emit()

	GameStateManager.room_cleared.emit()

	assert_int(rm._run_outcome).is_equal(GameEnums.RunOutcome.WIN)

	_teardown_rm(rm)


# ── AC-RM-05: run_ended(true) after room_cleared → active=false, outcome=WIN ──

## GIVEN room_cleared fired (outcome=WIN)
## WHEN run_ended(true) emitted
## THEN _run_active=false AND _run_outcome=WIN
func test_run_manager_run_ended_win_true_after_room_cleared_sets_active_false_and_keeps_win() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()
	GameStateManager.room_cleared.emit()

	GameStateManager.run_ended.emit(true)

	assert_bool(rm._run_active).is_false()
	assert_int(rm._run_outcome).is_equal(GameEnums.RunOutcome.WIN)

	_teardown_rm(rm)


# ── AC-RM-06: run_ended(false) with NONE outcome → LOSS ──────────────────────

## GIVEN run is active, no room_cleared fired (outcome=NONE)
## WHEN run_ended(false) emitted
## THEN _run_active=false AND _run_outcome=LOSS
func test_run_manager_run_ended_win_false_with_none_outcome_sets_loss() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()

	GameStateManager.run_ended.emit(false)

	assert_bool(rm._run_active).is_false()
	assert_int(rm._run_outcome).is_equal(GameEnums.RunOutcome.LOSS)

	_teardown_rm(rm)


# ── AC-RM-07: run_ended(false) after WIN does NOT overwrite to LOSS ───────────

## GIVEN room_cleared fired (outcome=WIN)
## WHEN run_ended(false) emitted
## THEN _run_active=false AND _run_outcome remains WIN (guard prevents WIN→LOSS)
func test_run_manager_run_ended_win_false_after_win_does_not_overwrite_to_loss() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()
	GameStateManager.room_cleared.emit()

	GameStateManager.run_ended.emit(false)

	assert_bool(rm._run_active).is_false()
	assert_int(rm._run_outcome).is_equal(GameEnums.RunOutcome.WIN)

	_teardown_rm(rm)


# ── AC-RM-08: run_ended with no active run → push_error; active stays false ───

## GIVEN _run_active=false (no active run — initial state)
## WHEN run_ended(false) emitted
## THEN _run_active remains false; push_error logged
## Note: push_error() is not assertable in GdUnit4 v6.1.3 (known gap G4).
##       _run_active remaining false is the observable contract.
func test_run_manager_run_ended_without_active_run_keeps_active_false() -> void:
	var rm: Node = _make_rm()
	# Initial state: _run_active=false (no run_started fired)

	GameStateManager.run_ended.emit(false)

	assert_bool(rm._run_active).is_false()

	_teardown_rm(rm)


# ── AC-RM-09: get_run_data() post-run → complete dict with correct keys ───────

## GIVEN run_started → room_cleared → run_ended(true) sequence
## WHEN get_run_data() called after run_ended
## THEN dict has "run_active" (false), "run_outcome" (WIN), "waves_completed" (0)
func test_run_manager_get_run_data_post_run_returns_finalized_values() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()
	GameStateManager.room_cleared.emit()
	GameStateManager.run_ended.emit(true)

	var data: Dictionary = rm.get_run_data()

	assert_bool(data.has("run_active")).is_true()
	assert_bool(data.has("run_outcome")).is_true()
	assert_bool(data.has("waves_completed")).is_true()
	assert_bool(data["run_active"]).is_false()
	assert_int(data["run_outcome"]).is_equal(GameEnums.RunOutcome.WIN)
	assert_int(data["waves_completed"]).is_equal(0)

	_teardown_rm(rm)


# ── AC-RM-10: get_run_data() mid-run → active=true, outcome=NONE ─────────────

## GIVEN run_started fired (run in progress)
## WHEN get_run_data() called mid-run
## THEN result["run_active"]==true AND result["run_outcome"]==NONE
func test_run_manager_get_run_data_mid_run_returns_active_true_and_none_outcome() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()

	var data: Dictionary = rm.get_run_data()

	assert_bool(data["run_active"]).is_true()
	assert_int(data["run_outcome"]).is_equal(GameEnums.RunOutcome.NONE)

	_teardown_rm(rm)


# ── AC-RM-11: get_run_data() returns a copy — mutation doesn't affect state ───

## GIVEN run_started fired (_run_active=true, _waves_completed=0)
## WHEN caller mutates the returned dict
## THEN RunManager's internal fields are unchanged (copy semantics)
func test_run_manager_get_run_data_returns_copy_mutation_does_not_affect_internals() -> void:
	var rm: Node = _make_rm()
	GameStateManager.run_started.emit()

	var data: Dictionary = rm.get_run_data()
	data["run_active"] = false
	data["waves_completed"] = 99

	assert_bool(rm._run_active).is_true()
	assert_int(rm._waves_completed).is_equal(0)

	_teardown_rm(rm)


# ── AC-RM-12: wave_ended while inactive → increment + push_error ─────────────

## GIVEN _run_active=false (no active run)
## WHEN wave_ended emitted
## THEN _waves_completed increments to 1; push_error logged
## Note: push_error() is not assertable in GdUnit4 v6.1.3 (known gap G4).
##       The increment is the observable contract tested here.
func test_run_manager_wave_ended_while_inactive_increments_waves_and_logs_error() -> void:
	var rm: Node = _make_rm()
	# Initial state: _run_active=false

	GameStateManager.wave_ended.emit()

	assert_int(rm._waves_completed).is_equal(1)
	assert_bool(rm._run_active).is_false()

	_teardown_rm(rm)
