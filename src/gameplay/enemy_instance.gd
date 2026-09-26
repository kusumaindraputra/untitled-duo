## enemy_instance.gd — Enemy AI controller for a single enemy instance.
## Layer: Gameplay | Stories: EAI-001 (skeleton), EAI-002 (FP movement), EAI-003 (contact attack), EAI-004 (death), S8-02 (collision layer 4).
## Implements: design/gdd/enemy-ai.md (AC-EAI-01–06, AC-EAI-07–09, AC-EAI-10–14, AC-EAI-15–17, AC-EAI-18, AC-EAI-19, AC-EAI-28, AC-EAI-29)
class_name EnemyInstance
extends CharacterBody2D

## Story-local state enum. STUNNED added when apply_stun/apply_speed_modifier landed.
## The full GameEnums.EnemyState (IDLE, PURSUING, ATTACKING, STUNNED, DEAD) gates
## in at a later story when archetype tick functions are formalised.
enum EnemyState { CHASING = 0, DEAD = 1, STUNNED = 2 }

## Emitted when a boss gains pattern layers as its HP crosses a phase threshold
## (ADR-0018). [param phase] counts distinct HP thresholds crossed (1 = first phase-up).
signal phase_changed(phase: int)

## Elite knobs (HP / damage / scale / extra pattern) — ADR-0018.
const BULLET_HELL_TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")
## Aggro / alert knobs (ADR-0024).
const AWARENESS_TUNING: EnemyAwarenessTuning = preload("res://assets/data/enemy_awareness_tuning.tres")

## Emitted once when a dormant enemy notices Fayde (ADR-0024).
signal alerted()

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

## Max HP — set from EnemyCatalog in init(). Used by HP bar ratio computation.
var _max_hp: int = 0
## Current HP — updated via HealthAndDamage.damage_taken signal. Used for boss enrage.
var _current_hp: int = 0
## HP bar visual node created in init(). Null until first init() call.
var _hp_bar: _EnemyHPBar = null
## Enemy display name from EnemyType.name (e.g. "VaultSentinel"). Set in init().
var _enemy_name: String = ""

## BOSS archetype — active attack index: 0=SLAM, 1=CHARGE, 2=SALVO.
var _catalog_type_id: int = -1
var _boss_attack: int = 0
## BOSS archetype — sub-phase within the current attack. -1 = "just entered, initialise me".
var _boss_phase: int = -1
## BOSS archetype — countdown timer for the current sub-phase. 0.0 = not ticking.
var _boss_phase_timer: float = 0.0
## BOSS archetype — locked direction captured at start of CHARGE burst.
var _boss_charge_dir: Vector2 = Vector2.ZERO

## ADR-0018 — one runner per EnemyType.pattern_layers entry (+ the elite layer).
var _pattern_runners: Array[BulletPatternRunner] = []
## ADR-0019 difficulty curve (set by WaveManager from the floor's EnemyPoolConfig).
var _bullet_speed_mult: float = 1.0
## ADR-0028 — this run's boss variant (null for non-bosses and unvaried bosses).
var _boss_variant: BossVariant = null
var _fire_rate_mult: float = 1.0
var _telegraph_mult: float = 1.0
## Volley released once on death (Splitter). Null = none.
var _death_pattern: BulletPattern = null
## SHOOTER keep-away distance — from EnemyType.keep_distance.
var _keep_distance: float = KEEP_DISTANCE
## True after make_elite(). Elites are tougher, hit harder and fire an extra layer.
var _is_elite: bool = false
## HP phases reached last frame — distinct hp_threshold values (< 1) whose layers
## are active. A rise means the boss entered a new phase. Several layers sharing one
## threshold are one phase. -1 = not sampled yet (first frame never counts).
var _active_layer_count: int = -1
## Short pre-fire flash; separate from _vfx_tween so looping telegraphs are untouched.
var _windup_tween: Tween = null

## ADR-0024 — true while this enemy has not noticed Fayde yet: it stands still and
## holds fire. Only WaveManager sets it (opening-wave spawns); default is awake.
var _dormant: bool = false
## Seconds of active combat spent dormant — wakes at AWARENESS_TUNING.max_dormant_sec.
var _dormant_timer: float = 0.0
## Tuning used by the awareness check. Overridable in tests.
var _awareness: EnemyAwarenessTuning = AWARENESS_TUNING

## Active Tween for attack/telegraph modulate pulse. Null when idle.
var _vfx_tween: Tween = null

## Active Tween for status effect color (Freeze=icy-blue, Burn=ember, Chill=light-blue).
## Separate from _vfx_tween so contact/telegraph and status visuals coexist.
var _status_tween: Tween = null

## AudioSystem reference; null-safe — set in _ready().
var _audio: Variant = null

## IsoCharacter sprite component — auto-set from scene tree.
@onready var _iso_char: Node = $IsoCharacter
var _last_anim: String = ""

## Minimum seconds between contact damage events (design/gdd/enemy-ai.md Tuning Knobs).
## Must remain >= 0.3s — H&D i-frame guarantee depends on this (Enemy AI Dep. #3).
const ENEMY_MIN_CONTACT_INTERVAL: float = 0.3

