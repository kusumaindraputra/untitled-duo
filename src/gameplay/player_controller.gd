## player_controller.gd — Fayde's CharacterBody2D controller.
## Layer: Core | Stories: PC-001–PC-004, S5-05, S8-02 — Skeleton, state machine, WASD movement,
##   friction, dash system, I-frame, interface getters, footstep shuffle-bag, audio events,
##   dash_cooldown_changed signal (CombatHUD discoverability), collision layer setup,
##   dash pass-through (collision_mask toggle), i-frame blink visual.
class_name PlayerController
extends CharacterBody2D

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when dash availability changes. Fires false when dash activates (no longer
## available); fires true when cooldown expires or preparation_started resets dash (GDD Rule 4).
signal dash_cooldown_changed(available: bool)

## Emitted whenever a dash charge is spent or recharged (ADR-0018).
signal dash_charges_changed(charges: int, max_charges: int)

## Emitted when a dash passes through an enemy bullet or hazard that would have hit
## (ADR-0019 Perfect Dodge). At most once per dash, gated by a cooldown.
signal perfect_dodged(world_pos: Vector2)

# ── Enums ─────────────────────────────────────────────────────────────────────

enum ControllerState { DISABLED, ENABLED, DASHING }

# ── Constants ─────────────────────────────────────────────────────────────────

const MOVE_SPEED: float = 180.0
const MOVE_ACCELERATION: float = 0.80
const MOVE_FRICTION: float = 0.50
const VELOCITY_SNAP_THRESHOLD: float = 8.0
const DASH_SPEED: float = 400.0
const DASH_DURATION: float = 0.15
## Dash charges, recharge time, hurtbox dot and graze ring (ADR-0018). The old single
## 2.0 s DASH_COOLDOWN is now BULLET_HELL_TUNING.dash_charges × dash_recharge_sec.
const BULLET_HELL_TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")
const PACE_TUNING: PaceTuning = preload("res://assets/data/pace_tuning.tres")
const FOOTSTEP_INTERVAL_SEC: float = 0.38           # activated: Story PC-004
const FOOTSTEP_VELOCITY_THRESHOLD: float = 10.0     # activated: Story PC-004

## Collision layer bits (S8-02, S9-09).
## Layer 1 (bit 0, value  1): World/Walls — TileMapLayer, StaticBody2D arenas.
## Layer 2 (bit 1, value  2): Player.
## Layer 3 (bit 2, value  4): Enemies.
## Layer 4 (bit 3, value  8): Projectiles (Rifter shots).
## Layer 5 (bit 4, value 16): Half-cover debris — blocks movement, not Prana/projectiles.
const COLLISION_LAYER_PLAYER: int = 2
const COLLISION_MASK_NORMAL: int = 53  # walls (1) + enemies (4) + debris (16) + pillars (32, ADR-0020)
const COLLISION_MASK_DASHING: int = 33  # walls (1) + pillars (32) — dash passes through enemies and debris, never through full cover

## Modulate alpha oscillation interval during i-frames — ~8 blinks/sec at 60fps.
const BLINK_INTERVAL: float = 0.06
## Duration of knockback velocity override (seconds). Brief window where movement
## input is suppressed so the push-away reads clearly regardless of held keys.
const KNOCKBACK_DURATION: float = 0.08

## Camera zoom, look-ahead and smoothing live in camera_tuning.tres (ADR-0024).
const CAMERA_TUNING: CameraTuning = preload("res://assets/data/camera_tuning.tres")

## Movement speed multiplier during cast lock — Fayde can still move but at reduced speed.
## GDD Rule 6: movement is dampened, not zeroed, during the post-hit recovery window.
const CAST_LOCK_SPEED_FACTOR: float = 0.55

## Zoom tween timing. The zoom levels themselves are in CAMERA_TUNING (ADR-0024):
## combat 2.0× shows 576×324 game-px (Fayde ~10% of screen height), prep 0.55× the
## whole 1280×768 arena.
const ZOOM_TWEEN_DURATION: float = 0.35
## Faster TRANS_BACK punch-in for combat start — more energetic than the prep smooth-out.
## Replaces the old black-flash snap so the zoom-in IS the combat-start signal.
const ZOOM_COMBAT_PUNCH_DURATION: float = 0.22

## Trauma-based camera shake parameters (Gamefeel Audit Issue 2.3).
## Trauma decays at TRAUMA_DECAY units/sec; squared before applying to offset (quadratic feel).
const TRAUMA_DECAY: float = 3.5
const SHAKE_MAX_OFFSET: float = 10.0

# ── Private variables ─────────────────────────────────────────────────────────

var _controller_state: ControllerState = ControllerState.DISABLED
var _is_invincible: bool = false
var _last_facing_dir: Vector2 = Vector2.RIGHT
var _dash_duration_timer: float = 0.0  # countdown; > 0.0 means currently dashing
var _dash_cooldown_timer: float = 0.0  # countdown to the next recharged charge; > 0.0 = recharging
## Dash charges available now (ADR-0018). A dash needs at least one.
var _dash_charges: int = maxi(BULLET_HELL_TUNING.dash_charges, 1)
## Hurtbox dot + graze ring drawn on Fayde during combat (ADR-0018). Null in tests
## that never call _ready().
var _hurt_dot: _HurtboxDot = null

## Run sigil multipliers (1.0 = no sigil). Persist across rooms; reset only on a
## fresh scene/run. Applied to MOVE_SPEED and DASH_COOLDOWN at their use sites.
var _move_speed_mult: float = 1.0
var _dash_cooldown_mult: float = 1.0
## ADR-0019 bullet-hell sigils: extra dash charges, graze ring multiplier and the
## dash-cut radius (0 = dash does not cut bullets).
var _bonus_dash_charges: int = 0
var _graze_radius_mult: float = 1.0
var _dash_cut_radius: float = 0.0
## ADR-0019 Perfect Dodge: true once the current dash has already counted, plus the
## real-time cooldown before another dash can count.
var _perfect_dodged_this_dash: bool = false
var _perfect_dodge_cd: float = 0.0
var _cast_beam_timer: float = 0.0     # countdown; > 0.0 means cast beam visible (debug)
var _cast_prana_type: int = -1        # primary type of last resolved spell; -1 = none
var _blink_timer: float = 0.0         # counts up; toggles modulate.a every BLINK_INTERVAL
var _cast_lock_timer: float = 0.0      # countdown; > 0.0 means post-hit movement dampened
var _knockback_timer: float = 0.0      # countdown; > 0.0 means knockback velocity override active

## AudioSystem Autoload reference; null-safe — set in _ready(), overridable for tests.
## Variant (not Node) intentional — allows MockAudioSystem injection without Node inheritance.
var audio_system: Variant = null
var _footstep_timer: float = 0.0
var _footstep_bag: Array[StringName] = []
var _last_footstep_played: StringName = &""

## Trauma-based camera shake accumulator. Range [0.0, 1.0]. Decays each frame.
## Written by add_camera_trauma(); read in _physics_process() to compute offset.
var _trauma: float = 0.0

## Remaining seconds of post-hit i-frame blink (white, no tint — distinct from dash cyan).
## Driven by HealthAndDamage.damage_taken so the player can read grace frames after being hit.
var _post_hit_blink_timer: float = 0.0

@onready var _camera: Camera2D = $Camera2D
@onready var _iso_char: Node = $IsoCharacter
@onready var _spell_vfx: AnimatedSprite2D = $SpellVFX
var _zoom_tween: Tween = null
var _last_anim: String = ""

## Combat-start flash — masks the prep→combat zoom snap so it doesn't read as Fayde teleporting.
var _flash_rect: ColorRect = null
var _flash_tween: Tween = null

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group(&"player")
	assert(get_tree().get_nodes_in_group(&"player").size() == 1,
		"PlayerController: exactly one 'player' node expected")
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.room_cleared.connect(_on_room_cleared)
	HealthAndDamage.player_died.connect(_on_player_died)
	HealthAndDamage.heavy_hit.connect(_on_heavy_hit)
	HealthAndDamage.damage_taken.connect(_on_player_damage_taken)
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)
	CombinationResolution.combo_resolved.connect(_on_combo_resolved)
	SpellCastingEffects.grazed.connect(_on_grazed)
	audio_system = get_node_or_null("/root/AudioSystem")
	collision_layer = COLLISION_LAYER_PLAYER
	collision_mask = COLLISION_MASK_NORMAL
	_setup_combat_flash()
	_setup_camera_smoothing()
	_hurt_dot = _HurtboxDot.new()
	_hurt_dot.hurt_radius = BULLET_HELL_TUNING.player_hurt_radius
	_hurt_dot.graze_radius = get_graze_radius()
	_hurt_dot.visible = false
	add_child(_hurt_dot)
	if is_instance_valid(_iso_char):
		_iso_char.configure({
			"idle": "fayde_idle",
			"walk": "fayde_walk",
			"cast": "fayde_cast",
		})
		_iso_char.play_anim("idle")
		# _setup_spell_vfx() — disabled; spell cast VFX removed
	if VELOCITY_SNAP_THRESHOLD >= FOOTSTEP_VELOCITY_THRESHOLD:
		push_error("VELOCITY_SNAP_THRESHOLD (%f) must be < FOOTSTEP_VELOCITY_THRESHOLD (%f)" % [
			VELOCITY_SNAP_THRESHOLD, FOOTSTEP_VELOCITY_THRESHOLD])


