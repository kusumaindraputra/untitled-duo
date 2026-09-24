## BulletPattern — one data-driven enemy attack (ADR-0018).
##
## A pattern fires every [member interval] seconds once the owner's HP ratio is at or
## below [member hp_threshold]. Each firing is [member bursts] volleys spaced by
## [member burst_interval]; each volley's directions come from [member shape].
## LASER and MORTAR kinds spawn a telegraphed hazard instead of bullets.
## The geometry is computed by BulletPatternRunner (pure, unit-tested).
## Design: design/gdd/bullet-hell.md
class_name BulletPattern
extends Resource

enum Kind { BULLETS = 0, LASER = 1, MORTAR = 2 }
enum Shape { AIMED = 0, FAN = 1, RING = 2, SPIRAL = 3 }
enum Motion { STRAIGHT = 0, SINE = 1, HOMING = 2 }

@export_group("Timing")

@export var kind: Kind = Kind.BULLETS
## Seconds between firings.
@export var interval: float = 2.0
## Seconds before the first firing (lets layered patterns desync).
@export var initial_delay: float = 0.5
## Seconds the owner flashes before each firing (readability telegraph). 0 = none.
@export var windup_sec: float = 0.25
## Active only while owner HP ratio <= this. 1.0 = always. Boss phase layers use < 1.
@export_range(0.0, 1.0) var hp_threshold: float = 1.0

@export_group("Geometry")

@export var shape: Shape = Shape.AIMED
## Bullets per volley.
@export var count: int = 1
## FAN / AIMED spread in degrees (total arc). RING / SPIRAL ignore it (full circle).
@export var spread_deg: float = 0.0
## Volleys per firing.
@export var bursts: int = 1
## Seconds between volleys inside one firing.
@export var burst_interval: float = 0.1
## Rotation added per volley (degrees). Drives SPIRAL; also usable on FAN/RING.
@export var spin_deg: float = 0.0
## Aim volley 0 at Fayde. False = start at angle 0 (fixed patterns).
@export var aim_at_player: bool = true

@export_group("Bullet")

@export var speed: float = 160.0
## Speed added per volley inside one firing (layered "wall" of bullets).
@export var speed_step: float = 0.0
@export var motion: Motion = Motion.STRAIGHT
## SINE: lateral amplitude (px) and frequency (Hz).
@export var sine_amplitude: float = 18.0
@export var sine_frequency: float = 2.0
## HOMING: max turn rate (deg/s) and seconds of homing before flying straight.
@export var homing_turn_deg: float = 90.0
@export var homing_duration: float = 1.2
## Damage = owner base_damage × this.
@export var damage_mult: float = 0.5
@export var bullet_radius: float = 4.0
@export var max_range: float = 420.0
@export var color: Color = Color(0.6, 0.8, 1.0, 1.0)

@export_group("Hazard (LASER / MORTAR)")

## Seconds the warning line / circle shows before the hazard goes live.
@export var telegraph_sec: float = 0.8
## LASER: seconds the beam stays active.
@export var active_sec: float = 0.35
## LASER: beam length and half-width (px). MORTAR: blast radius (px).
@export var length: float = 520.0
@export var width: float = 6.0
@export var radius: float = 48.0
## MORTAR: bullets released in a ring when the shell lands (0 = none).
@export var splash_count: int = 0