## Knockback strength applied to Fayde on contact damage (pixels/sec away from enemy).
## Gamefeel Pass 3 item #7 — small push-away on hit.
const ENEMY_KNOCKBACK_STRENGTH: float = 150.0

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

## BOSS archetype — SLAM pattern constants.
const BOSS_SLAM_TRIGGER_DIST: float = 150.0
const BOSS_SLAM_TELEGRAPH_SEC: float = 1.5
const BOSS_SLAM_COOLDOWN_SEC: float = 2.0
const BOSS_SLAM_RADIUS: float = 130.0
## BOSS archetype — CHARGE pattern constants.
const BOSS_CHARGE_TRIGGER_DIST: float = 220.0
const BOSS_CHARGE_TELEGRAPH_SEC: float = 0.5
const BOSS_CHARGE_SPEED_MULT: float = 4.5
const BOSS_CHARGE_DURATION_SEC: float = 0.7
const BOSS_CHARGE_COOLDOWN_SEC: float = 1.8
## BOSS archetype — SALVO pattern constants.
const BOSS_SALVO_WINDUP_SEC: float = 0.8
const BOSS_SALVO_COOLDOWN_SEC: float = 2.2
const BOSS_SALVO_COUNT: int = 6
## HP fraction below which the boss enrages (speeds up 30 %).
const BOSS_ENRAGE_THRESHOLD: float = 0.33
## Distance below which the boss prefers SLAM over SALVO when selecting next attack.
const BOSS_SELECT_SLAM_DIST: float = 80.0
## Distance above which the boss prefers CHARGE over SALVO when selecting next attack.
const BOSS_SELECT_CHARGE_DIST: float = 150.0
## Threshold reduction applied during enrage: boss reads space more aggressively.
const BOSS_ENRAGE_DIST_REDUCTION: float = 20.0

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
	HealthAndDamage.damage_taken.connect(_on_damage_taken_hp_bar)
	_fayde_ref = get_tree().get_first_node_in_group(&"player") as Node2D
	_audio = get_node_or_null("/root/AudioSystem")
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
	# Enemies on layer 3 (bit 2, value 4). Mask: walls (1) + debris (16) = 17 (S9-09),
	# plus full-cover pillars (32, ADR-0020) = 49.
	# Player is NOT in enemy mask — contact damage fires via HitArea (Area2D), not physics.
	collision_layer = 4
	collision_mask = 49
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
	if HealthAndDamage.damage_taken.is_connected(_on_damage_taken_hp_bar):
		HealthAndDamage.damage_taken.disconnect(_on_damage_taken_hp_bar)
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

	# ADR-0024 — dormant enemies wait until Fayde is inside their aggro area.
	if _dormant:
		_tick_dormant(delta)
		if _dormant:
			velocity = Vector2.ZERO
			return

	match _archetype:
		GameEnums.EnemyArchetype.SHOOTER:
			_tick_shooter(delta)
		GameEnums.EnemyArchetype.RUSHER:
			_tick_rusher(delta)
		GameEnums.EnemyArchetype.SWARMER:
			_tick_swarmer(delta)
		GameEnums.EnemyArchetype.BOSS:
			_tick_boss(delta)
		_:
			_tick_seeker(delta)

	# ADR-0018 bullet patterns — layered on top of every archetype's movement.
	_tick_patterns(delta)

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
				GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT,
				DeathRecap.cause(_enemy_name, DeathRecap.ATTACK_CONTACT))
			if _fayde_ref != null and _fayde_ref.has_method(&"request_knockback"):
				_fayde_ref.request_knockback(global_position, ENEMY_KNOCKBACK_STRENGTH)
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
	_enemy_name = et.name
	_catalog_type_id = et.id
	_base_damage = et.base_damage
	_move_speed = et.base_move_speed
	_max_hp = et.base_hp
	_current_hp = et.base_hp
	var debug_circle: Node = get_node_or_null("DebugCircle")
	if debug_circle != null:
		debug_circle.set("color", et.debug_color)
		debug_circle.set("hide_body", et.sprite_sheet != null)
	_apply_sprite(et)
	if _archetype == GameEnums.EnemyArchetype.SWARMER:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_swarmer_angle = rng.randf_range(0.0, TAU)
	_rusher_phase = 0
	_rusher_timer = 0.0
	_keep_distance = et.keep_distance
	_death_pattern = et.death_pattern
	_pattern_runners.clear()
	for pattern: BulletPattern in et.pattern_layers:
		if pattern != null:
			_pattern_runners.append(BulletPatternRunner.new(pattern))
	_active_layer_count = -1
	_is_elite = false
	_boss_variant = null
	if _archetype == GameEnums.EnemyArchetype.BOSS:
		_boss_attack = 0
		_boss_phase = -1
		_boss_phase_timer = 0.0
	# Create HP bar on first init — reuse across re-inits if already attached.
	if _hp_bar == null:
		_hp_bar = _EnemyHPBar.new()
		_hp_bar.z_index = 5
		add_child(_hp_bar)


## Returns true when this enemy is not in the DEAD state.
## Required by ADR-0011 (StatusEffectsManager API Contract).
func is_alive() -> bool:
	return _state != EnemyState.DEAD


