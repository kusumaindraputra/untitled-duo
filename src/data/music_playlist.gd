## MusicPlaylist — which music cue plays on each screen and floor (ADR-0049).
##
## Authored as assets/data/music_playlist.tres and read by AudioSystem through a
## preload const. Every entry is an event name from audio_event_registry.tres, so
## swapping a track (for example a hand-made or ElevenLabs version) is a data edit:
## register the new file in the registry and point the matching field here at it.
class_name MusicPlaylist
extends Resource

## Title screen and main menu loop (MAIN_MENU state). Empty = silent menu.
@export var menu_cue: StringName = &"mus_title"

## Preparation loop between rooms (PREPARATION state).
@export var preparation_cue: StringName = &"mus_preparation"

## Default combat loop per floor: index 0 is floor 1. A floor past the end of the
## list reuses the last entry, so a longer run never falls silent.
@export var floor_combat_cues: Array[StringName] = [
	&"mus_combat_floor", &"mus_combat_floor2", &"mus_combat_floor3",
]

## Cue played when a run is won (END_VICTORY). This is the ending track; it plays
## once and AudioSystem returns to [member menu_cue] when it finishes.
@export var victory_cue: StringName = &"mus_ending"

## Cue played when a run is lost (END_DEFEAT). Plays once, then back to the menu.
@export var defeat_cue: StringName = &"sfx_run_lose"


## Returns the default combat cue for 1-based [param floor_number]. Floors below 1
## count as floor 1; floors past the list reuse the last entry. Empty list → &"".
func combat_cue_for_floor(floor_number: int) -> StringName:
	if floor_combat_cues.is_empty():
		return &""
	var idx: int = clampi(floor_number - 1, 0, floor_combat_cues.size() - 1)
	return floor_combat_cues[idx]
