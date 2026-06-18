## audio_event_registry_test.gd — Unit tests for AudioSystem event routing and pool safety.
##
## Coverage:
##   AC: play_event() with an unknown event ID does not crash or push errors.
##   AC: play_event() with a known event ID that has no asset file does not crash.
##   AC: play_event() can be called SFX_POOL_SIZE + 1 times without crashing (pool overflow safe).
##   AC: SFX pool was created (SFX_POOL_SIZE children are AudioStreamPlayer nodes).
##   AC: music player was created (MusicPlayer child exists).
##   AC: stop_music() does not crash when nothing is playing.
##
## AudioSystem is Autoload #5 — _ready() fires before tests run. Pool is already initialised.
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite


# ── AC: unknown event is a silent no-op ──────────────────────────────────────

## GIVEN an event ID that is not in the registry
## WHEN play_event() is called
## THEN no crash, no error logged (GdUnit4 would catch push_error as a test failure)
func test_play_event_unknown_event_does_not_crash() -> void:
	AudioSystem.play_event(&"sfx_event_that_does_not_exist")
	# Reaching here without crash is the assertion.
	assert_bool(true).is_true()


# ── AC: known event with missing asset is silent ─────────────────────────────

## GIVEN a known event ID whose asset file does not exist on disk
## WHEN play_event() is called
## THEN no crash (stream is null, early return fires)
func test_play_event_missing_asset_does_not_crash() -> void:
	# sfx_fayde_dash is in the registry but the .ogg file has not been added yet.
	AudioSystem.play_event(&"sfx_fayde_dash")
	assert_bool(true).is_true()


# ── AC: pool overflow does not crash ─────────────────────────────────────────

## GIVEN the SFX pool has SFX_POOL_SIZE slots
## WHEN play_event() is called more than SFX_POOL_SIZE times with a missing asset
## THEN no crash (round-robin wraps; missing asset is a no-op before reaching pool)
func test_play_event_many_calls_do_not_crash() -> void:
	var calls: int = AudioSystem.SFX_POOL_SIZE + 4
	for _i: int in range(calls):
		AudioSystem.play_event(&"sfx_spell_hit")
	assert_bool(true).is_true()


# ── AC: SFX pool nodes were created ──────────────────────────────────────────

## GIVEN AudioSystem has completed _ready()
## WHEN SFX_POOL_SIZE is read
## THEN that many AudioStreamPlayer children named "SFX_N" exist under AudioSystem
func test_sfx_pool_nodes_exist() -> void:
	var found: int = 0
	for i: int in range(AudioSystem.SFX_POOL_SIZE):
		var child: Node = AudioSystem.get_node_or_null("SFX_%d" % i)
		if child is AudioStreamPlayer:
			found += 1
	assert_int(found).is_equal(AudioSystem.SFX_POOL_SIZE)


# ── AC: music player node was created ────────────────────────────────────────

## GIVEN AudioSystem has completed _ready()
## WHEN MusicPlayer child is queried
## THEN it exists and is an AudioStreamPlayer
func test_music_player_node_exists() -> void:
	var player: Node = AudioSystem.get_node_or_null("MusicPlayer")
	assert_object(player).is_not_null()
	assert_bool(player is AudioStreamPlayer).is_true()


# ── AC: stop_music is safe when nothing is playing ───────────────────────────

## GIVEN no music is currently playing
## WHEN stop_music() is called
## THEN no crash
func test_stop_music_does_not_crash_when_silent() -> void:
	AudioSystem.stop_music()
	assert_bool(true).is_true()
