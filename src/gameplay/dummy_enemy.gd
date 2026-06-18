## dummy_enemy.gd — Stationary training dummy for combo testing.
##
## Uses StaticBody2D (always solid — no move_and_slide needed).
## No HitArea → no contact damage to Fayde.
## Spawn contract (ADR-0007): caller must call
##   HealthAndDamage.register_enemy(dummy, DUMMY_TYPE_ID)
## BEFORE add_child(). training_room.gd owns this responsibility.
class_name DummyEnemy
extends StaticBody2D

## Emitted before queue_free() so training_room.gd can schedule a respawn.
signal dummy_killed

## Read by SpellCastingEffects Step9 elemental multiplier.
var prana_affiliation: int = GameEnums.DamageClass.NONE

# ── Constants ─────────────────────────────────────────────────────────────────

## WarpedWarden catalog entry (50 HP) — enough to observe multi-hit combos.
const DUMMY_TYPE_ID: int = 3

const _DEBUG_CIRCLE_SCRIPT: GDScript = preload("res://src/scenes/debug_circle_2d.gd")
const _DUMMY_COLOR: Color = Color(0.80, 0.80, 0.80, 1.0)  # light gray — training target

const _COLOR_BAR_BG: Color  = Color(0.10, 0.10, 0.10, 0.85)
const _COLOR_BAR_HP: Color  = Color(0.20, 0.90, 0.25)
const _COLOR_BAR_LOW: Color = Color(0.90, 0.20, 0.15)

## HP bar geometry — positioned above the debug silhouette (~43px tall).
const _BAR_W: float = 54.0
const _BAR_H: float = 7.0
const _BAR_Y: float = -55.0

# ── Private state ─────────────────────────────────────────────────────────────

var _current_hp: int  = 50
var _max_hp: int      = 50
var _is_dead: bool    = false

var _bar_bg: Polygon2D   = null
var _bar_fill: Polygon2D = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group(&"enemy")
	_setup_collision()
	_read_max_hp()
	_build_debug_circle()
	_build_hp_bar()
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)


func _exit_tree() -> void:
	if HealthAndDamage.damage_taken.is_connected(_on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(_on_damage_taken)
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)

# ── Public API ────────────────────────────────────────────────────────────────

## Duck-type contract shared with EnemyInstance — called by StatusEffectsManager.
func is_alive() -> bool:
	return not _is_dead


## Pushes this dummy away from [param direction] by [param distance] pixels over 0.1s.
## Called by SpellCastingEffects after each successful spell hit for combo game feel.
## StaticBody2D uses position tween — no move_and_slide needed.
func apply_knockback(direction: Vector2, distance: float) -> void:
	if _is_dead:
		return
	var offset: Vector2 = direction.normalized() * distance
	var target_pos: Vector2 = global_position + offset
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", target_pos, 0.10)


## Resets HP and visual state after H&D re-registration (called on Tab/prep reset).
func reset_hp() -> void:
	_is_dead = false
	_read_max_hp()
	_current_hp = _max_hp
	modulate = Color.WHITE
	_refresh_bar()

# ── Private — setup ───────────────────────────────────────────────────────────

func _setup_collision() -> void:
	# Layer 4 (enemy): spell physics ray (mask=5) detects this.
	# Mask 0: StaticBody2D needs no outbound detection to block movement.
	collision_layer = 4
	collision_mask = 0
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)


func _read_max_hp() -> void:
	var enemy_type: EnemyType = EnemyCatalog.get_type(DUMMY_TYPE_ID)
	if enemy_type != null:
		_max_hp = enemy_type.base_hp
		_current_hp = _max_hp


func _build_debug_circle() -> void:
	var dbg: Node2D = Node2D.new()
	dbg.set_script(_DEBUG_CIRCLE_SCRIPT)
	dbg.set("color", _DUMMY_COLOR)
	add_child(dbg)


func _build_hp_bar() -> void:
	_bar_bg = Polygon2D.new()
	_bar_bg.polygon = _rect_poly(-_BAR_W * 0.5, _BAR_Y, _BAR_W, _BAR_H)
	_bar_bg.color = _COLOR_BAR_BG
	add_child(_bar_bg)

	_bar_fill = Polygon2D.new()
	_bar_fill.color = _COLOR_BAR_HP
	add_child(_bar_fill)
	_refresh_bar()

# ── Private — visual updates ──────────────────────────────────────────────────

func _refresh_bar() -> void:
	if not is_instance_valid(_bar_fill) or not is_instance_valid(_bar_bg):
		return
	var ratio: float = float(_current_hp) / float(_max_hp) if _max_hp > 0 else 0.0
	_bar_fill.polygon = _rect_poly(-_BAR_W * 0.5, _BAR_Y, _BAR_W * ratio, _BAR_H)
	_bar_fill.color = _COLOR_BAR_HP.lerp(_COLOR_BAR_LOW, 1.0 - ratio)
	_bar_bg.visible = not _is_dead
	_bar_fill.visible = not _is_dead

# ── Static polygon helper ─────────────────────────────────────────────────────

static func _rect_poly(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x,     y),
		Vector2(x + w, y),
		Vector2(x + w, y + h),
		Vector2(x,     y + h),
	])

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_damage_taken(target: Node, _final_damage: int, current_hp: int) -> void:
	if target != self:
		return
	_current_hp = current_hp
	_refresh_bar()


func _on_enemy_killed(instance_id: int, _type_id: int, _affil: GameEnums.DamageClass) -> void:
	if instance_id != get_instance_id():
		return
	_is_dead = true
	_current_hp = 0
	collision_layer = 0  # stop spell raycasts from hitting dead body (ADR-0007)
	_refresh_bar()
	dummy_killed.emit()
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(self):
		queue_free()