## Returns true if this enemy is a BOSS archetype. Used by WaveManager to emit
## boss_spawned for the boss-intro UI.
func is_boss() -> bool:
	return _archetype == GameEnums.EnemyArchetype.BOSS


## EnemyType id this instance was initialised from (-1 before init()).
func get_type_id() -> int:
	return _catalog_type_id


## Returns the raw EnemyType.name (e.g. "VaultSentinel"). Presentation layer
## (CombatHUD) handles humanisation for display.
func get_display_name() -> String:
	return _enemy_name


## Returns this enemy's max HP (from EnemyType.base_hp). Used by the boss HP bar.
func get_max_hp() -> int:
	return _max_hp


## Promotes this enemy to an elite (ADR-0018): more HP and damage, a golden aura and
## an extra pattern layer from [param tuning]. Call after init(). Bosses never become
## elites. The H&D pool must be registered with the same HP multiplier
## (WaveManager passes it to register_enemy()).
func make_elite(tuning: BulletHellTuning = BULLET_HELL_TUNING) -> void:
	if _is_elite or _archetype == GameEnums.EnemyArchetype.BOSS:
		return
	_is_elite = true
	_base_damage *= tuning.elite_damage_mult
	_max_hp = roundi(float(_max_hp) * tuning.elite_hp_mult)
	_current_hp = _max_hp
	if tuning.elite_pattern != null:
		var runner := BulletPatternRunner.new(tuning.elite_pattern)
		runner.rate_mult = _fire_rate_mult
		_pattern_runners.append(runner)
	var aura := _EliteAura.new()
	aura.tint = tuning.elite_tint
	add_child(aura)


## ADR-0019 — applies the floor difficulty curve: bullet speed, pattern fire rate and
## laser / mortar telegraph length. Call after init() (and make_elite(), so the elite
## layer is scaled too). Values are clamped to sane ranges.
func apply_difficulty(bullet_speed_mult: float, fire_rate_mult: float, telegraph_mult: float) -> void:
	_bullet_speed_mult = clampf(bullet_speed_mult, 0.25, 3.0)
	_fire_rate_mult = clampf(fire_rate_mult, 0.25, 3.0)
	_telegraph_mult = clampf(telegraph_mult, 0.1, 2.0)
	for runner: BulletPatternRunner in _pattern_runners:
		runner.rate_mult = _fire_rate_mult


## Difficulty multipliers as [bullet_speed, fire_rate, telegraph] (test / debug hook).
func get_difficulty() -> Vector3:
	return Vector3(_bullet_speed_mult, _fire_rate_mult, _telegraph_mult)


## ADR-0028 — applies this run's [param variant] to a boss: extra bullet layers,
## HP, bullet speed, fire rate, move speed and sprite tint. Call after init() and
## apply_difficulty(); the variant's multipliers stack on the floor's. The H&D pool
## must be registered with the same HP multiplier (WaveManager does this).
func apply_boss_variant(variant: BossVariant) -> void:
	if variant == null or _archetype != GameEnums.EnemyArchetype.BOSS:
		return
	_boss_variant = variant
	_max_hp = maxi(roundi(float(_max_hp) * variant.hp_mult), 1)
	_current_hp = _max_hp
	_move_speed *= variant.move_speed_mult
	_bullet_speed_mult = clampf(_bullet_speed_mult * variant.bullet_speed_mult, 0.25, 3.0)
	_fire_rate_mult = clampf(_fire_rate_mult * variant.fire_rate_mult, 0.25, 3.0)
	for pattern: BulletPattern in variant.extra_layers:
		if pattern != null:
			_pattern_runners.append(BulletPatternRunner.new(pattern))
	for runner: BulletPatternRunner in _pattern_runners:
		runner.rate_mult = _fire_rate_mult
	var pc: PixelCharacter = get_node_or_null(^"PixelCharacter") as PixelCharacter
	if pc != null:
		pc.modulate *= variant.tint


## The run's variant applied to this boss, or null.
func get_boss_variant() -> BossVariant:
	return _boss_variant


## True after make_elite().
func is_elite() -> bool:
	return _is_elite


## True while a pattern windup flash is running (a volley is about to fire).
## OffscreenIndicators flashes this enemy's edge arrow while it is true.
func is_winding_up() -> bool:
	return _windup_tween != null and _windup_tween.is_running()


## Number of bullet-pattern layers this enemy owns (test / debug hook).
func get_pattern_layer_count() -> int:
	return _pattern_runners.size()


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
	if dist < _keep_distance:
		velocity = (-_dir_last_valid * _move_speed + sep) * _speed_modifier
	else:
		velocity = sep * _speed_modifier
	move_and_slide()
	_shoot_timer += delta
	if _shoot_timer >= SHOOT_INTERVAL:
		_shoot_timer -= SHOOT_INTERVAL
		# Pattern-driven shooters fire through _tick_patterns(); the single aimed
		# shot is the fallback for a SHOOTER authored without pattern layers.
		if _pattern_runners.is_empty():
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


