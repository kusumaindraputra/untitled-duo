## screen_shake.gd — ScreenShake Autoload: the one owner of Camera2D.offset (ADR-0040).
##
## Every system that wants the screen to shake calls this instead of touching the
## camera. Shakes from different sources add into one trauma value and one
## directional kick (see ShakeState), so two hits in one frame no longer fight over
## the offset.
##
## API (all fire-and-forget, safe with no camera):
##   ScreenShake.impact(ShakeState.Strength.HEAVY, direction)  # preferred: named sizes
##   ScreenShake.add_trauma(0.3, direction)                    # raw trauma 0–1
##   ScreenShake.kick(direction, 6.0)                          # a lurch only, no rattle
##   ScreenShake.reset()                                       # settle at once
## direction is the way the blow travels (e.g. attacker → target); the view lurches
## that way and springs back. Vector2.ZERO = no kick.
##
## Settings: every shake is scaled by the Screen shake slider and, with Reduce
## motion on, by ShakeTuning.reduce_motion_scale. Runs on real time, so it keeps
## moving through hit-stop but stops while the game is paused.
## Gamepad rumble stays separate (Rumble, ADR-0031).
##
## Registration: Autoload in project.godot. No class_name — Godot 4.6 rejects a
## class_name matching the Autoload name; the pure logic lives in ShakeState.
extends Node

## Longest real-time step taken in one frame, so a hitch or unpause does not jump.
const MAX_STEP_SEC: float = 1.0 / 20.0

var state: ShakeState = ShakeState.new()
var _camera: Camera2D = null
var _last_us: int = 0


func _ready() -> void:
	_last_us = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = minf(float(now - _last_us) / 1_000_000.0, MAX_STEP_SEC)
	_last_us = now
	tick(dt)


## Shakes by a named [param strength] (ShakeState.Strength) with an optional kick
## along [param direction].
func impact(strength: ShakeState.Strength, direction: Vector2 = Vector2.ZERO) -> void:
	add_trauma(state.tuning.preset(strength), direction)


## Adds [param amount] trauma (0–1) with an optional kick along [param direction].
func add_trauma(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	state.add_trauma(amount, direction, settings_multiplier())


## Lurches the view [param pixels] along [param direction] with no rattle.
func kick(direction: Vector2, pixels: float) -> void:
	state.add_kick(direction, pixels, settings_multiplier())


## Current trauma, 0 to 1.
func get_trauma() -> float:
	return state.trauma


## Stops all shaking and puts the camera back at rest.
func reset() -> void:
	state.reset()
	if is_instance_valid(_camera):
		_camera.offset = Vector2.ZERO


## Advances the shake by [param dt] seconds and writes the camera offset. Called from
## _process; public so tests can step it.
func tick(dt: float) -> void:
	var cam: Camera2D = _active_camera()
	if cam != _camera:
		if is_instance_valid(_camera):
			_camera.offset = Vector2.ZERO
		_camera = cam
	if state.is_idle() and state.offset == Vector2.ZERO:
		return
	var off: Vector2 = state.step(dt)
	if is_instance_valid(_camera):
		_camera.offset = off


## Share of each shake the player's settings allow: the Screen shake slider, times
## ShakeTuning.reduce_motion_scale when Reduce motion is on.
static func settings_multiplier() -> float:
	var m: float = GameSettings.shake_multiplier()
	if GameSettings.motion_reduced():
		m *= ShakeState.DEFAULT_TUNING.reduce_motion_scale
	return m


func _active_camera() -> Camera2D:
	var vp: Viewport = get_viewport()
	return vp.get_camera_2d() if vp != null else null
