## HudJuiceTuning — timings for the HP bar ghost chunk and jolt, the prep→combat dim
## and the defeat crumple pose (ADR-0042).
##
## Authored as assets/data/hud_juice_tuning.tres and read through preload consts by
## CombatHUD, the game loop and CrumplePose.
class_name HudJuiceTuning
extends Resource

@export_group("HP ghost chunk")

## Seconds the lost HP stays visible as a pale chunk before it starts to drain.
@export var ghost_hold_sec: float = 0.4
## Seconds the chunk takes to drain down to the real HP once the hold ends.
@export var ghost_drain_sec: float = 0.35
## Colour of the chunk: a bone white from the UI text colour, so it reads as "lost",
## not as a second resource.
@export var ghost_color: Color = Color("#E9E1D3")

@export_group("HP bar jolt")

## Peak jolt offset in px on a hit.
@export var jolt_px: float = 3.0
## Seconds the jolt takes to settle.
@export var jolt_sec: float = 0.16
## Damage (as a share of max HP) at which the jolt reaches its full size. Smaller
## hits jolt less, down to half size.
@export_range(0.01, 1.0) var jolt_full_share: float = 0.15

@export_group("Combat dim")

## How much the room darkens while fighting (art bible §2.3: 15–20 %).
@export_range(0.0, 0.5) var combat_dim: float = 0.18
## Seconds of the dim at wave start (art bible §2.3: 0.3 s).
@export var dim_in_sec: float = 0.3
## Seconds the room takes to brighten again after the room is cleared.
@export var dim_out_sec: float = 0.8

@export_group("Crumple pose")

## Seconds the crumple strip takes to play (art bible §5.3: 8–12 frames at 60 fps,
## held a touch longer so it reads during the death slow-mo).
@export var crumple_sec: float = 0.45
## Defeat screen portrait scale (whole number keeps the pixels square).
@export var crumple_portrait_scale: int = 5
