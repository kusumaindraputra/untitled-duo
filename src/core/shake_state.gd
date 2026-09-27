## ShakeState — the pure math behind the ScreenShake autoload (ADR-0040).
##
## Holds trauma (0–1) and a directional kick, and turns them into a camera offset
## each step. No nodes, no clocks: step() takes the delta and the noise runs off its
## own accumulated time, so tests get the same numbers every run.
class_name ShakeState
extends RefCounted

## Named shake sizes. Callers pick one instead of a raw trauma number, so every
## system shakes on the same scale (values in ShakeTuning).
enum Strength { LIGHT, MEDIUM, HEAVY, MASSIVE }

const DEFAULT_TUNING: ShakeTuning = preload("res://assets/data/shake_tuning.tres")
## Kicks shorter than this (px) snap to zero so the camera settles exactly.
const KICK_REST_PX: float = 0.05

var tuning: ShakeTuning = DEFAULT_TUNING
## Current trauma, 0 to 1. Decays by tuning.trauma_decay per second.
var trauma: float = 0.0
## Current directional kick in game px. Returns to zero exponentially.
var kick: Vector2 = Vector2.ZERO
## Offset computed by the last step().
var offset: Vector2 = Vector2.ZERO
var _time: float = 0.0


func _init(p_tuning: ShakeTuning = null) -> void:
	if p_tuning != null:
		tuning = p_tuning


## Adds [param amount] trauma, scaled by [param mult] (the player's settings) and
## clamped to 1. A non-zero [param direction] also kicks the view along it, in
## proportion to the amount.
func add_trauma(amount: float, direction: Vector2 = Vector2.ZERO, mult: float = 1.0) -> void:
	var a: float = maxf(amount, 0.0) * clampf(mult, 0.0, 1.0)
	if a <= 0.0:
		return
	trauma = minf(trauma + a, 1.0)
	if direction != Vector2.ZERO:
		add_kick(direction, amount * tuning.kick_per_trauma_px, mult)


## Pushes the view [param pixels] along [param direction], scaled by [param mult].
## Kicks stack but never exceed tuning.kick_max_px.
func add_kick(direction: Vector2, pixels: float, mult: float = 1.0) -> void:
	if direction == Vector2.ZERO or pixels <= 0.0:
		return
	kick += direction.normalized() * pixels * clampf(mult, 0.0, 1.0)
	kick = kick.limit_length(tuning.kick_max_px)


## Advances by [param delta] real seconds and returns the new camera offset.
func step(delta: float) -> Vector2:
	var dt: float = maxf(delta, 0.0)
	_time += dt
	trauma = maxf(trauma - tuning.trauma_decay * dt, 0.0)
	kick *= exp(-tuning.kick_return * dt)
	if kick.length() < KICK_REST_PX:
		kick = Vector2.ZERO
	var s: float = trauma * trauma * tuning.max_offset_px
	offset = kick
	if s > 0.0:
		offset += Vector2(noise(_time * tuning.noise_speed, 0.0),
			noise(_time * tuning.noise_speed, 17.3)) * s
	return offset


## True when nothing is shaking (the camera offset can rest at zero).
func is_idle() -> bool:
	return trauma <= 0.0 and kick == Vector2.ZERO


## Drops all trauma and kick at once (a new room, the prep phase).
func reset() -> void:
	trauma = 0.0
	kick = Vector2.ZERO
	offset = Vector2.ZERO


## Smooth pseudo-noise in [-1, 1] at time [param t]; [param seed] picks the axis.
## Two detuned sines — cheap, continuous and deterministic. Pure.
static func noise(t: float, seed: float) -> float:
	return sin(t + seed) * 0.6 + sin(t * 2.31 + seed * 1.7) * 0.4
