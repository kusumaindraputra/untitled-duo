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

# ── Built-in ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.run_started.connect(_on_run_started)
	GameStateManager.wave_ended.connect(_on_wave_ended)
	GameStateManager.room_cleared.connect(_on_room_cleared)
	GameStateManager.run_ended.connect(_on_run_ended)


func _exit_tree() -> void:
	if GameStateManager.run_started.is_connected(_on_run_started):
		GameStateManager.run_started.disconnect(_on_run_started)
	if GameStateManager.wave_ended.is_connected(_on_wave_ended):
		GameStateManager.wave_ended.disconnect(_on_wave_ended)
	if GameStateManager.room_cleared.is_connected(_on_room_cleared):
		GameStateManager.room_cleared.disconnect(_on_room_cleared)
	if GameStateManager.run_ended.is_connected(_on_run_ended):
		GameStateManager.run_ended.disconnect(_on_run_ended)

# ── Public API ────────────────────────────────────────────────────────────────

## Returns a copy of the current run state dictionary.
##
## Keys:
##   "run_active"      — bool: true if a run is in progress
##   "run_outcome"     — GameEnums.RunOutcome: NONE / WIN / LOSS
##   "waves_completed" — int: number of waves completed this run
##
## The returned Dictionary is a shallow copy — mutating it does not affect
## RunManager's internal state (all values are primitives).
##
## Example:
##   var data: Dictionary = RunManager.get_run_data()
##   if data["run_active"]:
##       show_wave_count(data["waves_completed"])
func get_run_data() -> Dictionary:
	return {
		"run_active": _run_active,
		"run_outcome": _run_outcome,
		"waves_completed": _waves_completed,
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


## Increments waves_completed on each wave_ended signal.
## push_error() if no run is active (logic error — wave ended outside of a run).
func _on_wave_ended() -> void:
	if not _run_active:
		push_error(
			"[RunManager] wave_ended received while no run is active."
		)
	_waves_completed += 1


## Sets run_outcome to WIN when the room is cleared.
## Idempotent — repeated calls while already WIN are silent no-ops.
func _on_room_cleared() -> void:
	_run_outcome = GameEnums.RunOutcome.WIN


## Finalises the run: sets run_active = false and conditionally sets LOSS.
## Rule 7: only sets LOSS when win == false AND _run_outcome == NONE.
## Wins (room_cleared) are never overwritten.
## push_error() if no run is active when this signal fires.
func _on_run_ended(win: bool) -> void:
	if not _run_active:
		push_error(
			"[RunManager] run_ended received while no run is active."
		)
		return
	_run_active = false
	if not win and _run_outcome == GameEnums.RunOutcome.NONE:
		_run_outcome = GameEnums.RunOutcome.LOSS
