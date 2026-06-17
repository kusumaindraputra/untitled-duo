## enemy_instance.gd — Enemy AI controller for a single enemy instance.
## Layer: Gameplay | Stories: EAI-001 (skeleton), EAI-002 (FP movement), EAI-003 (contact attack), EAI-004 (death), S8-02 (collision layer 4).
## Implements: design/gdd/enemy-ai.md (AC-EAI-01–06, AC-EAI-07–09, AC-EAI-10–14, AC-EAI-15–17, AC-EAI-18, AC-EAI-19, AC-EAI-28, AC-EAI-29)
class_name EnemyInstance
extends CharacterBody2D

## Story-local state enum — only CHASING and DEAD are needed at this story scope.
## The full GameEnums.EnemyState (IDLE, PURSUING, ATTACKING, STUNNED, DEAD) gates
## in at Story 002+ when per-archetype tick functions are implemented.
enum EnemyState { CHASING = 0, DEAD = 1 }

# ── Private state ─────────────────────────────────────────────────────────────

var _state: EnemyState = EnemyState.CHASING
var _combat_active: bool = false
var _archetype: GameEnums.EnemyArchetype = GameEnums.EnemyArchetype.SEEKER
var _base_damage: float = 0.0
var _move_speed: float = 0.0
var _fayde_ref: Node2D = null

## Last valid direction toward Fayde — held when dir.length() < 0.01 (Story 002).
var _dir_last_valid: Vector2 = Vector2.RIGHT

## True while Fayde's CharacterBody2D overlaps this enemy's HitArea (Story 003).
var _fayde_in_contact: bool = false

## Accumulator tracking contact interval cooldown (Story 003).
var _contact_timer: float = 0.0

## True while the no-animation death fallback timer is counting down (Story 004).
var _death_fallback_active: bool = false

## Remaining seconds before queue_free() fires in the fallback path (Story 004).
var _death_fallback_timer: float = 0.0

## Float accumulator for SHOOTER shoot interval (S8-05, ADR-0004 pattern).
var _shoot_timer: float = 0.0

## Minimum seconds between contact damage events (design/gdd/enemy-ai.md Tuning Knobs).
## Must remain >= 0.3s — H&D i-frame guarantee depends on this (Enemy AI Dep. #3).
const ENEMY_MIN_CONTACT_INTERVAL: float = 0.3

## Seconds before queue_free() fires when no "death" animation is available (AC-EAI-29).
const BASE_DEATH_DURATION: float = 0.7

## SHOOTER archetype — minimum distance maintained from Fayde (S8-05).
const KEEP_DISTANCE: float = 150.0
## SHOOTER archetype — seconds between projectile shots (S8-05).
const SHOOT_INTERVAL: float = 2.0

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group(&"enemy")
	_setup_collision_nodes()
	$HitArea.body_entered.connect(_on_hitarea_body_entered)
	$HitArea.body_exited.connect(_on_hitarea_body_exited)
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
	_fayde_ref = get_tree().get_first_node_in_group(&"player") as Node2D
	# Enemies are spawned inside WaveManager._on_combat_started, so they always
	# miss the combat_started signal. Self-activate when spawned mid-combat.
	if GameStateManager.get_active_state() == GameEnums.GameState.COMBAT_PHASE:
		_on_combat_started(false)


## Programmatic collision node setup — replaced by EnemyInstance.tscn in a later story.
## Creates a root CollisionShape2D (movement) and a child Area2D named "HitArea"
## with its own CollisionShape2D (contact detection). (AC-EAI-02)
## Placeholder radii (8 / 12 px) chosen for physics correctness; tune with real art.
func _setup_collision_nodes() -> void:
	var body_circle := CircleShape2D.new()
	body_circle.radius = 8.0
	var root_shape := CollisionShape2D.new()
	root_shape.name = "CollisionShape2D"
	root_shape.shape = body_circle
	add_child(root_shape)
	# Enemies on layer 3 (bit 2, value 4). Mask includes walls (1) and half-cover debris (16).
	# Player dash pass-through works by removing layer 3 from player's mask (S8-02, S9-09).
	collision_layer = 4
	collision_mask = 17
	var hit_circle := CircleShape2D.new()
	hit_circle.radius = 12.0
	var hit_shape := CollisionShape2D.new()
	hit_shape.shape = hit_circle
	var hit_area := Area2D.new()
	hit_area.name = "HitArea"
	hit_area.collision_layer = 0  # sensor only — not on any layer
	hit_area.collision_mask = 2   # detect player body (COLLISION_LAYER_PLAYER = 2)
	hit_area.add_child(hit_shape)
	add_child(hit_area)
	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)


