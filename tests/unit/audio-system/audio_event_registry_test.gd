## audio_event_registry_test.gd — Unit tests for AudioSystem node creation (ADR-0012).
##
## Coverage:
##   AC: SFX pool was created — 24 AudioStreamPlayer nodes with correct naming
##   AC: Music A/B players were created
##   AC: Ambient A/B players were created
##   AC: UI player was created
##   AC: Stinger player was created
##   AC: play_event() with an injected valid event does not crash (pool slot dispatched)
##   AC: Pool overflow is safe — SFX_POOL_SIZE + N calls with injected event do not crash
##
## AudioSystem is Autoload #5 — _ready() fires before tests run. All nodes created.
## call_deferred("add_child") in _ready() has resolved by the time tests run (many frames later).
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const _TEST_EVENT: StringName = &"_test_event_registry_suite"


func before_test() -> void:
	# Register a minimal test event for tests that need a valid event.
	var data := AudioEventData.new()
	data.bus = &"SFX"
	data.priority = 1
	# stream = null is intentional — AudioStreamPlayer.play() with null stream is a no-op.
	AudioSystem._validated_events[_TEST_EVENT] = data


func after_test() -> void:
	AudioSystem._validated_events.erase(_TEST_EVENT)
	# Clear any stream that may have been assigned to pool slot 0 during tests.
	if not AudioSystem._sfx_pool.is_empty():
		AudioSystem._sfx_pool[0].stream = null


# ── SFX pool node creation ────────────────────────────────────────────────────

## GIVEN AudioSystem has completed _ready()
## WHEN _sfx_pool array is read
## THEN it contains exactly SFX_POOL_SIZE AudioStreamPlayer entries
func test_sfx_pool_array_size_is_correct() -> void:
	assert_int(AudioSystem._sfx_pool.size()).is_equal(AudioSystem.SFX_POOL_SIZE)


## GIVEN AudioSystem has completed _ready() and deferred add_child has resolved
## WHEN SFX pool child nodes are queried
## THEN SFX_POOL_SIZE children named "SFX_NN" exist under AudioSystem
func test_sfx_pool_nodes_exist_with_correct_naming() -> void:
	var found: int = 0
	for i: int in range(AudioSystem.SFX_POOL_SIZE):
		var child: Node = AudioSystem.get_node_or_null("SFX_%02d" % i)
		if child is AudioStreamPlayer:
			found += 1
	assert_int(found).is_equal(AudioSystem.SFX_POOL_SIZE)


# ── Music A/B player creation ─────────────────────────────────────────────────

func test_music_a_player_exists() -> void:
	assert_object(AudioSystem.get_node_or_null("MusicA")).is_not_null()


func test_music_b_player_exists() -> void:
	assert_object(AudioSystem.get_node_or_null("MusicB")).is_not_null()


# ── Ambient A/B player creation ───────────────────────────────────────────────

func test_ambient_a_player_exists() -> void:
	assert_object(AudioSystem.get_node_or_null("AmbientA")).is_not_null()


func test_ambient_b_player_exists() -> void:
	assert_object(AudioSystem.get_node_or_null("AmbientB")).is_not_null()


# ── UI + Stinger player creation ──────────────────────────────────────────────

func test_ui_player_exists() -> void:
	assert_object(AudioSystem.get_node_or_null("UIPlayer")).is_not_null()


func test_stinger_player_exists() -> void:
	assert_object(AudioSystem.get_node_or_null("StingerPlayer")).is_not_null()


# ── play_event dispatch ───────────────────────────────────────────────────────

## GIVEN an event registered in _validated_events
## WHEN play_event() is called
## THEN no crash; a pool slot receives the stream (or null for placeholder data)
func test_play_event_with_valid_event_does_not_crash() -> void:
	AudioSystem.play_event(_TEST_EVENT)
	# Reaching here without crash = pass (GdUnit4 catches push_error as failure).
	assert_bool(true).is_true()


## GIVEN SFX_POOL_SIZE + 4 calls with a valid injected event
## WHEN play_event is called more than pool capacity
## THEN no crash — fallback eviction handles overflow
func test_play_event_pool_overflow_does_not_crash() -> void:
	var calls: int = AudioSystem.SFX_POOL_SIZE + 4
	for _i: int in range(calls):
		AudioSystem.play_event(_TEST_EVENT)
	assert_bool(true).is_true()
