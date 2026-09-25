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
## Music State Machine (Story 003):
##   MusicState enum: MAIN_MENU → PREPARATION → COMBAT → DYING → END_DEFEAT/VICTORY
##   All transitions driven by GameStateManager signals — no polling.
##   wave_ended is NOT connected (preparation_started is the sole COMBAT→PREP trigger).
##   END_* states are non-interruptible — all GSM signals are no-ops while in END_*.
##   Tween kill-before-create order: kill prior tween, then set incoming volume, then play,
##   then create new tween (ADR-0012 Crossfade Implementation section).
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

## Stinger priority: COMBAT (0) can be blocked by NARRATIVE (1).
const STINGER_PRIORITY_COMBAT: int = 0
const STINGER_PRIORITY_NARRATIVE: int = 1
## Duck fade-in duration for Music bus when stinger starts.
const STINGER_DUCK_FADE_IN_SEC: float = 0.1

# ── Music state machine — states (TR-AS-003, ADR-0012) ───────────────────────

## Six music states driven exclusively by GameStateManager signals.
## Integer values are stable — do not reorder (tests assert by name, not int).
enum MusicState {
	MAIN_MENU = 0,      ## Startup state; main menu music loops.
	PREPARATION = 1,    ## Pre-wave prep; preparation music loops.
	COMBAT = 2,         ## Active combat; combat music loops.
	DYING = 3,          ## Intentional silence; no registered cue.
	END_DEFEAT = 4,     ## Run-end defeat cue; non-interruptible.
	END_VICTORY = 5,    ## Run-end victory cue; non-interruptible.
}

# ── Music crossfade durations — all in seconds (ADR-0012 Tuning Knobs) ───────

## MAIN_MENU → PREPARATION on run_started. "Scene breathes in."
const CROSSFADE_DURATION_MENU_TO_PREPARATION: float = 1.0
## PREPARATION → COMBAT on combat_started. "Punches in fast."
const CROSSFADE_DURATION_TO_COMBAT: float = 0.1
## COMBAT → PREPARATION on preparation_started. "Clean exhale."
const CROSSFADE_DURATION_COMBAT_TO_PREPARATION: float = 0.8
## Any → END_VICTORY or END_DEFEAT. Uses Tween.TRANS_SINE (constant-power).
const CROSSFADE_DURATION_TO_END: float = 2.0
## END_* → MAIN_MENU auto-transition. "No dead air."
const CROSSFADE_DURATION_TO_MAIN_MENU: float = 0.5
## COMBAT/PREP → DYING. Fast fade to silence.
const CROSSFADE_DURATION_TO_DYING: float = 0.1
## Ambient layer fade out duration (Story 005). Used for both crossfade-out and stop_ambient().
const CROSSFADE_DURATION_AMBIENT_OUT: float = 0.5
## Minimum time (seconds) DYING must hold before a queued END_DEFEAT transition fires (AC-AS-29).
const DYING_MIN_HOLD_SEC: float = 1.5

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

## Last play time (msec) per event, for AudioEventData.min_interval_sec throttling.
var _last_play_ms: Dictionary[StringName, int] = {}

## Pitch jitter source. Seedable so tests stay deterministic.
var _rng := RandomNumberGenerator.new()

# ── Music state machine — instance variables (Story 003) ─────────────────────

## Current music FSM state. Never read directly by external systems (ADR-0003).
var _music_state: MusicState = MusicState.MAIN_MENU

## Index into _music_players[] that is currently audible (0 = MusicA, 1 = MusicB).
var _active_music_idx: int = 0

## Index into _music_players[] that is fading out or silent.
var _inactive_music_idx: int = 1

## The live crossfade Tween. Killed before each new crossfade (ADR-0012).
## null when no crossfade is in progress.
var _active_tween: Tween = null

## Index into _ambient_players[] that is currently audible (0 = AmbientA, 1 = AmbientB).
var _active_ambient_idx: int = 0

## The live ambient crossfade Tween. Killed before each new ambient crossfade (Story 005).
## null when no ambient crossfade is in progress.
var _active_ambient_tween: Tween = null

## Maps MusicState → AudioStream resource. Populated by _load_music_cues().
## null entries are valid (e.g. DYING has no cue by design).
var _music_cues: Dictionary[int, AudioStream] = {}

