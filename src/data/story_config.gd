## StoryConfig — the memory-fragment story and its unlock rules (ADR-0027).
##
## Authored as assets/data/story/story_config.tres. Fragments unlock strictly in
## [member fragments] order, one per story beat, so every player reads the same
## story in the same order whatever their runs look like.
##
## Design: design/gdd/memory-fragments.md
class_name StoryConfig
extends Resource

## The story, in the order it is recovered.
@export var fragments: Array[MemoryFragment] = []

## Ending shown after the final boss when some fragments are still missing.
@export var ending_partial: MemoryFragment = null

## Ending shown after the final boss once every fragment has been recovered.
@export var ending_true: MemoryFragment = null

@export_group("Unlock rules")

## Clearing a floor (its boss falls, not the last floor) recovers the next fragment.
@export var unlock_on_floor_clear: bool = true

## Dying recovers the next fragment, if the run cleared at least
## [member death_unlock_min_rooms] rooms (so an instant death is not a shortcut).
@export var unlock_on_death: bool = true

## Rooms a run must clear before its death recovers a fragment.
@export_range(0, 50) var death_unlock_min_rooms: int = 3

## Winning the run also recovers the next fragment before the ending plays.
@export var unlock_on_win: bool = true

## The run must reach this floor for a win to play an ending. The one-floor demo
## scene wins on floor 1 and gets a floor-clear fragment instead.
@export_range(1, 10) var ending_min_floor: int = 3