func _exit_tree() -> void:
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.room_cleared.is_connected(_on_room_cleared):
		GameStateManager.room_cleared.disconnect(_on_room_cleared)
	if HealthAndDamage.player_died.is_connected(_on_player_died):
		HealthAndDamage.player_died.disconnect(_on_player_died)
	if HealthAndDamage.heavy_hit.is_connected(_on_heavy_hit):
		HealthAndDamage.heavy_hit.disconnect(_on_heavy_hit)
	if HealthAndDamage.damage_taken.is_connected(_on_player_damage_taken):
		HealthAndDamage.damage_taken.disconnect(_on_player_damage_taken)
	if SpellCastingEffects.cast_hit_started.is_connected(_on_cast_hit_started):
		SpellCastingEffects.cast_hit_started.disconnect(_on_cast_hit_started)
	if SpellCastingEffects.grazed.is_connected(_on_grazed):
		SpellCastingEffects.grazed.disconnect(_on_grazed)


func _physics_process(delta: float) -> void:
	# Isometric draw-order sort: higher Y = closer to viewer = draw on top (ADR-0001).
	# Entities live in different subtrees (PlayerController, WaveManager enemies) so
	# y_sort_enabled cannot connect them — z_index is the correct substitute until
	# all entities are moved into a shared EntityLayer (ADR-0001 migration plan).
	z_index = clamp(int(global_position.y) + 500, 1, 2000)

	if _cast_beam_timer > 0.0:
		_cast_beam_timer -= delta

	# ── I-frame blink (S8-02, Gamefeel Audit Issue 5.2) ──────────────────────────
	# Dash i-frame: cyan tint so the player can distinguish "I dashed safely"
	# from post-hit grace frames (which use white alpha blink).
	if _is_invincible:
		_blink_timer += delta
		if _blink_timer >= BLINK_INTERVAL:
			_blink_timer -= BLINK_INTERVAL
			var a: float = 0.25 if modulate.a > 0.5 else 1.0
			modulate = Color(0.5, 1.0, 1.0, a)  # cyan — dash i-frame identity
	elif _post_hit_blink_timer > 0.0:
		_post_hit_blink_timer -= delta
		_blink_timer += delta
		if _blink_timer >= BLINK_INTERVAL:
			_blink_timer -= BLINK_INTERVAL
			modulate.a = 0.25 if modulate.a > 0.5 else 1.0
			modulate.r = 1.0
			modulate.g = 1.0
			modulate.b = 1.0
	else:
		if modulate != Color.WHITE:
			modulate = Color.WHITE
		_blink_timer = 0.0

	# ── Camera shake (Gamefeel Audit Issue 2.3) ──────────────────────────────────
	if _trauma > 0.0:
		_trauma = maxf(_trauma - TRAUMA_DECAY * delta, 0.0)
		var shake: float = _trauma * _trauma  # quadratic: gentle at low trauma, sharp at high
		if is_instance_valid(_camera) and shake > 0.001:
			var t_ms: float = float(Time.get_ticks_msec())
			_camera.offset = Vector2(
				sin(t_ms * 0.073) * shake * SHAKE_MAX_OFFSET,
				cos(t_ms * 0.091) * shake * SHAKE_MAX_OFFSET
			)
		elif is_instance_valid(_camera):
			_camera.offset = Vector2.ZERO

	if _controller_state == ControllerState.DISABLED:
		velocity = Vector2.ZERO
		return

	# ── ENABLED: movement + dash trigger ────────────────────────────────────────
	if _controller_state == ControllerState.ENABLED:
		# Knockback override: suppress movement input so the push-away reads
		# clearly regardless of held keys. Friction still decays the velocity.
		if _knockback_timer > 0.0:
			_knockback_timer -= delta
			var friction_factor: float = 1.0 - pow(1.0 - MOVE_FRICTION, delta * 60.0)
			velocity = velocity.lerp(Vector2.ZERO, friction_factor)
			if velocity.length() < VELOCITY_SNAP_THRESHOLD:
				velocity = Vector2.ZERO
		else:
			var input_dir: Vector2 = Input.get_vector(
				&"move_left", &"move_right", &"move_up", &"move_down")
			var move_factor: float = 1.0 - pow(1.0 - MOVE_ACCELERATION, delta * 60.0)
			var friction_factor: float = 1.0 - pow(1.0 - MOVE_FRICTION, delta * 60.0)
			if input_dir != Vector2.ZERO:
				velocity = velocity.lerp(input_dir.normalized() * MOVE_SPEED * _move_speed_mult, move_factor)
				_last_facing_dir = _snap_to_8dir(input_dir)
			else:
				velocity = velocity.lerp(Vector2.ZERO, friction_factor)
				if velocity.length() < VELOCITY_SNAP_THRESHOLD:
					velocity = Vector2.ZERO
			if Input.is_action_just_pressed(&"dash") and _dash_charges > 0:
				var dash_dir: Vector2 = _snap_to_8dir(input_dir) if input_dir != Vector2.ZERO \
					else _last_facing_dir
				_last_facing_dir = dash_dir
				velocity = dash_dir * DASH_SPEED
				_controller_state = ControllerState.DASHING
				_dash_duration_timer = DASH_DURATION
				_perfect_dodged_this_dash = false
				_is_invincible = true
				collision_mask = COLLISION_MASK_DASHING
				_cast_lock_timer = 0.0  # dash cancels cast lock (GDD Rule 6)
				_knockback_timer = 0.0   # dash cancels knockback
				if audio_system != null:
					audio_system.play_event(&"sfx_fayde_dash")
				_dash_charges -= 1
				dash_charges_changed.emit(_dash_charges, _max_dash_charges())
				if _dash_charges == 0:
					dash_cooldown_changed.emit(false)
				_spawn_dash_dust()
				_spawn_dash_ghosts(dash_dir)
		# Cast lock: dampen velocity to CAST_LOCK_SPEED_FACTOR during post-hit recovery.
		# Knockback overrides cast lock dampening — the push-away should feel unhindered.
		if _cast_lock_timer > 0.0 and _knockback_timer <= 0.0:
			velocity *= CAST_LOCK_SPEED_FACTOR

	# ── DASHING: duration countdown ───────────────────────────────────────────
	if _perfect_dodge_cd > 0.0:
		_perfect_dodge_cd = maxf(_perfect_dodge_cd - delta, 0.0)
	if _controller_state == ControllerState.DASHING:
		if _dash_cut_radius > 0.0 and is_inside_tree():
			_cut_bullets()
		_dash_duration_timer -= delta
		if _dash_duration_timer <= 0.0:
			_controller_state = ControllerState.ENABLED
			_is_invincible = false
			collision_mask = COLLISION_MASK_NORMAL
			if _dash_charges < _max_dash_charges() and _dash_cooldown_timer <= 0.0:
				_dash_cooldown_timer = _dash_recharge_duration()

	# ── Dash recharge countdown (unconditional) — one charge per recharge ─────
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
		if _dash_cooldown_timer <= 0.0:
			_dash_cooldown_timer = 0.0
			var was_empty: bool = _dash_charges <= 0
			_dash_charges = mini(_dash_charges + 1, _max_dash_charges())
			dash_charges_changed.emit(_dash_charges, _max_dash_charges())
			if was_empty:
				dash_cooldown_changed.emit(true)
			if _dash_charges < _max_dash_charges():
				_dash_cooldown_timer = _dash_recharge_duration()

	# ── Cast lock countdown (unconditional) ───────────────────────────────────
	if _cast_lock_timer > 0.0:
		_cast_lock_timer -= delta
		if _cast_lock_timer <= 0.0:
			_cast_lock_timer = 0.0

	# ── Footstep accumulator (count-up; fires when >= interval) ─────────────────
	# Timer advances during DASHING — post-dash first footstep may fire early (by design).
	_footstep_timer += delta
	if _footstep_timer >= FOOTSTEP_INTERVAL_SEC:
		_footstep_timer -= FOOTSTEP_INTERVAL_SEC  # decrement not reset — ADR-0004
		if _controller_state == ControllerState.ENABLED and velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD:
			_fire_footstep()

	# ── IsoCharacter sprite sync ──────────────────────────────────────────────
	if is_instance_valid(_iso_char) and _iso_char._initialized:
		_iso_char.set_facing(_last_facing_dir)
		var speed: float = velocity.length()
		var wanted: String = "walk" if speed > FOOTSTEP_VELOCITY_THRESHOLD else "idle"
		if wanted != _last_anim:
			_last_anim = wanted
			_iso_char.play_anim(wanted)

	# Look-ahead offset: shift camera ahead in movement direction.
	# Null-safe: headless unit tests have no Camera2D child.
	if is_instance_valid(_camera):
		var speed_ratio: float = minf(velocity.length() / MOVE_SPEED, 1.0)
		if velocity.length() > 1.0:
			_camera.position = velocity.normalized() * speed_ratio * CAMERA_TUNING.look_ahead_max
		else:
			_camera.position = _camera.position.lerp(Vector2.ZERO, delta * 4.0)

	move_and_slide()

