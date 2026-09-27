## BossDeathCinematic — the beat between a boss's last hit and the reward screen (ADR-0041).
##
## When a boss dies: time drops into slow-mo, a white flash hits, the music cuts to
## a low boom (a ducking stinger), and a cinematic Camera2D glides onto the boss,
## holds while its sprite dissolves (EnemyInstance uses the longer boss dissolve),
## then glides back to Fayde's camera. [signal finished] fires at the end, and the
## run loop waits for it before the memory card or run summary opens.
##
## Reduce motion skips the camera move (the beat still holds for its full length);
## the flash follows the Reduce flashes setting. Slow-mo goes through DeferredWarp,
## so it never overrides another TimeWarp. The cinematic camera is its own Camera2D,
## so it never writes a camera offset: the kill shake goes through ShakeHook to the
## ScreenShake autoload (ADR-0040), which owns the offset.
## Created by debug_game_loop, which wires [member flash_layer] in its _ready().
class_name BossDeathCinematic
extends Node

## The cinematic ended and Fayde's camera is current again.
signal finished

enum Phase { IDLE = 0, ZOOM_IN = 1, HOLD = 2, ZOOM_OUT = 3 }

const TUNING: BigMomentTuning = preload("res://assets/data/big_moment_tuning.tres")
## Stinger that ducks the music and plays the boss-felled boom.
const STINGER: StringName = &"stg_boss_felled"

## CanvasLayer the white flash is drawn on. Null = the cinematic makes its own.
var flash_layer: CanvasLayer = null

var _phase: Phase = Phase.IDLE
## Real seconds spent in the current phase.
var _phase_t: float = 0.0
## Real seconds since the cinematic started (drives the flash).
var _elapsed: float = 0.0
var _plan: Dictionary = {}
var _warp: DeferredWarp = DeferredWarp.new()
var _camera: Camera2D = null
var _prev_camera: Camera2D = null
var _from_pos: Vector2 = Vector2.ZERO
var _from_zoom: Vector2 = Vector2.ONE
var _focus_pos: Vector2 = Vector2.ZERO
var _focus_zoom: Vector2 = Vector2.ONE
var _flash: ColorRect = null
var _flash_peak: float = 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)


func _exit_tree() -> void:
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
	_restore_camera()


func _process(delta: float) -> void:
	# Real seconds: the whole beat plays through its own slow-mo.
	if _phase != Phase.IDLE:
		advance(minf(DeferredWarp.real_delta(delta), 0.1))


## The beat's timing in real seconds: { zoom_in, hold, zoom_out, total, camera }.
## [param reduce_motion] drops the camera glide but keeps the beat as long, so the
## dissolve still gets its moment.
static func plan(t: BigMomentTuning, reduce_motion: bool) -> Dictionary:
	var zoom_in: float = maxf(t.boss_zoom_in_sec, 0.0)
	var hold: float = maxf(t.boss_hold_sec, 0.0)
	var zoom_out: float = 0.0 if reduce_motion else maxf(t.boss_zoom_out_sec, 0.0)
	return {
		"zoom_in": zoom_in, "hold": hold, "zoom_out": zoom_out,
		"total": zoom_in + hold + zoom_out, "camera": not reduce_motion,
	}


## Flash alpha [param elapsed] real seconds after the kill: full at once, then an
## ease-out fade over boss_flash_sec. [param flash_mult] is the Reduce flashes scale.
static func flash_alpha(t: BigMomentTuning, elapsed: float, flash_mult: float) -> float:
	if t.boss_flash_sec <= 0.0 or elapsed >= t.boss_flash_sec:
		return 0.0
	var k: float = 1.0 - clampf(elapsed / t.boss_flash_sec, 0.0, 1.0)
	return t.boss_flash_alpha * clampf(flash_mult, 0.0, 1.0) * k * k


## Real seconds a boss dissolve of [param t].boss_dissolve_sec game seconds takes when
## it starts with the boss slow-mo (assuming the slow-mo starts at once). The data
## test keeps this inside the beat, so the camera never leaves a half-gone boss.
static func dissolve_real_sec(t: BigMomentTuning) -> float:
	var slow_game: float = t.boss_slowmo_scale * t.boss_slowmo_sec
	if t.boss_dissolve_sec <= slow_game:
		return t.boss_dissolve_sec / maxf(t.boss_slowmo_scale, 0.01)
	return t.boss_slowmo_sec + (t.boss_dissolve_sec - slow_game)


