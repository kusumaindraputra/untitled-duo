## game_state_manager_test.gd — Unit tests for GameStateManager (Story 001).
##
## Coverage:
##   AC-1:  Boss self-transition emits grid_locked before combat_started(is_boss: true)
##   AC-2:  Boss defeat deferred transition reaches RUN_SUMMARY
##   AC-3:  Same-frame death priority — DEATH_SCREEN beats deferred RUN_SUMMARY
##   AC-4:  Death signal ordering: death_started → state_changed → run_ended(win: false)
##   AC-5:  run_started emitted once; second start_run() from non-MAIN_MENU is no-op
##   AC-6:  Invalid loadout blocks PREPARATION_PHASE → COMBAT_PHASE
##   AC-7:  Re-entrancy guard rejects nested transition; final state = outer target
##   AC-8:  Pause/resume stores and restores previous state
##   AC-9:  Pause from MAIN_MENU / RUN_SUMMARY / DEATH_SCREEN is a no-op
##   AC-10: Wave cleared: COMBAT_PHASE → PREPARATION_PHASE emits wave_ended
##   AC-11: preparation_started carries correct wave_index and waves_remaining
##   AC-12: Prep timer auto-confirms on expiry; halts on invalid loadout
##
## Framework: GdUnit4 v6 (GUT-compatible runner)
extends GdUnitTestSuite

## GameStateManager has no class_name (Godot 4 Autoload constraint).
## Use preload() to instantiate isolated instances in each test.
const GameStateManagerScript = preload("res://src/core/game_state_manager.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh GameStateManager node. Not added to the scene tree unless the
## test requires deferred calls or get_tree().paused access.
func _make_gsm() -> Node:
	return GameStateManagerScript.new()


## Forces [param gsm] into [param state] without running transition side-effects.
## Used to set up preconditions for the state under test.
func _force_state(gsm: Node, state: GameEnums.GameState) -> void:
	gsm._active_state = state

# ── AC-1: Boss self-transition signal order ───────────────────────────────────

func test_boss_self_transition_emits_grid_locked_before_combat_started() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var order: Array[String] = []
	gsm.grid_locked.connect(func() -> void: order.append("grid_locked"))
	gsm.combat_started.connect(func(_b: bool) -> void: order.append("combat_started"))

	gsm._on_all_waves_cleared()

	assert_int(order.size()).is_equal(2)
	assert_str(order[0]).is_equal("grid_locked")
	assert_str(order[1]).is_equal("combat_started")
	gsm.free()


func test_boss_self_transition_emits_combat_started_with_is_boss_true() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var received: Array[bool] = []
	gsm.combat_started.connect(func(is_boss: bool) -> void: received.append(is_boss))

	gsm._on_all_waves_cleared()

	assert_int(received.size()).is_equal(1)
	assert_bool(received[0]).is_true()
	gsm.free()


func test_boss_self_transition_state_remains_combat_phase() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)

	gsm._on_all_waves_cleared()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.COMBAT_PHASE)
	gsm.free()

# ── AC-2: Boss defeat deferred → RUN_SUMMARY ─────────────────────────────────

func test_boss_defeated_transitions_to_run_summary_after_frame() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var wins: Array[bool] = []
	gsm.run_ended.connect(func(win: bool) -> void: wins.append(win))

	gsm._on_boss_defeated()
	await get_tree().process_frame

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.RUN_SUMMARY)
	assert_int(wins.size()).is_equal(1)
	assert_bool(wins[0]).is_true()
	gsm.free()

# ── AC-3: Same-frame death priority ──────────────────────────────────────────

func test_player_died_beats_deferred_boss_defeated_same_frame() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var wins: Array[bool] = []
	gsm.run_ended.connect(func(win: bool) -> void: wins.append(win))

	gsm._on_boss_defeated()
	gsm._on_player_died()
	await get_tree().process_frame

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.DEATH_SCREEN)
	gsm.free()


