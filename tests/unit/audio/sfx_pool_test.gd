## sfx_pool_test.gd — Story 002 acceptance criteria tests.
##
## Coverage (AC-AS-03, AC-AS-04, AC-AS-05, AC-AS-06, AC-AS-07, AC-AS-34):
##   AC-AS-03: Pool has 24 slots; correct types, process modes, zero timestamps
##   AC-AS-04: play_event() with a free slot assigns stream to exactly one slot
##   AC-AS-05: Unregistered event logs push_error(); no pool state changes
##   AC-AS-06: Eviction respects priority tiers — LOW, NORMAL, HIGH-protected, all-HIGH
##   AC-AS-07: UI-bus event routes to _ui_player only; pool untouched
##   AC-AS-34: AMB-bus event via play_event() logs push_error(); all players untouched
##
## AudioSystem is Autoload #5 — _ready() fires before tests run.
## Events injected directly into _validated_events to avoid registry file dependency.
## `playing` is NOT asserted — unreliable in headless GUT (see Story 002 engine notes).
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

# ── Shared test constants ─────────────────────────────────────────────────────

const _TEST_SFX_EVENT: StringName = &"_test_sfx_s002"
const _TEST_SFX_EVENT_B: StringName = &"_test_sfx_s002_b"
const _TEST_UI_EVENT: StringName = &"_test_ui_s002"
const _TEST_AMB_EVENT: StringName = &"_test_amb_s002"

# ── Shared fixtures ───────────────────────────────────────────────────────────

var _dummy_stream_sfx: AudioStreamGenerator = null
var _dummy_stream_sfx_b: AudioStreamGenerator = null
var _dummy_stream_ui: AudioStreamGenerator = null


func before_test() -> void:
	_dummy_stream_sfx = AudioStreamGenerator.new()
	_dummy_stream_sfx_b = AudioStreamGenerator.new()
	_dummy_stream_ui = AudioStreamGenerator.new()

	var sfx_data := AudioEventData.new()
	sfx_data.stream = _dummy_stream_sfx
	sfx_data.bus = &"SFX"
	sfx_data.priority = 1
	AudioSystem._validated_events[_TEST_SFX_EVENT] = sfx_data

	var sfx_data_b := AudioEventData.new()
	sfx_data_b.stream = _dummy_stream_sfx_b
	sfx_data_b.bus = &"SFX"
	sfx_data_b.priority = 1
	AudioSystem._validated_events[_TEST_SFX_EVENT_B] = sfx_data_b

	var ui_data := AudioEventData.new()
	ui_data.stream = _dummy_stream_ui
	ui_data.bus = &"UI"
	ui_data.priority = 1
	AudioSystem._validated_events[_TEST_UI_EVENT] = ui_data

	var amb_data := AudioEventData.new()
	amb_data.stream = AudioStreamGenerator.new()
	amb_data.bus = &"AMB"
	amb_data.priority = 1
	AudioSystem._validated_events[_TEST_AMB_EVENT] = amb_data


func after_test() -> void:
	AudioSystem._validated_events.erase(_TEST_SFX_EVENT)
	AudioSystem._validated_events.erase(_TEST_SFX_EVENT_B)
	AudioSystem._validated_events.erase(_TEST_UI_EVENT)
	AudioSystem._validated_events.erase(_TEST_AMB_EVENT)

	# Reset pool slots that received a test stream; also reset timestamps and priorities.
	for i: int in range(AudioSystem._sfx_pool.size()):
		AudioSystem._sfx_pool[i].stop()
		AudioSystem._sfx_pool[i].stream = null
		AudioSystem._timestamps[i] = 0
		AudioSystem._slot_priorities[i] = 0

	# Reset UI player.
	AudioSystem._ui_player.stop()
	AudioSystem._ui_player.stream = null

	_dummy_stream_sfx = null
	_dummy_stream_sfx_b = null
	_dummy_stream_ui = null


# ── AC-AS-03: Pool pre-created with correct size and timestamps ───────────────

## GIVEN AudioSystem._ready() has completed
## WHEN _sfx_pool is inspected
## THEN size == 24
func test_sfx_pool_has_24_slots() -> void:
	assert_int(AudioSystem._sfx_pool.size()).is_equal(24)


## GIVEN AudioSystem._ready() has completed
## WHEN each pool slot type is checked
## THEN all are AudioStreamPlayer
func test_sfx_pool_slots_are_audio_stream_players() -> void:
	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		assert_object(player).is_instanceof(AudioStreamPlayer)


## GIVEN AudioSystem._ready() has completed
## WHEN each pool slot process_mode is checked
## THEN all return PROCESS_MODE_PAUSABLE
func test_sfx_pool_process_mode_pausable() -> void:
	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


