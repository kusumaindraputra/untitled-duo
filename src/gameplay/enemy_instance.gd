## enemy_instance.gd — Enemy AI controller for a single enemy instance.
## Layer: Gameplay | Stories: EAI-001 (skeleton), EAI-002 (FP movement), EAI-003 (contact attack), EAI-004 (death), S8-02 (collision layer 4).
## Implements: design/gdd/enemy-ai.md (AC-EAI-01–06, AC-EAI-07–09, AC-EAI-10–14, AC-EAI-15–17, AC-EAI-18, AC-EAI-19, AC-EAI-28, AC-EAI-29)
class_name EnemyInstance
extends CharacterBody2D

## Story-local state enum. STUNNED added when apply_stun/apply_speed_modifier landed.
## The full GameEnums.EnemyState (IDLE, PURSUING, ATTACKING, STUNNED, DEAD) gates
## in at a later story when archetype tick functions are formalised.
enum EnemyState { CHASING = 0, DEAD = 1, STUNNED = 2 }

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

## Speed multiplier applied by StatusEffectsManager (Freeze = 0.50, Chill = 0.85).
## Restored to 1.0 by SEM on status expiry or wave clear.
var _speed_modifier: float = 1.0

## Countdown to stun expiry (ADR-0011). Positive = STUNNED; managed in _physics_process.
var _stun_timer: float = 0.0

## RUSHER charge cycle phase (0=APPROACH, 1=TELEGRAPH, 2=CHARGING, 3=COOLDOWN).
var _rusher_phase: int = 0
## Countdown for RUSHER phase transitions.
var _rusher_timer: float = 0.0
## Locked direction captured at end of RUSHER TELEGRAPH phase.
var _rusher_charge_dir: Vector2 = Vector2.ZERO

## Current orbit angle (radians) for SWARMER. Randomised per instance in init().
var _swarmer_angle: float = 0.0

## Active Tween for attack/telegraph modulate pulse. Null when idle.
var _vfx_tween: Tween = null

## Active Tween for status effect color (Freeze=icy-blue, Burn=ember, Chill=light-blue).
## Separate from _vfx_tween so contact/telegraph and status visuals coexist.
var _status_tween: Tween = null

## IsoCharacter sprite component — auto-set from scene tree.
@onready var _iso_char: Node = $IsoCharacter
var _last_anim: String = ""

## Minimum seconds between contact damage events (design/gdd/enemy-ai.md Tuning Knobs).
## Must remain >= 0.3s — H&D i-frame guarantee depends on this (Enemy AI Dep. #3).
const ENEMY_MIN_CONTACT_INTERVAL: float = 0.3

## Radius within which a nearby enemy generates a push force (pixels).
const SEPARATION_RADIUS: float = 28.0
## Scales the raw separation sum into a pixel/s force added to the chase velocity.
const SEPARATION_STRENGTH: float = 80.0

## Seconds before queue_free() fires when no "death" animation is available (AC-EAI-29).
const BASE_DEATH_DURATION: float = 0.7

## SHOOTER archetype — minimum distance maintained from Fayde (S8-05).
const KEEP_DISTANCE: float = 150.0
## SHOOTER archetype — seconds between projectile shots (S8-05).
const SHOOT_INTERVAL: float = 2.0

## RUSHER archetype — charge cycle constants (design/gdd/level-generation.md).
const RUSHER_CHARGE_RANGE: float = 180.0
const RUSHER_APPROACH_SPEED_MULT: float = 0.65
const RUSHER_TELEGRAPH_DURATION: float = 0.45
const RUSHER_CHARGE_SPEED_MULT: float = 3.5
const RUSHER_CHARGE_DURATION: float = 0.55
const RUSHER_COOLDOWN_DURATION: float = 1.2

