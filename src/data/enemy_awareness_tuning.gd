## EnemyAwarenessTuning — alert / aggro knobs for enemies (ADR-0024).
##
## Enemies of a room's opening wave spawn DORMANT: they stand still and hold fire
## until Fayde walks into their aggro area, hits them, or a nearby ally is alerted
## (Diablo-style pull). Reinforcements and bosses always arrive awake.
## Authored as assets/data/enemy_awareness_tuning.tres, consumed via preload const.
class_name EnemyAwarenessTuning
extends Resource

## Master switch. Off = every enemy chases from the moment it spawns (old behaviour).
@export var enabled: bool = true
## Aggro radius in ground px. Distances are measured on the isometric floor, so the
## area is a 2:1 ellipse on screen (see iso_y_scale). 230 wakes an enemy 230 px to
## the side or 115 px above/below Fayde — inside the 576×324 view at combat zoom 2.0,
## so a dormant enemy is always on screen before it starts shooting.
@export var aggro_radius: float = 230.0
## An enemy that becomes alerted wakes every dormant enemy within this ground radius
## of itself, so packs pull together instead of one by one.
@export var alert_link_radius: float = 170.0
## Screen-y stretch applied before measuring distance (2.0 = the 2:1 iso diamond).
@export var iso_y_scale: float = 2.0
## Safety net: a dormant enemy wakes on its own after this many seconds of combat so
## a room never stalls. 0 = never.
@export var max_dormant_sec: float = 6.0
## Seconds the "!" alert mark stays above an enemy's head.
@export var alert_mark_sec: float = 0.5