func test_same_frame_run_ended_win_true_not_emitted() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var wins: Array[bool] = []
	gsm.run_ended.connect(func(win: bool) -> void: wins.append(win))

	gsm._on_boss_defeated()
	gsm._on_player_died()
	await get_tree().process_frame

	assert_bool(wins.has(true)).is_false()
	assert_int(wins.size()).is_equal(1)
	assert_bool(wins[0]).is_false()
	gsm.free()

# ── AC-4: Death signal ordering ───────────────────────────────────────────────

func test_player_died_signal_order_is_death_started_state_changed_run_ended() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var order: Array[String] = []
	gsm.death_started.connect(func() -> void: order.append("death_started"))
	gsm.state_changed.connect(func(_o: int, _n: int) -> void: order.append("state_changed"))
	gsm.run_ended.connect(func(_win: bool) -> void: order.append("run_ended"))

	gsm._on_player_died()

	assert_int(order.size()).is_equal(3)
	assert_str(order[0]).is_equal("death_started")
	assert_str(order[1]).is_equal("state_changed")
	assert_str(order[2]).is_equal("run_ended")
	gsm.free()


func test_state_is_death_screen_when_run_ended_fires() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var state_at_run_ended: Array[int] = []
	gsm.run_ended.connect(func(_win: bool) -> void:
		state_at_run_ended.append(gsm.get_active_state())
	)

	gsm._on_player_died()

	assert_int(state_at_run_ended.size()).is_equal(1)
	assert_int(state_at_run_ended[0]).is_equal(GameEnums.GameState.DEATH_SCREEN)
	gsm.free()

# ── AC-5: run_started emitted exactly once ────────────────────────────────────

func test_start_run_emits_run_started_once_and_enters_preparation_phase() -> void:
	var gsm: Node = _make_gsm()
	var count: Array[int] = [0]
	gsm.run_started.connect(func() -> void: count[0] += 1)

	gsm.start_run()

	assert_int(count[0]).is_equal(1)
	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PREPARATION_PHASE)
	gsm.free()


func test_start_run_from_preparation_phase_does_not_emit_run_started() -> void:
	var gsm: Node = _make_gsm()
	gsm.start_run()
	var count: Array[int] = [0]
	gsm.run_started.connect(func() -> void: count[0] += 1)

	gsm.start_run()  # second call while not in MAIN_MENU

	assert_int(count[0]).is_equal(0)
	gsm.free()


func test_start_run_emits_run_started_before_preparation_started() -> void:
	var gsm: Node = _make_gsm()
	var order: Array[String] = []
	gsm.run_started.connect(func() -> void: order.append("run_started"))
	gsm.preparation_started.connect(func(_wi: int, _wr: int) -> void:
		order.append("preparation_started")
	)

	gsm.start_run()

	assert_int(order.size()).is_equal(2)
	assert_str(order[0]).is_equal("run_started")
	assert_str(order[1]).is_equal("preparation_started")
	gsm.free()

# ── AC-6: Invalid loadout blocks combat ───────────────────────────────────────

func test_arrangement_confirmed_blocked_when_loadout_invalid() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	gsm._loadout_valid = false
	var count: Array[int] = [0]
	gsm.combat_started.connect(func(_b: bool) -> void: count[0] += 1)

	gsm._on_arrangement_confirmed()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PREPARATION_PHASE)
	assert_int(count[0]).is_equal(0)
	gsm.free()


func test_arrangement_confirmed_proceeds_when_loadout_valid() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	gsm._loadout_valid = true

	gsm._on_arrangement_confirmed()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.COMBAT_PHASE)
	gsm.free()

# ── AC-7: Re-entrancy guard ───────────────────────────────────────────────────

func test_reentrant_transition_rejected_outer_state_wins() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	# Connect a handler that attempts a second transition during the first.
	gsm.state_changed.connect(func(_o: int, _n: int) -> void:
		gsm._request_transition(GameEnums.GameState.DEATH_SCREEN)
	)

	gsm._request_transition(GameEnums.GameState.COMBAT_PHASE)

	# Inner DEATH_SCREEN transition was rejected; outer COMBAT_PHASE stands.
	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.COMBAT_PHASE)
	gsm.free()

# ── AC-8: Pause / resume cycle ────────────────────────────────────────────────

