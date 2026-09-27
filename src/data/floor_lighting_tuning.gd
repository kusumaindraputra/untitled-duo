## FloorLightingTuning — the 2D lights that light the arena floor (ADR-0043).
##
## Authored as assets/data/floor_lighting_tuning.tres and read by FloorLighting through a
## preload const. Lights only reach the floor tiles (art bible §6: no dynamic lighting on
## sprite layers), so characters and bullets keep their exact colours.
class_name FloorLightingTuning
extends Resource

## Master switch. Off = no floor lights.
@export var enabled: bool = true

@export_group("Light texture")

## Size of the shared radial light texture, px.
@export var texture_size: int = 64
## Flat brightness bands in the light texture, so the falloff reads as pixel art.
@export var texture_bands: int = 5

@export_group("Fayde")

## Fayde's carried light. Art bible E7 Warm Lantern Bleed.
@export var fayde_color: Color = Color(0.556863, 0.45098, 0.345098, 1.0)
@export var fayde_energy: float = 1.0
## Radius of Fayde's light on the floor, px.
@export var fayde_radius: float = 128.0

@export_group("Spell pulses")

## Short lights spawned by casts, hits, Cascades, Specials and enemy spawns. When all
## are busy the oldest one is reused.
@export var pulse_pool_size: int = 6
@export var cast_energy: float = 0.9
@export var cast_radius: float = 80.0
@export var cast_sec: float = 0.18
@export var hit_energy: float = 0.8
@export var hit_radius: float = 64.0
@export var hit_sec: float = 0.22
@export var burst_energy: float = 1.3
## Cascade and Special lights cover their burst radius times this.
@export var burst_radius_mult: float = 1.1
## Burst light radius when the signal carries no radius.
@export var burst_fallback_radius: float = 120.0
@export var burst_sec: float = 0.45
## Spawn glyph light, in the enemy rim colour.
@export var spawn_energy: float = 0.6
@export var spawn_radius: float = 48.0
@export var spawn_sec: float = 0.35

@export_group("Enemy bullets")

## At most this many enemy bullets carry a light; the rest stay unlit.
@export var bullet_light_cap: int = 8
@export var bullet_energy: float = 0.35
@export var bullet_radius: float = 32.0
## Seconds between re-picking which bullets carry the lights.
@export var bullet_refresh_sec: float = 0.1