## ADR-0018 — ticks every pattern layer whose HP gate is open and acts on its events.
## Runs after the archetype tick, only while CHASING (stun and death return earlier).
func _tick_patterns(delta: float) -> void:
	if _pattern_runners.is_empty():
		return
	var hp_ratio: float = 1.0 if _max_hp <= 0 else float(_current_hp) / float(_max_hp)
	var aim: float = _dir_last_valid.angle()
	var thresholds: Dictionary = {}
	for runner: BulletPatternRunner in _pattern_runners:
		if not runner.is_active(hp_ratio):
			continue
		if runner.pattern.hp_threshold < 1.0:
			thresholds[runner.pattern.hp_threshold] = true
		for ev: Dictionary in runner.tick(delta, aim):
			if ev["type"] == BulletPatternRunner.EVENT_WINDUP:
				_start_windup_flash(runner.pattern)
			else:
				_fire_pattern_volley(runner.pattern, ev["angles"], float(ev["speed"]))
	var phase: int = thresholds.size()
	if _active_layer_count >= 0 and phase > _active_layer_count:
		_on_phase_up(phase)
	_active_layer_count = phase


## Spawns one volley of [param pattern]: bullets from the pool, or a laser / mortar
## hazard per angle. Guards against a missing parent (headless test context).
func _fire_pattern_volley(pattern: BulletPattern, angles: PackedFloat32Array, speed: float) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var damage: float = _base_damage * pattern.damage_mult
	var hit_cause: Dictionary = DeathRecap.cause(_enemy_name, DeathRecap.attack_for_pattern(pattern))
	match pattern.kind:
		BulletPattern.Kind.LASER:
			for a: float in angles:
				var laser := EnemyLaser.new()
				laser.pattern = pattern
				laser.damage = damage
				laser.cause = hit_cause
				laser.telegraph_mult = _telegraph_mult
				laser.angle = a
				laser.anchor = self
				parent_node.add_child(laser)
				laser.global_position = global_position
			Sfx.play(&"sfx_laser_charge")
		BulletPattern.Kind.MORTAR:
			var target: Vector2 = _fayde_ref.global_position if is_instance_valid(_fayde_ref) \
				else global_position
			var shell := MortarShell.new()
			shell.pattern = pattern
			shell.damage = damage
			shell.cause = hit_cause
			shell.telegraph_mult = _telegraph_mult
			parent_node.add_child(shell)
			shell.global_position = target
			Sfx.play(&"sfx_mortar_whistle")
		_:
			var pool: BulletPool = BulletPool.for_parent(parent_node)
			if pool == null:
				return
			for a: float in angles:
				var b: Projectile = pool.acquire()
				b.global_position = global_position
				b.launch_pattern(Vector2.from_angle(a), damage, pattern, speed * _bullet_speed_mult)
				b.cause = hit_cause
			Sfx.play(&"sfx_bullet_fire")


## Brief pre-fire glow in the pattern's colour so every volley is telegraphed.
## Skipped while a looping telegraph (_vfx_tween) owns modulate.
func _start_windup_flash(pattern: BulletPattern) -> void:
	if _vfx_tween != null or pattern.windup_sec <= 0.0:
		return
	Sfx.play(&"sfx_enemy_windup")
	if _windup_tween:
		_windup_tween.kill()
	var c: Color = pattern.color
	modulate = Color(1.0 + c.r, 1.0 + c.g, 1.0 + c.b, 1.0)
	_windup_tween = create_tween()
	_windup_tween.tween_property(self, "modulate", Color.WHITE, pattern.windup_sec)


## Boss phase-up (ADR-0018): a new HP-gated layer just switched on.
func _on_phase_up(phase: int) -> void:
	phase_changed.emit(phase)
	request_hit_flash()
	if is_instance_valid(_fayde_ref) and _fayde_ref.has_method(&"add_camera_trauma"):
		_fayde_ref.add_camera_trauma(0.35)
	Sfx.play(&"sfx_boss_phase")


# ── Awareness (ADR-0024) ──────────────────────────────────────────────────────

## Puts this enemy to sleep until it notices Fayde. Bosses ignore this and stay
## awake. No-op when EnemyAwarenessTuning.enabled is false.
func enter_dormant() -> void:
	if not _awareness.enabled or _archetype == GameEnums.EnemyArchetype.BOSS:
		return
	if _state == EnemyState.DEAD:
		return
	_dormant = true
	_dormant_timer = 0.0


## Returns true while this enemy has not noticed Fayde yet.
func is_dormant() -> bool:
	return _dormant


## Wakes this enemy and, when [param chain] is true, every dormant enemy within
## EnemyAwarenessTuning.alert_link_radius of it. No-op when already awake.
func alert(chain: bool = true) -> void:
	if not _dormant:
		return
	_dormant = false
	_dormant_timer = 0.0
	_show_alert_mark()
	Sfx.play(&"sfx_enemy_alert")
	alerted.emit()
	if chain and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"enemy"):
			var other := node as EnemyInstance
			if other == null or other == self or not other._dormant:
				continue
			if iso_distance(global_position, other.global_position,
					_awareness.iso_y_scale) <= _awareness.alert_link_radius:
				other.alert(false)


