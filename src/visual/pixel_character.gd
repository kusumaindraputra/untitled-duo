## PixelCharacter — plays a pixel-art sprite sheet for Fayde or an enemy (ADR-0022, ADR-0034).
##
## Sheets come from tools/art-gen/generate_character_sprites.gd: FRAMES columns ×
## ROWS rows (row 0 idle, row 1 moving, row 2 cast / attack wind-up). The feet sit on
## the node origin, like the DebugCircle placeholder it replaces. The node reads its
## parent's velocity (and get_facing_direction() when present) to pick the row and
## flip left/right, so PlayerController and EnemyInstance need no extra wiring.
##
## An optional glow sheet (white where the character emits Prana light) is drawn
## on top and tinted with glow_color.
##
## ADR-0034 effects, all driven from _process and the pixel_character shader:
## flash() turns every opaque pixel one colour for a moment (hit flash), play_cast()
## plays the cast row once, and dissolve() breaks the sprite apart in 2×2 clusters.
## ADR-0056: with a cast_sheet, play_cast() can take a cast style (one row per Prana,
## GameEnums.CastAnimation) and shows that row instead of the plain cast row.
## ADR-0040: squash() deforms the sprite around its feet and springs it back (dash,
## cast, hit bounce). It scales the sprites, not this node, so callers' scale is kept.
class_name PixelCharacter
extends Node2D

## Emitted once when a dissolve() finishes (the sprite is fully gone).
signal dissolved

const FRAMES: int = 4
const ROWS: int = 3
const ROW_IDLE: int = 0
const ROW_MOVE: int = 1
const ROW_CAST: int = 2
## Rows in a cast_sheet, one per GameEnums.CastAnimation value.
const CAST_STYLES: int = 5
## Parent speed (px/s) above which the moving row plays.
const MOVE_THRESHOLD: float = 12.0
const FX_TUNING: CharacterFxTuning = preload("res://assets/data/character_fx_tuning.tres")
const FX_SHADER: Shader = preload("res://assets/shaders/pixel_character.gdshader")

@export var sheet: Texture2D = null:
	set(value):
		sheet = value
		_apply_sheet()
@export var glow_sheet: Texture2D = null:
	set(value):
		glow_sheet = value
		_apply_sheet()
## Per-Prana cast poses (ADR-0056): CAST_STYLES rows of FRAMES columns, same cell
## size as [member sheet]. Null: every cast plays the sheet's own cast row.
@export var cast_sheet: Texture2D = null
## Glow for [member cast_sheet], same layout.
@export var cast_glow_sheet: Texture2D = null
## Tint of the glow sheet (Fayde: the active Prana colour).
@export var glow_color: Color = Color(0.239, 0.851, 0.941, 1.0):
	set(value):
		glow_color = value
		if _glow != null:
			_glow.modulate = glow_color
## Pixel scale after the parent's own scale. Enemies set it to 1 / base_scale so one
## sheet pixel is one world pixel, the same as Fayde.
@export var pixel_scale: float = 1.0:
	set(value):
		pixel_scale = value
		_apply_sheet()
## Frames per second of the idle and moving rows.
@export var fps: float = 6.0

var _body: Sprite2D = null
var _glow: Sprite2D = null
var _material: ShaderMaterial = null
var _time: float = 0.0
var _moving: bool = false
var _facing_left: bool = false
var _flash_strength: float = 0.0
var _flash_sec: float = 0.0
var _flash_elapsed: float = 0.0
var _cast_sec: float = 0.0
var _cast_elapsed: float = 0.0
var _cast_style: int = -1
var _showing_styles: bool = false
var _dissolve_sec: float = 0.0
var _dissolve_elapsed: float = 0.0
var _squash_peak: Vector2 = Vector2.ONE
var _squash_sec: float = 0.0
var _squash_elapsed: float = 0.0


func _init() -> void:
	_body = _make_sprite()
	add_child(_body)
	_glow = _make_sprite()
	_glow.modulate = glow_color
	add_child(_glow)


func _process(delta: float) -> void:
	_time += delta
	var parent: Node = get_parent()
	if parent is CharacterBody2D:
		var v: Vector2 = (parent as CharacterBody2D).velocity
		set_moving(v.length() > MOVE_THRESHOLD)
		var face_x: float = v.x
		if parent.has_method(&"get_facing_direction"):
			face_x = (parent.call(&"get_facing_direction") as Vector2).x
		if absf(face_x) > 0.05:
			set_facing_left(face_x < 0.0)
	advance_fx(delta)
	_update_frame()


## Selects the moving (true) or idle (false) row.
func set_moving(moving: bool) -> void:
	_moving = moving


## Mirrors the sprite so it faces left.
func set_facing_left(left: bool) -> void:
	_facing_left = left
	if _body != null:
		_body.flip_h = left
		_glow.flip_h = left


## Returns the sheet frame index currently shown (row * FRAMES + column).
func get_frame() -> int:
	return _body.frame


