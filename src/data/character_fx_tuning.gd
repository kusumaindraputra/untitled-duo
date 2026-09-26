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