## Distance measured on the isometric floor: screen-y is stretched by
## [param y_scale] first, so a fixed radius is a 2:1 ellipse on screen.
static func iso_distance(a: Vector2, b: Vector2, y_scale: float = 2.0) -> float:
	var d: Vector2 = b - a
	return Vector2(d.x, d.y * y_scale).length()


## Dormant tick: wakes on Fayde entering the aggro area or on the safety timeout.
func _tick_dormant(delta: float) -> void:
	_dormant_timer += delta
	var dist: float = iso_distance(global_position, _fayde_ref.global_position,
		_awareness.iso_y_scale)
	var timed_out: bool = _awareness.max_dormant_sec > 0.0 \
		and _dormant_timer >= _awareness.max_dormant_sec
	if dist <= _awareness.aggro_radius or timed_out:
		alert()


## Pops a pixel "!" above the head for EnemyAwarenessTuning.alert_mark_sec.
func _show_alert_mark() -> void:
	if not is_inside_tree() or _awareness.alert_mark_sec <= 0.0:
		return
	var mark := _AlertMark.new()
	mark.duration = _awareness.alert_mark_sec
	mark.position = Vector2(0.0, -48.0)  # just above the HP bar (-35)
	mark.z_index = 6
	add_child(mark)


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
	_boss_phase = -1
	_boss_phase_timer = 0.0
	for runner: BulletPatternRunner in _pattern_runners:
		runner.reset()
	_stop_attack_vfx()
	if _state == EnemyState.STUNNED:
		_state = EnemyState.CHASING


## Responds to H&D's enemy_killed signal (AC-EAI-15, 16, 28, 29).
## Instance ID guard ensures only this enemy handles its own death event.
func _on_enemy_killed(instance_id: int, _type_id: int, prana_affiliation: GameEnums.DamageClass) -> void:
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
	collision_layer = 0  # stop spell raycasts from hitting dead body (ADR-0007)

	# Spawn death burst VFX — color bloom outward per Art Bible principle.
	# PranaType.color mapped from prana_affiliation; neutral enemies burst white.
	_spawn_death_burst(prana_affiliation)
	# ADR-0018 — Splitter-style death volley.
	if _death_pattern != null:
		_fire_pattern_volley(_death_pattern,
			BulletPatternRunner.compute_angles(_death_pattern, _dir_last_valid.angle(), 0),
			_death_pattern.speed)
	# Audio: fire-and-forget, null-safe.
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_enemy_death"):
		_audio.play_event(&"sfx_enemy_death")

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
		body, _base_damage, GameEnums.DamageClass.NONE, GameEnums.DamageSource.CONTACT,
		DeathRecap.cause(_enemy_name, DeathRecap.ATTACK_CONTACT))
	if body.has_method(&"request_knockback"):
		body.request_knockback(global_position, ENEMY_KNOCKBACK_STRENGTH)
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

## Updates _current_hp and refreshes the HP bar whenever this enemy takes damage.
## Filters by instance identity — cheap no-op for all other targets' damage events.
func _on_damage_taken_hp_bar(target: Node, _damage: int, current_hp: int) -> void:
	if target != self:
		return
	_current_hp = current_hp
	alert()  # being hit always wakes a dormant enemy (ADR-0024)
	if is_instance_valid(_hp_bar):
		_hp_bar.show_hp(_current_hp, _max_hp)


# ── BOSS archetype AI ─────────────────────────────────────────────────────────

## Top-level BOSS tick: ticks the phase timer and dispatches to the active pattern.
## Patterns cycle SLAM → CHARGE → SALVO → SLAM.
## At HP < BOSS_ENRAGE_THRESHOLD (33 %), speed/cadence scaled by 1.3×.
func _tick_boss(delta: float) -> void:
	if _fayde_ref == null:
		velocity = Vector2.ZERO
		return
	if _boss_phase_timer > 0.0:
		_boss_phase_timer -= delta
	var dist: float = global_position.distance_to(_fayde_ref.global_position)
	var hp_mult: float = 1.3 if _max_hp > 0 and \
		float(_current_hp) / float(_max_hp) < BOSS_ENRAGE_THRESHOLD else 1.0
	var sep: Vector2 = _compute_separation()
	match _boss_attack:
		0: _tick_boss_slam(delta, sep, dist, hp_mult)
		1: _tick_boss_charge(delta, sep, dist, hp_mult)
		2: _tick_boss_salvo(delta, sep, dist, hp_mult)


## BOSS SLAM: approach slowly → stop at range → telegraph → AoE ring → cooldown.
func _tick_boss_slam(_delta: float, sep: Vector2, dist: float, hp_mult: float) -> void:
	if _boss_phase == -1:
		_boss_phase = 0
		_boss_phase_timer = 0.0
	match _boss_phase:
		0:  # APPROACH
			velocity = (_dir_last_valid * _move_speed * 0.5 * hp_mult + sep)
			move_and_slide()
			if dist <= BOSS_SLAM_TRIGGER_DIST:
				_boss_phase = 1
				_boss_phase_timer = BOSS_SLAM_TELEGRAPH_SEC / hp_mult
				_start_slam_telegraph()
		1:  # TELEGRAPH — stand still, warning circle pulses
			velocity = Vector2.ZERO
			move_and_slide()
			if _boss_phase_timer <= 0.0:
				_stop_attack_vfx()
				_slam_aoe()
				_boss_phase = 2
				_boss_phase_timer = BOSS_SLAM_COOLDOWN_SEC / hp_mult
		2:  # COOLDOWN
			velocity = sep
			move_and_slide()
			if _boss_phase_timer <= 0.0:
				_boss_phase = -1
				_boss_attack = _select_boss_attack(dist, hp_mult > 1.0)