## Flashes every opaque pixel [param color] for [param duration] seconds: full
## [param strength] for the tuning's flash_hold share, then fading out. A new flash
## replaces one in progress.
func flash(color: Color, duration: float, strength: float = 1.0) -> void:
	if duration <= 0.0 or strength <= 0.0:
		return
	_flash_strength = clampf(strength, 0.0, 1.0)
	_flash_sec = duration
	_flash_elapsed = 0.0
	_ensure_material()
	_material.set_shader_parameter(&"flash_color", color)
	_push_fx()


## Plays the cast row once over [param duration] seconds (wind-up, release, hold,
## recover). Idle and moving rows resume afterwards. [param style] picks a row of
## [member cast_sheet] (a GameEnums.CastAnimation value); -1, an out-of-range style
## or no cast_sheet plays the plain cast row.
func play_cast(duration: float, style: int = -1) -> void:
	if duration <= 0.0:
		return
	_cast_sec = duration
	_cast_elapsed = 0.0
	var styled: bool = cast_sheet != null and style >= 0 and style < CAST_STYLES
	_cast_style = style if styled else -1
	_update_frame()


## Cast style row showing now, or -1 when not casting or casting the plain row.
func get_cast_style() -> int:
	return _cast_style if is_casting() else -1


## True while the cast row is playing.
func is_casting() -> bool:
	return _cast_elapsed < _cast_sec


## Deforms the sprite to [param peak] scale (e.g. Vector2(1.2, 0.8)) and springs it
## back to normal over [param duration] seconds, pivoting on the feet. A new squash
## replaces one in progress. No-op with Reduce motion on.
func squash(peak: Vector2, duration: float) -> void:
	if duration <= 0.0 or peak == Vector2.ONE or GameSettings.motion_reduced():
		return
	_squash_peak = peak
	_squash_sec = duration
	_squash_elapsed = 0.0
	_apply_squash()


## Current squash multiplier on the sprite scale (Vector2.ONE at rest).
func get_squash() -> Vector2:
	return squash_at(_squash_elapsed, _squash_sec, _squash_peak, FX_TUNING.squash_wobbles)


## Breaks the sprite apart over [param duration] seconds, with a [param rim] colour
## at the dissolve front. Emits [signal dissolved] when it is gone.
func dissolve(duration: float, rim: Color) -> void:
	_dissolve_sec = maxf(duration, 0.01)
	_dissolve_elapsed = 0.0
	_ensure_material()
	_material.set_shader_parameter(&"dissolve_color", rim)
	_push_fx()


## Current dissolve progress, 0 (whole) to 1 (gone); 0 when no dissolve has started.
func get_dissolve() -> float:
	if _dissolve_sec <= 0.0:
		return 0.0
	return clampf(_dissolve_elapsed / _dissolve_sec, 0.0, 1.0)


## Current hit-flash strength, 0 to 1.
func get_flash_amount() -> float:
	return flash_amount_at(_flash_elapsed, _flash_sec, FX_TUNING.flash_hold) * _flash_strength


## Advances the flash, cast and dissolve timers by [param delta] seconds and pushes
## the result to the shader. Called from _process; public so tests can step it.
func advance_fx(delta: float) -> void:
	if _cast_elapsed < _cast_sec:
		_cast_elapsed += delta
	if _flash_elapsed < _flash_sec:
		_flash_elapsed += delta
	if _squash_elapsed < _squash_sec:
		_squash_elapsed += delta
		_apply_squash()
	var was_dissolving: bool = _dissolve_sec > 0.0 and _dissolve_elapsed < _dissolve_sec
	if was_dissolving:
		_dissolve_elapsed += delta
	if _material != null:
		_push_fx()
	if was_dissolving and _dissolve_elapsed >= _dissolve_sec:
		dissolved.emit()


## Returns a standalone Sprite2D showing the current frame (dash afterimages).
## The caller owns it and places it with global_position.
func make_ghost() -> Sprite2D:
	var g: Sprite2D = _make_sprite()
	g.texture = _body.texture
	g.vframes = _body.vframes
	g.frame = _body.frame
	g.flip_h = _body.flip_h
	g.offset = _body.offset
	g.scale = _body.scale * scale
	return g


## Squash multiplier [param elapsed] seconds into a squash of [param duration]
## seconds peaking at [param peak]: starts at the peak, springs past rest
## [param wobbles] times with a shrinking swing, ends exactly at Vector2.ONE. Pure.
static func squash_at(elapsed: float, duration: float, peak: Vector2, wobbles: float = 1.0) -> Vector2:
	if duration <= 0.0 or elapsed >= duration:
		return Vector2.ONE
	var u: float = clampf(elapsed / duration, 0.0, 1.0)
	var envelope: float = (1.0 - u) * (1.0 - u) * cos(u * PI * (wobbles + 0.5))
	return Vector2.ONE + (peak - Vector2.ONE) * envelope


