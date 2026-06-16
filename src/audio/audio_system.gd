## audio_system.gd — AudioSystem Autoload #5.
## Sole audio service for all gameplay systems (ADR-0012).
##
## S7-06 skeleton: 4-bus init + play_event() stub.
## Full implementation (SFX pool, music state machine, AudioEventRegistry)
## deferred to the audio implementation sprint.
##
## Registration: Autoload #5 in project.godot (after SceneManager at #4).
## No class_name — Godot 4.6 rejects class_name matching the Autoload node name.
## Access: AudioSystem.play_event(&"event_name")
##
## ADR: ADR-0012 (AudioSystem Implementation Contract)
extends Node


## Bus name constants — sole definitions in the project. No other file may define
## these bus names independently (ADR-0012 Forbidden Patterns).
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUS_AMB: StringName = &"AMB"


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not is_instance_valid(GameStateManager):
		push_error("AudioSystem: GameStateManager must be initialized before AudioSystem (ADR-0012).")
		return
	_init_buses()


# ── Bus setup ─────────────────────────────────────────────────────────────────

## Ensures the 4 buses (Music, SFX, UI, AMB) exist under Master.
## Idempotent — safe to call if buses were pre-configured in the bus layout file.
## New buses route to Master by default (Godot 4 AudioServer behavior).
func _init_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX, BUS_UI, BUS_AMB]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)


# ── Public API (stubs) ────────────────────────────────────────────────────────

## Routes [param event_id] to the correct player via AudioEventRegistry.
## Stub — full dispatch pending AudioEventRegistry implementation.
## [param event_id] StringName key into AudioEventRegistry.
func play_event(event_id: StringName) -> void:
	push_error("AudioSystem.play_event: registry not yet implemented — event '%s' ignored." % event_id)