func test_pause_from_combat_stores_previous_state_and_emits_game_paused() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var count: Array[int] = [0]
	gsm.game_paused.connect(func() -> void: count[0] += 1)

	gsm.pause_game()

	# Unset before assertions so a failing assert cannot leave the tree paused.
	get_tree().paused = false
	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PAUSED)
	assert_int(gsm._previous_state).is_equal(GameEnums.GameState.COMBAT_PHASE)
	assert_int(count[0]).is_equal(1)
	gsm.free()


func test_resume_restores_previous_state_and_emits_game_resumed() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	gsm.pause_game()
	var count: Array[int] = [0]
	gsm.game_resumed.connect(func() -> void: count[0] += 1)

	gsm.resume_game()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.COMBAT_PHASE)
	assert_int(count[0]).is_equal(1)
	gsm.free()

# ── AC-9: Pause unavailable from menu states ──────────────────────────────────

func test_pause_from_main_menu_is_noop() -> void:
	var gsm: Node = _make_gsm()
	var count: Array[int] = [0]
	gsm.game_paused.connect(func() -> void: count[0] += 1)

	gsm.pause_game()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.MAIN_MENU)
	assert_int(count[0]).is_equal(0)
	gsm.free()


func test_pause_from_run_summary_is_noop() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.RUN_SUMMARY)
	var count: Array[int] = [0]
	gsm.game_paused.connect(func() -> void: count[0] += 1)

	gsm.pause_game()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.RUN_SUMMARY)
	assert_int(count[0]).is_equal(0)
	gsm.free()


func test_pause_from_death_screen_is_noop() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.DEATH_SCREEN)
	var count: Array[int] = [0]
	gsm.game_paused.connect(func() -> void: count[0] += 1)

	gsm.pause_game()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.DEATH_SCREEN)
	assert_int(count[0]).is_equal(0)
	gsm.free()

# ── AC-10: Wave cleared — emits signals, stays in COMBAT_PHASE ───────────────

## GIVEN GSM in COMBAT_PHASE
## WHEN _on_wave_cleared() is called
## THEN wave_ended and room_cleared are emitted; state stays COMBAT_PHASE.
## (State transitions to PREPARATION_PHASE only after the room transition via restart_preparation.)
func test_wave_cleared_emits_wave_ended_and_room_cleared_stays_in_combat() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var wave_ended_count: Array[int] = [0]
	var room_cleared_count: Array[int] = [0]
	gsm.wave_ended.connect(func() -> void: wave_ended_count[0] += 1)
	gsm.room_cleared.connect(func() -> void: room_cleared_count[0] += 1)

	gsm._on_wave_cleared()

	assert_int(wave_ended_count[0]).is_equal(1)
	assert_int(room_cleared_count[0]).is_equal(1)
	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.COMBAT_PHASE)
	gsm.free()


## GIVEN GSM in COMBAT_PHASE
## WHEN _on_wave_cleared() is called from non-COMBAT_PHASE state
## THEN no signals emitted (guard fires)
func test_wave_cleared_noop_when_not_in_combat_phase() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	var count: Array[int] = [0]
	gsm.room_cleared.connect(func() -> void: count[0] += 1)

	gsm._on_wave_cleared()

	assert_int(count[0]).is_equal(0)
	gsm.free()

# ── AC-11: restart_preparation transitions to PREPARATION_PHASE ──────────────

## GIVEN GSM in COMBAT_PHASE
## WHEN restart_preparation() is called
## THEN state transitions to PREPARATION_PHASE and preparation_started emitted
func test_restart_preparation_from_combat_enters_preparation_phase() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var count: Array[int] = [0]
	gsm.preparation_started.connect(func(_wi: int, _wr: int) -> void: count[0] += 1)

	gsm.restart_preparation()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PREPARATION_PHASE)
	assert_int(count[0]).is_equal(1)
	gsm.free()


