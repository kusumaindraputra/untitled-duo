## EnemyType — Immutable data resource for one enemy variant.
##
## Loaded by EnemyCatalog at startup; returned as deep copies via get_type(id).
## Nullable fields (drop_prana_type, drop_rate, wave_threat_value) use Variant —
## typed int/float cannot hold null. Consumers must null-check before use (boss entries).
## prana_affiliation sentinel: DamageClass.NONE = -1 (never null) — TR-ED-004.
class_name EnemyType
extends Resource

@export var id: int = -1
@export var name: String = ""
@export var archetype: GameEnums.EnemyArchetype = GameEnums.EnemyArchetype.SEEKER
@export var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
@export var base_hp: int = 0
@export var base_damage: float = 0.0
@export var base_move_speed: float = 0.0
@export var drop_prana_type: Variant = null
@export var drop_rate: Variant = null
@export var wave_threat_value: Variant = null
@export var sprite_size: Vector2i = Vector2i(16, 16)
@export var status: GameEnums.EnemyStatus = GameEnums.EnemyStatus.ACTIVE
@export var scene: PackedScene = null
## Debug placeholder colour shown on DebugCircle until real sprites land.
## Applied in EnemyInstance.init() via DebugCircle.color = et.debug_color.
@export var debug_color: Color = Color.WHITE
