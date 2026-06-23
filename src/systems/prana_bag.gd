## PranaBag — transient pool of Prana acquired from post-room rewards, awaiting placement.
##
## The grid-as-build model (Prana drop redesign #3) makes Prana acquisition choice-only:
## clearing a room offers reward cards, and picking a Prana card drops one fragment into
## this bag. During the NEXT preparation phase the player places bag fragments into empty
## grid slots; any fragment left in the bag on confirm is discarded (the bag is transient).
##
## Unlike PranaLoadout (the persistent 9-slot build), the bag holds only the Prana waiting
## to be placed — an ordered Array of type_ids (duplicates allowed, since two of the same
## type can be acquired). Created programmatically by debug_game_loop (no Autoload) and
## registered in the "prana_bag" group so SigilManager (writer) and PranaGrid (reader)
## find it without a hard reference. Resets on run_started.
class_name PranaBag
extends Node

## Emitted whenever the bag contents change (add / remove / clear). Carries a copy
## of the current items so listeners (the prep tray) can rebuild without re-querying.
signal bag_changed(items: Array)

## Ordered Prana type_ids awaiting placement. Duplicates allowed.
var _items: Array[int] = []


func _ready() -> void:
	add_to_group(&"prana_bag")
	GameStateManager.run_started.connect(_on_run_started)


func _exit_tree() -> void:
	if GameStateManager.run_started.is_connected(_on_run_started):
		GameStateManager.run_started.disconnect(_on_run_started)


## Appends [param type_id] to the bag and emits bag_changed.
func add(type_id: int) -> void:
	_items.append(type_id)
	bag_changed.emit(_items.duplicate())


## Removes the first occurrence of [param type_id]. Returns true if one was removed,
## false if the bag held none of that type. Emits bag_changed only on success.
func remove_one(type_id: int) -> bool:
	var idx: int = _items.find(type_id)
	if idx == -1:
		return false
	_items.remove_at(idx)
	bag_changed.emit(_items.duplicate())
	return true


## Returns a copy of the current bag contents (ordered type_ids).
func get_items() -> Array[int]:
	return _items.duplicate()


## Number of fragments currently in the bag.
func size() -> int:
	return _items.size()


## True when the bag holds no fragments.
func is_empty() -> bool:
	return _items.is_empty()


## True when the bag holds at least one fragment of [param type_id].
func has_type(type_id: int) -> bool:
	return _items.has(type_id)


## Empties the bag and emits bag_changed. Called on run_started and on prep confirm
## (un-placed fragments are discarded — the bag is transient).
func clear() -> void:
	_items.clear()
	bag_changed.emit(_items.duplicate())


func _on_run_started() -> void:
	clear()
