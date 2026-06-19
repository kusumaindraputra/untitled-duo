## RoomExitDoor — exit trigger placed in dungeon rooms (LD-20).
##
## Area2D that detects when Fayde enters, then signals RoomTransitionManager
## to begin a room transition. Locked until the room is cleared (all enemies defeated).
##
## Each door carries its destination_room_idx (set by RoomTransitionManager._wire_exit_doors())
## and the destination room type (for display). Multiple doors exist at branch points.
##
## Usage:
##   # Set by RoomTransitionManager after scene load:
##   door.destination_idx = 3
##   door.set_destination_type(DungeonGraph.ROOM_TYPE_ELITE)
##
## GDD:  design/room-connection-model.md (LD-09 § Door UX)
## Roadmap: design/level-design-roadmap.md (LD-20)
class_name RoomExitDoor
extends Area2D

## Must match PlayerController.COLLISION_LAYER_PLAYER — no global constant exists yet.
const _PLAYER_LAYER: int = 2

## Emitted when an unlocked door is entered by the player.
signal player_entered(destination_idx: int)

## Room index in DungeonGraph this door leads to. Set by RoomTransitionManager.
var destination_idx: int = -1

## Room type of the destination (Combat/Elite/Rest/Boss). Drives visual label.
var destination_type: int = DungeonGraph.ROOM_TYPE_COMBAT

## True until room_cleared signal is received.
var _locked: bool = true

@onready var _label: Label = $Label if has_node("Label") else null


func _ready() -> void:
	collision_mask = _PLAYER_LAYER  # detect CharacterBody2D on player physics layer
	body_entered.connect(_on_body_entered)
	monitoring = false   # locked at spawn — wait for room_cleared
	if GameStateManager != null:
		GameStateManager.room_cleared.connect(_on_room_cleared)


func _exit_tree() -> void:
	if GameStateManager != null \
			and GameStateManager.room_cleared.is_connected(_on_room_cleared):
		GameStateManager.room_cleared.disconnect(_on_room_cleared)


# ── Public API ─────────────────────────────────────────────────────────────────

## Sets the destination room type and updates the door label.
func set_destination_type(type: int) -> void:
	destination_type = type
	_update_label()


# ── Private ────────────────────────────────────────────────────────────────────

func _on_room_cleared() -> void:
	_locked = false
	monitoring = true
	_update_label()


func _on_body_entered(body: Node2D) -> void:
	if _locked or destination_idx < 0:
		return
	if body.is_in_group(&"player"):
		player_entered.emit(destination_idx)


func _update_label() -> void:
	if _label == null:
		return
	var type_names: Array[String] = ["⚔ Combat", "💀 Elite", "♥ Rest", "👑 Boss"]
	var lock_str: String = " [LOCKED]" if _locked else ""
	_label.text = type_names[destination_type] + lock_str if destination_type < type_names.size() else "?"