## BOSS CHARGE: approach → freeze telegraph → burst at BOSS_CHARGE_SPEED_MULT → cooldown.
func _tick_boss_charge(_delta: float, sep: Vector2, dist: float, hp_mult: float) -> void:
	if _boss_phase == -1:
		_boss_phase = 0
		_boss_phase_timer = 0.0
	match _boss_phase:
		0:  # APPROACH
			velocity = (_dir_last_valid * _move_speed * 0.7 * hp_mult + sep)
			move_and_slide()
			if dist <= BOSS_CHARGE_TRIGGER_DIST:
				_boss_phase = 1
				_boss_phase_timer = BOSS_CHARGE_TELEGRAPH_SEC / hp_mult
				_start_telegraph_vfx()
		1:  # TELEGRAPH — freeze, lock direction
			velocity = Vector2.ZERO
			move_and_slide()
			if _boss_phase_timer <= 0.0:
				_boss_charge_dir = _dir_last_valid
				_boss_phase = 2
				_boss_phase_timer = BOSS_CHARGE_DURATION_SEC / hp_mult
				if _vfx_tween:
					_vfx_tween.kill()
					_vfx_tween = null
				modulate = Color(2.5, 0.2, 0.2)
				if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_boss_charge"):
					_audio.play_event(&"sfx_boss_charge")
		2:  # CHARGING — burst in locked direction; end early on impact
			velocity = (_boss_charge_dir * _move_speed * BOSS_CHARGE_SPEED_MULT + sep) * hp_mult
			move_and_slide()
			if _fayde_in_contact or _boss_phase_timer <= 0.0:
				_stop_attack_vfx()
				if _fayde_in_contact and _fayde_ref != null and \
						_fayde_ref.has_method(&"request_knockback"):
					_fayde_ref.request_knockback(global_position, 400.0)
				_boss_phase = 3
				_boss_phase_timer = BOSS_CHARGE_COOLDOWN_SEC / hp_mult
		3:  # COOLDOWN
			velocity = sep
			move_and_slide()
			if _boss_phase_timer <= 0.0:
				_boss_phase = -1
				_boss_attack = _select_boss_attack(dist, hp_mult > 1.0)


## BOSS SALVO: stop → blue telegraph → fire star of 6 projectiles → cooldown.
func _tick_boss_salvo(_delta: float, sep: Vector2, dist: float, hp_mult: float) -> void:
	if _boss_phase == -1:
		_boss_phase = 0
		_boss_phase_timer = BOSS_SALVO_WINDUP_SEC / hp_mult
		if _vfx_tween:
			_vfx_tween.kill()
		_vfx_tween = create_tween().set_loops()
		_vfx_tween.tween_property(self, "modulate", Color(0.5, 0.5, 2.5), 0.15)
		_vfx_tween.tween_property(self, "modulate", Color(0.3, 0.3, 1.5), 0.15)
	match _boss_phase:
		0:  # WINDUP — stand still while timer counts
			velocity = sep
			move_and_slide()
			if _boss_phase_timer <= 0.0:
				_stop_attack_vfx()
				_fire_salvo()
				_boss_phase = 1
				_boss_phase_timer = BOSS_SALVO_COOLDOWN_SEC / hp_mult
		1:  # COOLDOWN
			velocity = sep
			move_and_slide()
			if _boss_phase_timer <= 0.0:
				_boss_phase = -1
				_boss_attack = _select_boss_attack(dist, hp_mult > 1.0)


## Selects the next boss attack index based on current distance to Fayde.
## Close  (< BOSS_SELECT_SLAM_DIST)   → 0 SLAM
## Far    (> BOSS_SELECT_CHARGE_DIST) → 1 CHARGE
## Middle                             → 2 SALVO
## Enrage reduces both thresholds by BOSS_ENRAGE_DIST_REDUCTION.
func _select_boss_attack(dist: float, is_enraged: bool) -> int:
	var reduction: float = BOSS_ENRAGE_DIST_REDUCTION if is_enraged else 0.0
	if dist < BOSS_SELECT_SLAM_DIST - reduction:
		return 0
	elif dist > BOSS_SELECT_CHARGE_DIST - reduction:
		return 1
	return 2


## Starts the slow red pulse VFX and spawns the ground-circle SLAM warning.
func _start_slam_telegraph() -> void:
	if _vfx_tween:
		_vfx_tween.kill()
	_vfx_tween = create_tween().set_loops()
	_vfx_tween.tween_property(self, "modulate", Color(2.5, 0.3, 0.3), 0.3)
	_vfx_tween.tween_property(self, "modulate", Color(1.0, 0.1, 0.1), 0.3)
	_spawn_slam_warning()
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_boss_slam_telegraph"):
		_audio.play_event(&"sfx_boss_slam_telegraph")


