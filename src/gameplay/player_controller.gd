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

# ── Enums ─────────────────────────────────────────────────────────────────────

enum ControllerState { DISABLED, ENABLED, DASHING }

# ── Constants ─────────────────────────────────────────────────────────────────

const MOVE_SPEED: float = 180.0
const MOVE_ACCELERATION: float = 0.80
const MOVE_FRICTION: float = 0.50
const VELOCITY_SNAP_THRESHOLD: float = 8.0
const DASH_SPEED: float = 400.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 2.0
const FOOTSTEP_INTERVAL_SEC: float = 0.38           # activated: Story PC-004
const FOOTSTEP_VELOCITY_THRESHOLD: float = 10.0     # activated: Story PC-004

## Collision layer bits (S8-02, S9-09).
## Layer 1 (bit 0, value  1): World/Walls — TileMapLayer, StaticBody2D arenas.
## Layer 2 (bit 1, value  2): Player.
## Layer 3 (bit 2, value  4): Enemies.
## Layer 4 (bit 3, value  8): Projectiles (Rifter shots).
## Layer 5 (bit 4, value 16): Half-cover debris — blocks movement, not Prana/projectiles.
const COLLISION_LAYER_PLAYER: int = 2
const COLLISION_MASK_NORMAL: int = 21  # bits 0+2+4: walls (1) + enemies (4) + debris (16)
const COLLISION_MASK_DASHING: int = 1  # bit 0 only: walls only — dash passes through enemies and debris

## Modulate alpha oscillation interval during i-frames — ~8 blinks/sec at 60fps.
const BLINK_INTERVAL: float = 0.06
## Duration of knockback velocity override (seconds). Brief window where movement
## input is suppressed so the push-away reads clearly regardless of held keys.
const KNOCKBACK_DURATION: float = 0.08

## Camera smoothing speed — pixels/sec² toward the target position.
## Higher = snappier; 8.0 gives subtle smoothing without sluggish feel.
const CAMERA_SMOOTH_SPEED: float = 8.0
## Maximum camera look-ahead offset in pixels (ahead of player in movement direction).
const CAMERA_LOOK_AHEAD_MAX: float = 30.0

## Movement speed multiplier during cast lock — Fayde can still move but at reduced speed.
## GDD Rule 6: movement is dampened, not zeroed, during the post-hit recovery window.
const CAST_LOCK_SPEED_FACTOR: float = 0.55

## Camera zoom levels.
## COMBAT 1.5×: visible 768×432 game-px, Fayde occupies ~15% height (Hades-like scale).
## PREP 0.55×: visible 2094×1178 game-px, shows full 1280×768 arena with ~400px margin.
const ZOOM_COMBAT: Vector2 = Vector2(1.5, 1.5)
const ZOOM_PREP: Vector2 = Vector2(0.55, 0.55)
const ZOOM_TWEEN_DURATION: float = 0.35

# ── Private variables ─────────────────────────────────────────────────────────

var _controller_state: ControllerState = ControllerState.DISABLED
var _is_invincible: bool = false
var _last_facing_dir: Vector2 = Vector2.RIGHT
var _dash_duration_timer: float = 0.0  # countdown; > 0.0 means currently dashing
var _dash_cooldown_timer: float = 0.0  # countdown; > 0.0 means on cooldown
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

@onready var _camera: Camera2D = $Camera2D
@onready var _iso_char: Node = $IsoCharacter
@onready var _spell_vfx: AnimatedSprite2D = $SpellVFX
var _zoom_tween: Tween = null
var _last_anim: String = ""

## Combat-start flash — masks the 0.55x→1.5x zoom snap so it doesn't read as Fayde teleporting.
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
	HealthAndDamage.player_died.connect(_on_player_died)
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)
	CombinationResolution.combo_resolved.connect(_on_combo_resolved)
	audio_system = get_node_or_null("/root/AudioSystem")
	collision_layer = COLLISION_LAYER_PLAYER
	collision_mask = COLLISION_MASK_NORMAL
	_setup_combat_flash()
	_setup_camera_smoothing()
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
	if HealthAndDamage.player_died.is_connected(_on_player_died):
		HealthAndDamage.player_died.disconnect(_on_player_died)
	if SpellCastingEffects.cast_hit_started.is_connected(_on_cast_hit_started):
		SpellCastingEffects.cast_hit_started.disconnect(_on_cast_hit_started)