## GIVEN GSM in COMBAT_PHASE with _wave_index = 3
## WHEN restart_preparation() is called
## THEN _wave_index is reset to 0 and preparation_started carries wave_index=0
func test_restart_preparation_resets_wave_index_to_zero() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	gsm._wave_index = 3
	var wi_out: Array[int] = []
	gsm.preparation_started.connect(func(wi: int, _wr: int) -> void: wi_out.append(wi))

	gsm.restart_preparation()

	assert_int(wi_out.size()).is_equal(1)
	assert_int(wi_out[0]).is_equal(0)
	gsm.free()

# ── AC-12: Prep timer auto-confirm and halt ───────────────────────────────────

func test_prep_timer_auto_confirms_when_elapsed_and_loadout_valid() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	gsm.preparation_phase_time_limit_sec = 5.0
	gsm._loadout_valid = true

	gsm._process(5.01)

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.COMBAT_PHASE)
	gsm.free()


func test_prep_timer_halted_when_elapsed_and_loadout_invalid() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	gsm.preparation_phase_time_limit_sec = 5.0
	gsm._loadout_valid = false

	gsm._process(5.01)

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PREPARATION_PHASE)
	assert_bool(gsm._prep_timer_halted).is_true()
	gsm.free()


func test_prep_timer_does_not_resume_after_halt() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	gsm.preparation_phase_time_limit_sec = 5.0
	gsm._loadout_valid = false
	gsm._process(5.01)   # first expiry — halts timer
	gsm._loadout_valid = true  # loadout becomes valid after halt

	gsm._process(1.0)  # more time arrives

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PREPARATION_PHASE)
	gsm.free()


func test_prep_timer_does_not_tick_while_tree_is_paused() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	gsm.preparation_phase_time_limit_sec = 5.0
	gsm._loadout_valid = true
	get_tree().paused = true

	gsm._process(5.01)

	# Tree is paused — accumulator should not have advanced; state unchanged.
	get_tree().paused = false
	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PREPARATION_PHASE)
	gsm.free()

# ── AC-19: quit_to_menu ───────────────────────────────────────────────────────

func test_quit_to_menu_transitions_to_main_menu_and_emits_run_ended_false() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.PAUSED)
	gsm._previous_state = GameEnums.GameState.COMBAT_PHASE
	var wins: Array[bool] = []
	gsm.run_ended.connect(func(win: bool) -> void: wins.append(win))

	gsm.quit_to_menu()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.MAIN_MENU)
	assert_int(wins.size()).is_equal(1)
	assert_bool(wins[0]).is_false()
	gsm.free()


func test_quit_to_menu_noop_when_not_paused() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var count: Array[int] = [0]
	gsm.run_ended.connect(func(_w: bool) -> void: count[0] += 1)

	gsm.quit_to_menu()

	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.COMBAT_PHASE)
	assert_int(count[0]).is_equal(0)
	gsm.free()

# ── RUN_SUMMARY entry emits run_ended(true) ───────────────────────────────────

func test_run_summary_entry_emits_run_ended_win_true() -> void:
	var gsm: Node = _make_gsm()
	_force_state(gsm, GameEnums.GameState.COMBAT_PHASE)
	var wins: Array[bool] = []
	gsm.run_ended.connect(func(win: bool) -> void: wins.append(win))

	gsm._request_transition(GameEnums.GameState.RUN_SUMMARY)

	assert_int(wins.size()).is_equal(1)
	assert_bool(wins[0]).is_true()
	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.RUN_SUMMARY)
	gsm.free()

# ── Pause from PREPARATION_PHASE ─────────────────────────────────────────────

func test_pause_from_preparation_phase_stores_previous_state() -> void:
	var gsm: Node = _make_gsm()
	add_child(gsm)
	_force_state(gsm, GameEnums.GameState.PREPARATION_PHASE)
	var count: Array[int] = [0]
	gsm.game_paused.connect(func() -> void: count[0] += 1)

	gsm.pause_game()

	get_tree().paused = false
	assert_int(gsm.get_active_state()).is_equal(GameEnums.GameState.PAUSED)
	assert_int(gsm._previous_state).is_equal(GameEnums.GameState.PREPARATION_PHASE)
	assert_int(count[0]).is_equal(1)
	gsm.free()
