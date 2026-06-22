## PranaLoadout — persistent 9-slot Prana build carried across rooms in a run.
##
## The PranaGrid lives inside each IsometricRoom and is rebuilt on every room
## transition, so it cannot itself hold the run's build. PranaLoadout is a single
## run-scoped node (created by the game loop, registered in the "prana_loadout"
## group) that survives transitions: the grid restores its slots from here on each
## preparation phase and saves them back on confirm.
##
## Slots are a flat Array of length 9 — null = empty, int = Prana type_id. Index 4
## is the centre (primary) slot.
class_name PranaLoadout
extends Node

## Number of grid slots (3×3). Mirrors PranaGrid.GRID_SIZE.
const SLOT_COUNT: int = 9
## Centre slot index — the primary/core slot.
const CORE_SLOT: int = 4

## Emitted whenever the build changes (seed/save/clear). Carries a copy of slots.
signal loadout_changed(slots: Array)

## Persistent build. null entries are empty slots; ints are Prana type_ids.
var _slots: Array = []


func _ready() -> void:
	add_to_group(&"prana_loadout")
	if _slots.is_empty():
		_slots.resize(SLOT_COUNT)
		_slots.fill(null)


## Returns a copy of the current build (length SLOT_COUNT).
func get_slots() -> Array:
	if _slots.is_empty():
		_slots.resize(SLOT_COUNT)
		_slots.fill(null)
	return _slots.duplicate()


## Replaces the whole build from [param slots] (copied, length-normalised to SLOT_COUNT).
func set_slots(slots: Array) -> void:
	_slots = slots.duplicate()
	_slots.resize(SLOT_COUNT)
	loadout_changed.emit(_slots.duplicate())


## Empties the build and seeds the core Prana [param type_id] into the centre slot.
## Used at run start from the "choose your core" screen.
func seed_core(type_id: int) -> void:
	_slots.resize(SLOT_COUNT)
	_slots.fill(null)
	_slots[CORE_SLOT] = type_id
	loadout_changed.emit(_slots.duplicate())


## Number of filled (non-null) slots.
func filled_count() -> int:
	var n: int = 0
	for v in _slots:
		if v != null:
			n += 1
	return n


## True when every slot is filled.
func is_full() -> bool:
	return filled_count() >= SLOT_COUNT


## Returns the index of the first empty slot, or -1 if the build is full.
func first_empty_slot() -> int:
	for i in SLOT_COUNT:
		if _slots[i] == null:
			return i
	return -1


## Clears the build to all-empty.
func clear() -> void:
	_slots.resize(SLOT_COUNT)
	_slots.fill(null)
	loadout_changed.emit(_slots.duplicate())