## Applies DIRECT AoE damage to Fayde if she is within BOSS_SLAM_RADIUS.
## DIRECT source bypasses i-frames so the player must dodge rather than tank.
func _slam_aoe() -> void:
	if _fayde_ref == null or not is_instance_valid(_fayde_ref):
		return
	if global_position.distance_to(_fayde_ref.global_position) <= BOSS_SLAM_RADIUS:
		HealthAndDamage.apply_damage(
			_fayde_ref, _base_damage,
			GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT,
			DeathRecap.cause(_enemy_name, DeathRecap.ATTACK_SLAM))
		if _fayde_ref.has_method(&"request_knockback"):
			_fayde_ref.request_knockback(global_position, 350.0)


## Spawns a _SlamWarning sibling that draws a pulsing circle for BOSS_SLAM_TELEGRAPH_SEC.
func _spawn_slam_warning() -> void:
	if not is_inside_tree():
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var warning := _SlamWarning.new()
	warning.global_position = global_position
	warning.duration = BOSS_SLAM_TELEGRAPH_SEC
	warning.radius = BOSS_SLAM_RADIUS
	parent_node.add_child(warning)


## Fires BOSS_SALVO_COUNT projectiles evenly distributed around a full circle,
## with the 0th spoke aimed at Fayde's current position (no safe static spot).
func _fire_salvo() -> void:
	if get_parent() == null:
		return
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_boss_salvo"):
		_audio.play_event(&"sfx_boss_salvo")
	var aim_angle: float = 0.0
	if is_instance_valid(_fayde_ref):
		aim_angle = (_fayde_ref.global_position - global_position).angle()
	for i: int in BOSS_SALVO_COUNT:
		var angle: float = aim_angle + (TAU / float(BOSS_SALVO_COUNT)) * float(i)
		var dir: Vector2 = Vector2.from_angle(angle)
		var proj: Projectile = Projectile.new()
		get_parent().add_child(proj)
		proj.global_position = global_position
		proj.launch(dir, _base_damage * 0.7)


## Spawns a procedural _DeathBurst node that draws an expanding ring + outward dots
## at the enemy's position. Color is mapped from [param prana_affiliation] via
## PranaCatalog; neutral (NONE) enemies burst white. Duration: 0.35 s.
## Guard: no-op when not inside the scene tree (headless test safety).
func _spawn_death_burst(prana_affiliation: GameEnums.DamageClass) -> void:
	if not is_inside_tree():
		return
	var burst := _DeathBurst.new()
	burst.prana_affiliation = prana_affiliation
	burst.global_position = global_position
	# Attach as sibling so the burst is not freed with the enemy's queue_free().
	# If parent is null (test context), skip — the burst has nowhere to live.
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	parent_node.add_child(burst)


## Shows [param et]'s pixel-art sheet (ADR-0022), creating the PixelCharacter child
## on first use. The sprite is counter-scaled by base_scale so one sheet pixel lands
## on exactly sprite_pixel_scale screen-world pixels.
func _apply_sprite(et: EnemyType) -> void:
	var pc: PixelCharacter = get_node_or_null(^"PixelCharacter") as PixelCharacter
	if et.sprite_sheet == null:
		if pc != null:
			pc.visible = false
		return
	if pc == null:
		pc = PixelCharacter.new()
		pc.name = "PixelCharacter"
		add_child(pc)
	pc.visible = true
	pc.sheet = et.sprite_sheet
	pc.pixel_scale = et.sprite_pixel_scale / maxf(et.base_scale, 0.01)
	pc.modulate = et.sprite_tint


## Inner class: single procedural death burst instance.
## Draws an expanding ring (radius 8→55 px) with 6 outward dots along radial rays.
## Auto-frees after DEATH_BURST_DURATION seconds via process-mode-ALWAYS timer.
class _DeathBurst extends Node2D:
	var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
	var _start_us: int = 0
	const DEATH_BURST_DURATION: float = 0.35

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 90
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= int(DEATH_BURST_DURATION * 1_000_000.0):
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed: float = float(Time.get_ticks_usec() - _start_us) / 1_000_000.0
		var p: float = clampf(elapsed / DEATH_BURST_DURATION, 0.0, 1.0)
		var alpha: float = 1.0 - p
		# Color from PranaCatalog, or white for neutral enemies.
		var c: Color = Color.WHITE
		if prana_affiliation >= 0:
			var type_data: PranaType = PranaCatalog.get_type(prana_affiliation)
			if type_data != null:
				c = type_data.color
		# Expanding ring: radius 8 → 55 px.
		var ring_r: float = lerpf(8.0, 55.0, p)
		PixelVFX.stroke_ring(self, ring_r, 3.0, c, alpha * 0.7)
		# 6 outward dots along radial rays.
		for i: int in 6:
			var angle: float = (TAU / 6.0) * float(i)
			var dot_dist: float = lerpf(5.0, 40.0, p)
			var dot_r: float = lerpf(4.0, 1.5, p)
			PixelVFX.fill_disc(self, Vector2.from_angle(angle) * dot_dist, maxf(dot_r, 1.5),
					c, alpha * 0.85)


