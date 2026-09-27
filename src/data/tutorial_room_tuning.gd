## TutorialRoomTuning — data-driven values for the guided first room (ADR-0055).
##
## Authored as assets/data/tutorial_room_tuning.tres and read by TutorialRoom through
## a preload const, so the lesson can be retuned without touching code.
class_name TutorialRoomTuning
extends Resource

@export_group("Grid")

## Prana of the core's type dropped in the bag for the "place" lesson.
@export var bag_prana: int = 2

@export_group("Moves")

## World px Fayde must travel before "move" ticks (a nudge is not enough).
@export var move_distance: float = 120.0

@export_group("Targets")

## Training targets spawned when the fight starts.
@export var target_count: int = 2
## Targets never spawn closer to Fayde than this, in world px.
@export var target_min_distance: float = 90.0
## Target HP as a multiple of the dummy's catalog HP, so a first cast rarely kills.
@export var target_hp_mult: float = 4.0
## Seconds before a destroyed target comes back while the lesson runs.
@export var target_respawn_sec: float = 1.2

@export_group("Perfect Dodge")

## Ideal distance from Fayde to the shot pylon, in world px.
@export var turret_distance: float = 150.0
## Seconds between shots while the Perfect Dodge lesson is on screen.
@export var shot_interval_sec: float = 1.8
## Seconds the pylon glows before each shot.
@export var shot_telegraph_sec: float = 0.55
## Shot speed in px/s; slower than real bullets so the timing is learnable.
@export var shot_speed: float = 120.0
## Shot radius in px.
@export var shot_radius: float = 6.0
## After this many shots the lesson ticks on its own (Assist auto-dash earns no
## Perfect Dodge, so the room must never soft-lock).
@export var dodge_fallback_shots: int = 12

@export_group("Flow")

## Seconds the skip action must be held.
@export var skip_hold_sec: float = 1.0
## Seconds a ticked lesson keeps its check before the next one shows.
@export var tick_hold_sec: float = 0.8
## Seconds the "training complete" line stays before the real wave arrives.
@export var done_hold_sec: float = 1.6
