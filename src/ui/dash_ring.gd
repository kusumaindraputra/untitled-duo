## DashRing — small ring at Fayde's feet showing dash charges and recharge (beta plan U3).
##
## Drawn in screen space by CombatHUD, which moves it under Fayde each frame and feeds it
## the PlayerController's charges and recharge timer. One pip per charge (lit when
## available) and an arc that fills while a charge recharges. Hidden while every charge
## is full, so it only appears when the player needs to know.
class_name DashRing
extends Control

## Ring radius and line width in px.
const RADIUS: float = 15.0
const WIDTH: float = 3.0
## Pip radius in px.
const PIP_RADIUS: float = 2.5
## Colours: filling arc, track, and lit / spent pips.
const ARC_COLOR := Color(0.55, 0.9, 1.0, 0.95)
const TRACK_COLOR := Color(1.0, 1.0, 1.0, 0.18)
const PIP_ON := Color(0.85, 0.97, 1.0, 1.0)
const PIP_OFF := Color(1.0, 1.0, 1.0, 0.25)

## Charges available now, and the maximum.
var charges: int = 1
var max_charges: int = 1
## 0..1 fill of the charge that is recharging (1 = none recharging).
var progress: float = 1.0


## Returns { "visible": bool, "progress": float } for a charge state: shown only while at
## least one charge is missing; progress is how far the recharging charge has come.
static func ring_state(charges_now: int, charges_max: int, remaining: float, duration: float) -> Dictionary:
	if charges_now >= charges_max or charges_max <= 0:
		return {"visible": false, "progress": 1.0}
	var p: float = 1.0 if duration <= 0.0 else clampf(1.0 - remaining / duration, 0.0, 1.0)
	return {"visible": true, "progress": p}


## Sets the state and redraws. Hides the ring when every charge is available.
func set_state(charges_now: int, charges_max: int, remaining: float, duration: float) -> void:
	var st: Dictionary = ring_state(charges_now, charges_max, remaining, duration)
	charges = charges_now
	max_charges = charges_max
	progress = st["progress"]
	visible = st["visible"]
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RADIUS, RADIUS) * 2.0 + Vector2(8, 8)


func _draw() -> void:
	var c: Vector2 = size * 0.5
	draw_arc(c, RADIUS, 0.0, TAU, 32, TRACK_COLOR, WIDTH, true)
	if progress > 0.0:
		draw_arc(c, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, ARC_COLOR, WIDTH, true)
	# Pips along the bottom of the ring, centred.
	var n: int = maxi(max_charges, 1)
	var spacing: float = PIP_RADIUS * 3.0
	var start_x: float = c.x - spacing * float(n - 1) * 0.5
	for i in n:
		var col: Color = PIP_ON if i < charges else PIP_OFF
		draw_circle(Vector2(start_x + spacing * float(i), c.y), PIP_RADIUS, col)
