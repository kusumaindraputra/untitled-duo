## run_manager_integration_test.gd — Integration test for full FP run lifecycle.
##
## Coverage:
##   AC-RM-13: Full FP run sequence (run_started → room_cleared → run_ended(true))
##             → get_run_data() returns { run_active: false, run_outcome: WIN, waves_completed: 0 }
##
## Setup pattern:
##   - RunManager added to tree via add_child(): triggers _ready(), connects to real GSM signals
##   - Full phase sequence emitted via real GameStateManager signals
##   - Teardown: remove_child() then free() — not queue_free() (headless GdUnit4, exit 101 guard)
##
## AC-RM-14 (manual smoke check): RunManager appears at position #9 in Project Settings → AutoLoad;
##   game starts without signal-connection errors. Cannot be unit-tested in GUT.
##
## Story: RunManagement Story 002 — FP Run Integration Test
## ADR:   ADR-0003 (Signal-Driven Architecture — real signal wiring verified end-to-end)
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const RunManagerScript = preload("res://src/systems/run_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_rm() -> Node:
	var rm: Node = RunManagerScript.new()
	add_child(rm)
	return rm


func _teardown_rm(rm: Node) -> void:
	remove_child(rm)
	rm.free()


# ── AC-RM-13: Full FP run end-to-end ─────────────────────────────────────────

## GIVEN RunManager connected to real GameStateManager Autoload
## WHEN full FP run sequence: run_started → room_cleared → run_ended(true)
## THEN get_run_data() returns { run_active: false, run_outcome: WIN, waves_completed: 0 }
func test_full_fp_run_get_run_data_returns_win_with_zero_waves() -> void:
	var rm: Node = _make_rm()

	GameStateManager.run_started.emit()
	# At FP scope: no wave_ended fires (single wave; all_waves_cleared → room_cleared directly)
	GameStateManager.room_cleared.emit()    # sets run_outcome = WIN
	GameStateManager.run_ended.emit(true)   # finalises run

	var data: Dictionary = rm.get_run_data()

	assert_bool(data["run_active"]).is_false()
	assert_int(data["run_outcome"]).is_equal(GameEnums.RunOutcome.WIN)
	assert_int(data["waves_completed"]).is_equal(0)

	_teardown_rm(rm)


# ── AC-RM-13 (edge): Loss path — Fayde died before room cleared ───────────────

## GIVEN RunManager connected to real GSM
## WHEN run_started → run_ended(false) (no room_cleared — Fayde died)
## THEN get_run_data() returns { run_active: false, run_outcome: LOSS, waves_completed: 0 }
func test_full_fp_run_loss_path_fayde_died_returns_loss() -> void:
	var rm: Node = _make_rm()

	GameStateManager.run_started.emit()
	GameStateManager.run_ended.emit(false)  # Fayde died; room_cleared never fired

	var data: Dictionary = rm.get_run_data()

	assert_bool(data["run_active"]).is_false()
	assert_int(data["run_outcome"]).is_equal(GameEnums.RunOutcome.LOSS)
	assert_int(data["waves_completed"]).is_equal(0)

	_teardown_rm(rm)


# ── AC-RM-13 (consecutive runs): second run resets cleanly ───────────────────

## GIVEN a completed run (win)
## WHEN a second run_started fires
## THEN run_active=true, outcome=NONE, waves_completed=0 (clean reset)
func test_consecutive_runs_second_run_resets_state_cleanly() -> void:
	var rm: Node = _make_rm()

	# First run — win
	GameStateManager.run_started.emit()
	GameStateManager.room_cleared.emit()
	GameStateManager.run_ended.emit(true)

	# Second run begins
	GameStateManager.run_started.emit()

	var data: Dictionary = rm.get_run_data()

	assert_bool(data["run_active"]).is_true()
	assert_int(data["run_outcome"]).is_equal(GameEnums.RunOutcome.NONE)
	assert_int(data["waves_completed"]).is_equal(0)

	# Clean up second run (prevent orphan signal from run_ended-less teardown)
	GameStateManager.run_ended.emit(false)

	_teardown_rm(rm)
