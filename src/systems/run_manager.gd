## RunManager — Autoload #9. Tracks run lifecycle state.
##
## Contract (ADR-0002, ADR-0003):
##   - Signal consumer only — no _process() loop, no _request_transition() calls.
##   - Connects to GameStateManager signals in _ready(); disconnects in _exit_tree().
##   - get_run_data() returns a Dictionary copy (.duplicate()) — callers cannot mutate
##     internal state through the returned value.
##   - run_outcome is set to WIN by room_cleared; run_ended(false) does NOT overwrite WIN.
##   - push_error() called when invariants are violated (run already active on start,
##     run not active on end, wave_ended while inactive).
##
## Registration: Autoload #9 in Project Settings → AutoLoad (ADR-0002), after SpellCastingEffects.
## No class_name — Godot 4 parse error when class_name matches Autoload node name.
## Access in game code: RunManager.get_run_data() (via Autoload path, not class_name).
## Access in tests: preload("res://src/systems/run_manager.gd").new(); add_child(rm)
extends Node

# ── Private state ─────────────────────────────────────────────────────────────

## True while a run is in progress (between run_started and run_ended).
var _run_active: bool = false

## Current outcome of the run. NONE while in progress.
var _run_outcome: GameEnums.RunOutcome = GameEnums.RunOutcome.NONE

## Number of waves completed this run (incremented on each wave_ended signal).
var _waves_completed: int = 0

## Number of rooms cleared this run (incremented on each room_cleared signal).
var _rooms_cleared: int = 0

## Current floor number within this run (1-based). Incremented on floor_completed.
var _current_floor: int = 1

## Total enemies killed this run (incremented on each HealthAndDamage.enemy_killed).
var _enemies_killed: int = 0

## Highest combo chain index reached this run (from SpellCastingEffects.chain_index_changed).
var _best_combo: int = 0

## Wall-clock ticks (msec) captured at run_started; basis for run_time_sec.
var _run_start_msec: int = 0

## Final run duration in seconds, computed once on run_ended. 0.0 while a run is active.
var _run_elapsed_sec: float = 0.0

# ── Built-in ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.run_started.connect(_on_run_started)
	GameStateManager.wave_ended.connect(_on_wave_ended)
	GameStateManager.room_cleared.connect(_on_room_cleared)
	GameStateManager.floor_completed.connect(_on_floor_completed)
	GameStateManager.run_ended.connect(_on_run_ended)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
	SpellCastingEffects.chain_index_changed.connect(_on_chain_index_changed)


func _exit_tree() -> void:
	if GameStateManager.run_started.is_connected(_on_run_started):
		GameStateManager.run_started.disconnect(_on_run_started)
	if GameStateManager.wave_ended.is_connected(_on_wave_ended):
		GameStateManager.wave_ended.disconnect(_on_wave_ended)
	if GameStateManager.room_cleared.is_connected(_on_room_cleared):
		GameStateManager.room_cleared.disconnect(_on_room_cleared)
	if GameStateManager.floor_completed.is_connected(_on_floor_completed):
		GameStateManager.floor_completed.disconnect(_on_floor_completed)
	if GameStateManager.run_ended.is_connected(_on_run_ended):
		GameStateManager.run_ended.disconnect(_on_run_ended)
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
	if SpellCastingEffects.chain_index_changed.is_connected(_on_chain_index_changed):
		SpellCastingEffects.chain_index_changed.disconnect(_on_chain_index_changed)

# ── Public API ────────────────────────────────────────────────────────────────

## Seconds on the run clock: live while a run is active, the final time after it ends
## (0.0 before the first run). The same wall clock the Records use (ADR-0046 timer).
func get_elapsed_sec() -> float:
	if _run_active:
		return float(Time.get_ticks_msec() - _run_start_msec) / 1000.0
	return _run_elapsed_sec


## Returns a copy of the current run state dictionary.
##
## Keys:
##   "run_active"      — bool: true if a run is in progress
##   "run_outcome"     — GameEnums.RunOutcome: NONE / WIN / LOSS
##   "waves_completed" — int: number of waves completed this run
##   "rooms_cleared"   — int: number of rooms cleared this run
##   "current_floor"   — int: current floor number (1-based)
##   "enemies_killed"  — int: total enemies defeated this run
##   "best_combo"      — int: highest combo chain index reached this run
##   "run_time_sec"    — float: run duration in seconds (0.0 until run_ended)
##
## The returned Dictionary is a shallow copy — mutating it does not affect
## RunManager's internal state (all values are primitives).
##
## Example:
##   var data: Dictionary = RunManager.get_run_data()
##   if data["run_active"]:
##       show_floor_count(data["current_floor"])
func get_run_data() -> Dictionary:
	return {
		"run_active": _run_active,
		"run_outcome": _run_outcome,
		"waves_completed": _waves_completed,
		"rooms_cleared": _rooms_cleared,
		"current_floor": _current_floor,
		"enemies_killed": _enemies_killed,
		"best_combo": _best_combo,
		"run_time_sec": _run_elapsed_sec,
	}.duplicate()

# ── Signal callbacks ───────────────────────────────────────────────────────────

## Resets all run state when a new run begins.
## push_error() if a run was already active (logic error — run never ended).
func _on_run_started() -> void:
	if _run_active:
		push_error(
			"[RunManager] run_started received while a run is already active. Resetting."
		)
	_run_active = true
	_run_outcome = GameEnums.RunOutcome.NONE
	_waves_completed = 0
	_rooms_cleared = 0
	_current_floor = 1
	_enemies_killed = 0
	_best_combo = 0
	_run_start_msec = Time.get_ticks_msec()
	_run_elapsed_sec = 0.0


## Increments waves_completed on each wave_ended signal.
## push_error() if no run is active (logic error — wave ended outside of a run).
func _on_wave_ended() -> void:
	if not _run_active:
		push_error(
			"[RunManager] wave_ended received while no run is active."
		)
	_waves_completed += 1


## Increments rooms_cleared counter on each room_cleared signal.
## Does NOT set the run outcome — outcome is only set by run_ended.
func _on_room_cleared() -> void:
	_rooms_cleared += 1


## Increments current_floor when a non-final floor's boss is defeated.
func _on_floor_completed() -> void:
	_current_floor += 1


## Finalises the run: sets run_active = false and the definitive outcome.
## WIN when win == true (boss of final floor defeated).
## LOSS when win == false and outcome was not already WIN (guard against WIN→LOSS overwrite).
## push_error() if no run is active when this signal fires.
func _on_run_ended(win: bool) -> void:
	if not _run_active:
		push_error(
			"[RunManager] run_ended received while no run is active."
		)
		return
	_run_active = false
	_run_elapsed_sec = float(Time.get_ticks_msec() - _run_start_msec) / 1000.0
	if win:
		_run_outcome = GameEnums.RunOutcome.WIN
	elif _run_outcome == GameEnums.RunOutcome.NONE:
		_run_outcome = GameEnums.RunOutcome.LOSS


## Increments enemies_killed on each HealthAndDamage.enemy_killed during an active run.
func _on_enemy_killed(_instance_id: int, _type_id: int,
		_prana_affiliation: GameEnums.DamageClass) -> void:
	if _run_active:
		_enemies_killed += 1


## Tracks the highest combo chain index reached this run.
func _on_chain_index_changed(combo_index: int, _combo_attack_count: int) -> void:
	if _run_active and combo_index > _best_combo:
		_best_combo = combo_index