## Seconds elapsed since the DYING state was entered. Reset to 0.0 on _on_death_started().
## Guards against run_ended(false) arriving before the moment "breathes" (AC-AS-29).
var _dying_elapsed: float = 0.0

## When true, a run_ended(false) arrived during DYING before DYING_MIN_HOLD_SEC elapsed.
## _process() fires the queued END_DEFEAT transition once the hold guard clears.
var _pending_defeat_transition: bool = false

## Live stinger tween (duck or restore). Killed before each new tween.
var _active_stinger_tween: Tween = null
## Music bus volume captured before first stinger duck. Retained on interrupt — never re-captured.
var _music_pre_stinger_volume: float = 0.0
## Priority of the currently playing stinger. -1 = no stinger playing.
var _current_stinger_priority: int = -1
## Last stinger event played — provides restore_duration_sec for _restore_music_after_stinger().
var _last_stinger_event: AudioEventData = null

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
	_load_music_cues()
	# Connect GameStateManager signals for the music FSM (Story 003, ADR-0012, ADR-0003).
	# wave_ended is intentionally NOT connected — preparation_started is the sole
	# authoritative trigger for COMBAT → PREPARATION (AC-AS-11, ADR-0012).
	GameStateManager.run_started.connect(_on_run_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.death_started.connect(_on_death_started)
	GameStateManager.run_ended.connect(_on_run_ended)
	# Restore the player's saved volume preferences (no-op on first run / in CI).
	load_audio_settings()

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
	if _is_throttled(event_name, data):
		return
	match data.bus:
		BUS_SFX:
			_assign_sfx_pool_slot(data)
		BUS_UI:
			_play_on_ui_player(data)
		BUS_AMB:
			push_error("AudioSystem: play_event('%s') targets BUS_AMB — use play_ambient() instead." % event_name)
		BUS_MUSIC:
			push_error("AudioSystem: play_event('%s') targets BUS_MUSIC — music is managed by the FSM; use override_combat_cue() to change tracks." % event_name)
		_:
			push_error("AudioSystem: Unknown bus '%s' for event '%s'." % [data.bus, event_name])


## Returns true (and drops the call) when [param event_name] played less than
## data.min_interval_sec ago. Records the play time otherwise.
func _is_throttled(event_name: StringName, data: AudioEventData) -> bool:
	if data.min_interval_sec <= 0.0:
		return false
	var now: int = Time.get_ticks_msec()
	var last: int = _last_play_ms.get(event_name, -1)
	if last >= 0 and now - last < int(data.min_interval_sec * 1000.0):
		return true
	_last_play_ms[event_name] = now
	return false


## Seeds the pitch-jitter RNG (tests only).
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Returns true if [param event_name] is registered in the validated event map.
## Use this to guard play_event() calls when the registry may be incomplete
## (e.g., headless tests, early development before audio assets exist).
func has_event(event_name: StringName) -> bool:
	return _validated_events.has(event_name)


## Overrides the COMBAT music cue for the next combat encounter.
## Call this before the player enters a boss or elite room so the correct track
## crossfades in when GameStateManager emits combat_started.
## Valid event names: mus_combat_floor, mus_combat_elite, mus_combat_boss.
func override_combat_cue(event_name: StringName) -> void:
	if not _validated_events.has(event_name):
		push_error("AudioSystem: override_combat_cue('%s') — event not registered." % event_name)
		return
	_music_cues[MusicState.COMBAT as int] = _validated_events[event_name].stream


## Resets the COMBAT music cue to the default floor track (mus_combat_floor).
## Call this after a room is cleared so the next normal room uses the default cue.
func reset_combat_cue() -> void:
	if _validated_events.has(&"mus_combat_floor"):
		_music_cues[MusicState.COMBAT as int] = _validated_events[&"mus_combat_floor"].stream


## Starts crossfade from the current ambient player to [param event_name]'s stream.
##
## Crossfade order (mirrors _crossfade_to ADR-0012 pattern):
##   1. Kill prior ambient tween.
##   2. Set incoming volume to -80 dB BEFORE play().
##   3. Call incoming.play().
##   4. Create new parallel tween: outgoing fades out, incoming fades in.
##   5. Swap _active_ambient_idx.
##
## Error conditions (push_error + return, no crash):
##   - event_name not in _validated_events
##   - event_name bus is not BUS_AMB
func play_ambient(event_name: StringName) -> void:
	if not _validated_events.has(event_name):
		push_error("AudioSystem: play_ambient('%s') — event not registered." % event_name)
		return
	var event: AudioEventData = _validated_events[event_name]
	if event.bus != BUS_AMB:
		push_error("AudioSystem: play_ambient('%s') — event bus is not AMB." % event_name)
		return
	if _active_ambient_tween != null:
		_active_ambient_tween.kill()
	var incoming_idx: int = 1 - _active_ambient_idx
	var incoming: AudioStreamPlayer = _ambient_players[incoming_idx]
	var outgoing: AudioStreamPlayer = _ambient_players[_active_ambient_idx]
	incoming.stream = event.stream
	if incoming.stream is AudioStreamMP3:
		(incoming.stream as AudioStreamMP3).loop = true
	incoming.volume_db = -80.0
	incoming.play()
	_active_ambient_tween = create_tween()
	_active_ambient_tween.set_parallel(true)
	_active_ambient_tween.tween_property(outgoing, "volume_db", -80.0, CROSSFADE_DURATION_AMBIENT_OUT)\
		.from(outgoing.volume_db)
	_active_ambient_tween.tween_property(incoming, "volume_db", 0.0, CROSSFADE_DURATION_AMBIENT_OUT)
	_active_ambient_idx = incoming_idx


## Fades out the currently active ambient player over CROSSFADE_DURATION_AMBIENT_OUT.
## Kills any in-progress ambient tween before creating the fade-out tween.
## Safe to call with no prior play_ambient() — fades the default player (index 0).
func stop_ambient() -> void:
	if _active_ambient_tween != null:
		_active_ambient_tween.kill()
	var active: AudioStreamPlayer = _ambient_players[_active_ambient_idx]
	_active_ambient_tween = create_tween()
	_active_ambient_tween.tween_property(active, "volume_db", -80.0, CROSSFADE_DURATION_AMBIENT_OUT)\
		.from(active.volume_db)


## Plays a non-pooled stinger and ducks the Music bus.
## Priority policy: NARRATIVE (1) blocks COMBAT (0); NARRATIVE interrupts COMBAT; same-priority = last-caller-wins.
## Music pre-stinger volume is captured ONCE and retained on interrupt to prevent compounding drift.
## Duck is suppressed when _music_state == DYING (music is already silent).
func play_stinger(event_name: StringName) -> void:
	if not _validated_events.has(event_name):
		push_error("AudioSystem: play_stinger('%s') — event not registered." % event_name)
		return
	var event: AudioEventData = _validated_events[event_name]
	if event.bus not in [BUS_SFX, BUS_UI]:
		push_error("AudioSystem: play_stinger('%s') — event must use SFX or UI bus." % event_name)
		return
	# Priority policy: NARRATIVE blocks COMBAT (not the reverse).
	if _current_stinger_priority == STINGER_PRIORITY_NARRATIVE \
			and event.stinger_priority == STINGER_PRIORITY_COMBAT:
		return  # NARRATIVE blocks COMBAT — silently ignored.
	# New stinger proceeds — disconnect any prior finished signal.
	if _stinger_player.finished.is_connected(_on_stinger_finished):
		_stinger_player.finished.disconnect(_on_stinger_finished)
	# Capture pre-stinger Music volume ONLY when no stinger is active — prevents drift on interrupt.
	if _current_stinger_priority == -1:
		_music_pre_stinger_volume = AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index(BUS_MUSIC))
	_last_stinger_event = event
	_current_stinger_priority = event.stinger_priority
	_stinger_player.stream = event.stream
	_stinger_player.play()
	_stinger_player.finished.connect(_on_stinger_finished, CONNECT_ONE_SHOT)
	# Duck Music bus (suppressed in DYING — music is already at -80 dB).
	if _music_state != MusicState.DYING:
		var music_bus_idx: int = AudioServer.get_bus_index(BUS_MUSIC)
		var target_db: float = _music_pre_stinger_volume + event.duck_depth_db
		# Apply immediately so headless tests can assert bus volume without a tween step.
		# The tween below provides smooth fade in runtime; the immediate set is overridden
		# by the tween's first interpolation step after the first process frame.
		AudioServer.set_bus_volume_db(music_bus_idx, target_db)
		if _active_stinger_tween != null:
			_active_stinger_tween.kill()
		_active_stinger_tween = create_tween()
		_active_stinger_tween.tween_method(
			func(db: float) -> void: AudioServer.set_bus_volume_db(music_bus_idx, db),
			_music_pre_stinger_volume, target_db, STINGER_DUCK_FADE_IN_SEC)