# ── Public methods ────────────────────────────────────────────────────────────

## Returns the current controller state (DISABLED, ENABLED, or DASHING).
func get_controller_state() -> ControllerState:
	return _controller_state


## Returns true when the player is currently invincible (e.g. during a dash).
## Queried by HealthAndDamage at apply_damage step 1a (ADR-0007).
func is_invincible() -> bool:
	return _is_invincible


## Returns true when the player is alive (W-1 fix).
## Delegates to GameStateManager state — DEATH_SCREEN is the authoritative dead state.
## Required by ADR-0011 (StatusEffectsManager Public API Contract).
func is_alive() -> bool:
	return GameStateManager.get_active_state() != GameEnums.GameState.DEATH_SCREEN


## Returns Fayde's last snapped facing direction (8-directional, normalized).
func get_facing_direction() -> Vector2:
	return _last_facing_dir


## Returns Fayde's world position for spell targeting (SC&E targeting origin).
func get_cast_position() -> Vector2:
	return global_position


## Returns seconds until a dash is available. Returns 0.0 while any charge is left.
## TR-PC-002 (ADR-0004 float accumulator); charges per ADR-0018.
func get_dash_cooldown_remaining() -> float:
	if _dash_charges > 0:
		return 0.0
	return max(_dash_cooldown_timer, 0.0)


