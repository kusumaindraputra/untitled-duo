## HudReadoutTuning — timings and sizes for the boss bar and the sigil strip (ADR-0045).
##
## Authored as assets/data/hud_readout_tuning.tres and read by BossHealthBar and
## SigilStrip through a preload const. These are feel values, not gameplay values.
class_name HudReadoutTuning
extends Resource

@export_group("Boss bar")

## Seconds the ghost chunk holds at the old HP before it starts to drain.
@export var boss_ghost_hold_sec: float = 0.45
## Ghost drain speed as a share of max HP per second.
@export var boss_ghost_drain_per_sec: float = 0.6
## Length of the white flash over the bar when the boss enters a new phase.
@export var boss_phase_flash_sec: float = 0.5
## Peak alpha of that flash (0–1).
@export var boss_phase_flash_alpha: float = 0.75
## Width of a phase notch in px.
@export var boss_notch_width: float = 2.0

@export_group("Sigil strip")

## Side of one sigil / Core chip in px.
@export var strip_chip_size: float = 28.0
## Gap between chips and between rows in px.
@export var strip_chip_gap: float = 4.0
## Seconds a chip stays lit after its sigil fires.
@export var strip_pulse_sec: float = 0.35