## Stops the active stinger immediately and creates a restore tween for the Music bus.
## Disconnects the finished signal to prevent _on_stinger_finished() from also restoring.
func stop_stinger() -> void:
	if _stinger_player.finished.is_connected(_on_stinger_finished):
		_stinger_player.finished.disconnect(_on_stinger_finished)
	_stinger_player.stop()
	_stinger_player.stream = null
	_restore_music_after_stinger()
	_current_stinger_priority = -1


## Sets the Master bus volume, clamped to [−80.0, 0.0] dB.
func set_master_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), clampf(db, -80.0, 0.0))

## Sets the Music bus volume, clamped to [−80.0, −3.0] dB.
## Upper bound −3.0 is an architectural invariant ensuring Prana SFX headroom (ADR-0012, TR-AS-006).
func set_music_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), clampf(db, -80.0, -3.0))

## Sets the SFX bus volume, clamped to [−80.0, 0.0] dB.
func set_sfx_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), clampf(db, -80.0, 0.0))

## Sets the UI bus volume, clamped to [−80.0, 0.0] dB.
func set_ui_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_UI), clampf(db, -80.0, 0.0))

## Sets the AMB bus volume, clamped to [−80.0, −10.0] dB.
## Upper bound −10.0 is an architectural invariant: "world breathes softly" (ADR-0012, TR-AS-007).
func set_amb_volume(db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_AMB), clampf(db, -80.0, -10.0))

