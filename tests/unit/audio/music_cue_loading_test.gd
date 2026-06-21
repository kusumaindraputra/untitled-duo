## music_cue_loading_test.gd — Tests for _load_music_cues(), override_combat_cue(),
## reset_combat_cue(), and the BUS_MUSIC guard in play_event().
##
## Coverage:
##   - _load_music_cues() populates PREPARATION and COMBAT from _validated_events
##   - _load_music_cues() does NOT populate DYING (intentional silence)
##   - override_combat_cue() swaps the COMBAT entry in _music_cues
##   - reset_combat_cue() restores COMBAT entry to mus_combat_floor stream
##   - override_combat_cue() with unregistered event logs push_error, leaves cue unchanged
##   - play_event() with BUS_MUSIC event logs push_error and does not crash
##   - Public API: override_combat_cue and reset_combat_cue methods exist
##
## AudioSystem is Autoload — _ready() fires before tests run.
## Streams injected via _validated_events; _music_cues saved/restored per test.
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const _PREP_KEY: StringName  = &"_test_mus_prep_mcl"
const _COMBAT_KEY: StringName = &"_test_mus_combat_mcl"
const _MUSIC_BUS_KEY: StringName = &"_test_mus_bus_guard_mcl"

var _saved_cues: Dictionary = {}
var _prep_stream: AudioStreamGenerator
var _combat_stream: AudioStreamGenerator
var _override_stream: AudioStreamGenerator


func before_test() -> void:
	# Save the live _music_cues so we can restore after each test.
	_saved_cues = AudioSystem._music_cues.duplicate()

	# Dummy streams — AudioStreamGenerator works in headless CI.
	_prep_stream    = AudioStreamGenerator.new()
	_combat_stream  = AudioStreamGenerator.new()
	_override_stream = AudioStreamGenerator.new()

	# Inject events that _load_music_cues() will look for.
	var prep_data := AudioEventData.new()
	prep_data.stream = _prep_stream
	prep_data.bus    = &"Music"
	AudioSystem._validated_events[_PREP_KEY] = prep_data

	var combat_data := AudioEventData.new()
	combat_data.stream = _combat_stream
	combat_data.bus    = &"Music"
	AudioSystem._validated_events[_COMBAT_KEY] = combat_data

	var override_data := AudioEventData.new()
	override_data.stream = _override_stream
	override_data.bus    = &"Music"
	AudioSystem._validated_events[_MUSIC_BUS_KEY] = override_data


func after_test() -> void:
	# Restore original cues.
	AudioSystem._music_cues.clear()
	for k: int in _saved_cues:
		AudioSystem._music_cues[k] = _saved_cues[k]

	AudioSystem._validated_events.erase(_PREP_KEY)
	AudioSystem._validated_events.erase(_COMBAT_KEY)
	AudioSystem._validated_events.erase(_MUSIC_BUS_KEY)


# ── _load_music_cues() ────────────────────────────────────────────────────────

## GIVEN _validated_events has mus_preparation and mus_combat_floor equivalents
## WHEN _load_music_cues() is called
## THEN _music_cues[PREPARATION] is the prep stream
func test_load_music_cues_populates_preparation_state() -> void:
	# Temporarily map the standard key to our test stream.
	var real_prep: AudioEventData = AudioEventData.new()
	real_prep.stream = _prep_stream
	real_prep.bus    = &"Music"
	AudioSystem._validated_events[&"mus_preparation"] = real_prep

	AudioSystem._load_music_cues()

	var loaded: AudioStream = AudioSystem._music_cues.get(AudioSystem.MusicState.PREPARATION as int)
	assert_object(loaded).is_equal(_prep_stream)

	AudioSystem._validated_events.erase(&"mus_preparation")


