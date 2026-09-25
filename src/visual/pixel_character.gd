## PixelCharacter — plays a pixel-art sprite sheet for Fayde or an enemy (ADR-0022).
##
## Sheets come from tools/art-gen/generate_character_sprites.gd: FRAMES columns ×
## 2 rows (row 0 idle, row 1 moving). The feet sit on the node origin, like the
## DebugCircle placeholder it replaces. The node reads its parent's velocity (and
## get_facing_direction() when present) to pick the row and flip left/right, so
## PlayerController and EnemyInstance need no extra wiring.
##
## An optional glow sheet (white where the character emits Prana light) is drawn
## on top and tinted with glow_color.
class_name PixelCharacter
extends Node2D

const FRAMES: int = 4
## Parent speed (px/s) above which the moving row plays.
const MOVE_THRESHOLD: float = 12.0

@export var sheet: Texture2D = null:
	set(value):
		sheet = value
		_apply_sheet()
@export var glow_sheet: Texture2D = null:
	set(value):
		glow_sheet = value
		_apply_sheet()
## Tint of the glow sheet (Fayde: the active Prana colour).
@export var glow_color: Color = Color(0.239, 0.851, 0.941, 1.0):
	set(value):
		glow_color = value
		if _glow != null:
			_glow.modulate = glow_color
## Integer pixel scale after the parent's own scale (bosses are scaled 2–2.5×).
@export var pixel_scale: float = 1.0:
	set(value):
		pixel_scale = value
		_apply_sheet()
## Frames per second of both rows.
@export var fps: float = 6.0

var _body: Sprite2D = null
var _glow: Sprite2D = null
var _time: float = 0.0
var _moving: bool = false
var _facing_left: bool = false


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


## Returns a standalone Sprite2D showing the current frame (dash afterimages).
## The caller owns it and places it with global_position.
func make_ghost() -> Sprite2D:
	var g: Sprite2D = _make_sprite()
	g.texture = sheet
	g.frame = _body.frame
	g.flip_h = _body.flip_h
	g.offset = _body.offset
	g.scale = _body.scale * scale
	return g


## Returns the size of one frame in sheet pixels.
func get_frame_size() -> Vector2i:
	if sheet == null:
		return Vector2i.ZERO
	return Vector2i(sheet.get_width() / FRAMES, sheet.get_height() / 2)


## Returns the frame index for elapsed [param time] on the given row. Pure.
static func frame_for(time: float, moving: bool, frames_per_sec: float) -> int:
	var col: int = int(floor(time * frames_per_sec)) % FRAMES
	return (FRAMES if moving else 0) + col


func _update_frame() -> void:
	if sheet == null:
		return
	var f: int = frame_for(_time, _moving, fps)
	_body.frame = f
	if _glow.visible:
		_glow.frame = f


func _apply_sheet() -> void:
	if _body == null:
		return
	for s: Sprite2D in [_body, _glow]:
		s.hframes = FRAMES
		s.vframes = 2
		s.scale = Vector2(pixel_scale, pixel_scale)
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
	s.vframes = 2
	return s
