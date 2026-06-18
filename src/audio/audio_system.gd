## audio_system.gd — AudioSystem Autoload #5.
## Sole audio service for all gameplay systems (ADR-0012).
##
## Access: AudioSystem.play_event(&"event_name")
## No class_name — Godot 4 parse error when class_name matches Autoload node name.
##
## 30 managed AudioStreamPlayer nodes — all created in _ready():
##   Music A/B    × 2  —  PROCESS_MODE_ALWAYS,   BUS_MUSIC
##   Ambient A/B  × 2  —  PROCESS_MODE_ALWAYS,   BUS_AMB
##   UI           × 1  —  PROCESS_MODE_ALWAYS,   BUS_UI
##   Stinger      × 1  —  PROCESS_MODE_ALWAYS,   BUS_SFX  (non-pooled)
##   SFX pool    × 24  —  PROCESS_MODE_PAUSABLE, BUS_SFX
##
## ADR: adr-0012-audio-system-implementation-contract.md
extends Node

# ── Bus constants — sole definitions in the codebase (TR-AS-001) ──────────────

const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_UI: StringName = &"UI"
const BUS_AMB: StringName = &"AMB"

## Pre-instantiated SFX pool node count (TR-AS-002, ADR-0012).
const SFX_POOL_SIZE: int = 24

## AudioEventRegistry resource path (ADR-0012 — no hardcoded event data in GDScript).
const _REGISTRY_PATH: String = "res://assets/data/audio_event_registry.tres"

# ── Managed nodes — created in _ready(), never scene-wired ───────────────────

## Music crossfade pair [A, B]. PROCESS_MODE_ALWAYS (TR-AS-005).
var _music_players: Array[AudioStreamPlayer] = []
## Ambient crossfade pair [A, B]. PROCESS_MODE_ALWAYS (TR-AS-005).
var _ambient_players: Array[AudioStreamPlayer] = []
## Dedicated UI player. PROCESS_MODE_ALWAYS (TR-AS-005).
var _ui_player: AudioStreamPlayer = null
## Non-pooled stinger player. PROCESS_MODE_ALWAYS, BUS_SFX (TR-AS-011).
var _stinger_player: AudioStreamPlayer = null
## 24-slot SFX pool. PROCESS_MODE_PAUSABLE (TR-AS-002, TR-AS-005).
var _sfx_pool: Array[AudioStreamPlayer] = []

## Per-slot play timestamps for priority eviction (TR-AS-012).
## 0 = never played — makes never-played slots appear oldest and evict first.
var _timestamps: Array[int] = []

## Per-slot priority mirrors the event priority at time of assignment.
## Parallel to _sfx_pool. Initialised to 0 (LOW). Updated on every slot assignment.
var _slot_priorities: Array[int] = []

## Validated event map. Populated from AudioEventRegistry.tres at startup.
## Invalid entries are skipped or clamped; all play_event() calls use this map.
var _validated_events: Dictionary[StringName, AudioEventData] = {}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not is_instance_valid(GameStateManager):
		push_error("AudioSystem: GameStateManager must be initialized before AudioSystem (ADR-0012).")
		return
	_init_buses()
	_create_music_players()
	_create_ambient_players()
	_create_ui_player()
	_create_stinger_player()
	_create_sfx_pool()
	_load_event_registry()
	# GSM signal connections: Story 003

# ── Bus setup ─────────────────────────────────────────────────────────────────

## Creates the 5 audio buses if not already present in Project Settings.
## Idempotent — safe to call when buses pre-exist (editor-configured or prior _ready()).
func _init_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX, BUS_UI, BUS_AMB]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)

# ── Node creation ─────────────────────────────────────────────────────────────

func _create_music_players() -> void:
	var names: Array[StringName] = [&"MusicA", &"MusicB"]
	for i: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = names[i]
		player.bus = BUS_MUSIC
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		call_deferred("add_child", player)
		_music_players.append(player)


func _create_ambient_players() -> void:
	var names: Array[StringName] = [&"AmbientA", &"AmbientB"]
	for i: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = names[i]
		player.bus = BUS_AMB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		call_deferred("add_child", player)
		_ambient_players.append(player)


func _create_ui_player() -> void:
	_ui_player = AudioStreamPlayer.new()
	_ui_player.name = &"UIPlayer"
	_ui_player.bus = BUS_UI
	_ui_player.process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("add_child", _ui_player)


func _create_stinger_player() -> void:
	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.name = &"StingerPlayer"
	_stinger_player.bus = BUS_SFX
	_stinger_player.process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("add_child", _stinger_player)