## Dash charges available now (ADR-0018).
func get_dash_charges() -> int:
	return _dash_charges


## Maximum dash charges (BulletHellTuning.dash_charges, at least 1, plus sigils).
func _max_dash_charges() -> int:
	return maxi(BULLET_HELL_TUNING.dash_charges, 1) + _bonus_dash_charges


## Maximum dash charges including sigil bonuses (ADR-0019).
func get_max_dash_charges() -> int:
	return _max_dash_charges()


## True while a dash is in progress (dash i-frames, not post-hit grace).
func is_dashing() -> bool:
	return _controller_state == ControllerState.DASHING and _dash_duration_timer > 0.0


## ADR-0019 Perfect Dodge. Enemy bullets and hazards call this when they overlap
## Fayde's hurtbox. Counts only during a dash, once per dash, and not again until
## PaceTuning.perfect_dodge_cooldown_sec has passed. Returns true when it counted.
func register_perfect_dodge(world_pos: Vector2) -> bool:
	if not is_dashing() or _perfect_dodged_this_dash or _perfect_dodge_cd > 0.0:
		return false
	_perfect_dodged_this_dash = true
	_perfect_dodge_cd = PACE_TUNING.perfect_dodge_cooldown_sec
	perfect_dodged.emit(world_pos)
	return true


