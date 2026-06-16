## GameStateManager — Autoload #3. Owns the top-level game state machine.
##
## Contract (ADR-0002, ADR-0003, ADR-0004):
##   - Emits state-change signals; no system reads _active_state directly (ADR-0003).
##   - All timing via float delta accumulator — no Timer nodes (ADR-0004).
##   - Re-entrancy guard rejects nested transition calls with push_error() (TR-GSF-005).
##   - boss_defeated uses call_deferred — player_died immediate call wins same frame (TR-GSF-006).
##   - death_started fires BEFORE state changes and BEFORE run_ended(win: false) (TR-GSF-008).
##
## Registration: Autoload #3 in Project Settings → AutoLoad (ADR-0002).
## No class_name — Godot 4 parse error when class_name matches Autoload node name.
## Access in game code: GameStateManager.start_run() (via Autoload path, not class_name).
## Access in tests: preload("res://src/core/game_state_manager.gd").new()
extends Node

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted on every state transition. Parameters carry GameEnums.GameState int values.
signal state_changed(old_state: int, new_state: int)

## Emitted when a new run begins — before [signal preparation_started].
signal run_started()

## Emitted each time the game enters PREPARATION_PHASE.
## [param wave_index] is zero-based. [param waves_remaining] counts waves not yet started.
signal preparation_started(wave_index: int, waves_remaining: int)

## Emitted after [signal grid_locked] when combat begins.
## [param is_boss] is true for the final boss encounter self-transition.
signal combat_started(is_boss: bool)

## Emitted immediately before [signal combat_started] on every combat entry.
signal grid_locked()

## Emitted when the Prana grid should be hidden (consumed by PranaGrid — Story 002+).
signal grid_hidden()

## Emitted when a non-boss wave ends and state returns to PREPARATION_PHASE.
signal wave_ended()

## Emitted when state transitions to PAUSED.
signal game_paused()

## Emitted when state resumes from PAUSED.
signal game_resumed()

## Emitted before state changes to DEATH_SCREEN and before run_ended(win: false).
signal death_started()

## Emitted when a run ends. [param win] true on boss defeat, false on death or quit.
signal run_ended(win: bool)

## Emitted on room clear (consumed by SceneManager — Story 002).
signal room_cleared()

# ── Export ────────────────────────────────────────────────────────────────────

## Seconds available in PREPARATION_PHASE before timer auto-confirms.
## Set to 0.0 to disable the timer entirely.
@export var preparation_phase_time_limit_sec: float = 0.0

# ── Private state ─────────────────────────────────────────────────────────────

var _active_state: GameEnums.GameState = GameEnums.GameState.MAIN_MENU
var _previous_state: GameEnums.GameState = GameEnums.GameState.MAIN_MENU
var _is_transitioning: bool = false
var _wave_index: int = 0
var _waves_remaining: int = 0

## Float accumulator for the preparation-phase countdown (ADR-0004).
var _prep_timer_acc: float = 0.0

## True after the prep timer fires with an invalid loadout — does not resume (AC-17).
var _prep_timer_halted: bool = false

## Set by PranaGrid — defaults true until grid is implemented.
var _loadout_valid: bool = true

# ── Built-in ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	HealthAndDamage.player_died.connect(_on_player_died)


func _process(delta: float) -> void:
	_tick_prep_timer(delta)

# ── Public API ────────────────────────────────────────────────────────────────

## Returns the current game state without exposing [member _active_state] directly.
func get_active_state() -> GameEnums.GameState:
	return _active_state


## Returns [member _loadout_valid]. Called by [method _on_arrangement_confirmed] (AC-05).
func is_loadout_valid() -> bool:
	return _loadout_valid


## Starts a new run from MAIN_MENU.
## Emits [signal run_started] then enters PREPARATION_PHASE.
## No-op if not in MAIN_MENU — does not re-emit [signal run_started] (AC-03b).
func start_run() -> void:
	if _active_state != GameEnums.GameState.MAIN_MENU:
		return
	_wave_index = 0
	_waves_remaining = 3  # placeholder — WaveManager will own this value in Wave/Encounter epic
	run_started.emit()
	_request_transition(GameEnums.GameState.PREPARATION_PHASE)


## Pauses from PREPARATION_PHASE or COMBAT_PHASE only (AC-11, AC-13).
## Stores previous state for [method resume_game]. No-op from menu states.
func pause_game() -> void:
	if _active_state != GameEnums.GameState.PREPARATION_PHASE \
			and _active_state != GameEnums.GameState.COMBAT_PHASE:
		return
	if not is_inside_tree():
		return
	_previous_state = _active_state
	_request_transition(GameEnums.GameState.PAUSED)
	get_tree().paused = true
	game_paused.emit()


## Resumes from PAUSED, restoring [member _previous_state] (AC-12).
func resume_game() -> void:
	if _active_state != GameEnums.GameState.PAUSED:
		return
	if not is_inside_tree():
		return
	var restore: GameEnums.GameState = _previous_state
	_request_transition(restore)
	get_tree().paused = false
	game_resumed.emit()