func _physics_process(delta: float) -> void:
	# Isometric draw-order sort: higher Y = closer to viewer = draw on top (ADR-0001).
	# Entities live in different subtrees (PlayerController, WaveManager enemies) so
	# y_sort_enabled cannot connect them — z_index is the correct substitute until
	# all entities are moved into a shared EntityLayer (ADR-0001 migration plan).
	z_index = clamp(int(global_position.y) + 500, 1, 2000)

	if _cast_beam_timer > 0.0:
		_cast_beam_timer -= delta

	# ── I-frame blink (S8-02) ────────────────────────────────────────────────────
	if _is_invincible:
		_blink_timer += delta
		if _blink_timer >= BLINK_INTERVAL:
			_blink_timer -= BLINK_INTERVAL
			modulate.a = 0.25 if modulate.a > 0.5 else 1.0
	else:
		if modulate.a != 1.0:
			modulate.a = 1.0
		_blink_timer = 0.0

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
				velocity = velocity.lerp(input_dir.normalized() * MOVE_SPEED, move_factor)
				_last_facing_dir = _snap_to_8dir(input_dir)
			else:
				velocity = velocity.lerp(Vector2.ZERO, friction_factor)
				if velocity.length() < VELOCITY_SNAP_THRESHOLD:
					velocity = Vector2.ZERO
			if Input.is_action_just_pressed(&"dash") and _dash_cooldown_timer <= 0.0:
				var dash_dir: Vector2 = _snap_to_8dir(input_dir) if input_dir != Vector2.ZERO \
					else _last_facing_dir
				_last_facing_dir = dash_dir
				velocity = dash_dir * DASH_SPEED
				_controller_state = ControllerState.DASHING
				_dash_duration_timer = DASH_DURATION
				_is_invincible = true
				collision_mask = COLLISION_MASK_DASHING
				_cast_lock_timer = 0.0  # dash cancels cast lock (GDD Rule 6)
				_knockback_timer = 0.0   # dash cancels knockback
				if audio_system != null:
					audio_system.play_event(&"sfx_fayde_dash")
				dash_cooldown_changed.emit(false)
				_spawn_dash_dust()
				_spawn_dash_ghosts(dash_dir)
		# Cast lock: dampen velocity to CAST_LOCK_SPEED_FACTOR during post-hit recovery.
		# Knockback overrides cast lock dampening — the push-away should feel unhindered.
		if _cast_lock_timer > 0.0 and _knockback_timer <= 0.0:
			velocity *= CAST_LOCK_SPEED_FACTOR

	# ── DASHING: duration countdown ───────────────────────────────────────────
	if _controller_state == ControllerState.DASHING:
		_dash_duration_timer -= delta
		if _dash_duration_timer <= 0.0:
			_controller_state = ControllerState.ENABLED
			_is_invincible = false
			collision_mask = COLLISION_MASK_NORMAL
			_dash_cooldown_timer = DASH_COOLDOWN

	# ── Dash cooldown countdown (unconditional) ───────────────────────────────
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
		if _dash_cooldown_timer <= 0.0:
			_dash_cooldown_timer = 0.0
			dash_cooldown_changed.emit(true)

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
			_camera.position = velocity.normalized() * speed_ratio * CAMERA_LOOK_AHEAD_MAX
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


## Returns the remaining dash cooldown in seconds. Returns 0.0 when ready.
## TR-PC-002 (ADR-0004 float accumulator).
func get_dash_cooldown_remaining() -> float:
	return max(_dash_cooldown_timer, 0.0)


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
	if _camera != null:
		if _zoom_tween:
			_zoom_tween.kill()
			_zoom_tween = null
		_camera.zoom = ZOOM_COMBAT
	_play_combat_flash()


func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO
	_is_invincible = false
	collision_mask = COLLISION_MASK_NORMAL
	modulate.a = 1.0
	_blink_timer = 0.0
	_dash_duration_timer = 0.0
	_dash_cooldown_timer = 0.0
	_cast_lock_timer = 0.0
	_knockback_timer = 0.0
	dash_cooldown_changed.emit(true)
	_footstep_timer = 0.0
	_footstep_bag.clear()
	_tween_zoom(ZOOM_PREP)


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
	_camera.position_smoothing_speed = CAMERA_SMOOTH_SPEED


func _tween_zoom(target: Vector2) -> void:
	if _zoom_tween:
		_zoom_tween.kill()
	_zoom_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_property(_camera, "zoom", target, ZOOM_TWEEN_DURATION)


func _on_player_died() -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO


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
			draw_circle(Vector2.from_angle(angle) * dist + Vector2(0, -p * 10.0), r, c)
