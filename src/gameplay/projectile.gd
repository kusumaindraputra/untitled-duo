## projectile.gd — Straight-line projectile fired by SHOOTER enemies.
## Moves in a locked direction, damages the player on overlap, despawns at max range.
## Layer: Gameplay | Story: S8-05 (bullet-hell prototype)
class_name Projectile
extends Area2D

const PROJECTILE_SPEED: float = 220.0
const MAX_RANGE: float = 400.0

var _direction: Vector2 = Vector2.RIGHT
var _base_damage: float = 1.5
var _distance_traveled: float = 0.0


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	collision_layer = 8
	collision_mask = 2   # PlayerController.COLLISION_LAYER_PLAYER
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += _direction * PROJECTILE_SPEED * delta
	_distance_traveled += PROJECTILE_SPEED * delta
	queue_redraw()
	if _distance_traveled >= MAX_RANGE:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, Color(0.2, 0.4, 1.0))


## Sets the travel direction (normalised) and damage amount. Call after add_child().
func launch(direction: Vector2, base_damage: float) -> void:
	_direction = direction.normalized()
	_base_damage = base_damage


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	HealthAndDamage.apply_damage(
		body, _base_damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	queue_free()
