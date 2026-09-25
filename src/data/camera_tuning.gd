## CameraTuning — data-driven knobs for Fayde's Camera2D (ADR-0024).
##
## Authored as assets/data/camera_tuning.tres and consumed via a preload const in
## PlayerController so it resolves in headless tests without an Autoload (same
## pattern as BulletHellTuning / PaceTuning).
## Base viewport is 1152×648, so the visible game area is 1152/zoom × 648/zoom px.
class_name CameraTuning
extends Resource

@export_group("Zoom")

## Zoom while fighting. 2.0 shows 576×324 game px and Fayde fills ~10% of the
## screen height (Hades / Diablo range). 1.5 = the old wider view (768×432).
## Diablo-close is ~2.4 (480×270). Safe range 1.5–2.6: past ~2.4 a 150 px/s bullet
## entering at the screen's top/bottom edge gives under 0.9 s to react.
@export var combat_zoom: float = 2.0
## Zoom during the preparation phase — pulls out to show the whole arena.
@export var prep_zoom: float = 0.55
## Boss-reveal pull-out, held briefly before easing back to combat_zoom.
## Keep it below combat_zoom so the boss is framed in.
@export var boss_reveal_zoom: float = 1.4
## Seconds the camera holds at boss_reveal_zoom.
@export var boss_reveal_hold_sec: float = 0.9

@export_group("Follow")

## Max look-ahead offset (game px) in Fayde's movement direction. A closer camera
## needs a little more lead so she can see what she is running into.
@export var look_ahead_max: float = 40.0
## Camera2D position smoothing speed. Higher = snappier.
@export var smooth_speed: float = 8.0

@export_group("Shake")

## Camera trauma added by every hit Fayde takes, so even chip damage is felt.
## Heavy hits add their own, larger kick on top (PlayerController._on_heavy_hit).
@export_range(0.0, 1.0) var player_hit_trauma: float = 0.2


## Visible game-px area at [param zoom] for a [param viewport] size.
static func visible_area(zoom: float, viewport: Vector2 = Vector2(1152.0, 648.0)) -> Vector2:
	if zoom <= 0.0:
		return viewport
	return viewport / zoom
