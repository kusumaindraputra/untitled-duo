## SpawnGlyphTuning — timings and look of the enemy spawn glyph (ADR-0043).
##
## Authored as assets/data/spawn_glyph_tuning.tres and read by WaveManager and SpawnGlyph
## through a preload const. The glyph is drawn on the floor first, then the enemy rises out
## of it, then the glyph fades. Its colour is the enemy family rim from EnemyBulletPalette
## (ADR-0037), so "magenta on the floor" always means "enemy".
class_name SpawnGlyphTuning
extends Resource

@export_group("Timeline")

## Seconds the glyph takes to draw its outer ring before the enemy starts to rise.
@export var draw_sec: float = 0.16
## Seconds the enemy takes to rise from flat to full height.
@export var rise_sec: float = 0.2
## Seconds the enemy stands still after rising before its AI and physics start.
@export var settle_sec: float = 0.08
## Seconds the glyph takes to fade once the enemy has risen.
@export var fade_sec: float = 0.3

@export_group("Glyph")

## Outer ring radius on the x axis, px, at enemy scale 1 (the y radius is iso_ratio of it).
@export var radius: float = 15.0
## Inner ring radius as a fraction of the outer one.
@export_range(0.1, 0.95) var inner_ratio: float = 0.62
## Vertical squash of the rings so they lie flat on the isometric floor (tile 64×32 → 0.5).
@export_range(0.2, 1.0) var iso_ratio: float = 0.5
## Rune ticks between the two rings.
@export var rune_count: int = 6
## Rune rotation speed, radians per second (0 with Reduce motion).
@export var spin_speed: float = 1.4
## Opacity of the glyph at full strength.
@export_range(0.0, 1.0) var alpha: float = 0.9
## Pulse rate while a reinforcement glyph waits to release its enemy, pulses per second.
@export var hold_pulse_hz: float = 3.0

@export_group("Rise")

## Enemy width at the start of the rise, as a fraction of its final scale.
@export_range(0.0, 1.0) var rise_start_width: float = 0.6
## Enemy tint at the start of the rise; it fades to the enemy's own modulate.
@export var rise_tint: Color = Color(0.55, 0.2, 0.45, 1.0)