## Smoothstep ease for camera glides, [param x] in 0..1.
static func ease_glide(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## True while the beat is running.
func is_playing() -> bool:
	return _phase != Phase.IDLE


## Current phase (for tests).
func get_phase() -> Phase:
	return _phase


## Starts the beat on a boss that died at [param world_pos]. Returns false (and does
## nothing) while a beat is already running.
func play(world_pos: Vector2) -> bool:
	if _phase != Phase.IDLE:
		return false
	_plan = plan(TUNING, GameSettings.motion_reduced())
	_elapsed = 0.0
	_phase_t = 0.0
	_focus_pos = world_pos
	_warp.request(TUNING.boss_slowmo_scale, TUNING.boss_slowmo_sec, TUNING.slowmo_wait_sec)
	_begin_flash()
	_play_stinger()
	ShakeHook.impact(ShakeHook.MASSIVE)
	if bool(_plan["camera"]):
		_begin_camera()
	_phase = Phase.ZOOM_IN
	return true


## Moves the beat forward by [param real_dt] real seconds. Public for tests.
func advance(real_dt: float) -> void:
	if _phase == Phase.IDLE:
		return
	_elapsed += real_dt
	_phase_t += real_dt
	if is_inside_tree():
		_warp.tick(get_tree(), real_dt)
	_update_flash()
	match _phase:
		Phase.ZOOM_IN:
			_glide(_from_pos, _focus_pos, _from_zoom, _focus_zoom, _progress(&"zoom_in"))
			if _phase_t >= float(_plan["zoom_in"]):
				_enter(Phase.HOLD)
		Phase.HOLD:
			if _phase_t >= float(_plan["hold"]):
				_enter(Phase.ZOOM_OUT)
		Phase.ZOOM_OUT:
			var back: Vector2 = _from_pos
			if is_instance_valid(_prev_camera):
				back = _prev_camera.get_screen_center_position()
			_glide(_focus_pos, back, _focus_zoom, _from_zoom, _progress(&"zoom_out"))
			if _phase_t >= float(_plan["zoom_out"]):
				_finish()


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_enemy_killed(instance_id: int, _type_id: int, _affiliation: GameEnums.DamageClass) -> void:
	var enemy: Node2D = instance_from_id(instance_id) as Node2D
	if is_instance_valid(enemy) and enemy.has_method(&"is_boss") and enemy.is_boss():
		play(enemy.global_position)


# ── Private ───────────────────────────────────────────────────────────────────

func _progress(key: StringName) -> float:
	var d: float = float(_plan[key])
	return 1.0 if d <= 0.0 else _phase_t / d


func _enter(p: Phase) -> void:
	_phase = p
	_phase_t = 0.0
	# A zero-length phase finishes in the same tick.
	if p == Phase.HOLD and float(_plan["hold"]) <= 0.0:
		_enter(Phase.ZOOM_OUT)
	elif p == Phase.ZOOM_OUT and float(_plan["zoom_out"]) <= 0.0:
		_finish()


func _finish() -> void:
	_phase = Phase.IDLE
	_warp.cancel()
	_restore_camera()
	if is_instance_valid(_flash):
		_flash.color.a = 0.0
	finished.emit()


## Swaps in a cinematic camera that starts exactly where Fayde's camera is looking.
func _begin_camera() -> void:
	if not is_inside_tree():
		return
	_prev_camera = get_viewport().get_camera_2d()
	if _prev_camera == null:
		return
	_from_pos = _prev_camera.get_screen_center_position()
	_from_zoom = _prev_camera.zoom
	_focus_zoom = _from_zoom * TUNING.boss_zoom_mult
	_camera = Camera2D.new()
	_camera.name = "BossDeathCamera"
	_camera.limit_left = _prev_camera.limit_left
	_camera.limit_top = _prev_camera.limit_top
	_camera.limit_right = _prev_camera.limit_right
	_camera.limit_bottom = _prev_camera.limit_bottom
	_camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	add_child(_camera)
	_camera.global_position = _from_pos
	_camera.zoom = _from_zoom
	_camera.make_current()


func _glide(a: Vector2, b: Vector2, za: Vector2, zb: Vector2, x: float) -> void:
	if not is_instance_valid(_camera):
		return
	var e: float = ease_glide(x)
	_camera.global_position = a.lerp(b, e)
	_camera.zoom = za.lerp(zb, e)


func _restore_camera() -> void:
	if is_instance_valid(_prev_camera) and _prev_camera.is_inside_tree():
		_prev_camera.make_current()
	if is_instance_valid(_camera):
		_camera.queue_free()
	_camera = null
	_prev_camera = null


func _begin_flash() -> void:
	_flash_peak = flash_alpha(TUNING, 0.0, GameSettings.flash_multiplier())
	if _flash_peak <= 0.0 or not is_inside_tree():
		return
	if not is_instance_valid(_flash):
		var layer: CanvasLayer = flash_layer
		if not is_instance_valid(layer):
			layer = CanvasLayer.new()
			layer.layer = 15
			add_child(layer)
		_flash = ColorRect.new()
		_flash.name = "BossDeathFlash"
		_flash.color = Color(1.0, 1.0, 1.0, 0.0)
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_flash)
	_update_flash()


func _update_flash() -> void:
	if is_instance_valid(_flash):
		_flash.color.a = flash_alpha(TUNING, _elapsed, GameSettings.flash_multiplier())


func _play_stinger() -> void:
	if not is_inside_tree():
		return
	var audio: Node = get_tree().root.get_node_or_null(^"AudioSystem")
	if audio != null and audio.has_method(&"has_event") and audio.has_event(STINGER):
		audio.play_stinger(STINGER)
