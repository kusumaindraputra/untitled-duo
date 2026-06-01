## EnemyHPInstance — Per-enemy HP record held inside HealthAndDamage._enemy_registry.
##
## One instance is created by HealthAndDamage.register_enemy() for every spawned enemy
## and erased from the registry immediately after enemy_killed is emitted (ADR-0007).
##
## Usage:
##   # Registered by WaveManager before add_child():
##   HealthAndDamage.register_enemy(enemy_node, enemy_type_id)
##   # Accessed internally inside HealthAndDamage:
##   var rec: EnemyHPInstance = _enemy_registry[instance_id]
##   rec.current_hp -= final_damage
class_name EnemyHPInstance
extends RefCounted

# ── Fields ────────────────────────────────────────────────────────────────────

## Maximum HP for this enemy instance (copied from EnemyType.base_hp at registration).
var max_hp: int = 0

## Current HP. Decremented by HealthAndDamage.apply_damage(); never goes negative.
var current_hp: int = 0

## Catalog type ID — passed as the second argument to enemy_killed.
var type_id: int = -1

## Whether enemy_killed has already been emitted for this record.
## Guards against duplicate death signals if apply_damage() is called concurrently.
var is_dead: bool = false

## Elemental affiliation from EnemyType.prana_affiliation.
## Included in the enemy_killed signal payload.
## NONE (DamageClass.NONE = -1) for neutral enemies — never null (ADR-0007).
var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
