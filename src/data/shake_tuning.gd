## ShakeTuning — data-driven knobs for the one screen-shake service (ADR-0040).
##
## Authored as assets/data/shake_tuning.tres and read by ShakeState / the ScreenShake
## autoload through a preload const, so it resolves in headless tests too.
## Two layers add up into Camera2D.offset: a trauma shake (noise, squared so small
## hits stay gentle) and a directional kick that lurches the view along the blow and
## springs back.
class_name ShakeTuning
extends Resource

@export_group("Trauma")

## Camera offset (game px) at trauma 1.0. Trauma is squared first, so 0.5 gives 1/4.
@export var max_offset_px: float = 10.0
## Trauma lost per real-time second.
@export var trauma_decay: float = 3.5
## Noise speed of the trauma shake. Higher = a faster, buzzier rattle.
@export var noise_speed: float = 42.0

@export_group("Kick")

## Longest directional kick (game px), however many hits stack.
@export var kick_max_px: float = 8.0
## Kick px added per unit of trauma when add_trauma() is given a direction.
@export var kick_per_trauma_px: float = 7.0
## Exponential return speed of the kick (1/s). 18 ≈ back in ~0.2 s.
@export var kick_return: float = 18.0

@export_group("Presets")

## Trauma for ScreenShake.impact(Strength.LIGHT): a spell hit, chip damage.
@export_range(0.0, 1.0) var light: float = 0.3
## Strength.MEDIUM: a Cascade burst, a boss phase change, a room clear.
@export_range(0.0, 1.0) var medium: float = 0.5
## Strength.HEAVY: a heavy hit, the Special.
@export_range(0.0, 1.0) var heavy: float = 0.7
## Strength.MASSIVE: Fayde's death, a boss death.
@export_range(0.0, 1.0) var massive: float = 0.9

@export_group("Accessibility")

## Share of every shake and kick kept while Reduce motion is on (on top of the
## Screen shake slider). 0 = no shake at all with Reduce motion.
@export_range(0.0, 1.0) var reduce_motion_scale: float = 0.35


## Trauma for preset [param strength] (ShakeState.Strength); 0 for an unknown value.
func preset(strength: int) -> float:
	match strength:
		0:
			return light
		1:
			return medium
		2:
			return heavy
		3:
			return massive
	return 0.0
