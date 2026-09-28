## CrumplePose — Fayde's defeat crumple, stage 1 of the art bible's all-ages defeat
## sequence (§5.3, ADR-0042): knees bend, arms go loose, head dips, and the pose holds.
##
## Plays assets/art/characters/fayde_crumple.png once (CRUMPLE_FRAMES columns, built
## by tools/art-gen/generate_character_sprites.gd) and holds the last frame. The glow
## sheet is tinted with the last active Prana colour, the one warm colour left on the
## defeat screen (§2.5). Time runs in real seconds, so the pose still plays during the
## death slow-mo. Feet sit on the node origin, like PixelCharacter.
class_name CrumplePose
extends Node2D

## Columns in the crumple strip.
const FRAMES: int = 4
const SHEET: Texture2D = preload("res://assets/art/characters/fayde_crumple.png")
const GLOW_SHEET: Texture2D = preload("res://assets/art/characters/fayde_crumple_glow.png")
const _JUICE: HudJuiceTuning = preload("res://assets/data/hud_juice_tuning.tres")

## Seconds the strip takes to play; the last frame holds after that.
var duration: float = _JUICE.crumple_sec

var _body: Sprite2D = null
var _glow: Sprite2D = null
var _elapsed: float = 0.0
var _last_usec: int = 0


func _init() -> void:
	_body = _make_sprite(SHEET)
	add_child(_body)
	_glow = _make_sprite(GLOW_SHEET)
	add_child(_glow)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_last_usec = Time.get_ticks_usec()
	_body.frame = 0
	_glow.frame = 0


func _process(_delta: float) -> void:
	# Real time, not scaled delta: the death slow-mo runs at 0.15×.
	var now: int = Time.get_ticks_usec()
	advance(float(now - _last_usec) / 1_000_000.0)
	_last_usec = now


## ADR-0058: shows [param character]'s crumple (a DuoSwap.Character; NONE = Fayde).
func set_character(character: int) -> void:
	var look: Dictionary = DuoLooks.for_character(character)
	_body.texture = look["crumple"]
	_glow.texture = look["crumple_glow"]


## Sets the colours: [param body_tint] on the sprite, [param glow_color] on the hands
## and lens, and [param face_left] mirrors it.
func setup(glow_color: Color, body_tint: Color = Color.WHITE, face_left: bool = false) -> void:
	_body.modulate = body_tint
	_glow.modulate = glow_color
	_body.flip_h = face_left
	_glow.flip_h = face_left


## Moves the pose on by [param seconds] (called from _process; tests drive it directly).
func advance(seconds: float) -> void:
	_elapsed += maxf(seconds, 0.0)
	var f: int = frame_at(_elapsed, duration)
	_body.frame = f
	_glow.frame = f


## The strip column shown now.
func get_frame() -> int:
	return _body.frame


## The glow tint (tests).
func get_glow_color() -> Color:
	return _glow.modulate


## Pure: the strip column [param elapsed] seconds into a [param total]-second crumple.
## Clamps to the last column, which holds.
static func frame_at(elapsed: float, total: float) -> int:
	if total <= 0.0:
		return FRAMES - 1
	return clampi(floori(elapsed / total * float(FRAMES)), 0, FRAMES - 1)


static func _make_sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.hframes = FRAMES
	var size := Vector2(float(tex.get_width()) / float(FRAMES), float(tex.get_height()))
	s.offset = Vector2(-size.x / 2.0, -size.y)
	return s
