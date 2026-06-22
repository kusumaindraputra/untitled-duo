## PranaInventory — run-scoped pool of Prana collected from enemy drops.
##
## Holds a count per Prana type id (0–4). PranaDrop collectibles call add() on
## pickup; the HUD listens to prana_collected to render counters. Resets on
## run_started so each run starts empty.
##
## Created programmatically by debug_game_loop (no Autoload / project.godot edit)
## and registered in the "prana_inventory" group so PranaDrop can find it without a
## hard reference. Display only at this stage — nothing consumes the pool yet
## (grid gating is a later step).
class_name PranaInventory
extends Node

## Emitted after a pickup. [param type_id] is the Prana type collected,
## [param new_count] its running total. Drives the HUD counter.
signal prana_collected(type_id: int, new_count: int)

## type_id -> collected count. Absent key means zero.
var _counts: Dictionary[int, int] = {}


func _ready() -> void:
	add_to_group(&"prana_inventory")
	GameStateManager.run_started.connect(_on_run_started)


func _exit_tree() -> void:
	if GameStateManager.run_started.is_connected(_on_run_started):
		GameStateManager.run_started.disconnect(_on_run_started)


## Adds [param amount] of [param type_id] to the pool and emits prana_collected.
func add(type_id: int, amount: int = 1) -> void:
	_counts[type_id] = get_count(type_id) + amount
	prana_collected.emit(type_id, _counts[type_id])


## Returns the collected count for [param type_id] (0 if none).
func get_count(type_id: int) -> int:
	return _counts.get(type_id, 0)


## Returns the total Prana collected across all types.
func get_total() -> int:
	var total: int = 0
	for c: int in _counts.values():
		total += c
	return total


## Returns a copy of the full type_id -> count map.
func get_counts() -> Dictionary:
	return _counts.duplicate()


## Clears the pool. Caller-facing for tests; also runs on run_started.
func reset() -> void:
	_counts.clear()


func _on_run_started() -> void:
	reset()