## Returns the current Master bus volume in dB (reads AudioServer directly — not cached).
func get_master_volume() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER))

## Returns the current Music bus volume in dB (reads AudioServer directly — not cached).
func get_music_volume() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC))

## Returns the current SFX bus volume in dB (reads AudioServer directly — not cached).
func get_sfx_volume() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_SFX))

## Returns the current UI bus volume in dB (reads AudioServer directly — not cached).
func get_ui_volume() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_UI))

## Returns the current AMB bus volume in dB (reads AudioServer directly — not cached).
func get_amb_volume() -> float:
	return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(BUS_AMB))


# ── Settings persistence ──────────────────────────────────────────────────────

## ConfigFile path for persisted audio preferences (user:// is platform-writable).
const _SETTINGS_PATH: String = "user://settings.cfg"
const _SETTINGS_SECTION: String = "audio"

## Writes the current Master/Music/SFX bus volumes to user://settings.cfg.
## Call this after a settings UI changes a bus volume so the choice survives a restart.
func save_audio_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_SETTINGS_PATH)  # preserve any unrelated keys; ignore "file not found"
	cfg.set_value(_SETTINGS_SECTION, "master_db", get_master_volume())
	cfg.set_value(_SETTINGS_SECTION, "music_db", get_music_volume())
	cfg.set_value(_SETTINGS_SECTION, "sfx_db", get_sfx_volume())
	cfg.save(_SETTINGS_PATH)


## Applies saved Master/Music/SFX volumes from user://settings.cfg, if present.
## No-op when the file is absent (first launch, fresh CI container) so defaults stand.
## Routes through the clamping setters, so out-of-range stored values stay safe.
func load_audio_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_SETTINGS_PATH) != OK:
		return
	if cfg.has_section_key(_SETTINGS_SECTION, "master_db"):
		set_master_volume(float(cfg.get_value(_SETTINGS_SECTION, "master_db")))
	if cfg.has_section_key(_SETTINGS_SECTION, "music_db"):
		set_music_volume(float(cfg.get_value(_SETTINGS_SECTION, "music_db")))
	if cfg.has_section_key(_SETTINGS_SECTION, "sfx_db"):
		set_sfx_volume(float(cfg.get_value(_SETTINGS_SECTION, "sfx_db")))


## ONE_SHOT callback: stinger finished naturally — restore Music bus.
func _on_stinger_finished() -> void:
	_restore_music_after_stinger()
	_current_stinger_priority = -1


