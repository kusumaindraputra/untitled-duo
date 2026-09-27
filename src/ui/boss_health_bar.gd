## BossHealthBar — the top-centre boss HP bar (ADR-0045).
##
## Drawn by hand instead of a ProgressBar so it can show three things a plain bar
## cannot: a notch at every HP phase threshold of the boss (ADR-0018 pattern layers),
## a ghost chunk that holds the HP just lost and then drains (same read as Fayde's bar,
## ADR-0042), and a short white flash when the boss enters a new phase.
##
## Keeps ProgressBar's [member max_value] / [member value] names so CombatHUD sets it
## the same way. Timings live in assets/data/hud_readout_tuning.tres. The ghost and
## flash maths are static so they are unit-tested headless.
class_name BossHealthBar
extends Control

const TUNING: HudReadoutTuning = preload("res://assets/data/hud_readout_tuning.tres")

## Track behind the fill.
const TRACK_COLOR := Color(0.12, 0.04, 0.05, 0.85)
## Live HP fill.
const FILL_COLOR := Color(0.78, 0.16, 0.18)
## HP lost in the last hit, before the ghost drains.
const GHOST_COLOR := Color(0.95, 0.82, 0.62, 0.9)
## Phase notch still ahead of the boss's HP, and one already crossed.
const NOTCH_COLOR := UIPalette.VOID
const NOTCH_PASSED_COLOR := Color(0.1, 0.1, 0.13, 0.45)

var tuning: HudReadoutTuning = TUNING

## Boss max HP. Setting it resets value and ghost to full.
var max_value: float = 100.0:
	set(v):
		max_value = maxf(v, 1.0)
		value = max_value
		_ghost = max_value
		_hold_left = 0.0
		queue_redraw()

## Boss current HP. A drop leaves a ghost chunk; a rise moves the ghost with it.
var value: float = 100.0:
	set(v):
		var nv: float = clampf(v, 0.0, max_value)
		if nv < value:
			_ghost = maxf(_ghost, value)
			_hold_left = tuning.boss_ghost_hold_sec
		else:
			_ghost = maxf(_ghost, nv)
		value = nv
		queue_redraw()

## HP ratios (0–1) where the boss gains a pattern layer, highest first.
var _thresholds: PackedFloat32Array = PackedFloat32Array()
var _ghost: float = 100.0
var _hold_left: float = 0.0
var _flash_left: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Distinct phase thresholds from [param ratios]: kept only inside (0, 1), sorted
## highest first. Layers sharing a threshold are one phase (ADR-0018).
static func clean_thresholds(ratios: PackedFloat32Array) -> PackedFloat32Array:
	var seen: Dictionary = {}
	for r: float in ratios:
		if r > 0.0 and r < 1.0:
			seen[snappedf(r, 0.0001)] = true
	var out: Array = seen.keys()
	out.sort()
	out.reverse()
	return PackedFloat32Array(out)


## One ghost tick: returns Vector2(ghost, hold_left). The ghost waits out
## [param hold_left], then drains toward [param current] at [param drain] × max per second.
static func ghost_step(ghost: float, current: float, hold_left: float, delta: float,
		drain: float, max_hp: float) -> Vector2:
	if ghost <= current:
		return Vector2(current, 0.0)
	if hold_left > 0.0:
		return Vector2(ghost, maxf(hold_left - delta, 0.0))
	return Vector2(maxf(ghost - drain * max_hp * delta, current), 0.0)


## Flash alpha with [param left] of [param total] seconds remaining (linear fade).
static func flash_alpha(left: float, total: float, peak: float) -> float:
	if total <= 0.0 or left <= 0.0:
		return 0.0
	return peak * clampf(left / total, 0.0, 1.0)


## Sets the phase notches from raw threshold ratios (see [method clean_thresholds]).
func set_thresholds(ratios: PackedFloat32Array) -> void:
	_thresholds = clean_thresholds(ratios)
	queue_redraw()


func get_thresholds() -> PackedFloat32Array:
	return _thresholds


## Ghost chunk end in HP (test hook).
func get_ghost() -> float:
	return _ghost


## True while the phase flash is showing (test hook).
func is_flashing() -> bool:
	return _flash_left > 0.0


## Starts the new-phase flash.
func flash_phase() -> void:
	_flash_left = tuning.boss_phase_flash_sec
	queue_redraw()


## Advances the ghost and flash by [param delta] seconds. Called from _process;
## public so tests can step it without a SceneTree.
func tick(delta: float) -> void:
	if _ghost > value:
		var g: Vector2 = ghost_step(_ghost, value, _hold_left, delta,
			tuning.boss_ghost_drain_per_sec, max_value)
		_ghost = g.x
		_hold_left = g.y
		queue_redraw()
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		queue_redraw()


func _process(delta: float) -> void:
	tick(delta)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, TRACK_COLOR)
	var w: float = size.x
	var ghost_w: float = w * clampf(_ghost / max_value, 0.0, 1.0)
	var fill_w: float = w * clampf(value / max_value, 0.0, 1.0)
	if ghost_w > fill_w:
		draw_rect(Rect2(fill_w, 0.0, ghost_w - fill_w, size.y), GHOST_COLOR)
	if fill_w > 0.0:
		draw_rect(Rect2(0.0, 0.0, fill_w, size.y), FILL_COLOR)
	var ratio: float = value / max_value
	var nw: float = tuning.boss_notch_width
	for t: float in _thresholds:
		var x: float = roundf(w * t - nw * 0.5)
		draw_rect(Rect2(x, 0.0, nw, size.y), NOTCH_PASSED_COLOR if ratio <= t else NOTCH_COLOR)
	var a: float = flash_alpha(_flash_left, tuning.boss_phase_flash_sec, tuning.boss_phase_flash_alpha)
	if a > 0.0:
		draw_rect(r, Color(1, 1, 1, a))
