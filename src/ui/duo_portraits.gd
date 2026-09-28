## DuoPortraits — the two brothers' faces at the head of the HUD duo row (ADR-0058).
##
## Ayden on the left and Faith on the right, like their hands on the grid, with the
## shared heart between them. The brother in the arena gets a frame in his colour and
## full brightness; the one waiting in the link is dimmed, and a dark shade drains off
## his face while the swap cools down, so "can I swap yet" reads at a glance. While a
## boss has the link severed the heart goes grey and the waiting brother is struck
## through. Drawn in code from the brothers' idle frames; CombatHUD feeds the state.
class_name DuoPortraits
extends Control

## Face crop of the 20×32 idle frame (both brothers share the rig, ADR-0034).
const FACE_REGION := Rect2(2, 0, 16, 14)
## Face scale; whole number so the pixel art stays crisp.
const FACE_SCALE: int = 2
## Border around each face, and the gap between a face and the heart.
const FRAME_WIDTH: float = 2.0
const GAP: float = 3.0
## Heart width in px.
const HEART_SIZE: float = 12.0
## Dimming of the brother who is out of the arena.
const BENCHED_ALPHA: float = 0.45
const FRAME_BG := Color(0.06, 0.05, 0.08, 0.9)
const IDLE_FRAME_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const COOLDOWN_SHADE := Color(0.0, 0.0, 0.0, 0.6)
const HEART_COLOR := Color(1.0, 0.45, 0.55)
const SEVERED_COLOR := Color(0.55, 0.55, 0.6)
const SLASH_COLOR := Color(1.0, 0.3, 0.3, 0.9)

## The brother in the arena (DuoSwap.Character).
var active: int = DuoSwap.Character.AYDEN
## 0..1 share of the swap cooldown still to run (0 = swap ready).
var cooldown: float = 0.0
## Heart brightness, from CombatHUD.heartbeat_alpha (1 on a beat).
var heart: float = 1.0
## True while a boss has the link severed (the swap is locked).
var severed: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = box_size() * Vector2(2.0, 1.0) + Vector2(HEART_SIZE + GAP * 2.0, 0.0)
	size = custom_minimum_size


## One framed face, in px.
static func box_size() -> Vector2:
	return FACE_REGION.size * FACE_SCALE + Vector2.ONE * FRAME_WIDTH * 2.0


## Left edge of [param character]'s face box: Ayden first, Faith after the heart.
static func box_x(character: int) -> float:
	if character == DuoSwap.Character.FAITH:
		return box_size().x + HEART_SIZE + GAP * 2.0
	return 0.0


## Share of [param face_height] the cooldown shade covers for [param left] of the
## cooldown still to run: full when the swap was just used, gone when it is ready.
static func shade_height(left: float, face_height: float) -> float:
	return face_height * clampf(left, 0.0, 1.0)


## Sets the state and redraws only when something changed.
func set_state(active_character: int, cooldown_left: float, heart_alpha: float, is_severed: bool) -> void:
	if active_character == active and is_equal_approx(cooldown_left, cooldown) \
			and is_equal_approx(heart_alpha, heart) and is_severed == severed:
		return
	active = active_character
	cooldown = cooldown_left
	heart = heart_alpha
	severed = is_severed
	queue_redraw()


func _draw() -> void:
	for c: int in [DuoSwap.Character.AYDEN, DuoSwap.Character.FAITH]:
		_draw_face(c)
	_draw_heart()


func _draw_face(c: int) -> void:
	var box := Rect2(Vector2(box_x(c), 0.0), box_size())
	var here: bool = c == active
	draw_rect(box, FRAME_BG)
	var face := Rect2(box.position + Vector2.ONE * FRAME_WIDTH, FACE_REGION.size * FACE_SCALE)
	var tex: Texture2D = DuoLooks.for_character(c)["sheet"]
	var tint := Color(1, 1, 1, 1.0 if here else BENCHED_ALPHA)
	draw_texture_rect_region(tex, face, FACE_REGION, tint)
	if not here:
		var shade: float = face.size.y if severed else shade_height(cooldown, face.size.y)
		if shade > 0.0:
			draw_rect(Rect2(face.position, Vector2(face.size.x, shade)), COOLDOWN_SHADE)
		if severed:
			draw_line(face.position + Vector2(face.size.x, 0.0), face.position + Vector2(0.0, face.size.y),
				SLASH_COLOR, 2.0)
	var frame_col: Color = DuoSwap.hud_color(c) if here else IDLE_FRAME_COLOR
	draw_rect(box.grow(-FRAME_WIDTH * 0.5), frame_col, false, FRAME_WIDTH)


func _draw_heart() -> void:
	var r: float = HEART_SIZE * 0.5
	var at := Vector2(box_size().x + GAP + r, box_size().y * 0.5)
	var col: Color = SEVERED_COLOR if severed else HEART_COLOR
	col.a = 0.5 if severed else clampf(heart, 0.3, 1.0)
	var s: float = r * (1.0 if severed else lerpf(0.85, 1.1, clampf(heart, 0.0, 1.0)))
	draw_circle(at + Vector2(-s * 0.5, -s * 0.3), s * 0.55, col)
	draw_circle(at + Vector2(s * 0.5, -s * 0.3), s * 0.55, col)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-s * 1.02, -s * 0.1), at + Vector2(s * 1.02, -s * 0.1), at + Vector2(0.0, s * 0.95),
	]), col)
	if severed:
		draw_line(at + Vector2(-1.0, -s), at + Vector2(1.5, s), FRAME_BG, 2.0)
