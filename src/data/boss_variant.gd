## BossVariant — one per-run twist on a boss (ADR-0028).
##
## Each BossProfile lists a few variants; BossRoster picks one per boss from the run
## seed, so the same boss plays differently from run to run. A variant adds bullet
## layers and arena events on top of the boss's own, and scales a few stats.
## The variant's name shown to the player lives in UICopy.boss_variant_titles.
class_name BossVariant
extends Resource

## Stable id, also the key into UICopy.boss_variant_titles.
@export var id: StringName = &""

@export_group("Attacks")
## Bullet layers added to the boss. Use an hp_threshold the boss already has (or 1.0),
## so the variant never adds an HP phase of its own.
@export var extra_layers: Array[BulletPattern] = []
## Arena events added to the boss profile's own.
@export var extra_events: Array[BossPhaseEvent] = []

@export_group("Stats")
@export_range(0.5, 2.0) var hp_mult: float = 1.0
@export_range(0.5, 2.0) var bullet_speed_mult: float = 1.0
@export_range(0.5, 2.0) var fire_rate_mult: float = 1.0
@export_range(0.5, 2.0) var move_speed_mult: float = 1.0

@export_group("Look")
## Multiplied onto the boss sprite's tint.
@export var tint: Color = Color.WHITE