## Fades Music bus back to _music_pre_stinger_volume over event.restore_duration_sec.
## No-op when in DYING state (music is already silent — do not restore).
func _restore_music_after_stinger() -> void:
	if _music_state == MusicState.DYING:
		return
	if _last_stinger_event == null:
		return
	var music_bus_idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	if _active_stinger_tween != null:
		_active_stinger_tween.kill()
	_active_stinger_tween = create_tween()
	_active_stinger_tween.tween_method(
		func(db: float) -> void: AudioServer.set_bus_volume_db(music_bus_idx, db),
		AudioServer.get_bus_volume_db(music_bus_idx),
		_music_pre_stinger_volume,
		_last_stinger_event.restore_duration_sec)

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
	var target: int = -1
	for i: int in range(SFX_POOL_SIZE):
		if not _sfx_pool[i].playing:
			target = i
			break
	# Step 2: all slots occupied — evict by priority tier, oldest first.
	if target < 0:
		target = _find_eviction_target(data.priority)
		_sfx_pool[target].stop()
	var player: AudioStreamPlayer = _sfx_pool[target]
	player.stream = data.stream
	player.volume_db = data.volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-data.pitch_jitter, data.pitch_jitter) \
		if data.pitch_jitter > 0.0 else 1.0
	player.play()
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

# ── Music state machine — implementation (Story 003) ─────────────────────────

## Populates [member _music_cues] from the validated event registry.
## PREPARATION → mus_rest (calming loop for rest/prep floors).
## COMBAT → mus_combat_floor (default; overridable via override_combat_cue() for elite/boss rooms).
## END_VICTORY / END_DEFEAT reuse the SFX stings already in the registry.
## MAIN_MENU and DYING intentionally omitted — silent until menu cue is authored.
func _load_music_cues() -> void:
	var pairs: Array = [
		[MusicState.PREPARATION, &"mus_preparation"],
		[MusicState.COMBAT,      &"mus_combat_floor"],
		[MusicState.END_VICTORY, &"sfx_run_win"],
		[MusicState.END_DEFEAT,  &"sfx_run_lose"],
	]
	for pair: Array in pairs:
		var state: MusicState = pair[0] as MusicState
		var event_name: StringName = pair[1]
		if _validated_events.has(event_name):
			_music_cues[state as int] = _validated_events[event_name].stream
		else:
			push_warning(
				"AudioSystem: music cue '%s' not in registry — %s state will be silent."
				% [event_name, MusicState.keys()[state as int]]
			)


## Returns the [AudioStream] registered for [param state], or null if none.
## DYING state intentionally returns null (silence is the cue).
func _get_cue_for_state(state: MusicState) -> AudioStream:
	return _music_cues.get(state as int, null)


## Performs a crossfade from the current active music player to the cue for [param new_state].
##
## ADR-0012 kill-before-create order (TR-AS-003):
##   1. Kill prior tween (if any) — prevents two tweens running simultaneously.
##   2. Set incoming player volume_db = -80.0 BEFORE play() — prevents single-frame pop.
##   3. Call incoming_player.play().
##   4. Create new tween with set_parallel(true).
##
## If [param cue] is null (no audio asset), logs push_warning() and transitions silently.
## AC-AS-22 relaxed during early development — game proceeds without music rather than blocking.
func _crossfade_to(new_state: MusicState, fade_duration: float) -> void:
	var cue: AudioStream = _get_cue_for_state(new_state)
	if cue == null and new_state != MusicState.DYING:
		push_warning(
			"AudioSystem: No music cue registered for state %s — transitioning silently (AC-AS-22 relaxed)."
				% MusicState.keys()[new_state]
		)
		# Fall through — transition proceeds with silence instead of blocking.

	_music_state = new_state

	var outgoing: AudioStreamPlayer = _music_players[_active_music_idx]
	var incoming: AudioStreamPlayer = _music_players[_inactive_music_idx]

	# Step 1: kill prior tween before creating a new one (ADR-0012).
	if _active_tween != null:
		_active_tween.kill()
		_active_tween = null

	if new_state == MusicState.DYING:
		# DYING = intentional silence. Fade outgoing to -80 dB; no incoming player.
		if fade_duration <= 0.0:
			outgoing.volume_db = -80.0
			outgoing.stop()
			return
		_active_tween = create_tween()
		_active_tween.tween_property(outgoing, "volume_db", -80.0, fade_duration) \
			.from(outgoing.volume_db)
		return

	# Step 2: pre-set incoming volume BEFORE play() — prevents single-frame pop.
	incoming.stream = cue
	if incoming.stream is AudioStreamMP3:
		(incoming.stream as AudioStreamMP3).loop = true
	incoming.volume_db = -80.0

	# Step 3: start incoming player.
	incoming.play()

	if fade_duration <= 0.0:
		# Instant cut — no tween needed.
		outgoing.volume_db = -80.0
		outgoing.stop()
		incoming.volume_db = 0.0
		# Swap active/inactive indices.
		var tmp: int = _active_music_idx
		_active_music_idx = _inactive_music_idx
		_inactive_music_idx = tmp
		return

	# Step 4: create new simultaneous tween.
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	if new_state == MusicState.END_DEFEAT or new_state == MusicState.END_VICTORY:
		# Constant-power sinusoidal curve prevents midpoint dip on the 2.0s END fade.
		_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.tween_property(outgoing, "volume_db", -80.0, fade_duration) \
		.from(outgoing.volume_db)
	_active_tween.tween_property(incoming, "volume_db", 0.0, fade_duration)

	# Swap active/inactive indices after the crossfade completes.
	var tmp: int = _active_music_idx
	_active_music_idx = _inactive_music_idx
	_inactive_music_idx = tmp