## Current graze ring radius: BulletHellTuning.graze_radius × graze sigils.
func get_graze_radius() -> float:
	return BULLET_HELL_TUNING.graze_radius * _graze_radius_mult


## Radius (px) of bullets a dash cuts through, 0 without the dash-cut sigil.
func get_dash_cut_radius() -> float:
	return _dash_cut_radius


## Sigil: adds [param count] dash charges (granted immediately).
func add_dash_charges(count: int) -> void:
	if count <= 0:
		return
	_bonus_dash_charges += count
	_dash_charges = mini(_dash_charges + count, _max_dash_charges())
	dash_charges_changed.emit(_dash_charges, _max_dash_charges())


## Sigil: multiplies the graze ring radius by [param factor]. Stacks multiplicatively.
func apply_graze_radius_mult(factor: float) -> void:
	_graze_radius_mult *= factor
	if is_instance_valid(_hurt_dot):
		_hurt_dot.graze_radius = get_graze_radius()
		_hurt_dot.queue_redraw()


## Sigil: dashes cut enemy bullets within [param radius] px. Keeps the largest radius.
func set_dash_cut_radius(radius: float) -> void:
	_dash_cut_radius = maxf(_dash_cut_radius, radius)


## Dash-cut sigil: wipes bullets around Fayde while dashing; each feeds the meter.
func _cut_bullets() -> void:
	var n: int = Projectile.cancel_in_radius(get_tree(), global_position, _dash_cut_radius)
	if n > 0:
		SpellCastingEffects.add_special_meter(float(n) * PACE_TUNING.cancel_meter_gain)


## Seconds to recharge one dash charge, scaled by dash-cooldown sigils.
func _dash_recharge_duration() -> float:
	return BULLET_HELL_TUNING.dash_recharge_sec * _dash_cooldown_mult


## Applies a brief velocity push away from [param from_pos].
## Called by EnemyInstance on contact damage to give Fayde a small knockback.
## Knockback is suppressed during dash (player is invincible) and when disabled.
## [param strength] is the initial velocity in pixels/sec away from the source.
func request_knockback(from_pos: Vector2, strength: float) -> void:
	if _controller_state != ControllerState.ENABLED:
		return
	if _is_invincible:
		return
	var dir: Vector2 = (global_position - from_pos).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector2.UP  # fallback if enemy is exactly at Fayde's position
	velocity = dir * strength
	_knockback_timer = KNOCKBACK_DURATION
	# Cancel cast lock — knockback feel takes priority over post-hit dampening.
	_cast_lock_timer = 0.0

# ── Private methods ───────────────────────────────────────────────────────────

## Snaps an input vector to the nearest of 8 directions (45° increments).
func _snap_to_8dir(input: Vector2) -> Vector2:
	var snap_angle: float = round(atan2(input.y, input.x) / (PI / 4.0)) * (PI / 4.0)
	return Vector2(cos(snap_angle), sin(snap_angle))


## Returns the theoretical maximum dash distance in pixels (DASH_SPEED * DASH_DURATION).
## AC-PC-13 verification helper. Not called at runtime.
func _compute_dash_distance() -> float:
	return DASH_SPEED * DASH_DURATION


