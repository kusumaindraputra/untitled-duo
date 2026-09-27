## spawn_glyph.gd — The rune circle an enemy rises out of (ADR-0043).
##
## WaveManager drops one on the floor at every spawn point. Timeline, from 0:
##   draw   (draw_sec)            the outer ring sweeps closed, runes appear one by one
##   hold   ([member hold] sec)   reinforcements only: the finished glyph pulses as a warning
##   rise   (rise_sec + settle)   the enemy rises out of it (tweened by WaveManager)
##   fade   (fade_sec)            the glyph fades and frees itself
## Drawn as pixel runs through PixelVFX (ADR-0023), flattened by iso_ratio so it lies on
## the isometric floor, in the enemy family rim colour (ADR-0037).
class_name SpawnGlyph
extends Node2D

const TUNING: SpawnGlyphTuning = preload("res://assets/data/spawn_glyph_tuning.tres")
const PALETTE: EnemyBulletPalette = preload("res://assets/data/enemy_bullet_palette.tres")
## Floor draw layer: over the tiles and floor hazards, under every y-sorted entity.
const FLOOR_Z: int = 3
## The outer ring closes in this many steps, so its spans can be cached.
const SWEEP_STEPS: int = 12
## Ellipse segments for a full ring.
const RING_SEGMENTS: int = 32

## Seconds the finished glyph waits before the enemy rises (reinforcement warning).
var hold: float = 0.0
## Multiplier on the tuning radius (bosses and elites are bigger).
var size_mult: float = 1.0
## Overrides the tuning (tests); null = TUNING.
var tuning: SpawnGlyphTuning = null

var _elapsed: float = 0.0
var _color: Color = PALETTE.rim
## Span cache keyed by sweep step × rotation step — the shape only changes on steps.
var _cache: Dictionary = {}


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	z_index = FLOOR_Z
	if tuning == null:
		tuning = TUNING


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= total_sec(tuning, hold):
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a: float = alpha_at(_elapsed, tuning, hold)
	if a <= 0.0:
		return
	var sweep_step: int = ceili(sweep_at(_elapsed, tuning) * float(SWEEP_STEPS))
	var rot_step: int = 0
	if not GameSettings.motion_reduced() and tuning.rune_count > 0:
		var step_angle: float = TAU / float(tuning.rune_count * 4)
		rot_step = int(floorf(_elapsed * tuning.spin_speed / step_angle)) % (tuning.rune_count * 4)
	var key: int = sweep_step * 1000 + rot_step
	if not _cache.has(key):
		_cache[key] = _build_spans(float(sweep_step) / float(SWEEP_STEPS),
				float(rot_step) * TAU / float(maxi(tuning.rune_count * 4, 1)))
	var spans: Array = _cache[key]
	var ramp: Array[Color] = PixelVFX.palette(_color)
	var o: Vector2 = PixelVFX.snap_origin(self)
	PixelVFX.draw_spans(self, spans[0], PixelVFX.with_alpha(ramp[0], a * 0.75), o)
	PixelVFX.draw_spans(self, spans[1], PixelVFX.with_alpha(ramp[1], a), o)
	PixelVFX.draw_spans(self, spans[2], PixelVFX.with_alpha(ramp[2], a), o)


## Seconds from spawn until the enemy starts to rise.
static func rise_delay(t: SpawnGlyphTuning, hold_sec: float) -> float:
	return t.draw_sec + maxf(hold_sec, 0.0)


## Seconds from spawn until the enemy's AI starts (rise finished and settled).
static func active_delay(t: SpawnGlyphTuning, hold_sec: float) -> float:
	return rise_delay(t, hold_sec) + t.rise_sec + t.settle_sec


## Total lifetime of a glyph, seconds.
static func total_sec(t: SpawnGlyphTuning, hold_sec: float) -> float:
	return active_delay(t, hold_sec) + t.fade_sec


## How far the outer ring has swept closed at [param elapsed], 0–1.
static func sweep_at(elapsed: float, t: SpawnGlyphTuning) -> float:
	if t.draw_sec <= 0.0:
		return 1.0
	return clampf(elapsed / t.draw_sec, 0.0, 1.0)


## Glyph opacity at [param elapsed]: full while drawing and rising, pulsing during a
## reinforcement hold, then fading to 0.
static func alpha_at(elapsed: float, t: SpawnGlyphTuning, hold_sec: float) -> float:
	var fade_at: float = active_delay(t, hold_sec)
	if elapsed >= fade_at + t.fade_sec:
		return 0.0
	if elapsed >= fade_at:
		return t.alpha * (1.0 - (elapsed - fade_at) / maxf(t.fade_sec, 0.001))
	if hold_sec > 0.0 and elapsed >= t.draw_sec and elapsed < rise_delay(t, hold_sec):
		var ph: float = (elapsed - t.draw_sec) * t.hold_pulse_hz * TAU
		return t.alpha * (0.85 + 0.15 * cos(ph))
	return t.alpha


## Point on the flattened ellipse of x-radius [param r] at [param angle].
static func ellipse_point(r: float, angle: float, iso_ratio: float) -> Vector2:
	return Vector2(cos(angle) * r, sin(angle) * r * iso_ratio)


## Spans for [dark under-ring, ring body, runes + light core] at [param sweep] 0–1 and
## rune rotation [param rot] radians.
func _build_spans(sweep: float, rot: float) -> Array:
	var r: float = tuning.radius * size_mult
	var ri: float = r * tuning.inner_ratio
	var iso: float = tuning.iso_ratio
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var segs: int = maxi(int(ceilf(RING_SEGMENTS * sweep)), 1)
	for i: int in segs + 1:
		var ang: float = -PI * 0.5 + TAU * sweep * float(i) / float(segs)
		outer.append(ellipse_point(r, ang, iso))
		# The inner ring sweeps the other way, so the two meet as the glyph closes.
		inner.append(ellipse_point(ri, -PI * 0.5 - TAU * sweep * float(i) / float(segs), iso))
	var under: Dictionary = PixelVFX.polyline_cells(outer, 3.0)
	var body: Dictionary = PixelVFX.polyline_cells(outer, 1.0)
	PixelVFX.polyline_cells(inner, 1.0, body)
	var light: Dictionary = {}
	var shown: int = int(floorf(sweep * float(tuning.rune_count)))
	for k: int in shown:
		var ang: float = rot + TAU * float(k) / float(maxi(tuning.rune_count, 1))
		PixelVFX.line_cells(ellipse_point(ri + 1.0, ang, iso), ellipse_point(r - 1.0, ang, iso), 1.0, light)
	if sweep >= 1.0:
		var d: float = maxf(ri * 0.35, 2.0)
		PixelVFX.polyline_cells(PackedVector2Array([
			Vector2(0.0, -d * iso), Vector2(d, 0.0), Vector2(0.0, d * iso),
			Vector2(-d, 0.0), Vector2(0.0, -d * iso)]), 1.0, light)
	return [PixelVFX.cells_to_spans(under), PixelVFX.cells_to_spans(body),
			PixelVFX.cells_to_spans(light)]
