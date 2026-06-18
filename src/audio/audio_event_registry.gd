## audio_event_registry.gd — Serialised catalog of all AudioEventData resources.
## Loaded from res://assets/data/audio_event_registry.tres at AudioSystem startup (ADR-0012).
## Populated by the audio-director via the Godot editor. No hardcoded event data in GDScript.
##
## Callers who build dynamic event keys from variables must wrap in StringName(variable) —
## bare String keys do not match StringName entries in a typed Dictionary[StringName, ...].
class_name AudioEventRegistry
extends Resource

## All audio events keyed by StringName event ID.
@export var events: Dictionary[StringName, AudioEventData]