## Pops the next footstep variant from the shuffle-bag and dispatches to AudioSystem.
## Anti-consecutive-repeat: swaps first element if it matches last played.
func _fire_footstep() -> void:
	if _footstep_bag.is_empty():
		_footstep_bag = [&"sfx_fayde_footstep_a", &"sfx_fayde_footstep_b", &"sfx_fayde_footstep_c"]
		_footstep_bag.shuffle()
		if _footstep_bag[0] == _last_footstep_played and _footstep_bag.size() > 1:
			var swap_idx: int = randi_range(1, _footstep_bag.size() - 1)
			var tmp: StringName = _footstep_bag[0]
			_footstep_bag[0] = _footstep_bag[swap_idx]
			_footstep_bag[swap_idx] = tmp
	var variant: StringName = _footstep_bag.pop_front()
	_last_footstep_played = variant
	if audio_system != null:
		audio_system.play_event(variant)


## Returns steps per second at the configured footstep interval. AC-PC-14 verification helper.
func _compute_steps_per_second() -> float:
	return 1.0 / FOOTSTEP_INTERVAL_SEC

# ── Signal callbacks ──────────────────────────────────────────────────────────

func _on_combat_started(_is_boss: bool = false) -> void:
	_controller_state = ControllerState.ENABLED
	if is_instance_valid(_hurt_dot):
		_hurt_dot.visible = BULLET_HELL_TUNING.show_hurtbox_dot
	# TRANS_BACK punch-in replaces the old snap+flash (Gamefeel Audit Issue 4.1).
	# The slight overshoot of EASE_OUT+BACK reads as energetic without jarring.
	if is_instance_valid(_camera):
		if _zoom_tween:
			_zoom_tween.kill()
		_zoom_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_zoom_tween.tween_property(_camera, "zoom", Vector2.ONE * CAMERA_TUNING.combat_zoom, ZOOM_COMBAT_PUNCH_DURATION)


func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO
	_is_invincible = false
	collision_mask = COLLISION_MASK_NORMAL
	modulate = Color.WHITE
	_blink_timer = 0.0
	_post_hit_blink_timer = 0.0
	_trauma = 0.0
	_dash_duration_timer = 0.0
	_dash_cooldown_timer = 0.0
	_dash_charges = _max_dash_charges()
	_perfect_dodged_this_dash = false
	_perfect_dodge_cd = 0.0
	_cast_lock_timer = 0.0
	_knockback_timer = 0.0
	if is_instance_valid(_hurt_dot):
		_hurt_dot.visible = false
	dash_cooldown_changed.emit(true)
	dash_charges_changed.emit(_dash_charges, _max_dash_charges())
	_footstep_timer = 0.0
	_footstep_bag.clear()
	if is_instance_valid(_camera):
		_camera.position = Vector2.ZERO
	_tween_zoom(Vector2.ONE * CAMERA_TUNING.prep_zoom)


func _on_room_cleared() -> void:
	_tween_zoom(Vector2.ONE * CAMERA_TUNING.prep_zoom)


func _setup_spell_vfx() -> void:
	var path: String = "res://assets/art/vfx/spell_cast/"
	var da := DirAccess.open(path)
	if da == null or not is_instance_valid(_spell_vfx):
		return
	var files: Array[String] = []
	da.list_dir_begin()
	var fname: String = da.get_next()
	while not fname.is_empty():
		if not da.current_is_dir() and fname.ends_with(".png"):
			files.append(fname)
		fname = da.get_next()
	da.list_dir_end()
	files.sort()
	var sf := SpriteFrames.new()
	sf.add_animation(&"cast")
	sf.set_animation_loop(&"cast", false)
	sf.set_animation_speed(&"cast", 20.0)
	for f: String in files:
		var tex := load(path + f) as Texture2D
		if tex != null:
			sf.add_frame(&"cast", tex)
	_spell_vfx.sprite_frames = sf
	_spell_vfx.animation_finished.connect(_on_spell_vfx_finished)


func _on_spell_vfx_finished() -> void:
	_spell_vfx.visible = false


## CAST_LOCKED movement sub-state (GDD Rule 6).
## Dampens movement during the post-hit recovery window. Dash cancels the lock.
## [param lock_duration] seconds of dampened movement (0.12 default, 0.20 Ashfire).
## [param slow_factor] is reserved on the signal but PlayerController uses its own constant.
func _on_cast_hit_started(lock_duration: float = 0.12) -> void:
	_cast_beam_timer = 0.20
	_cast_lock_timer = lock_duration


func _on_combo_resolved(spell_effect: SpellEffect) -> void:
	_cast_prana_type = spell_effect.primary_type


## Graze feedback (ADR-0018): the graze ring flashes when a bullet skims past.
func _on_grazed(_world_pos: Vector2, _meter_gain: float) -> void:
	if is_instance_valid(_hurt_dot):
		_hurt_dot.flash()


