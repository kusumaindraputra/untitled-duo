## audio_system_foundation_test.gd — Story 001 acceptance criteria tests.
##
## Coverage (AC-AS-01, AC-AS-02, AC-AS-21, AC-AS-32):
##   AC-AS-01: AudioServer has exactly 5 buses; all canonical names return index >= 0
##   AC-AS-02: Music/SFX/UI/AMB buses send to Master; Master sends to ""
##   AC-AS-21: play_event() dispatches to a pool slot (stream assigned) without errors
##   AC-AS-32: All 30 managed nodes have correct process modes
##
## AudioSystem is Autoload #5 — _ready() fires before tests run.
## Test events injected directly into _validated_events to avoid registry file dependency.
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

## Sentinel stream for dispatching tests — AudioStreamGenerator needs no audio file.
var _dummy_stream: AudioStreamGenerator = null
const _TEST_EVENT: StringName = &"_test_event_foundation"


func before_test() -> void:
	_dummy_stream = AudioStreamGenerator.new()
	var data := AudioEventData.new()
	data.stream = _dummy_stream
	data.bus = &"SFX"
	data.priority = 1
	AudioSystem._validated_events[_TEST_EVENT] = data


func after_test() -> void:
	AudioSystem._validated_events.erase(_TEST_EVENT)
	_dummy_stream = null
	# Reset pool slots that may have received the dummy stream.
	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		if player.stream != null and player.stream is AudioStreamGenerator:
			player.stream = null


# ── AC-AS-01: 5 buses with canonical names ────────────────────────────────────

## GIVEN AudioSystem has completed _ready()
## WHEN AudioServer.get_bus_count() is read
## THEN exactly 5 buses exist
func test_audio_server_has_five_buses() -> void:
	assert_int(AudioServer.get_bus_count()).is_equal(5)


## GIVEN AudioSystem has completed _ready()
## WHEN AudioServer.get_bus_index() is called for each canonical bus name
## THEN all five return index >= 0
func test_audio_bus_master_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"Master")).is_greater_equal(0)


func test_audio_bus_music_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"Music")).is_greater_equal(0)


func test_audio_bus_sfx_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"SFX")).is_greater_equal(0)


func test_audio_bus_ui_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"UI")).is_greater_equal(0)


func test_audio_bus_amb_exists() -> void:
	assert_int(AudioServer.get_bus_index(&"AMB")).is_greater_equal(0)


# ── AC-AS-02: non-master buses send to Master ──────────────────────────────────

## GIVEN AudioSystem has completed _ready()
## WHEN AudioServer.get_bus_send() is called for each bus
## THEN Music/SFX/UI/AMB all return "Master"; Master returns ""
func test_audio_bus_music_routes_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(&"Music")
	assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")


func test_audio_bus_sfx_routes_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(&"SFX")
	assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")


func test_audio_bus_ui_routes_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(&"UI")
	assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")


func test_audio_bus_amb_routes_to_master() -> void:
	var idx: int = AudioServer.get_bus_index(&"AMB")
	assert_str(AudioServer.get_bus_send(idx)).is_equal("Master")


func test_audio_bus_master_has_no_parent() -> void:
	var idx: int = AudioServer.get_bus_index(&"Master")
	assert_str(AudioServer.get_bus_send(idx)).is_equal("")


# ── AC-AS-21: play_event dispatches to a pool slot ────────────────────────────

## GIVEN a registered dummy SFX event with a known AudioStreamGenerator stream
## WHEN AudioSystem.play_event() is called from a standalone test node
## THEN no push_error fires AND the dummy stream appears on a pool slot
func test_play_event_dispatches_to_sfx_pool_slot() -> void:
	AudioSystem.play_event(_TEST_EVENT)

	var slot_received_stream: bool = false
	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		if player.stream == _dummy_stream:
			slot_received_stream = true
			break
	assert_bool(slot_received_stream).is_true()


# ── AC-AS-32: all 30 managed nodes have correct process modes ──────────────────

## GIVEN AudioSystem has completed _ready()
## WHEN process_mode is read from Music A and B players
## THEN both return PROCESS_MODE_ALWAYS (TR-AS-005)
func test_music_players_process_mode_always() -> void:
	assert_int(AudioSystem._music_players.size()).is_equal(2)
	for player: AudioStreamPlayer in AudioSystem._music_players:
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


## GIVEN AudioSystem has completed _ready()
## WHEN process_mode is read from Ambient A and B players
## THEN both return PROCESS_MODE_ALWAYS (TR-AS-005)
func test_ambient_players_process_mode_always() -> void:
	assert_int(AudioSystem._ambient_players.size()).is_equal(2)
	for player: AudioStreamPlayer in AudioSystem._ambient_players:
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


## GIVEN AudioSystem has completed _ready()
## WHEN process_mode is read from the UI player
## THEN it returns PROCESS_MODE_ALWAYS (TR-AS-005)
func test_ui_player_process_mode_always() -> void:
	assert_object(AudioSystem._ui_player).is_not_null()
	assert_int(AudioSystem._ui_player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


## GIVEN AudioSystem has completed _ready()
## WHEN process_mode is read from the stinger player
## THEN it returns PROCESS_MODE_ALWAYS (TR-AS-011)
func test_stinger_player_process_mode_always() -> void:
	assert_object(AudioSystem._stinger_player).is_not_null()
	assert_int(AudioSystem._stinger_player.process_mode).is_equal(Node.PROCESS_MODE_ALWAYS)


## GIVEN AudioSystem has completed _ready()
## WHEN process_mode is read from all 24 SFX pool nodes
## THEN all return PROCESS_MODE_PAUSABLE (TR-AS-005)
func test_sfx_pool_process_mode_pausable() -> void:
	assert_int(AudioSystem._sfx_pool.size()).is_equal(24)
	for player: AudioStreamPlayer in AudioSystem._sfx_pool:
		assert_int(player.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)


## GIVEN AudioSystem has completed _ready()
## WHEN total managed node count is calculated
## THEN exactly 30 nodes exist (2 music + 2 ambient + 1 UI + 1 stinger + 24 SFX pool)
func test_total_managed_node_count_is_30() -> void:
	var total: int = (
		AudioSystem._music_players.size()
		+ AudioSystem._ambient_players.size()
		+ (1 if AudioSystem._ui_player != null else 0)
		+ (1 if AudioSystem._stinger_player != null else 0)
		+ AudioSystem._sfx_pool.size()
	)
	assert_int(total).is_equal(30)