func _exit_tree() -> void:
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
	# Guard against mid-animation scene teardown racing the CONNECT_ONE_SHOT callback.
	if $AnimationPlayer.animation_finished.is_connected(_on_death_animation_finished):
		$AnimationPlayer.animation_finished.disconnect(_on_death_animation_finished)
	# HitArea child signals need no explicit disconnect — freed together with this node.


func _physics_process(delta: float) -> void:
	# Isometric draw-order sort — same rationale as PlayerController (ADR-0001).
	z_index = clamp(int(global_position.y) + 500, 1, 2000)

	# Death fallback timer — ticks even in DEAD state (AC-EAI-29).
	# Must come before the DEAD-state early return so the timer can expire.
	if _death_fallback_active:
		_death_fallback_timer -= delta
		if _death_fallback_timer <= 0.0:
			_death_fallback_active = false
			queue_free()
		return  # load-bearing: keeps movement + contact code from running while dying

	# AC-EAI-04: combat inactive → velocity zero.
	# AC-EAI-05: DEAD state takes precedence even when _combat_active is true.
	if not _combat_active or _state == EnemyState.DEAD:
		velocity = Vector2.ZERO
		return

	# Re-resolve Fayde ref if lost between frames (AC-EAI-27).
	# is_inside_tree() guard prevents get_tree() null crash in unit tests where
	# the node is exercised without being added to the scene tree.
	if _fayde_ref == null and is_inside_tree():
		_fayde_ref = get_tree().get_first_node_in_group(&"player") as Node2D
	if _fayde_ref == null:
		velocity = Vector2.ZERO
		return

	# Direction toward Fayde — update last-valid only when non-degenerate (AC-EAI-07, 08, 09).
	var raw_dir: Vector2 = _fayde_ref.global_position - global_position
	if raw_dir.length() >= 0.01:
		_dir_last_valid = raw_dir.normalized()

	if _archetype == GameEnums.EnemyArchetype.SHOOTER:
		_tick_shooter(delta)
	else:
		velocity = _dir_last_valid * _move_speed
		move_and_slide()

	# Contact repeat timer — ADR-0004 float accumulator. Fires repeat damage while
	# Fayde stays inside the hit zone. Timer is armed by _on_hitarea_body_entered
	# and disarmed by _on_hitarea_body_exited (AC-EAI-11, AC-EAI-12).
	if _fayde_in_contact and _contact_timer > 0.0:
		_contact_timer -= delta
		if _contact_timer <= 0.0:
			HealthAndDamage.apply_damage(
				_fayde_ref, _base_damage,
				GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
			# += preserves sub-frame overshoot per ADR-0004 decrement pattern.
			_contact_timer += ENEMY_MIN_CONTACT_INTERVAL

# ── Public API ────────────────────────────────────────────────────────────────

## Initialises this enemy from the catalog entry at [param enemy_type_id].
## Called by WaveManager after register_enemy() and add_child() (ADR-0014).
## [param catalog] is injected in tests; gameplay code passes null to use the Autoload.
func init(enemy_type_id: int, catalog: Variant = null) -> void:
	var et: EnemyType
	if catalog != null:
		et = catalog.get_type(enemy_type_id)
	else:
		et = EnemyCatalog.get_type(enemy_type_id)
	if et == null:
		push_error("EnemyInstance.init(): catalog returned null for type_id %d" % enemy_type_id)
		return
	_archetype = et.archetype
	_base_damage = et.base_damage
	_move_speed = et.base_move_speed
	var debug_circle: Node = get_node_or_null("DebugCircle")
	if debug_circle != null:
		debug_circle.set("color", et.debug_color)


## Returns true when this enemy is not in the DEAD state.
## Required by ADR-0011 (StatusEffectsManager API Contract).
func is_alive() -> bool:
	return _state != EnemyState.DEAD


## Required by ADR-0011 — stub; fully implemented in Story 005.
## SEM calls this on Freeze/Chill apply and expiry.
func apply_speed_modifier(_multiplier: float) -> void:
	pass


# ── Private helpers ───────────────────────────────────────────────────────────

## SHOOTER archetype tick — maintains distance, accumulates shoot timer (S8-05).
func _tick_shooter(delta: float) -> void:
	var dist: float = global_position.distance_to(_fayde_ref.global_position)
	if dist < KEEP_DISTANCE:
		velocity = -_dir_last_valid * _move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_shoot_timer += delta
	if _shoot_timer >= SHOOT_INTERVAL:
		_shoot_timer -= SHOOT_INTERVAL
		_fire_projectile()


## Spawns a Projectile aimed at the last known Fayde direction (S8-05).
## Guards against missing parent (headless test context).
func _fire_projectile() -> void:
	if get_parent() == null:
		return
	var proj: Projectile = Projectile.new()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.launch(_dir_last_valid, _base_damage)


## Required by ADR-0011 — stub; fully implemented in Story 005.
## SEM calls this on Stun/Stagger apply.
func apply_stun(_duration: float) -> void:
	pass

# ── Signal handlers ───────────────────────────────────────────────────────────

## Opens the combat phase gate. (AC-EAI-06)
## velocity > 0 deferred to Story 002 — skeleton has no movement direction code.
func _on_combat_started(_is_boss: bool = false) -> void:
	_combat_active = true


## Closes the combat phase gate and resets per-wave transient state.
func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_combat_active = false
	velocity = Vector2.ZERO
	_fayde_in_contact = false
	_contact_timer = 0.0
	_shoot_timer = 0.0


## Responds to H&D's enemy_killed signal (AC-EAI-15, 16, 28, 29).
## Instance ID guard ensures only this enemy handles its own death event.
func _on_enemy_killed(instance_id: int, _type_id: int, _prana_affiliation: GameEnums.DamageClass) -> void:
	if instance_id != get_instance_id():
		return
	if _state == EnemyState.DEAD:
		return

	_state = EnemyState.DEAD
	velocity = Vector2.ZERO
	_contact_timer = 0.0
	_fayde_in_contact = false
	$HitArea.monitoring = false

	if $AnimationPlayer.has_animation(&"death"):
		$AnimationPlayer.play(&"death")
		$AnimationPlayer.animation_finished.connect(
			_on_death_animation_finished, CONNECT_ONE_SHOT)
	else:
		_start_death_fallback_timer()


## Called when the "death" AnimationPlayer animation completes (AC-EAI-17).
## queue_free() defers node removal to end-of-frame — node remains valid for this frame.
func _on_death_animation_finished(_anim_name: StringName) -> void:
	queue_free()


## Arms the float-accumulator fallback timer when no "death" animation is available (AC-EAI-29).
func _start_death_fallback_timer() -> void:
	_death_fallback_active = true
	_death_fallback_timer = BASE_DEATH_DURATION


## Fires the initial contact hit and arms the repeat timer (AC-EAI-10).
## Guards against non-player bodies, DEAD state, inactive combat, and duplicate signals.
func _on_hitarea_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	if _state == EnemyState.DEAD or not _combat_active:
		return
	if _fayde_in_contact:
		return
	_fayde_in_contact = true
	HealthAndDamage.apply_damage(
		body, _base_damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT)
	_contact_timer = ENEMY_MIN_CONTACT_INTERVAL


## Disarms the contact timer when Fayde leaves the hit zone (AC-EAI-12).
## No further apply_damage calls occur until next body_entered.
func _on_hitarea_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_fayde_in_contact = false
	_contact_timer = 0.0