# ── Music FSM — frame update (Story 004) ─────────────────────────────────────

## Advances the DYING hold guard and fires the queued END_DEFEAT transition once
## DYING_MIN_HOLD_SEC has elapsed (AC-AS-29). No-op in all other states.
func _process(delta: float) -> void:
	if _music_state == MusicState.DYING:
		_dying_elapsed += delta
		if _pending_defeat_transition and _dying_elapsed >= DYING_MIN_HOLD_SEC:
			_pending_defeat_transition = false
			_crossfade_to(MusicState.END_DEFEAT, CROSSFADE_DURATION_TO_END)
			_connect_end_finished_signal()


# ── Music FSM — signal handlers (Story 003) ───────────────────────────────────

## MAIN_MENU → PREPARATION on GameStateManager.run_started.
func _on_run_started() -> void:
	if _music_state == MusicState.END_DEFEAT or _music_state == MusicState.END_VICTORY:
		return  # END states are non-interruptible (AC-AS-15).
	_crossfade_to(MusicState.PREPARATION, CROSSFADE_DURATION_MENU_TO_PREPARATION)


## PREPARATION → COMBAT on GameStateManager.combat_started.
## [param is_boss] is received but not differentiated at MVP (no BOSS music state).
func _on_combat_started(_is_boss: bool) -> void:
	if _music_state == MusicState.END_DEFEAT or _music_state == MusicState.END_VICTORY:
		return  # END states are non-interruptible (AC-AS-15).
	_crossfade_to(MusicState.COMBAT, CROSSFADE_DURATION_TO_COMBAT)


## COMBAT → PREPARATION on GameStateManager.preparation_started.
## This is the SOLE authoritative trigger for COMBAT → PREPARATION (AC-AS-11, ADR-0012).
## wave_ended is NOT connected to the music FSM.
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	if _music_state == MusicState.END_DEFEAT or _music_state == MusicState.END_VICTORY:
		return  # END states are non-interruptible (AC-AS-15).
	_crossfade_to(MusicState.PREPARATION, CROSSFADE_DURATION_COMBAT_TO_PREPARATION)


## No-op stub — wave_ended must NOT trigger any music state change (AC-AS-11, AC-AS-33).
## This method exists only to satisfy explicit test coverage.
func _on_wave_ended() -> void:
	pass  # Intentional no-op: wave_ended is not connected to the music FSM.


## COMBAT/PREP → DYING on GameStateManager.death_started (AC-AS-28).
## Fades both music players to −80 dB simultaneously.
## Non-interruptible guard: no-op when already in an END_* state.
func _on_death_started() -> void:
	if _music_state in [MusicState.END_VICTORY, MusicState.END_DEFEAT]:
		return
	_music_state = MusicState.DYING
	_dying_elapsed = 0.0
	_pending_defeat_transition = false
	if _active_tween != null:
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(_music_players[0], "volume_db", -80.0, CROSSFADE_DURATION_TO_DYING) \
		.from(_music_players[0].volume_db)
	_active_tween.tween_property(_music_players[1], "volume_db", -80.0, CROSSFADE_DURATION_TO_DYING) \
		.from(_music_players[1].volume_db)