## Quits to MAIN_MENU from PAUSED state only (AC-19).
## Emits [signal run_ended] before transitioning.
func quit_to_menu() -> void:
	if _active_state != GameEnums.GameState.PAUSED:
		return
	if not is_inside_tree():
		return
	get_tree().paused = false
	run_ended.emit(false)
	_request_transition(GameEnums.GameState.MAIN_MENU)

# ── Signal input handlers ─────────────────────────────────────────────────────

## PREPARATION_PHASE → COMBAT_PHASE when loadout valid; no-op otherwise (AC-05).
## Signal order: grid_locked before combat_started (AC-14).
func _on_arrangement_confirmed() -> void:
	if _active_state != GameEnums.GameState.PREPARATION_PHASE:
		return
	if not is_loadout_valid():
		return
	_enter_combat(false)


## COMBAT_PHASE → PREPARATION_PHASE on wave clear. Emits [signal wave_ended] (AC-10).
func _on_wave_cleared() -> void:
	if _active_state != GameEnums.GameState.COMBAT_PHASE:
		return
	wave_ended.emit()
	_wave_index += 1
	if _waves_remaining > 0:
		_waves_remaining -= 1
	_request_transition(GameEnums.GameState.PREPARATION_PHASE)


## COMBAT_PHASE self-transition for boss wave (AC-01).
## grid_locked emitted before combat_started(is_boss: true).
func _on_all_waves_cleared() -> void:
	if _active_state != GameEnums.GameState.COMBAT_PHASE:
		return
	_enter_combat(true)


## Deferred — same-frame player_died() wins over this call (TR-GSF-006, AC-01c).
func _on_boss_defeated() -> void:
	call_deferred("_request_boss_defeat_transition")


## Public entry point for WaveManager.all_waves_cleared signal connection (AV-5).
## External callers connect here; private _on_all_waves_cleared() is the implementation.
func receive_all_waves_cleared() -> void:
	_on_all_waves_cleared()


## Public entry point for WaveManager.boss_defeated signal connection (AV-5).
func receive_boss_defeated() -> void:
	_on_boss_defeated()


## Immediate death sequence (TR-GSF-008).
## Signal order: death_started → state changes to DEATH_SCREEN → run_ended(win: false).
func _on_player_died() -> void:
	if _active_state != GameEnums.GameState.COMBAT_PHASE:
		return
	death_started.emit()
	_request_transition(GameEnums.GameState.DEATH_SCREEN)
	run_ended.emit(false)

# ── Private ───────────────────────────────────────────────────────────────────

## Guards against re-entrant transition calls (TR-GSF-005, AC-07).
func _request_transition(new_state: GameEnums.GameState) -> void:
	if _is_transitioning:
		push_error(
			"[GameStateManager] Re-entrant transition request rejected: %s → %s"
				% [_active_state, new_state]
		)
		return
	_is_transitioning = true
	_do_transition(new_state)
	_is_transitioning = false


## Performs the raw state change and emits [signal state_changed].
func _do_transition(new_state: GameEnums.GameState) -> void:
	var old: GameEnums.GameState = _active_state
	_active_state = new_state
	state_changed.emit(old as int, new_state as int)
	_on_state_entered(new_state)


## Side-effects on entering a new state.
func _on_state_entered(state: GameEnums.GameState) -> void:
	match state:
		GameEnums.GameState.PREPARATION_PHASE:
			_prep_timer_acc = 0.0
			_prep_timer_halted = false
			preparation_started.emit(_wave_index, _waves_remaining)
		GameEnums.GameState.RUN_SUMMARY:
			run_ended.emit(true)
		_:
			pass


## Shared combat entry: grid_locked → transition → combat_started.
func _enter_combat(is_boss: bool) -> void:
	grid_locked.emit()
	_request_transition(GameEnums.GameState.COMBAT_PHASE)
	combat_started.emit(is_boss)


## Deferred target of [method _on_boss_defeated].
## No-op if state has already changed (player died same frame).
func _request_boss_defeat_transition() -> void:
	if _active_state != GameEnums.GameState.COMBAT_PHASE:
		return
	_request_transition(GameEnums.GameState.RUN_SUMMARY)


## Advances the preparation-phase countdown (ADR-0004).
## Only ticks during PREPARATION_PHASE when timer is enabled, not halted, and tree is unpaused.
func _tick_prep_timer(delta: float) -> void:
	if _active_state != GameEnums.GameState.PREPARATION_PHASE:
		return
	if preparation_phase_time_limit_sec <= 0.0:
		return
	if _prep_timer_halted:
		return
	if not is_inside_tree() or get_tree().paused:
		return
	_prep_timer_acc += delta
	if _prep_timer_acc >= preparation_phase_time_limit_sec:
		if is_loadout_valid():
			_on_arrangement_confirmed()
		else:
			_prep_timer_halted = true
