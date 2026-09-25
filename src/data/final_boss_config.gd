## FinalBossConfig — data for the Floor 3 final boss, the Cipher Keeper (ADR-0026).
##
## The boss's bullet layers live on its EnemyType (enemy_cipher_keeper.tres). This
## resource holds what happens to the arena when it crosses each HP phase: which
## stage hazards appear, and on which phase every bullet is wiped for a breather
## before the last stand. Banner text lives in UICopy (keeper_phase_banners).
## Authored as assets/data/final_boss/final_boss_config.tres.
class_name FinalBossConfig
extends Resource

## EnemyType id of the final boss.
@export var boss_type_id: int = 11

## Phase (1-based, as EnemyInstance.phase_changed counts) that spawns the sweep pylon.
@export var sweep_phase: int = 1
## Rotating beam pylon placed on the room centre.
@export var sweep_spec: HazardSpec = null

## Phase that closes the arena in.
@export var ring_phase: int = 2
## Closing ring (room-centred; half extents come from the room).
@export var ring_spec: HazardSpec = null

## Phase that clears every enemy bullet before the last stand.
@export var breather_phase: int = 3
## Camera trauma on each phase change.
@export var phase_trauma: float = 0.5