## SWARMER archetype — orbit constants (design/gdd/level-generation.md).
const SWARMER_ORBIT_RADIUS: float = 80.0
const SWARMER_ORBIT_SPEED: float = 1.4

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
	# Configure IsoCharacter with skeleton animations.
	if is_instance_valid(_iso_char):
		_iso_char.configure({
			"walk": "skeleton_default_walk",
			"death": "skeleton_special_death",
		})
		_iso_char.play_anim("walk")
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
	# Enemies on layer 3 (bit 2, value 4). Mask: walls (1) + player (2) + debris (16) = 19.
	# Player dash pass-through: player switches to mask=1 (walls only) during dash, so
	# enemies slide off the player body normally but are bypassed on dash (S8-02, S9-09).
	collision_layer = 4
	collision_mask = 19
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

	# STUNNED: count down timer, zero velocity, skip movement and contact damage.
	if _state == EnemyState.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_state = EnemyState.CHASING
		velocity = Vector2.ZERO
		move_and_slide()
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

	match _archetype:
		GameEnums.EnemyArchetype.SHOOTER:
			_tick_shooter(delta)
		GameEnums.EnemyArchetype.RUSHER:
			_tick_rusher(delta)
		GameEnums.EnemyArchetype.SWARMER:
			_tick_swarmer(delta)
		_:
			_tick_seeker(delta)

	# ── IsoCharacter sprite sync ──────────────────────────────────────────────
	if is_instance_valid(_iso_char) and _iso_char._initialized:
		_iso_char.set_facing(_dir_last_valid)

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
	if _archetype == GameEnums.EnemyArchetype.SWARMER:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_swarmer_angle = rng.randf_range(0.0, TAU)
	_rusher_phase = 0
	_rusher_timer = 0.0


## Returns true when this enemy is not in the DEAD state.
## Required by ADR-0011 (StatusEffectsManager API Contract).
func is_alive() -> bool:
	return _state != EnemyState.DEAD


## Required by ADR-0011 (StatusEffectsManager API Contract).
## SEM calls this on Freeze/Chill apply and on status expiry to restore full speed.
func apply_speed_modifier(multiplier: float) -> void:
	_speed_modifier = multiplier


## Pushes this enemy away from [param direction] by [param distance] pixels over 0.1s.
## Called by SpellCastingEffects after each successful spell hit for combo game feel.
## Uses a position tween with EASE_OUT — the enemy slides back then continues its AI
## movement on the next physics frame after the tween completes.
func apply_knockback(direction: Vector2, distance: float) -> void:
	if _state == EnemyState.DEAD:
		return
	var offset: Vector2 = direction.normalized() * distance
	var target_pos: Vector2 = global_position + offset
	var tw: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position", target_pos, 0.10)


# ── Private helpers ───────────────────────────────────────────────────────────

## Sums repulsion vectors from all live enemies within SEPARATION_RADIUS.
## Inverse-linear weight: neighbours at distance 0 push at full strength, at SEPARATION_RADIUS push at 0.
## Returns Vector2.ZERO outside the scene tree (safe in headless unit tests).
func _compute_separation() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var force: Vector2 = Vector2.ZERO
	for node: Node in get_tree().get_nodes_in_group(&"enemy"):
		if node == self:
			continue
		var other := node as EnemyInstance
		if other == null or other._state == EnemyState.DEAD:
			continue
		var offset: Vector2 = global_position - other.global_position
		var dist: float = offset.length()
		if dist < SEPARATION_RADIUS and dist > 0.001:
			force += offset.normalized() * (1.0 - dist / SEPARATION_RADIUS)
	return force * SEPARATION_STRENGTH


## SHOOTER archetype tick — maintains distance, accumulates shoot timer (S8-05).
func _tick_shooter(delta: float) -> void:
	var dist: float = global_position.distance_to(_fayde_ref.global_position)
	var sep: Vector2 = _compute_separation()
	if dist < KEEP_DISTANCE:
		velocity = (-_dir_last_valid * _move_speed + sep) * _speed_modifier
	else:
		velocity = sep * _speed_modifier
	move_and_slide()
	_shoot_timer += delta
	if _shoot_timer >= SHOOT_INTERVAL:
		_shoot_timer -= SHOOT_INTERVAL
		_fire_projectile()


## Pulsing red modulate — fired when melee contact starts.
func _start_contact_vfx() -> void:
	if _vfx_tween:
		_vfx_tween.kill()
	_vfx_tween = create_tween().set_loops()
	_vfx_tween.tween_property(self, "modulate", Color(2.2, 0.3, 0.3), 0.12)
	_vfx_tween.tween_property(self, "modulate", Color(1.0, 0.55, 0.55), 0.12)


