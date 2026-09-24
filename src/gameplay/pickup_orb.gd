## pickup_orb.gd — HP or Special-meter orb dropped by a kill (ADR-0019).
## Pops out of the corpse, idles, then flies to Fayde once she is inside the magnet
## radius (or when the room is cleared). Collected orbs heal through HealthAndDamage
## or feed the Special meter through SpellCastingEffects.
class_name PickupOrb
extends Node2D

enum Kind { HP = 0, METER = 1 }

## Every live orb is in this group — room clear and preparation query it.
const GROUP: StringName = &"pickup_orb"
const TUNING: PaceTuning = preload("res://assets/data/pace_tuning.tres")
const HP_COLOR: Color = Color(0.45, 1.0, 0.55, 1.0)
const METER_COLOR: Color = Color(1.0, 0.85, 0.35, 1.0)
## Seconds of outward pop before the magnet can take over.
const POP_SEC: float = 0.18
const FADE_SEC: float = 0.6

var kind: Kind = Kind.METER
## HP healed or meter added on collect.
var amount: float = 0.0
## Initial pop velocity (px/s), set by the spawner.
var pop_velocity: Vector2 = Vector2.ZERO

var _age: float = 0.0
var _magnet: bool = false
## Flight speed multiplier (raised by a room-clear magnetize).
var _speed_mult: float = 1.0
var _collected: bool = false
var _player: Node2D = null


func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	z_index = 2080
	add_to_group(GROUP)
	if _player == null and is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Node2D


func _physics_process(delta: float) -> void:
	var target: Vector2 = _player.global_position if is_instance_valid(_player) else global_position
	if step(delta, target, is_instance_valid(_player)):
		_apply()
		queue_free()
		return
	if _age >= TUNING.orb_lifetime_sec:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var c: Color = HP_COLOR if kind == Kind.HP else METER_COLOR
	var fade: float = clampf((TUNING.orb_lifetime_sec - _age) / FADE_SEC, 0.0, 1.0)
	var pulse: float = 1.0 + 0.15 * sin(_age * 12.0)
	var r: float = (4.5 if kind == Kind.HP else 3.0) * pulse
	draw_circle(Vector2.ZERO, r * 2.4, Color(c.r, c.g, c.b, 0.18 * fade))
	draw_circle(Vector2.ZERO, r + 1.2, Color(0.05, 0.03, 0.08, 0.8 * fade))
	draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, fade))
	if kind == Kind.HP:
		# Small plus so HP reads apart from meter without relying on colour alone.
		var w: Color = Color(1.0, 1.0, 1.0, fade)
		draw_line(Vector2(-r * 0.55, 0.0), Vector2(r * 0.55, 0.0), w, 1.5)
		draw_line(Vector2(0.0, -r * 0.55), Vector2(0.0, r * 0.55), w, 1.5)


## Moves the orb one frame toward [param target] (Fayde's position). Returns true
## when the orb reaches her and should be collected. [param has_target] false keeps
## the orb idle (no player in the tree).
func step(delta: float, target: Vector2, has_target: bool = true) -> bool:
	if _collected:
		return false
	_age += delta
	if _age < POP_SEC:
		position += pop_velocity * delta * (1.0 - _age / POP_SEC)
		return false
	if not has_target:
		return false
	var to: Vector2 = target - global_position
	var dist: float = to.length()
	if not _magnet and dist <= TUNING.orb_magnet_radius:
		_magnet = true
	if not _magnet:
		return false
	if dist <= TUNING.orb_pickup_radius:
		_collected = true
		return true
	var step_len: float = minf(TUNING.orb_magnet_speed * _speed_mult * delta, dist)
	global_position += to / dist * step_len
	if dist - step_len <= TUNING.orb_pickup_radius:
		_collected = true
		return true
	return false


## Forces the orb to fly to Fayde from anywhere (room cleared) at [param speed_mult]
## times the magnet speed. Also keeps it alive until it arrives.
func magnetize(speed_mult: float = 1.0) -> void:
	_magnet = true
	_speed_mult = maxf(_speed_mult, speed_mult)
	_age = minf(_age, TUNING.orb_lifetime_sec - FADE_SEC - 1.0)


## True once the orb is flying to Fayde.
func is_magnetized() -> bool:
	return _magnet


## Test seam: sets the node the orb flies to.
func set_player(p: Node2D) -> void:
	_player = p


## Magnetises every live orb in [param tree] at [param speed_mult]. Returns how many.
static func magnetize_all(tree: SceneTree, speed_mult: float = 1.0) -> int:
	if tree == null:
		return 0
	var n: int = 0
	for node: Node in tree.get_nodes_in_group(GROUP):
		var orb := node as PickupOrb
		if orb != null:
			orb.magnetize(speed_mult)
			n += 1
	return n


## Frees every live orb in [param tree] (new preparation phase, run end).
static func clear_all(tree: SceneTree) -> void:
	if tree == null:
		return
	for node: Node in tree.get_nodes_in_group(GROUP):
		node.queue_free()


func _apply() -> void:
	if kind == Kind.HP:
		if is_instance_valid(_player):
			HealthAndDamage.apply_heal(_player, amount)
	else:
		SpellCastingEffects.add_special_meter(amount)