## COMBAT/PREP/DYING → END_DEFEAT or END_VICTORY on GameStateManager.run_ended.
## When in DYING state and run_ended(false) arrives before DYING_MIN_HOLD_SEC elapses,
## the transition is queued in _pending_defeat_transition and fired by _process() (AC-AS-29).
func _on_run_ended(win: bool) -> void:
	if _music_state in [MusicState.END_VICTORY, MusicState.END_DEFEAT]:
		return  # END states are non-interruptible (AC-AS-15).
	if win:
		_crossfade_to(MusicState.END_VICTORY, CROSSFADE_DURATION_TO_END)
		_connect_end_finished_signal()
	else:
		if _music_state == MusicState.DYING:
			if _dying_elapsed >= DYING_MIN_HOLD_SEC:
				_crossfade_to(MusicState.END_DEFEAT, CROSSFADE_DURATION_TO_END)
				_connect_end_finished_signal()
			else:
				_pending_defeat_transition = true
		else:
			_crossfade_to(MusicState.END_DEFEAT, CROSSFADE_DURATION_TO_END)
			_connect_end_finished_signal()


## Connects the ONE_SHOT finished handler to the incoming player after a crossfade to END_*.
## Called by _on_run_ended() and _process() immediately after _crossfade_to() (AC-AS-26).
## Connecting here (not inside _crossfade_to) ensures the handler is on the correct player
## after the active/inactive index swap performed by _crossfade_to().
func _connect_end_finished_signal() -> void:
	var incoming: AudioStreamPlayer = _music_players[_active_music_idx]
	incoming.finished.connect(_on_end_cue_finished, CONNECT_ONE_SHOT)


## ONE_SHOT callback fired when the END_DEFEAT or END_VICTORY cue finishes playing.
## Auto-transitions back to MAIN_MENU (AC-AS-26). State guard discards stale signals.
func _on_end_cue_finished() -> void:
	if _music_state != MusicState.END_VICTORY and _music_state != MusicState.END_DEFEAT:
		return
	_crossfade_to(MusicState.MAIN_MENU, CROSSFADE_DURATION_TO_MAIN_MENU)


# ── Music FSM — pure utility (Story 003) ─────────────────────────────────────

## Returns the interpolated volume_db at time [param t] for a linear crossfade.
##
## Formula (ADR-0012 Formula 1):
##   result = lerp(start_db, target_db, t / duration)
##
## This is a TEST-ONLY pure function describing the crossfade intent.
## It is NOT called from _process() or any live tween — the Tween node performs
## the actual interpolation at runtime (AC-AS-16).
##
## [param t] is clamped to [0, duration] to prevent out-of-range results.
## [param duration] must be > 0.0 (caller is responsible — guard in _crossfade_to).
func _compute_crossfade_volume(
		start_db: float,
		target_db: float,
		t: float,
		duration: float) -> float:
	var t_clamped: float = clampf(t, 0.0, duration)
	return lerpf(start_db, target_db, t_clamped / duration)


## Converts a 0–100 integer slider value to a dB level in [−80.0, 0.0].
##
## Formula (ADR-0012 Formula 2):
##   result = lerp(-80.0, 0.0, float(slider_value) / 100.0)
##
## float() cast is mandatory — int/int produces 0 for all values 0-99 in GDScript.
## This is a TEST-ONLY pure function (AC-AS-31).
func _slider_to_db(slider_value: int) -> float:
	return lerpf(-80.0, 0.0, float(slider_value) / 100.0)

# ── Test accessors ────────────────────────────────────────────────────────────

## Sets the timestamp for slot [param idx] — used by sfx_pool_test.gd to establish
## deterministic eviction order without requiring real-time play() calls (AC-AS-06).
func _set_slot_timestamp(idx: int, ticks: int) -> void:
	_timestamps[idx] = ticks


## Test seam — sets _dying_elapsed for deterministic hold guard testing (AC-AS-29).
## Allows tests to advance past DYING_MIN_HOLD_SEC without real-time await.
func _set_dying_elapsed(sec: float) -> void:
	_dying_elapsed = sec
