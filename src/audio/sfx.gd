## Sfx — one-line, null-safe access to AudioSystem for gameplay nodes.
##
## Sfx.play(&"sfx_bullet_fire") plays a registered event and silently does nothing
## when the AudioSystem autoload is missing (headless tests) or the event is not in
## the registry yet. Throttling and pitch jitter live in AudioEventData, so callers
## can fire as often as the gameplay does without flooding the SFX pool.
class_name Sfx
extends RefCounted

## Optional override used by tests: an object with has_event()/play_event().
static var audio_override: Object = null


## Plays [param event_name] through AudioSystem when it is available and registered.
static func play(event_name: StringName) -> void:
	var audio: Object = _audio()
	if audio != null and audio.has_event(event_name):
		audio.play_event(event_name)


static func _audio() -> Object:
	if audio_override != null:
		return audio_override
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	return loop.root.get_node_or_null(^"AudioSystem")