## Creates a full-screen ColorRect on a high-layer CanvasLayer for the combat start flash.
## Called once from _ready(). Starts invisible; _play_combat_flash() drives it.
func _setup_combat_flash() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100  # above HUD (layer=10) and all game content
	add_child(canvas)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color.BLACK
	_flash_rect.modulate.a = 0.0
	_flash_rect.anchor_right = 1.0
	_flash_rect.anchor_bottom = 1.0
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_flash_rect)


## Briefly flashes black to mask the 0.55x→1.5x zoom snap at combat start.
## Holds opaque for one physics frame, then fades to transparent over 0.15 s.
func _play_combat_flash() -> void:
	if _flash_rect == null:
		return
	if _flash_tween:
		_flash_tween.kill()
	_flash_rect.modulate.a = 1.0
	_flash_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_flash_tween.tween_interval(get_physics_process_delta_time())
	_flash_tween.tween_property(_flash_rect, "modulate:a", 0.0, 0.15)


## Enables Camera2D built-in position smoothing so the camera glides
## instead of snapping to the player. Called once from _ready().
func _setup_camera_smoothing() -> void:
	if _camera == null:
		return
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = CAMERA_TUNING.smooth_speed


func _tween_zoom(target: Vector2) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_camera, "zoom", target, ZOOM_TWEEN_DURATION)


## Sigil: multiplies the move-speed multiplier by [param factor] (e.g. 1.15 = +15%).
## Stacks multiplicatively with prior speed sigils. Persists for the rest of the run.
func apply_move_speed_mult(factor: float) -> void:
	_move_speed_mult *= factor


## Sigil: multiplies the dash-cooldown multiplier by [param factor] (e.g. 0.75 = -25%).
## Lower is better. Stacks multiplicatively. Persists for the rest of the run.
func apply_dash_cooldown_mult(factor: float) -> void:
	_dash_cooldown_mult *= factor


## Cinematic boss-reveal beat: pulls the camera out to show more of the arena,
## holds, then eases back to combat zoom. Only touches zoom (never position), so
## it does not fight the per-frame look-ahead. Called by CombatHUD on boss spawn.
## No-op in headless tests where the Camera2D child is absent.
func boss_reveal_zoom() -> void:
	if not is_instance_valid(_camera):
		return
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_zoom_tween.tween_property(_camera, "zoom", Vector2.ONE * CAMERA_TUNING.boss_reveal_zoom, 0.5).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_interval(CAMERA_TUNING.boss_reveal_hold_sec)
	_zoom_tween.tween_property(_camera, "zoom", Vector2.ONE * CAMERA_TUNING.combat_zoom, 0.6).set_ease(Tween.EASE_IN_OUT)


func _on_player_died() -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO
	add_camera_trauma(0.85)  # death shake: strong jolt before overlay appears


## Spawns a procedural dust burst at Fayde's feet when a dash starts.
## Two _DashDust nodes offset ±15px perpendicular to dash direction.
func _spawn_dash_dust() -> void:
	if not is_inside_tree():
		return
	# Perpendicular offset so both dust puffs are visible from iso perspective.
	var perp: Vector2 = _last_facing_dir.rotated(PI / 2.0)
	for sign in [-1.0, 1.0]:
		var dust := _DashDust.new()
		dust.global_position = global_position + perp * 15.0 * sign
		add_child(dust)


## Spawns 2 ghost afterimage sprites at Fayde's current position.
## Each ghost captures the current IsoCharacter sprite frame, offset backward
## along the dash direction, and fades out over 0.25 s.
func _spawn_dash_ghosts(dash_dir: Vector2) -> void:
	var pixel: PixelCharacter = get_node_or_null(^"PixelCharacter") as PixelCharacter
	if pixel != null and pixel.sheet != null:
		_spawn_pixel_ghosts(pixel, dash_dir)
		return
	if _iso_char == null or not _iso_char._initialized:
		return
	var sprite: AnimatedSprite2D = _iso_char.get_sprite()
	if sprite == null or sprite.sprite_frames == null:
		return
	var current_anim: String = sprite.animation
	if current_anim.is_empty():
		return
	var frame_idx: int = sprite.frame
	var frame_tex: Texture2D = sprite.sprite_frames.get_frame_texture(current_anim, frame_idx)
	if frame_tex == null:
		return
	var backward: Vector2 = -dash_dir
	for i: int in range(2):
		var ghost := Sprite2D.new()
		ghost.texture = frame_tex
		ghost.scale = _iso_char.sprite_scale
		ghost.global_position = global_position + backward * (20.0 + float(i) * 18.0)
		ghost.z_index = z_index - 1
		ghost.modulate.a = 0.35 - float(i) * 0.15
		# Top-level so ghost stays in place while Fayde dashes forward.
		ghost.top_level = true
		get_tree().root.add_child(ghost)
		var tw: Tween = create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
		tw.tween_callback(ghost.queue_free)


