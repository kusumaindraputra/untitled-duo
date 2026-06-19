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

## Maps MusicState → AudioStream resource. Populated by _load_music_cues().
## null entries are valid (e.g. DYING has no cue by design).
var _music_cues: Dictionary[int, AudioStream] = {}

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

# ── Music state machine — implementation (Story 003) ─────────────────────────

## Populates [member _music_cues] from audio-director-delivered resource paths.
## Stub for Story 003 — assets are not yet delivered; cues are null by default.
## Story 004 will replace this stub with actual resource loads.
func _load_music_cues() -> void:
	pass  # Story 004: load cue resources from AudioEventRegistry or dedicated paths.


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
## If [param cue] is null, logs push_error() and returns without changing state (AC-AS-22).
## If [param fade_duration] <= 0.0, applies instant cut (no tween) per ADR-0012 guard.
## Connects [signal AudioStreamPlayer.finished] via CONNECT_ONE_SHOT on incoming player
## when transitioning to END_VICTORY or END_DEFEAT (auto-returns to MAIN_MENU, AC-AS-26).
func _crossfade_to(new_state: MusicState, fade_duration: float) -> void:
	var cue: AudioStream = _get_cue_for_state(new_state)
	if cue == null and new_state != MusicState.DYING:
		push_error(
			"AudioSystem: No music cue registered for state %s — transition to %s blocked (AC-AS-22)."
				% [MusicState.keys()[new_state], MusicState.keys()[new_state]]
		)
		return

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
	incoming.volume_db = -80.0

	# Step 3: start incoming player.
	incoming.play()

	# Connect ONE_SHOT finished handler for END states (auto-transition to MAIN_MENU).
	if new_state == MusicState.END_DEFEAT or new_state == MusicState.END_VICTORY:
		incoming.finished.connect(_on_end_cue_finished, CONNECT_ONE_SHOT)

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


## COMBAT/PREP → DYING on GameStateManager.death_started (Story 004).
## Stub for Story 003 — DYING hold guard (AC-AS-29) implemented in Story 004.
func _on_death_started() -> void:
	pass  # Story 004: implement DYING hold guard and pending defeat transition.


## COMBAT/PREP → END_DEFEAT or END_VICTORY on GameStateManager.run_ended.
## Also handles defensive fallback: DYING → END_DEFEAT on run_ended(win: false)
## after DYING_MIN_HOLD_SEC has elapsed (Story 004).
func _on_run_ended(win: bool) -> void:
	if _music_state == MusicState.END_DEFEAT or _music_state == MusicState.END_VICTORY:
		return  # END states are non-interruptible (AC-AS-15).
	if win:
		_crossfade_to(MusicState.END_VICTORY, CROSSFADE_DURATION_TO_END)
	else:
		_crossfade_to(MusicState.END_DEFEAT, CROSSFADE_DURATION_TO_END)


## ONE_SHOT callback connected to incoming player.finished when entering END_*.
## Auto-transitions back to MAIN_MENU (AC-AS-26).
func _on_end_cue_finished() -> void:
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

# ── Test accessors ────────────────────────────────────────────────────────────

## Sets the timestamp for slot [param idx] — used by sfx_pool_test.gd to establish
## deterministic eviction order without requiring real-time play() calls (AC-AS-06).
func _set_slot_timestamp(idx: int, ticks: int) -> void:
	_timestamps[idx] = ticks
