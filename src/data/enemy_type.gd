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
## Visual scale multiplier for wave spawn tween target. 1.0 = normal enemy, 2.5 = boss.
## Read by WaveManager._spawn_wave() to set the pop-in tween final scale. (LD-03)
@export var base_scale: float = 1.0
## Pixel-art sheet (ADR-0022): 4 columns × 2 rows (idle, moving) from
## tools/art-gen/generate_character_sprites.gd. Null = DebugCircle placeholder.
@export var sprite_sheet: Texture2D = null
## On-screen pixel size of one sheet pixel, after base_scale (keep it a whole number
## so pixels stay square: bosses use 2.0 whatever their base_scale).
@export var sprite_pixel_scale: float = 1.0
## Colour multiplied onto the sprite, so one sheet can serve a distinct enemy
## (the final boss reuses the Vault Sentinel sheet in gold, ADR-0026).
@export var sprite_tint: Color = Color.WHITE

@export_group("Bullet Patterns (ADR-0018)")
## Attack layers fired on their own interval while the enemy is active. Each layer's
## hp_threshold gates it by HP ratio, which is how bosses gain layers per phase.
@export var pattern_layers: Array[BulletPattern] = []
## Volley released once when this enemy dies (Splitter). Null = none.
@export var death_pattern: BulletPattern = null
## SHOOTER archetype — distance (px) it backs away to keep from Fayde.
@export var keep_distance: float = 150.0