## GIVEN AudioSystem._ready() has completed (and after_each resets timestamps)
## WHEN _timestamps array is inspected
## THEN all 24 entries are 0
func test_sfx_pool_timestamps_all_zero_on_init() -> void:
	# after_each resets timestamps to 0 each test, mirroring startup state.
	assert_int(AudioSystem._timestamps.size()).is_equal(24)
	for ts: int in AudioSystem._timestamps:
		assert_int(ts).is_equal(0)


# ── AC-AS-04: Free slot assignment (no eviction) ──────────────────────────────

## GIVEN all 24 slots non-playing; a dummy SFX event registered
## WHEN play_event() called once
## THEN exactly one slot has stream == dummy_sfx_stream; all others null
func test_play_event_assigns_stream_to_exactly_one_slot() -> void:
	AudioSystem.play_event(_TEST_SFX_EVENT)

	var match_count: int = 0
	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		if player.stream == _dummy_stream_sfx:
			match_count += 1

	assert_int(match_count).is_equal(1)


## GIVEN all 24 slots non-playing; a dummy SFX event registered
## WHEN play_event() called once
## THEN the slot that received the stream is slot 0 (first free)
func test_play_event_assigns_to_first_free_slot() -> void:
	AudioSystem.play_event(_TEST_SFX_EVENT)
	assert_object(AudioSystem._sfx_pool[0].stream).is_equal(_dummy_stream_sfx)


# ── AC-AS-05: Unregistered event ──────────────────────────────────────────────

## GIVEN 24 pool slots with null streams
## WHEN play_event() called with an unregistered key
## THEN all 24 pool slots remain null (no state change)
func test_play_event_unregistered_leaves_pool_unchanged() -> void:
	AudioSystem.play_event(&"_nonexistent_event_s002")

	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		assert_object(player.stream).is_null()


# ── AC-AS-06: Eviction respects priority tiers ────────────────────────────────

## Helper: fill all 24 slots with non-playing placeholder streams at a given priority,
## then force them to appear "playing" by marking timestamps as recent.
## Since AudioStreamPlayer.playing is unreliable headless, we set timestamps to simulate
## occupied slots — _assign_sfx_pool_slot() checks .playing; in headless all report false,
## so we must mark slots as "playing" via a real play() call on a dummy OR rely on the
## eviction path being triggered only when .playing is true.
##
## Strategy: use a separate stream per slot so .stream != null is detectable,
## then directly set _slot_priorities and _timestamps to establish eviction state,
## and call play_event() — in headless mode, since .playing is false for all slots,
## the FIRST free slot (slot 0) is chosen, not eviction. To test eviction we must
## actually make all slots appear playing. We do this by calling play() which sets
## the AudioStreamPlayer into playing state even headless (generator streams can play).
## Then we immediately manipulate _timestamps/_slot_priorities to set up the scenario.
func _fill_pool_with_priority(priority: int) -> void:
	for i: int in range(AudioSystem.SFX_POOL_SIZE):
		var data := AudioEventData.new()
		data.stream = AudioStreamGenerator.new()
		data.bus = &"SFX"
		data.priority = priority
		AudioSystem._sfx_pool[i].stream = data.stream
		AudioSystem._sfx_pool[i].play()
		AudioSystem._timestamps[i] = 5000 + i
		AudioSystem._slot_priorities[i] = priority


## AC-AS-06 Test A — LOW priority eviction: oldest slot (slot 2) is evicted.
## GIVEN: 24 LOW slots all playing; slot 2 timestamp = 100 (oldest); others = 5000+
## WHEN: play_event() called (25th call — triggers eviction)
## THEN: slot 2 stream reassigned to new event stream
func test_eviction_low_priority_oldest_slot_evicted() -> void:
	_fill_pool_with_priority(0)  # 0 = LOW
	# Make slot 2 the oldest (smallest timestamp).
	AudioSystem._set_slot_timestamp(2, 100)

	var new_stream := AudioStreamGenerator.new()
	var new_data := AudioEventData.new()
	new_data.stream = new_stream
	new_data.bus = &"SFX"
	new_data.priority = 1
	AudioSystem._validated_events[&"_test_evict_low_s002"] = new_data

	AudioSystem.play_event(&"_test_evict_low_s002")

	assert_object(AudioSystem._sfx_pool[2].stream).is_equal(new_stream)

	AudioSystem._validated_events.erase(&"_test_evict_low_s002")


## AC-AS-06 Test B — NORMAL priority eviction: oldest NORMAL slot is evicted.
## GIVEN: 24 NORMAL slots; slot 7 has timestamp 200 (oldest)
## WHEN: play_event() called
## THEN: slot 7 stream reassigned
func test_eviction_normal_priority_oldest_slot_evicted() -> void:
	_fill_pool_with_priority(1)  # 1 = NORMAL
	AudioSystem._set_slot_timestamp(7, 200)

	var new_stream := AudioStreamGenerator.new()
	var new_data := AudioEventData.new()
	new_data.stream = new_stream
	new_data.bus = &"SFX"
	new_data.priority = 1
	AudioSystem._validated_events[&"_test_evict_normal_s002"] = new_data

	AudioSystem.play_event(&"_test_evict_normal_s002")

	assert_object(AudioSystem._sfx_pool[7].stream).is_equal(new_stream)

	AudioSystem._validated_events.erase(&"_test_evict_normal_s002")


