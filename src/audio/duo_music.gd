## DuoMusic — the music leans toward the brother in the arena (ADR-0058,
## design/gdd/duo-swap.md Rule 6i).
##
## Two shelf filters on the Music bus: a low shelf for Ayden (weight) and a high shelf
## for Faith (air). A swap fades the gain from one band to the other, a Link Burst
## swells both, and every shared heartbeat plays a soft thump, low for Ayden and
## pitched up for Faith, so the player can hear when a swap would Resonate. The thump
## is synthesised, so no audio file is needed. Run-scoped: created by debug_game_loop;
## the filters go back to flat when it leaves the tree.
class_name DuoMusic
extends Node

const TUNING: DuoTuning = preload("res://assets/data/duo_tuning.tres")
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const LOW_NAME: String = "DuoAyden"
const HIGH_NAME: String = "DuoFaith"

var tuning: DuoTuning = TUNING
var _low: AudioEffectLowShelfFilter = null
var _high: AudioEffectHighShelfFilter = null
var _thump: AudioStreamPlayer = null
var _tween: Tween = null
var _character: int = DuoSwap.NONE


func _ready() -> void:
	_install_filters()
	_thump = AudioStreamPlayer.new()
	_thump.name = "HeartThump"
	_thump.bus = BUS_SFX if AudioServer.get_bus_index(BUS_SFX) != -1 else &"Master"
	_thump.stream = make_thump()
	_thump.volume_db = tuning.thump_db
	add_child(_thump)


func _exit_tree() -> void:
	_set_gains(Vector2.ONE)


## (low, high) shelf gains for [param character]: the brother's band raised.
static func voice_gains(character: int, t: DuoTuning = TUNING) -> Vector2:
	if not t.duo_music:
		return Vector2.ONE
	match character:
		DuoSwap.Character.AYDEN: return Vector2(t.voice_gain, 1.0)
		DuoSwap.Character.FAITH: return Vector2(1.0, t.voice_gain)
	return Vector2.ONE


## Thump pitch for [param character].
static func thump_pitch(character: int, t: DuoTuning = TUNING) -> float:
	return t.faith_thump_pitch if character == DuoSwap.Character.FAITH else 1.0


## A short decaying 55 Hz sine: the heart thump. [param seconds] long at
## [param rate] Hz, 16-bit mono.
static func make_thump(seconds: float = 0.16, rate: int = 22050) -> AudioStreamWAV:
	var n: int = maxi(int(seconds * float(rate)), 1)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i: int in n:
		var t: float = float(i) / float(rate)
		var env: float = exp(-t * 28.0) * minf(t * 400.0, 1.0)
		var v: float = sin(TAU * 55.0 * t) * env * 0.9
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


## PlayerController.character_swapped: lean the music toward [param character].
func on_character_swapped(character: int, _cooldown: float = 0.0) -> void:
	_character = character
	_fade_to(voice_gains(character, tuning), tuning.voice_fade_sec)


## PlayerController.heartbeat: one thump in the brother's pitch.
func on_heartbeat(character: int) -> void:
	if not tuning.heartbeat_thump or _thump == null or not _thump.is_inside_tree():
		return
	_thump.pitch_scale = thump_pitch(character, tuning)
	_thump.play()


## SpellCastingEffects.link_burst: both bands swell, then lean back.
func on_link_burst(_name: String, _pos: Vector2, _radius: float, _character: int) -> void:
	if not tuning.duo_music:
		return
	_fade_to(Vector2(tuning.voice_gain, tuning.voice_gain), 0.05)
	if is_inside_tree():
		get_tree().create_timer(tuning.link_burst_music_sec, false).timeout.connect(
			func() -> void: _fade_to(voice_gains(_character, tuning), tuning.voice_fade_sec))


## Current (low, high) shelf gains (tests).
func get_gains() -> Vector2:
	return Vector2(_low.gain if _low else 1.0, _high.gain if _high else 1.0)


func _install_filters() -> void:
	var idx: int = AudioServer.get_bus_index(BUS_MUSIC)
	if idx == -1:
		return
	for slot: int in AudioServer.get_bus_effect_count(idx):
		var e: AudioEffect = AudioServer.get_bus_effect(idx, slot)
		if e.resource_name == LOW_NAME:
			_low = e as AudioEffectLowShelfFilter
		elif e.resource_name == HIGH_NAME:
			_high = e as AudioEffectHighShelfFilter
	if _low == null:
		_low = AudioEffectLowShelfFilter.new()
		_low.resource_name = LOW_NAME
		AudioServer.add_bus_effect(idx, _low)
	if _high == null:
		_high = AudioEffectHighShelfFilter.new()
		_high.resource_name = HIGH_NAME
		AudioServer.add_bus_effect(idx, _high)
	_low.cutoff_hz = tuning.ayden_shelf_hz
	_high.cutoff_hz = tuning.faith_shelf_hz
	_set_gains(Vector2.ONE)


func _fade_to(gains: Vector2, seconds: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if seconds <= 0.0 or not is_inside_tree():
		_set_gains(gains)
		return
	_tween = create_tween()
	_tween.tween_method(_set_gains, get_gains(), gains, seconds)


func _set_gains(g: Vector2) -> void:
	if _low != null:
		_low.gain = g.x
	if _high != null:
		_high.gain = g.y