## Fast orange flash — fired when RUSHER enters TELEGRAPH (charge wind-up warning).
func _start_telegraph_vfx() -> void:
	if _vfx_tween:
		_vfx_tween.kill()
	_vfx_tween = create_tween().set_loops()
	_vfx_tween.tween_property(self, "modulate", Color(2.5, 1.4, 0.1), 0.08)
	_vfx_tween.tween_property(self, "modulate", Color(0.9, 0.5, 0.1), 0.08)


## Kills any active modulate tween and restores white.
func _stop_attack_vfx() -> void:
	if _vfx_tween:
		_vfx_tween.kill()
		_vfx_tween = null
	modulate = Color.WHITE


## Overbright-white flash on successful spell hit.
## Kills _vfx_tween so the looping contact/telegraph pulse does not immediately
## override the flash — called via duck-typing from SpellVFX._on_damage_taken.
func request_hit_flash() -> void:
	if _vfx_tween:
		_vfx_tween.kill()
		_vfx_tween = null
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.10)


## Applies a status effect color tint to communicate active status to the player.
## Called via duck-typing from StatusEffectsManager.apply_status().
## Freeze=icy-blue, Burn=ember orange flicker, Chill=light blue, Stagger=hit flash.
func apply_status_visual(status_type: GameEnums.BaseStatus, duration: float) -> void:
	if _status_tween:
		_status_tween.kill()
		_status_tween = null
	match status_type:
		GameEnums.BaseStatus.FREEZE:
			modulate = Color(0.5, 0.8, 1.4, 1.0)
			_status_tween = create_tween()
			_status_tween.tween_interval(maxf(duration - 0.15, 0.0))
			_status_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
		GameEnums.BaseStatus.BURN:
			_status_tween = create_tween().set_loops()
			_status_tween.tween_property(self, "modulate", Color(1.6, 0.5, 0.1, 1.0), 0.15)
			_status_tween.tween_property(self, "modulate", Color(1.2, 0.4, 0.1, 1.0), 0.15)
		GameEnums.BaseStatus.CHILL:
			modulate = Color(0.8, 0.9, 1.2, 1.0)
			_status_tween = create_tween()
			_status_tween.tween_interval(maxf(duration - 0.15, 0.0))
			_status_tween.tween_property(self, "modulate", Color.WHITE, 0.15)
		GameEnums.BaseStatus.STAGGER:
			request_hit_flash()


## Clears the status effect tint when a status expires.
## Called via duck-typing from StatusEffectsManager._expire_status().
func clear_status_visual(status_type: GameEnums.BaseStatus) -> void:
	if _status_tween:
		_status_tween.kill()
		_status_tween = null
	# Only reset to white if the expiring type was the one last applied
	# (a newer status may have already overridden with its own tint).
	match status_type:
		GameEnums.BaseStatus.FREEZE, GameEnums.BaseStatus.BURN, GameEnums.BaseStatus.CHILL:
			if modulate != Color.WHITE:
				var tw: Tween = create_tween()
				tw.tween_property(self, "modulate", Color.WHITE, 0.15)


## SEEKER archetype tick — direct chase at full speed (design/gdd/level-generation.md).
func _tick_seeker(_delta: float) -> void:
	var sep: Vector2 = _compute_separation()
	velocity = (_dir_last_valid * _move_speed + sep) * _speed_modifier
	move_and_slide()