func _create_sfx_pool() -> void:
	_timestamps.resize(SFX_POOL_SIZE)
	_timestamps.fill(0)
	_slot_priorities.resize(SFX_POOL_SIZE)
	_slot_priorities.fill(0)
	for i: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%02d" % i
		player.bus = BUS_SFX
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		call_deferred("add_child", player)
		_sfx_pool.append(player)

# ── Registry loading ──────────────────────────────────────────────────────────

func _load_event_registry() -> void:
	var registry: AudioEventRegistry = load(_REGISTRY_PATH) as AudioEventRegistry
	if registry == null:
		push_error("AudioSystem: AudioEventRegistry not found at '%s' — all play_event() calls will be no-ops." % _REGISTRY_PATH)
		return
	for event_name: StringName in registry.events:
		var data: AudioEventData = registry.events[event_name]
		if not data is AudioEventData:
			push_error("AudioSystem: event '%s' is not AudioEventData — skipped." % event_name)
			continue
		if data.priority < 0 or data.priority > 2:
			push_error("AudioSystem: event '%s' priority %d out of range — clamped to NORMAL (1)." % [event_name, data.priority])
			var clamped: AudioEventData = data.duplicate_deep() as AudioEventData
			clamped.priority = 1
			_validated_events[event_name] = clamped
		else:
			_validated_events[event_name] = data

# ── Public API ────────────────────────────────────────────────────────────────

## Routes [param event_name] to the correct player based on AudioEventData.bus.
## SFX → pool (PAUSABLE); UI → dedicated UI player (ALWAYS); AMB → push_error.
## Unregistered or unknown-bus events log push_error() and return — no crash.
func play_event(event_name: StringName) -> void:
	if not _validated_events.has(event_name):
		push_error("AudioSystem: play_event('%s') — event not registered." % event_name)
		return
	var data: AudioEventData = _validated_events[event_name]
	match data.bus:
		BUS_SFX:
			_assign_sfx_pool_slot(data)
		BUS_UI:
			_play_on_ui_player(data)
		BUS_AMB:
			push_error("AudioSystem: play_event('%s') targets BUS_AMB — use play_ambient() instead." % event_name)
		_:
			push_error("AudioSystem: Unknown bus '%s' for event '%s'." % [data.bus, event_name])


## Stubs for future stories (Story 005, 006, 007).
func play_ambient(_event_name: StringName) -> void:
	pass  # Story 005


func stop_ambient() -> void:
	pass  # Story 005


func play_stinger(_event_name: StringName) -> void:
	pass  # Story 006


func stop_stinger() -> void:
	pass  # Story 006

# ── Private dispatch ──────────────────────────────────────────────────────────

func _play_on_ui_player(data: AudioEventData) -> void:
	if _ui_player == null:
		return
	_ui_player.stream = data.stream
	_ui_player.play()


## Assigns stream to the first free pool slot.
## When all 24 slots are playing, evicts the lowest-priority oldest slot (TR-AS-012).
func _assign_sfx_pool_slot(data: AudioEventData) -> void:
	# Step 1: find first non-playing slot.
	for i: int in range(SFX_POOL_SIZE):
		if not _sfx_pool[i].playing:
			_sfx_pool[i].stream = data.stream
			_sfx_pool[i].play()
			_timestamps[i] = Time.get_ticks_msec()
			_slot_priorities[i] = data.priority
			return
	# Step 2: all slots occupied — evict by priority tier, oldest first.
	var target: int = _find_eviction_target(data.priority)
	_sfx_pool[target].stop()
	_sfx_pool[target].stream = data.stream
	_sfx_pool[target].play()
	_timestamps[target] = Time.get_ticks_msec()
	_slot_priorities[target] = data.priority


## Returns the index of the slot to evict.
## Algorithm: scan priority tiers LOW→NORMAL→HIGH; within a tier pick the smallest timestamp.
## Always returns a valid index — falls back to 0 if all tiers fail (should not occur).
func _find_eviction_target(_incoming_priority: int) -> int:
	for tier: int in [0, 1, 2]:
		var oldest_idx: int = -1
		var oldest_ts: int = 2147483647  # INT_MAX — any real timestamp will be smaller.
		for i: int in range(SFX_POOL_SIZE):
			if _slot_priorities[i] == tier and _timestamps[i] < oldest_ts:
				oldest_ts = _timestamps[i]
				oldest_idx = i
		if oldest_idx >= 0:
			return oldest_idx
	return 0  # Fallback: should never reach.

# ── Test accessors ────────────────────────────────────────────────────────────

## Sets the timestamp for slot [param idx] — used by sfx_pool_test.gd to establish
## deterministic eviction order without requiring real-time play() calls (AC-AS-06).
func _set_slot_timestamp(idx: int, ticks: int) -> void:
	_timestamps[idx] = ticks