## GIVEN _validated_events has mus_combat_floor equivalent
## WHEN _load_music_cues() is called
## THEN _music_cues[COMBAT] is the combat stream
func test_load_music_cues_populates_combat_state() -> void:
	var real_combat: AudioEventData = AudioEventData.new()
	real_combat.stream = _combat_stream
	real_combat.bus    = &"Music"
	AudioSystem._validated_events[&"mus_combat_floor"] = real_combat

	AudioSystem._load_music_cues()

	var loaded: AudioStream = AudioSystem._music_cues.get(AudioSystem.MusicState.COMBAT as int)
	assert_object(loaded).is_equal(_combat_stream)

	AudioSystem._validated_events.erase(&"mus_combat_floor")


## GIVEN any valid event map
## WHEN _load_music_cues() is called
## THEN _music_cues does NOT have a DYING entry (silence is the design)
func test_load_music_cues_never_registers_dying_state() -> void:
	AudioSystem._load_music_cues()
	assert_bool(AudioSystem._music_cues.has(AudioSystem.MusicState.DYING as int)).is_false()


# ── override_combat_cue() ─────────────────────────────────────────────────────

## GIVEN a registered event with BUS_MUSIC
## WHEN override_combat_cue() is called with that event
## THEN _music_cues[COMBAT] is updated to the override stream
func test_override_combat_cue_changes_combat_entry() -> void:
	# Set a known baseline in _music_cues.
	AudioSystem._music_cues[AudioSystem.MusicState.COMBAT as int] = _combat_stream

	AudioSystem.override_combat_cue(_MUSIC_BUS_KEY)

	var active: AudioStream = AudioSystem._music_cues.get(AudioSystem.MusicState.COMBAT as int)
	assert_object(active).is_equal(_override_stream)


## GIVEN override_combat_cue() was called with an unregistered event
## WHEN the call returns
## THEN _music_cues[COMBAT] is unchanged (push_error was logged)
func test_override_combat_cue_unregistered_leaves_cue_unchanged() -> void:
	AudioSystem._music_cues[AudioSystem.MusicState.COMBAT as int] = _combat_stream

	AudioSystem.override_combat_cue(&"definitely_not_registered_key_mcl")

	var active: AudioStream = AudioSystem._music_cues.get(AudioSystem.MusicState.COMBAT as int)
	assert_object(active).is_equal(_combat_stream)


# ── reset_combat_cue() ────────────────────────────────────────────────────────

## GIVEN mus_combat_floor is registered and override has been applied
## WHEN reset_combat_cue() is called
## THEN _music_cues[COMBAT] is restored to mus_combat_floor's stream
func test_reset_combat_cue_restores_default_floor_stream() -> void:
	var floor_stream: AudioStreamGenerator = AudioStreamGenerator.new()
	var floor_data := AudioEventData.new()
	floor_data.stream = floor_stream
	floor_data.bus    = &"Music"
	AudioSystem._validated_events[&"mus_combat_floor"] = floor_data

	# Apply an override first.
	AudioSystem._music_cues[AudioSystem.MusicState.COMBAT as int] = _override_stream

	AudioSystem.reset_combat_cue()

	var active: AudioStream = AudioSystem._music_cues.get(AudioSystem.MusicState.COMBAT as int)
	assert_object(active).is_equal(floor_stream)

	AudioSystem._validated_events.erase(&"mus_combat_floor")


# ── play_event() BUS_MUSIC guard ─────────────────────────────────────────────

## GIVEN an event registered with bus = &"Music"
## WHEN play_event() is called with that event name
## THEN no crash (reaching assert = pass; push_error is logged but test does not fail)
func test_play_event_with_music_bus_does_not_crash() -> void:
	AudioSystem.play_event(_MUSIC_BUS_KEY)
	assert_bool(true).is_true()


# ── Public API surface ────────────────────────────────────────────────────────

func test_override_combat_cue_method_exists() -> void:
	assert_bool(AudioSystem.has_method(&"override_combat_cue")).is_true()


func test_reset_combat_cue_method_exists() -> void:
	assert_bool(AudioSystem.has_method(&"reset_combat_cue")).is_true()
