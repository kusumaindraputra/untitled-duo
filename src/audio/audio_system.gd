## audio_system.gd — AudioSystem Autoload #5.
## Sole audio service for all gameplay systems (ADR-0012).
##
## SFX pool: 8 round-robin AudioStreamPlayer nodes on the SFX bus.
## Music: single dedicated AudioStreamPlayer on the Music bus with looping.
## Event registry: hardcoded StringName → path. Missing assets are silent (no crash).
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

## Number of pooled SFX players. 8 slots support simultaneous spell hits + footsteps + UI.
const SFX_POOL_SIZE: int = 8

## Event ID → resource path mapping. Entries with missing files play silence (null-safe).
const _EVENT_REGISTRY: Dictionary = {
	&"sfx_fayde_dash":        "res://assets/audio/sfx/fayde_dash.ogg",
	&"sfx_fayde_footstep_a":  "res://assets/audio/sfx/fayde_footstep_a.ogg",
	&"sfx_fayde_footstep_b":  "res://assets/audio/sfx/fayde_footstep_b.ogg",
	&"sfx_fayde_footstep_c":  "res://assets/audio/sfx/fayde_footstep_c.ogg",
	&"sfx_spell_hit":         "res://assets/audio/sfx/spell_hit.ogg",
	&"sfx_enemy_death":       "res://assets/audio/sfx/enemy_death.ogg",
	&"sfx_player_damaged":    "res://assets/audio/sfx/player_damaged.ogg",
	&"music_combat_loop":     "res://assets/audio/music/combat_loop.ogg",
}

## Cached AudioStream resources. Populated lazily on first play_event() call per event.
## Null value means asset file does not exist or failed to load — play silently.
var _stream_cache: Dictionary = {}

## SFX pool — SFX_POOL_SIZE AudioStreamPlayer nodes allocated in _ready().
var _sfx_pool: Array[AudioStreamPlayer] = []
## Round-robin index into _sfx_pool.
var _sfx_next: int = 0

## Dedicated music player (looping).
var _music_player: AudioStreamPlayer = null
## Event ID of the currently playing music track. Empty = nothing playing.
var _current_music_event: StringName = &""


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	if not is_instance_valid(GameStateManager):
		push_error("AudioSystem: GameStateManager must be initialized before AudioSystem (ADR-0012).")
		return
	_init_buses()
	_init_sfx_pool()
	_init_music_player()


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


## Creates SFX_POOL_SIZE AudioStreamPlayer nodes on the SFX bus.
func _init_sfx_pool() -> void:
	var sfx_bus_idx: int = AudioServer.get_bus_index(BUS_SFX)
	var sfx_bus_name: StringName = BUS_SFX if sfx_bus_idx != -1 else &"Master"
	for i: int in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_%d" % i
		player.bus = sfx_bus_name
		add_child(player)
		_sfx_pool.append(player)


## Creates a single looping AudioStreamPlayer on the Music bus.
func _init_music_player() -> void:
	var music_bus_idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	var music_bus_name: StringName = BUS_MUSIC if music_bus_idx != -1 else &"Master"
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = music_bus_name
	add_child(_music_player)


# ── Public API ────────────────────────────────────────────────────────────────

## Routes [param event_id] to the correct player.
## Music events (prefix "music_") go to the dedicated music player with looping.
## SFX events go to the round-robin pool.
## Silent no-op when the asset file is missing — no crash, no log spam.
func play_event(event_id: StringName) -> void:
	var stream: AudioStream = _get_stream(event_id)
	if stream == null:
		return  # Asset missing or unknown event — silent

	if str(event_id).begins_with("music_"):
		_play_music(event_id, stream)
	else:
		_play_sfx(stream)


## Stops the currently playing music track, if any.
func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_current_music_event = &""


# ── Private ───────────────────────────────────────────────────────────────────

## Returns the AudioStream for [param event_id], loading it on first access.
## Returns null if the event is unknown or the asset file is missing.
func _get_stream(event_id: StringName) -> AudioStream:
	if _stream_cache.has(event_id):
		return _stream_cache[event_id]

	if not _EVENT_REGISTRY.has(event_id):
		_stream_cache[event_id] = null
		return null

	var path: String = _EVENT_REGISTRY[event_id]
	if not ResourceLoader.exists(path):
		_stream_cache[event_id] = null
		return null

	var loaded: Resource = load(path)
	var stream: AudioStream = loaded as AudioStream
	_stream_cache[event_id] = stream  # null if cast failed (wrong asset type)
	return stream


## Assigns stream to the next pool slot and plays it (round-robin).
## Interrupts the oldest sound if all 8 slots are active simultaneously.
func _play_sfx(stream: AudioStream) -> void:
	var player: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.play()


## Plays or restarts a music track with looping enabled.
## No-ops if the same track is already playing to prevent restart-on-loop.
func _play_music(event_id: StringName, stream: AudioStream) -> void:
	if _current_music_event == event_id and _music_player.playing:
		return
	_music_player.stream = stream
	if _music_player.stream is AudioStreamOggVorbis:
		(_music_player.stream as AudioStreamOggVorbis).loop = true
	_music_player.play()
	_current_music_event = event_id
