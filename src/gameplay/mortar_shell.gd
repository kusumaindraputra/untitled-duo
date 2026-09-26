## mortar_shell.gd — Telegraphed ground blast fired by a MORTAR BulletPattern (ADR-0018).
## Marks Fayde's position with a closing ring for telegraph_sec, then explodes:
## damage inside [member BulletPattern.radius], plus an optional ring of splash bullets.
class_name MortarShell
extends Node2D

const TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")
const BLAST_FLASH_SEC: float = 0.18

var pattern: BulletPattern = null
var damage: float = 10.0
## What the shell is, for the death recap (DeathRecap.cause()); splash bullets inherit it.
var cause: Dictionary = {}
## ADR-0019 difficulty curve: multiplies pattern.telegraph_sec (set by the firing enemy).
var telegraph_mult: float = 1.0

var _timer: float = 0.0
var _exploded: bool = false
var _flash: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	z_index = 3
	_timer = _telegraph_sec()
	if is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	add_to_group(&"enemy_hazard")


func _physics_process(delta: float) -> void:
	if pattern == null:
		queue_free()
		return
	if _exploded:
		_flash -= delta
		if _flash <= 0.0:
			queue_free()
		queue_redraw()
		return
	_timer -= delta
	if _timer <= 0.0:
		explode()
	queue_redraw()


func _draw() -> void:
	if pattern == null:
		return
	var c: Color = pattern.color
	var r: float = pattern.radius
	if _exploded:
		var a: float = clampf(_flash / BLAST_FLASH_SEC, 0.0, 1.0)
		draw_circle(Vector2.ZERO, r, Color(1.0, 0.9, 0.6, 0.55 * a))
		draw_arc(Vector2.ZERO, r * (1.2 - 0.2 * a), 0.0, TAU, 32, Color(c.r, c.g, c.b, a), 3.0, true)
		return
	var p: float = 1.0 - clampf(_timer / maxf(_telegraph_sec(), 0.01), 0.0, 1.0)
	draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.10 + 0.15 * p))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.7), 1.5, true)
	# Closing ring: shrinks onto the blast edge as the shell lands.
	draw_arc(Vector2.ZERO, lerpf(r * 2.2, r, p), 0.0, TAU, 32, Color(c.r, c.g, c.b, 0.4 + 0.5 * p), 2.0, true)


## Detonates now: damages Fayde inside the radius and releases splash bullets.
func explode() -> void:
	if _exploded:
		return
	_exploded = true
	_flash = BLAST_FLASH_SEC
	Sfx.play(&"sfx_mortar_blast")
	if is_instance_valid(_player):
		var d: float = global_position.distance_to(_player.global_position)
		if d <= pattern.radius + TUNING.player_hurt_radius:
			if _player.has_method(&"register_perfect_dodge"):
				_player.register_perfect_dodge(_player.global_position)  # ADR-0019
			HealthAndDamage.apply_damage(
				_player, damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT, cause)
		elif d <= pattern.radius + Projectile.graze_radius_of(_player):
			SpellCastingEffects.register_graze(_player.global_position, 1.0)
	if pattern.splash_count > 0:
		var pool: BulletPool = BulletPool.for_parent(get_parent())
		if pool != null:
			for i: int in pattern.splash_count:
				var dir: Vector2 = Vector2.from_angle(TAU / float(pattern.splash_count) * float(i))
				var b: Projectile = pool.acquire()
				b.global_position = global_position
				b.launch_pattern(dir, damage * 0.5, pattern, pattern.speed)
				b.cause = cause


## Test hook.
func has_exploded() -> bool:
	return _exploded


## Telegraph length after the difficulty curve.
func _telegraph_sec() -> float:
	return (pattern.telegraph_sec if pattern != null else 0.8) * maxf(telegraph_mult, 0.05)
