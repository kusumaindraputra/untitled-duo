## CharacterFxTuning — timings for the sprite hit flash, cast pose and death dissolve (ADR-0034).
##
## Authored as assets/data/character_fx_tuning.tres and read by PixelCharacter through a
## preload const. The effects themselves run in assets/shaders/pixel_character.gdshader.
class_name CharacterFxTuning
extends Resource

@export_group("Hit flash")

## Seconds an enemy sprite stays flashed after a hit (full white, then fading out).
@export var enemy_flash_sec: float = 0.1
## Seconds Fayde's sprite flashes when he is hit.
@export var fayde_flash_sec: float = 0.14
## Flash colour on a hit. White on every character, never red (art bible §5.3).
@export var hit_flash_color: Color = Color.WHITE
## Fraction of the flash spent at full strength before it starts to fade.
@export_range(0.0, 1.0) var flash_hold: float = 0.4
## Strength of the Prana-coloured flash on Fayde when a cast begins (0 = none).
@export_range(0.0, 1.0) var cast_flash_strength: float = 0.45
## Seconds of that cast flash.
@export var cast_flash_sec: float = 0.12

@export_group("Cast pose")

## Seconds Fayde holds the cast row (wind-up → release → hold → recover).
@export var fayde_cast_sec: float = 0.32
## Extra seconds an enemy holds its wind-up row after the volley's windup_sec.
@export var enemy_cast_tail_sec: float = 0.12

@export_group("Death dissolve")

## Seconds the death dissolve takes. Keep it under EnemyInstance.BASE_DEATH_DURATION.
@export var dissolve_sec: float = 0.55
## Width of the glowing rim at the dissolve front, in dissolve units (0–0.5).
@export_range(0.0, 0.5) var dissolve_edge: float = 0.14
## How much the dissolve runs top-down instead of pure noise (0 = noise, 1 = a wipe).
@export_range(0.0, 1.0) var dissolve_rise: float = 0.45
## Rim colour for enemies with no Prana affiliation (bosses and neutral enemies).
@export var dissolve_neutral_color: Color = Color(1.0, 0.95, 0.85, 1.0)

@export_group("Squash & stretch")

## ADR-0040. Each amount is how far the sprite deforms at the peak (0.2 = 20 % wider
## and 20 % shorter, or the reverse); it then springs back with one overshoot.
## Reduce motion turns all of it off.

## Stretch along the dash direction when Fayde dashes.
@export_range(0.0, 0.5) var dash_stretch: float = 0.26
## Seconds the dash stretch takes to settle.
@export var dash_stretch_sec: float = 0.2
## Squash when the dash ends and Fayde plants her feet.
@export_range(0.0, 0.5) var dash_land_squash: float = 0.14
## Seconds of that landing squash.
@export var dash_land_sec: float = 0.16
## Squash (wide and short) when a cast begins; the overshoot is the release.
@export_range(0.0, 0.5) var cast_squash: float = 0.18
## Seconds of the cast squash.
@export var cast_squash_sec: float = 0.24
## Squash along the blow when an enemy is hit, so it visibly bounces.
@export_range(0.0, 0.5) var enemy_hit_squash: float = 0.22
## Seconds of the enemy hit bounce.
@export var enemy_hit_squash_sec: float = 0.22
## Share of the hit bounce a boss gets (big bodies wobbling reads as rubbery).
@export_range(0.0, 1.0) var boss_squash_scale: float = 0.45
## Extra springs after the peak: 1.0 = one overshoot the other way, then rest.
@export_range(0.0, 3.0) var squash_wobbles: float = 1.0