## RUSHER archetype tick — four-phase charge cycle (design/gdd/level-generation.md).
## Phases: 0=APPROACH (slow chase) → 1=TELEGRAPH (freeze, lock dir) →
##         2=CHARGING (burst) → 3=COOLDOWN (rest) → 0.
func _tick_rusher(delta: float) -> void:
	var sep: Vector2 = _compute_separation()
	match _rusher_phase:
		0:  # APPROACH
			velocity = (_dir_last_valid * _move_speed * RUSHER_APPROACH_SPEED_MULT + sep) * _speed_modifier
			move_and_slide()
			if _fayde_ref.global_position.distance_to(global_position) <= RUSHER_CHARGE_RANGE:
				_rusher_phase = 1
				_rusher_timer = RUSHER_TELEGRAPH_DURATION
				_start_telegraph_vfx()
		1:  # TELEGRAPH — freeze; lock direction at expiry
			velocity = Vector2.ZERO
			move_and_slide()
			_rusher_timer -= delta
			if _rusher_timer <= 0.0:
				_rusher_charge_dir = _dir_last_valid
				_rusher_phase = 2
				_rusher_timer = RUSHER_CHARGE_DURATION
				if _vfx_tween:
					_vfx_tween.kill()
					_vfx_tween = null
				modulate = Color(2.5, 0.2, 0.2)
		2:  # CHARGING — burst in locked direction
			velocity = (_rusher_charge_dir * _move_speed * RUSHER_CHARGE_SPEED_MULT + sep) * _speed_modifier
			move_and_slide()
			_rusher_timer -= delta
			# Impact detection: end charge early on contact to prevent sticking (S9-09).
			# Recoil pushes the RUSHER away from Fayde at 2× base speed so it doesn't
			# sit on top of the player dealing repeat contact damage for the full charge window.
			if _fayde_in_contact:
				_rusher_phase = 3
				_rusher_timer = RUSHER_COOLDOWN_DURATION
				var away: Vector2 = global_position.direction_to(_fayde_ref.global_position)
				velocity = -away * _move_speed * 2.0
				move_and_slide()
				_start_contact_vfx()
				return
			if _rusher_timer <= 0.0:
				_rusher_phase = 3
				_rusher_timer = RUSHER_COOLDOWN_DURATION
				# _fayde_in_contact is false here — guarded by early return above.
				_stop_attack_vfx()
		3:  # COOLDOWN — only separation force
			velocity = sep * _speed_modifier
			move_and_slide()
			_rusher_timer -= delta
			if _rusher_timer <= 0.0:
				_rusher_phase = 0


## SWARMER archetype tick — orbits Fayde at SWARMER_ORBIT_RADIUS (design/gdd/level-generation.md).
## Each instance starts at a random angle (set in init()), spreading multiple Swarmers around Fayde.
func _tick_swarmer(delta: float) -> void:
	_swarmer_angle += SWARMER_ORBIT_SPEED * delta
	var orbit_offset: Vector2 = Vector2(cos(_swarmer_angle), sin(_swarmer_angle)) * SWARMER_ORBIT_RADIUS
	var target: Vector2 = _fayde_ref.global_position + orbit_offset
	var to_target: Vector2 = target - global_position
	var dir: Vector2 = to_target.normalized() if to_target.length() >= 0.01 else _dir_last_valid
	var sep: Vector2 = _compute_separation()
	velocity = (dir * _move_speed + sep) * _speed_modifier
	move_and_slide()


## Spawns a Projectile aimed at the last known Fayde direction (S8-05).
## Guards against missing parent (headless test context).
func _fire_projectile() -> void:
	if get_parent() == null:
		return
	var proj: Projectile = Projectile.new()
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.launch(_dir_last_valid, _base_damage)


## Required by ADR-0011 (StatusEffectsManager API Contract).
## SEM calls this on Stun/Stagger apply. Re-entrant: resets timer on stun refresh.
func apply_stun(duration: float) -> void:
	_state = EnemyState.STUNNED
	_stun_timer = duration

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
	_speed_modifier = 1.0
	_stun_timer = 0.0
	_rusher_phase = 0
	_rusher_timer = 0.0
	_stop_attack_vfx()
	if _state == EnemyState.STUNNED:
		_state = EnemyState.CHASING


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
	_stop_attack_vfx()
	$HitArea.monitoring = false

	# Play IsoCharacter death animation if available; use fallback timer for cleanup.
	var has_iso_death: bool = false
	if is_instance_valid(_iso_char) and _iso_char._initialized:
		if _iso_char.has_anim("death"):
			_iso_char.play_anim("death")
			has_iso_death = true

	if has_iso_death:
		_start_death_fallback_timer()
	elif $AnimationPlayer.has_animation(&"death"):
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
	if _archetype != GameEnums.EnemyArchetype.SHOOTER:
		_start_contact_vfx()
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
	if _archetype != GameEnums.EnemyArchetype.SHOOTER:
		_stop_attack_vfx()