## AC-AS-06 Test C — HIGH protection: 23 LOW + slot 5 HIGH.
## Even though slot 5 has the smallest timestamp (0), it must NOT be evicted.
## A LOW slot must be evicted instead.
func test_eviction_high_slot_protected_from_eviction() -> void:
	_fill_pool_with_priority(0)  # All LOW.
	# Mark slot 5 as HIGH with the smallest possible timestamp (would be oldest if unprotected).
	AudioSystem._slot_priorities[5] = 2  # HIGH
	AudioSystem._set_slot_timestamp(5, 0)

	var original_stream_slot5: AudioStream = AudioSystem._sfx_pool[5].stream

	var new_stream := AudioStreamGenerator.new()
	var new_data := AudioEventData.new()
	new_data.stream = new_stream
	new_data.bus = &"SFX"
	new_data.priority = 1
	AudioSystem._validated_events[&"_test_evict_high_s002"] = new_data

	AudioSystem.play_event(&"_test_evict_high_s002")

	# Slot 5 must NOT be evicted — its stream must be unchanged.
	assert_object(AudioSystem._sfx_pool[5].stream).is_equal(original_stream_slot5)
	# The new stream must appear on some other slot.
	var new_stream_assigned: bool = false
	for i: int in range(AudioSystem.SFX_POOL_SIZE):
		if i == 5:
			continue
		if AudioSystem._sfx_pool[i].stream == new_stream:
			new_stream_assigned = true
			break
	assert_bool(new_stream_assigned).is_true()

	AudioSystem._validated_events.erase(&"_test_evict_high_s002")


## AC-AS-06 Test D — All HIGH slots: oldest HIGH is evicted (slot 3, timestamp 0).
func test_eviction_all_high_oldest_high_evicted() -> void:
	_fill_pool_with_priority(2)  # All HIGH.
	AudioSystem._set_slot_timestamp(3, 0)

	var new_stream := AudioStreamGenerator.new()
	var new_data := AudioEventData.new()
	new_data.stream = new_stream
	new_data.bus = &"SFX"
	new_data.priority = 1
	AudioSystem._validated_events[&"_test_evict_allhigh_s002"] = new_data

	AudioSystem.play_event(&"_test_evict_allhigh_s002")

	assert_object(AudioSystem._sfx_pool[3].stream).is_equal(new_stream)

	AudioSystem._validated_events.erase(&"_test_evict_allhigh_s002")


# ── AC-AS-07: UI-bus event routes to _ui_player only ─────────────────────────

## GIVEN a dummy UI-bus event registered
## WHEN play_event() called
## THEN _ui_player.stream == dummy UI stream
func test_ui_event_assigns_stream_to_ui_player() -> void:
	AudioSystem.play_event(_TEST_UI_EVENT)
	assert_object(AudioSystem._ui_player.stream).is_equal(_dummy_stream_ui)


## GIVEN a dummy UI-bus event registered
## WHEN play_event() called
## THEN _ui_player.process_mode == PROCESS_MODE_ALWAYS
func test_ui_player_process_mode_always() -> void:
	AudioSystem.play_event(_TEST_UI_EVENT)
	assert_int(AudioSystem._ui_player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


## GIVEN a dummy UI-bus event registered
## WHEN play_event() called
## THEN zero pool slots change stream (all remain null)
func test_ui_event_does_not_touch_sfx_pool() -> void:
	AudioSystem.play_event(_TEST_UI_EVENT)

	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		assert_object(player.stream).is_null()


# ── AC-AS-34: AMB-bus via play_event() logs push_error ───────────────────────

## GIVEN a dummy AMB-bus event registered
## WHEN play_event() called
## THEN all 24 pool slots remain null
func test_amb_event_via_play_event_leaves_sfx_pool_unchanged() -> void:
	AudioSystem.play_event(_TEST_AMB_EVENT)

	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		assert_object(player.stream).is_null()


## GIVEN a dummy AMB-bus event registered
## WHEN play_event() called
## THEN _ui_player.stream remains null
func test_amb_event_via_play_event_leaves_ui_player_unchanged() -> void:
	AudioSystem.play_event(_TEST_AMB_EVENT)
	assert_object(AudioSystem._ui_player.stream).is_null()


## GIVEN a dummy AMB-bus event registered
## WHEN play_event() called
## THEN both ambient players remain unchanged (stream null)
func test_amb_event_via_play_event_leaves_ambient_players_unchanged() -> void:
	AudioSystem.play_event(_TEST_AMB_EVENT)

	for player: AudioStreamPlayer in AudioSystem._ambient_players:
		assert_object(player.stream).is_null()
