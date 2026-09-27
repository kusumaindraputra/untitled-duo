## HandsTuning — the "two hands" layer of the Prana grid (ADR-0057).
##
## Fayde is made from two brothers: Ayden, raw power, and Faith, precise control. The
## grid's left column is Ayden's hand and its right column Faith's hand. Each Prana held
## in Ayden's hand adds damage to the cast; each Prana in Faith's hand lengthens the
## core Prana's status. When both hands hold the same number of Prana (at least one
## each), they touch and both bonuses grow. Authored as assets/data/hands_tuning.tres.
class_name HandsTuning
extends Resource

## Grid slots (0–8, reading order) that make up Ayden's hand. Default: left column.
@export var ayden_slots: PackedInt32Array = PackedInt32Array([0, 3, 6])
## Grid slots that make up Faith's hand. Default: right column.
@export var faith_slots: PackedInt32Array = PackedInt32Array([2, 5, 8])
## Damage added per Prana in Ayden's hand (0.06 = +6 %).
@export_range(0.0, 0.5, 0.01) var power_per_prana: float = 0.06
## Status duration added per Prana in Faith's hand (0.12 = +12 %).
@export_range(0.0, 1.0, 0.01) var control_per_prana: float = 0.12
## Multiplier on both bonuses when the hands touch (equal, non-zero counts).
@export_range(1.0, 3.0, 0.05) var touch_mult: float = 1.5
