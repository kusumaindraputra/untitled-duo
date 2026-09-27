## hazard_turret.gd — Static emplacement that fires a BulletPattern at Fayde (ADR-0020).
##
## Uses the same BulletPatternRunner and BulletPool as enemies, so its bullets graze,
## cancel and break on pillars like any enemy bullet. It cannot be destroyed; it
## powers down when the room is cleared. Its base is half cover (layer 16): it blocks
## walking, but bullets (its own included) fly over it.
class_name HazardTurret
extends StageHazard

## Physics layer for the base: half cover, same as debris.
const BASE_LAYER: int = 16
## Base collision radius in pixels.
const BASE_RADIUS: float = 18.0

var _runner: BulletPatternRunner = null
var _aim: float = PI * 0.5
var _windup: float = 0.0


func _ready() -> void:
	super._ready()
	var body := StaticBody2D.new()
	body.collision_layer = BASE_LAYER
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BASE_RADIUS
	shape.shape = circle
	body.add_child(shape)
	add_child(body)
	z_index = 5


## Test hook: the runner driving this turret (created on first activation).
func get_runner() -> BulletPatternRunner:
	return _runner


func _on_activated() -> void:
	if spec.pattern == null:
		return
	if _runner == null:
		_runner = BulletPatternRunner.new(spec.pattern)
	else:
		_runner.reset()


func _hazard_tick(delta: float) -> void:
	if _runner == null:
		return
	if is_instance_valid(_player):
		_aim = (_player.global_position - global_position).angle()
	_windup = maxf(_windup - delta, 0.0)
	for ev: Dictionary in _runner.tick(delta, _aim):
		if ev["type"] == BulletPatternRunner.EVENT_WINDUP:
			_windup = spec.pattern.windup_sec
		else:
			_fire(ev["angles"], float(ev["speed"]))


func _fire(angles: PackedFloat32Array, speed: float) -> void:
	var pool: BulletPool = BulletPool.for_parent(get_parent())
	if pool == null:
		return
	var muzzle: Vector2 = global_position + Vector2(0, -14)
	for a: float in angles:
		var b: Projectile = pool.acquire()
		if b == null:
			break  # live bullet cap (ADR-0050)
		b.global_position = muzzle
		b.launch_pattern(Vector2.from_angle(a), spec.damage, spec.pattern, speed)
		b.cause = DeathRecap.cause(DeathRecap.hazard_attacker(spec.kind),
			DeathRecap.attack_for_pattern(spec.pattern))
	Sfx.play(&"sfx_bullet_fire")


func _draw() -> void:
	if spec == null:
		return
	# ADR-0037: a turret that shoots bullets glows in the hostile rim colour.
	var c: Color = BulletPattern.rim_color() if spec.pattern != null else spec.color
	var body_col: Color = Color(0.22, 0.2, 0.26, 1.0)
	# Shadow + octagonal base.
	draw_colored_polygon(CoverPillar._ellipse(Vector2(0, 2), BASE_RADIUS * 1.2, BASE_RADIUS * 0.55), Color(0, 0, 0, 0.5))
	draw_colored_polygon(CoverPillar._ellipse(Vector2(0, -4), BASE_RADIUS, BASE_RADIUS * 0.5), body_col)
	draw_colored_polygon(CoverPillar._ellipse(Vector2(0, -14), BASE_RADIUS * 0.7, BASE_RADIUS * 0.35), body_col.lightened(0.2))
	# Barrel toward Fayde.
	var tip: Vector2 = Vector2(0, -14) + Vector2.from_angle(_aim) * Vector2(20, 10)
	draw_line(Vector2(0, -14), tip, body_col.lightened(0.35), 5.0, true)
	# Core light: dim idle, bright while winding up to fire.
	var glow: float = 0.35
	if _active:
		glow = 0.65 + (0.35 if _windup > 0.0 else 0.0)
	draw_circle(Vector2(0, -14), 5.0, Color(c.r, c.g, c.b, glow))
	if _windup > 0.0:
		draw_arc(Vector2(0, -14), 10.0, 0.0, TAU, 16, Color(c.r, c.g, c.b, 0.8), 2.0, true)