## Peak scale for a squash of [param amount]: wide and short when positive, tall
## and thin when negative. Pure.
static func squash_peak(amount: float) -> Vector2:
	return Vector2(1.0 + amount, 1.0 - amount)


## Peak scale that stretches [param amount] along [param direction] (and thins the
## other axis); a negative amount squashes along it instead. Diagonals blend. Pure.
static func stretch_along(direction: Vector2, amount: float) -> Vector2:
	if direction == Vector2.ZERO:
		return squash_peak(amount)
	var horizontal: float = absf(direction.normalized().x)
	return squash_peak(-amount).lerp(squash_peak(amount), horizontal)


## Returns the size of one frame in sheet pixels.
func get_frame_size() -> Vector2i:
	if sheet == null:
		return Vector2i.ZERO
	return Vector2i(sheet.get_width() / FRAMES, sheet.get_height() / ROWS)


## Returns the [member cast_sheet] frame [param elapsed] seconds into a cast of
## [param duration] seconds in cast style [param style]. Pure.
static func styled_cast_frame_for(elapsed: float, duration: float, style: int) -> int:
	return cast_frame_for(elapsed, duration) - ROW_CAST * FRAMES + style * FRAMES


## Returns the frame index for elapsed [param time] on a looping [param row]. Pure.
static func frame_for(time: float, row: int, frames_per_sec: float) -> int:
	var col: int = int(floor(time * frames_per_sec)) % FRAMES
	return row * FRAMES + col


## Returns the cast-row frame [param elapsed] seconds into a cast of [param duration]
## seconds: the four columns are spread evenly and the last one holds. Pure.
static func cast_frame_for(elapsed: float, duration: float) -> int:
	var t: float = clampf(elapsed / maxf(duration, 0.001), 0.0, 0.999)
	return ROW_CAST * FRAMES + int(floor(t * FRAMES))


## Flash strength [param elapsed] seconds into a flash of [param duration] seconds:
## 1 for the first [param hold] share, then a linear fade to 0. Pure.
static func flash_amount_at(elapsed: float, duration: float, hold: float) -> float:
	if duration <= 0.0 or elapsed >= duration:
		return 0.0
	var t: float = elapsed / duration
	if t <= hold:
		return 1.0
	return clampf(1.0 - (t - hold) / maxf(1.0 - hold, 0.001), 0.0, 1.0)


func _update_frame() -> void:
	if sheet == null:
		return
	var f: int
	var styled: bool = is_casting() and _cast_style >= 0
	_show_cast_sheet(styled)
	if styled:
		f = styled_cast_frame_for(_cast_elapsed, _cast_sec, _cast_style)
	elif is_casting():
		f = cast_frame_for(_cast_elapsed, _cast_sec)
	else:
		f = frame_for(_time, ROW_MOVE if _moving else ROW_IDLE, fps)
	_body.frame = f
	if _glow.visible:
		_glow.frame = f


## Swaps both sprites between the main sheet and the cast-style sheet.
func _show_cast_sheet(on: bool) -> void:
	if on == _showing_styles:
		return
	_showing_styles = on
	var rows: int = CAST_STYLES if on else ROWS
	for s: Sprite2D in [_body, _glow]:
		s.vframes = rows
	_body.texture = cast_sheet if on else sheet
	_glow.texture = cast_glow_sheet if on else glow_sheet
	if _material != null:
		_material.set_shader_parameter(&"sheet_rows", float(rows))


func _apply_squash() -> void:
	if _body == null:
		return
	var sc: Vector2 = Vector2(pixel_scale, pixel_scale) * get_squash()
	_body.scale = sc
	_glow.scale = sc


func _ensure_material() -> void:
	if _material != null:
		return
	_material = ShaderMaterial.new()
	_material.shader = FX_SHADER
	_material.set_shader_parameter(&"sheet_rows", float(CAST_STYLES if _showing_styles else ROWS))
	_material.set_shader_parameter(&"dissolve_edge", FX_TUNING.dissolve_edge)
	_material.set_shader_parameter(&"dissolve_rise", FX_TUNING.dissolve_rise)
	_body.material = _material
	_glow.material = _material


func _push_fx() -> void:
	_material.set_shader_parameter(&"flash_amount", get_flash_amount())
	_material.set_shader_parameter(&"dissolve", get_dissolve())


func _apply_sheet() -> void:
	if _body == null:
		return
	for s: Sprite2D in [_body, _glow]:
		s.hframes = FRAMES
		s.vframes = ROWS
	_apply_squash()
	_showing_styles = false
	_body.texture = sheet
	_glow.texture = glow_sheet
	_glow.visible = glow_sheet != null
	var size: Vector2i = get_frame_size()
	# Feet (bottom-centre of the frame) on the node origin.
	var off := Vector2(-size.x / 2.0, -float(size.y))
	_body.offset = off
	_glow.offset = off


static func _make_sprite() -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.hframes = FRAMES
	s.vframes = ROWS
	return s