## Inner class: HP bar drawn above the enemy head.
## Created in EnemyInstance.init() and shown whenever HealthAndDamage.damage_taken
## fires for this enemy. Auto-hides 2 seconds after the last hit.
## Positioned at y=-35 in the enemy's local space so it floats above the sprite.
## Scales with the parent node (boss at 2.5× gets a proportionally larger bar).
class _EnemyHPBar extends Node2D:
	const WIDTH: float = 40.0
	const HEIGHT: float = 5.0
	var _ratio: float = 1.0
	var _show_timer: float = 0.0
	const SHOW_DURATION: float = 2.0

	func _ready() -> void:
		position = Vector2(-WIDTH * 0.5, -35.0)
		visible = false
		process_mode = PROCESS_MODE_ALWAYS

	func show_hp(current: int, max_hp: int) -> void:
		if max_hp > 0:
			_ratio = clampf(float(current) / float(max_hp), 0.0, 1.0)
		_show_timer = SHOW_DURATION
		visible = true
		queue_redraw()

	func _process(delta: float) -> void:
		if visible:
			_show_timer -= delta
			if _show_timer <= 0.0:
				visible = false

	func _draw() -> void:
		draw_rect(Rect2(0.0, 0.0, WIDTH, HEIGHT), Color(0.1, 0.0, 0.0, 0.85))
		var filled: float = WIDTH * _ratio
		var bar_col: Color
		if _ratio > 0.5:
			bar_col = Color(0.1, 0.85, 0.1)
		elif _ratio > 0.25:
			bar_col = Color(0.9, 0.65, 0.1)
		else:
			bar_col = Color(0.9, 0.15, 0.15)
		if filled > 0.0:
			draw_rect(Rect2(0.0, 0.0, filled, HEIGHT), bar_col)
		draw_rect(Rect2(0.0, 0.0, WIDTH, HEIGHT), Color(0.8, 0.8, 0.8, 0.5), false, 1.0)


## Inner class: pulsing golden ring marking an elite enemy (ADR-0018).
## A child node (not modulate) so attack / status tints never hide it.
class _EliteAura extends Node2D:
	var tint: Color = Color(1.6, 1.3, 0.4, 1.0)
	var _t: float = 0.0

	func _ready() -> void:
		z_index = -1
		process_mode = PROCESS_MODE_PAUSABLE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(_t * 5.0)
		var c: Color = Color(minf(tint.r, 1.0), minf(tint.g, 1.0), minf(tint.b, 1.0), 0.35 + 0.35 * pulse)
		draw_arc(Vector2.ZERO, 15.0 + 2.0 * pulse, 0.0, TAU, 24, c, 2.0, true)
		draw_circle(Vector2.ZERO, 14.0, Color(c.r, c.g, c.b, 0.12))


## Inner class: pulsing ground circle shown during BOSS SLAM telegraph.
## Spawned as a sibling by EnemyInstance._spawn_slam_warning(); auto-frees after [duration].
class _SlamWarning extends Node2D:
	var duration: float = 1.5
	var radius: float = 130.0
	var _elapsed: float = 0.0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 1

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= duration:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var p: float = clampf(_elapsed / duration, 0.0, 1.0)
		# Pulse alpha 3 times during the telegraph window.
		var pulse: float = 0.5 + 0.5 * sin(p * TAU * 3.0)
		var alpha: float = 0.45 * pulse
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48,
				Color(0.9, 0.2, 0.1, alpha), 3.0, true)
		# Solid fill at low opacity so the zone is readable.
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.2, 0.1, alpha * 0.15))


## Inner class: pixel "!" that pops above an enemy the moment it notices Fayde
## (ADR-0024). Rises 4 px with a quick scale pop, blinks out, then frees itself.
class _AlertMark extends Node2D:
	var duration: float = 0.5
	var _elapsed: float = 0.0
	var _base_y: float = 0.0

	func _ready() -> void:
		_base_y = position.y
		scale = Vector2(0.4, 0.4)
		var tw: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "scale", Vector2.ONE, 0.12)

	func _process(delta: float) -> void:
		_elapsed += delta
		if _elapsed >= duration:
			queue_free()
			return
		position.y = _base_y - 4.0 * minf(_elapsed / 0.15, 1.0)
		# Blink during the last third so it reads as "gone" rather than cut off.
		visible = _elapsed < duration * 0.66 or int(_elapsed * 20.0) % 2 == 0

	func _draw() -> void:
		var outline := Color(0.08, 0.02, 0.02)
		var fill := Color(1.0, 0.82, 0.2)
		# 4×12 bar + 4×4 dot on a 2 px pixel grid, dark outline for any floor colour.
		draw_rect(Rect2(-4.0, -16.0, 8.0, 14.0), outline)
		draw_rect(Rect2(-4.0, 0.0, 8.0, 8.0), outline)
		draw_rect(Rect2(-2.0, -14.0, 4.0, 10.0), fill)
		draw_rect(Rect2(-2.0, 2.0, 4.0, 4.0), fill)