## Dash afterimages from the pixel-art sprite (ADR-0022): two copies of the current
## frame left behind along the dash, fading out over 0.25 s.
func _spawn_pixel_ghosts(pixel: PixelCharacter, dash_dir: Vector2) -> void:
	for i: int in range(2):
		var ghost: Sprite2D = pixel.make_ghost()
		ghost.global_position = global_position - dash_dir * (20.0 + float(i) * 18.0)
		ghost.z_index = z_index - 1
		ghost.modulate = Color(0.6, 0.9, 1.0, 0.4 - float(i) * 0.15)
		ghost.top_level = true
		get_tree().root.add_child(ghost)
		var tw: Tween = ghost.create_tween()
		tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
		tw.tween_callback(ghost.queue_free)


## Adds [param amount] to the camera shake trauma accumulator (clamped to 1.0).
## Values: 0.2 = light (Cluster hit), 0.5 = medium (Charger charge), 0.85 = heavy (death).
## Trauma decays at TRAUMA_DECAY per second and is squared before offset application.
func add_camera_trauma(amount: float) -> void:
	_trauma = minf(_trauma + amount, 1.0)


## Responds to heavy_hit (final_damage >= HEAVY_HIT_THRESHOLD) with camera trauma.
## Trauma scales linearly with damage above the threshold, capped at heavy-charge level.
func _on_heavy_hit(_target: Node, final_damage: int) -> void:
	var t: float = lerpf(0.25, 0.55,
		clampf((float(final_damage) - float(HealthAndDamage.HEAVY_HIT_THRESHOLD)) / 30.0, 0.0, 1.0))
	add_camera_trauma(t)


## Starts the post-hit white blink when Fayde takes damage.
## Sets _post_hit_blink_timer to the H&D i-frame duration so blink matches grace period.
func _on_player_damage_taken(target: Node, final_damage: int, _current_hp: int) -> void:
	if target.is_in_group(&"player") and final_damage > 0:
		_post_hit_blink_timer = HealthAndDamage.FAYDE_IFRAME_DURATION
		_blink_timer = 0.0  # start fresh so first blink fires immediately


## Inner class: single procedural dash dust puff.
## Draws 5 expanding circles in a small cluster, auto-frees after 0.3 s.
class _DashDust extends Node2D:
	const DUST_DURATION: float = 0.3

	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 89  # below Fayde, above floor
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= int(DUST_DURATION * 1_000_000.0):
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed: float = float(Time.get_ticks_usec() - _start_us) / 1_000_000.0
		var p: float = clampf(elapsed / DUST_DURATION, 0.0, 1.0)
		var alpha: float = 1.0 - p
		var c: Color = Color(0.8, 0.75, 0.65, alpha)
		# 5 dust motes expanding outward + upward.
		for i: int in 5:
			var angle: float = (TAU / 5.0) * float(i) + p * 0.5
			var dist: float = lerpf(2.0, 22.0, p)
			var r: float = lerpf(3.5, 0.5, p)
			var at: Vector2 = Vector2.from_angle(angle) * dist + Vector2(0, -p * 10.0)
			PixelVFX.draw_spans(self, PixelVFX.disc_spans(maxf(r, 1.0)),
					PixelVFX.with_alpha(c, alpha), PixelVFX.snap_origin(self) + at.round())


## Inner class: Fayde's hurtbox dot and graze ring (ADR-0018).
## Drawn above bullets (absolute z) so the player always knows exactly what can be
## hit. The graze ring is faint and flashes on each graze.
class _HurtboxDot extends Node2D:
	const FLASH_SEC: float = 0.18

	var hurt_radius: float = 3.0
	var graze_radius: float = 20.0
	var _flash: float = 0.0

	func _ready() -> void:
		z_as_relative = false
		z_index = 2200
		process_mode = PROCESS_MODE_PAUSABLE

	func flash() -> void:
		_flash = FLASH_SEC
		queue_redraw()

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(_flash - delta, 0.0)
			queue_redraw()

	func _draw() -> void:
		var f: float = _flash / FLASH_SEC
		# Pixel-art grid (ADR-0023): 1 px ring, 2 px while flashing.
		var o: Vector2 = PixelVFX.snap_origin(self)
		PixelVFX.draw_spans(self, PixelVFX.ring_spans(graze_radius, 1.0 + roundf(f)),
				PixelVFX.with_alpha(Color.WHITE, 0.10 + 0.55 * f, PixelVFX.FILL_ALPHA_STEPS), o)
		PixelVFX.draw_spans(self, PixelVFX.disc_spans(hurt_radius + 1.5), Color(0.05, 0.02, 0.1, 0.9), o)
		PixelVFX.draw_spans(self, PixelVFX.disc_spans(hurt_radius), Color.WHITE, o)
