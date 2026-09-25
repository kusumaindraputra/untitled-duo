## SigilEffects — runtime for the behaviour sigils (ADR-0026).
##
## Stat sigils change a number in their owning system. Behaviour sigils change how a
## run plays instead: burning ground behind a dash, a zap on every graze, a blast on a
## Perfect Dodge. Their effects hang off existing gameplay signals, so this node owns
## all of them and SigilManager only adds stacks here. Taking a sigil again adds a
## stack, which scales its damage, heal or radius.
##
## Run-scoped: created by debug_game_loop and freed with the scene. Tuning and copy
## live in SigilConfig (assets/data/sigil_config.tres). Pure maths are static so they
## are unit-tested headless.
class_name SigilEffects
extends Node

## Emitted after an effect fires, for audio / HUD feedback.
signal effect_fired(sigil_id: StringName, world_pos: Vector2)

const CONFIG: SigilConfig = preload("res://assets/data/sigil_config.tres")

## Ids handled here. SigilManager routes these to add_stack().
const IDS: Array[StringName] = [&"ember_wake", &"static_halo", &"afterglow", &"unravel",
	&"siphon", &"riposte", &"metronome"]

## Player node; polled for dashing, used as the origin of player-centred effects.
var player: Node2D = null

var _stacks: Dictionary[StringName, int] = {}
var _kills: int = 0
var _static_cd: float = 0.0
var _ember_last_pos: Vector2 = Vector2.INF


## True when [param id] is a behaviour sigil.
static func handles(id: StringName) -> bool:
	return IDS.has(id)


## Adds one stack of [param id]. Returns false for ids this node does not handle.
func add_stack(id: StringName) -> bool:
	if not handles(id):
		return false
	_stacks[id] = stacks(id) + 1
	return true


func stacks(id: StringName) -> int:
	return _stacks.get(id, 0)


func _ready() -> void:
	SpellCastingEffects.grazed.connect(_on_grazed)
	SpellCastingEffects.special_fired.connect(_on_special_fired)
	SpellCastingEffects.perfect_cast.connect(_on_perfect_cast)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
	GameStateManager.run_started.connect(reset)


func _exit_tree() -> void:
	if SpellCastingEffects.grazed.is_connected(_on_grazed):
		SpellCastingEffects.grazed.disconnect(_on_grazed)
	if SpellCastingEffects.special_fired.is_connected(_on_special_fired):
		SpellCastingEffects.special_fired.disconnect(_on_special_fired)
	if SpellCastingEffects.perfect_cast.is_connected(_on_perfect_cast):
		SpellCastingEffects.perfect_cast.disconnect(_on_perfect_cast)
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
	if GameStateManager.run_started.is_connected(reset):
		GameStateManager.run_started.disconnect(reset)


## Clears every stack (new run).
func reset() -> void:
	_stacks.clear()
	_kills = 0
	_ember_last_pos = Vector2.INF


func _physics_process(delta: float) -> void:
	_static_cd = maxf(_static_cd - delta, 0.0)
	if stacks(&"ember_wake") <= 0 or not is_instance_valid(player):
		return
	var dashing: bool = player.has_method(&"is_dashing") and player.is_dashing()
	if not dashing:
		_ember_last_pos = Vector2.INF
		return
	var pos: Vector2 = player.global_position
	if _ember_last_pos == Vector2.INF or pos.distance_to(_ember_last_pos) >= CONFIG.ember_spacing:
		_ember_last_pos = pos
		_spawn_ember(pos)


# ── Pure maths ────────────────────────────────────────────────────────────────

## Meter refunded by Afterglow at [param n] stacks on a meter of [param max_meter].
static func afterglow_amount(n: int, max_meter: float, t: SigilConfig = CONFIG) -> float:
	if n <= 0:
		return 0.0
	return max_meter * minf(t.afterglow_refund * float(n), t.afterglow_refund_cap)


## Unravel cancel radius at [param n] stacks (+50 % per extra stack).
static func unravel_radius(n: int, t: SigilConfig = CONFIG) -> float:
	return 0.0 if n <= 0 else t.unravel_radius * (1.0 + 0.5 * float(n - 1))


## Siphon: true when kill number [param kill_count] (1-based) triggers a heal.
static func siphon_triggers(kill_count: int, t: SigilConfig = CONFIG) -> bool:
	return kill_count > 0 and t.siphon_kills > 0 and kill_count % t.siphon_kills == 0


