## ThreatIcon — a small glyph over a previewed enemy that says how it threatens you
## (ADR-0032).
##
## Replaces the name labels the wave preview drew during preparation, which overlapped
## when enemies stood close. Each kind has its own shape (not only a colour), drawn
## white on a dark disc with the enemy's colour as a ring; elites get a gold ring and
## a swarm shows one icon with a count. The pause screen's legend draws the same
## glyphs through [method draw_glyph].
class_name ThreatIcon
extends Node2D

## What the enemy does, in legend order (UICopy.threat_names).
enum Kind { CHASER = 0, CHARGER = 1, SWARM = 2, SHOOTER = 3, LASER = 4, MORTAR = 5, SPLITTER = 6, BOSS = 7 }

## Disc radius in px (world space).
const RADIUS: float = 11.0
const DISC_COLOR := Color(0.04, 0.03, 0.07, 0.88)
const GLYPH_COLOR := Color(1.0, 1.0, 1.0)
const ELITE_RING := Color(1.0, 0.84, 0.3)
const COUNT_FONT_SIZE: int = 10

var kind: Kind = Kind.CHASER
## Ring colour (the enemy's debug colour).
var ring_color: Color = Color.WHITE
var elite: bool = false
## Shown as "×N" beside the icon when above 1 (swarms).
var count: int = 1


## The threat kind of [param et]: boss and archetype first, then its strongest
## pattern (laser, mortar, bullets), then a death pattern (splits), else it chases.
static func kind_for(et: EnemyType) -> Kind:
	if et == null:
		return Kind.CHASER
	match et.archetype:
		GameEnums.EnemyArchetype.BOSS:
			return Kind.BOSS
		GameEnums.EnemyArchetype.RUSHER:
			return Kind.CHARGER
		GameEnums.EnemyArchetype.SWARMER:
			return Kind.SWARM
	var has_bullets: bool = false
	for p: BulletPattern in et.pattern_layers:
		if p == null:
			continue
		if p.kind == BulletPattern.Kind.LASER:
			return Kind.LASER
		if p.kind == BulletPattern.Kind.MORTAR:
			return Kind.MORTAR
		has_bullets = true
	if has_bullets or et.archetype == GameEnums.EnemyArchetype.SHOOTER:
		return Kind.SHOOTER
	if et.death_pattern != null:
		return Kind.SPLITTER
	return Kind.CHASER


## Draws the glyph of [param k] centred on [param c] with radius [param r] into
## [param ci]'s current draw call. Shapes stay readable without colour.
static func draw_glyph(ci: CanvasItem, k: Kind, c: Vector2, r: float, col: Color) -> void:
	var w: float = maxf(1.5, r * 0.22)
	match k:
		Kind.CHASER:  # one chevron pointing in
			ci.draw_polyline([c + Vector2(-r * 0.5, -r * 0.2), c + Vector2(0, r * 0.35),
				c + Vector2(r * 0.5, -r * 0.2)], col, w, true)
		Kind.CHARGER:  # double chevron: fast charge
			for dx: float in [-r * 0.28, r * 0.22]:
				ci.draw_polyline([c + Vector2(dx - r * 0.2, -r * 0.45), c + Vector2(dx + r * 0.2, 0),
					c + Vector2(dx - r * 0.2, r * 0.45)], col, w, true)
		Kind.SWARM:  # three dots
			for a: float in [-PI * 0.5, PI * 0.5 / 3.0, PI * 5.0 / 6.0]:
				ci.draw_circle(c + Vector2.from_angle(a) * r * 0.36, r * 0.18, col)
		Kind.SHOOTER:  # dot with four short rays
			ci.draw_circle(c, r * 0.16, col)
			for i: int in 4:
				var d: Vector2 = Vector2.from_angle(PI * 0.25 + TAU * 0.25 * float(i))
				ci.draw_line(c + d * r * 0.34, c + d * r * 0.62, col, w, true)
		Kind.LASER:  # beam line with an emitter dot
			ci.draw_circle(c + Vector2(-r * 0.42, 0), r * 0.2, col)
			ci.draw_line(c + Vector2(-r * 0.3, 0), c + Vector2(r * 0.6, 0), col, w, true)
		Kind.MORTAR:  # target ring with a centre dot
			ci.draw_arc(c, r * 0.46, 0.0, TAU, 16, col, w, true)
			ci.draw_circle(c, r * 0.14, col)
		Kind.SPLITTER:  # two halves
			ci.draw_arc(c + Vector2(-r * 0.12, 0), r * 0.4, PI * 0.5, PI * 1.5, 10, col, w, true)
			ci.draw_arc(c + Vector2(r * 0.12, 0), r * 0.4, -PI * 0.5, PI * 0.5, 10, col, w, true)
		Kind.BOSS:  # crown
			ci.draw_polyline([c + Vector2(-r * 0.5, r * 0.35), c + Vector2(-r * 0.5, -r * 0.3),
				c + Vector2(-r * 0.2, 0), c + Vector2(0, -r * 0.45), c + Vector2(r * 0.2, 0),
				c + Vector2(r * 0.5, -r * 0.3), c + Vector2(r * 0.5, r * 0.35),
				c + Vector2(-r * 0.5, r * 0.35)], col, w, true)


## Draws the full icon (disc, ring, glyph) at [param c]. Shared with the legend.
static func draw_icon(ci: CanvasItem, k: Kind, c: Vector2, r: float, ring: Color, is_elite: bool) -> void:
	ci.draw_circle(c, r, DISC_COLOR)
	ci.draw_arc(c, r, 0.0, TAU, 20, ring, 1.5, true)
	if is_elite:  # a second, gold ring outside the colour ring
		ci.draw_arc(c, r + 2.5, 0.0, TAU, 20, ELITE_RING, 2.0, true)
	draw_glyph(ci, k, c, r, GLYPH_COLOR)


func _ready() -> void:
	z_index = 5


func _draw() -> void:
	draw_icon(self, kind, Vector2.ZERO, RADIUS, ring_color, elite)
	if count > 1:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(RADIUS + 2.0, COUNT_FONT_SIZE * 0.36), "×%d" % count,
			HORIZONTAL_ALIGNMENT_LEFT, -1, COUNT_FONT_SIZE, GLYPH_COLOR)