## Nearest living node in [param candidates] within [param max_range] of [param from].
static func nearest(from: Vector2, candidates: Array[Node], max_range: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = max_range
	for n: Node in candidates:
		var e := n as Node2D
		if e == null or (e.has_method(&"is_alive") and not e.is_alive()):
			continue
		var d: float = from.distance_to(e.global_position)
		if d <= best_d:
			best_d = d
			best = e
	return best


# ── Handlers ──────────────────────────────────────────────────────────────────

func _on_grazed(world_pos: Vector2, _gain: float) -> void:
	var n: int = stacks(&"static_halo")
	if n <= 0 or _static_cd > 0.0 or not is_inside_tree():
		return
	var target: Node2D = nearest(world_pos, get_tree().get_nodes_in_group(&"enemy"), CONFIG.static_range)
	if target == null:
		return
	_static_cd = CONFIG.static_cooldown
	HealthAndDamage.apply_damage(target, CONFIG.static_damage * float(n),
		GameEnums.DamageClass.LIGHTNING, GameEnums.DamageSource.DIRECT)
	_spawn_fx(_ZapFx.new(world_pos, target.global_position))
	effect_fired.emit(&"static_halo", target.global_position)


func _on_special_fired(_pt: int, world_pos: Vector2, _radius: float) -> void:
	var amount: float = afterglow_amount(stacks(&"afterglow"), SpellCastingEffects.ATTACK_TUNING.special_meter_max)
	if amount > 0.0:
		SpellCastingEffects.add_special_meter(amount)
		effect_fired.emit(&"afterglow", world_pos)


func _on_perfect_cast(world_pos: Vector2, streak: int) -> void:
	var n: int = stacks(&"metronome")
	if n <= 0 or streak < CONFIG.metronome_streak or not is_instance_valid(player):
		return
	HealthAndDamage.apply_heal(player, CONFIG.metronome_heal * float(n))
	effect_fired.emit(&"metronome", world_pos)


func _on_enemy_killed(instance_id: int, _type_id: int, _aff: GameEnums.DamageClass) -> void:
	var enemy := instance_from_id(instance_id) as Node2D
	var r: float = unravel_radius(stacks(&"unravel"))
	if r > 0.0 and is_instance_valid(enemy) and is_inside_tree():
		if Projectile.cancel_in_radius(get_tree(), enemy.global_position, r) > 0:
			_spawn_fx(_RingFx.new(enemy.global_position, r, Color(0.7, 0.85, 1.0)))
			effect_fired.emit(&"unravel", enemy.global_position)
	var n: int = stacks(&"siphon")
	if n > 0:
		_kills += 1
		if siphon_triggers(_kills) and is_instance_valid(player):
			HealthAndDamage.apply_heal(player, CONFIG.siphon_heal * float(n))
			effect_fired.emit(&"siphon", player.global_position)


## Riposte: called by the parent on PaceDirector.perfect_dodge_triggered.
func on_perfect_dodge(world_pos: Vector2) -> void:
	var n: int = stacks(&"riposte")
	if n <= 0 or not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		var e := node as Node2D
		if e == null or (e.has_method(&"is_alive") and not e.is_alive()):
			continue
		if e.global_position.distance_to(world_pos) <= CONFIG.riposte_radius:
			HealthAndDamage.apply_damage(e, CONFIG.riposte_damage * float(n),
				GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	_spawn_fx(_RingFx.new(world_pos, CONFIG.riposte_radius, Color(1.0, 0.9, 0.5)))
	Sfx.play(&"sfx_mortar_blast")
	effect_fired.emit(&"riposte", world_pos)


func _spawn_ember(pos: Vector2) -> void:
	var patch := _EmberPatch.new()
	patch.damage = CONFIG.ember_damage * float(stacks(&"ember_wake"))
	_spawn_fx(patch)
	patch.global_position = pos


func _spawn_fx(fx: Node2D) -> void:
	var parent_node: Node = player.get_parent() if is_instance_valid(player) else null
	if parent_node == null:
		fx.free()
		return
	parent_node.add_child(fx)


# ── Effect nodes ──────────────────────────────────────────────────────────────

## Burning ground left by Ember Wake. Damages enemies inside it every tick.
class _EmberPatch extends Node2D:
	var damage: float = 4.0
	var _life: float = 0.0
	var _tick: float = 0.0

	func _ready() -> void:
		z_index = 2
		_life = SigilEffects.CONFIG.ember_duration

	func _physics_process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
		_tick -= delta
		if _tick <= 0.0:
			_tick = SigilEffects.CONFIG.ember_tick_sec
			var r: float = SigilEffects.CONFIG.ember_radius
			for node: Node in get_tree().get_nodes_in_group(&"enemy"):
				var e := node as Node2D
				if e == null or (e.has_method(&"is_alive") and not e.is_alive()):
					continue
				if e.global_position.distance_to(global_position) <= r:
					HealthAndDamage.apply_damage(e, damage, GameEnums.DamageClass.FIRE,
						GameEnums.DamageSource.DOT)
		queue_redraw()

	func _draw() -> void:
		var t: float = clampf(_life / SigilEffects.CONFIG.ember_duration, 0.0, 1.0)
		var flicker: float = 0.8 + 0.2 * sin(float(Time.get_ticks_msec()) * 0.02 + position.x)
		PixelVFX.fill_disc(self, Vector2.ZERO, SigilEffects.CONFIG.ember_radius * 0.6,
			Color(1.0, 0.45, 0.1), 0.55 * t * flicker)


## Short lightning line for Static Halo.
class _ZapFx extends Node2D:
	var _a: Vector2
	var _b: Vector2
	var _life: float = 0.12

	func _init(a: Vector2, b: Vector2) -> void:
		_a = a
		_b = b

	func _ready() -> void:
		z_index = 20

	func _process(delta: float) -> void:
		_life -= delta
		if _life <= 0.0:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var mid: Vector2 = (_a + _b) * 0.5 + (_b - _a).orthogonal().normalized() * 10.0
		PixelVFX.stroke_polyline(self, PackedVector2Array([_a, mid, _b]), 2.0,
			Color(0.75, 0.9, 1.0), 1.0)


## Expanding ring for Riposte and Unravel.
class _RingFx extends Node2D:
	var _center: Vector2
	var _radius: float
	var _color: Color
	var _t: float = 0.0
	const DURATION: float = 0.3

	func _init(center: Vector2, radius: float, color: Color) -> void:
		_center = center
		_radius = radius
		_color = color

	func _ready() -> void:
		z_index = 20
		global_position = _center

	func _process(delta: float) -> void:
		_t += delta
		if _t >= DURATION:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var p: float = clampf(_t / DURATION, 0.0, 1.0)
		PixelVFX.stroke_ring(self, _radius * p, 3.0, _color, 1.0 - p)
