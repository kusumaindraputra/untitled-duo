## player_controller.gd — Fayde's CharacterBody2D controller.
## Layer: Core | Stories: PC-001–PC-004, S5-05 — Skeleton, state machine, WASD movement,
##   friction, dash system, I-frame, interface getters, footstep shuffle-bag, audio events,
##   dash_cooldown_changed signal (CombatHUD discoverability).
class_name PlayerController
extends CharacterBody2D

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when dash availability changes. Fires false when dash activates (no longer
## available); fires true when cooldown expires or preparation_started resets dash (GDD Rule 4).
signal dash_cooldown_changed(available: bool)

# ── Enums ─────────────────────────────────────────────────────────────────────

enum ControllerState { DISABLED, ENABLED, DASHING }

# ── Constants ─────────────────────────────────────────────────────────────────

const MOVE_SPEED: float = 120.0
const MOVE_ACCELERATION: float = 0.30
const MOVE_FRICTION: float = 0.25
const VELOCITY_SNAP_THRESHOLD: float = 8.0
const DASH_SPEED: float = 400.0
const DASH_DURATION: float = 0.15
const DASH_COOLDOWN: float = 2.0
const FOOTSTEP_INTERVAL_SEC: float = 0.38           # activated: Story PC-004
const FOOTSTEP_VELOCITY_THRESHOLD: float = 10.0     # activated: Story PC-004

# ── Private variables ─────────────────────────────────────────────────────────

var _controller_state: ControllerState = ControllerState.DISABLED
var _is_invincible: bool = false
var _last_facing_dir: Vector2 = Vector2.RIGHT
var _dash_duration_timer: float = 0.0  # countdown; > 0.0 means currently dashing
var _dash_cooldown_timer: float = 0.0  # countdown; > 0.0 means on cooldown
var _cast_beam_timer: float = 0.0     # countdown; > 0.0 means cast beam visible (debug)

## AudioSystem Autoload reference; null-safe — set in _ready(), overridable for tests.
## Variant (not Node) intentional — allows MockAudioSystem injection without Node inheritance.
var audio_system: Variant = null
var _footstep_timer: float = 0.0
var _footstep_bag: Array[StringName] = []
var _last_footstep_played: StringName = &""

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
	audio_system = get_node_or_null("/root/AudioSystem")
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

	if _controller_state == ControllerState.DISABLED:
		velocity = Vector2.ZERO
		return

	# ── ENABLED: movement + dash trigger ────────────────────────────────────────
	if _controller_state == ControllerState.ENABLED:
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
			if audio_system != null:
				audio_system.play_event(&"sfx_fayde_dash")
			dash_cooldown_changed.emit(false)

	# ── DASHING: duration countdown ───────────────────────────────────────────
	if _controller_state == ControllerState.DASHING:
		_dash_duration_timer -= delta
		if _dash_duration_timer <= 0.0:
			_controller_state = ControllerState.ENABLED
			_is_invincible = false
			_dash_cooldown_timer = DASH_COOLDOWN

	# ── Dash cooldown countdown (unconditional) ───────────────────────────────
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta
		if _dash_cooldown_timer <= 0.0:
			_dash_cooldown_timer = 0.0
			dash_cooldown_changed.emit(true)

	# ── Footstep accumulator (count-up; fires when >= interval) ─────────────────
	# Timer advances during DASHING — post-dash first footstep may fire early (by design).
	_footstep_timer += delta
	if _footstep_timer >= FOOTSTEP_INTERVAL_SEC:
		_footstep_timer -= FOOTSTEP_INTERVAL_SEC  # decrement not reset — ADR-0004
		if _controller_state == ControllerState.ENABLED and velocity.length() > FOOTSTEP_VELOCITY_THRESHOLD:
			_fire_footstep()

	move_and_slide()

# ── Public methods ────────────────────────────────────────────────────────────

## Returns the current controller state (DISABLED, ENABLED, or DASHING).
func get_controller_state() -> ControllerState:
	return _controller_state


## Returns true when the player is currently invincible (e.g. during a dash).
## Queried by HealthAndDamage at apply_damage step 1a (ADR-0007).
func is_invincible() -> bool:
	return _is_invincible


## Returns true when the player is alive.
## Required by ADR-0011 (StatusEffectsManager Public API Contract).
## Placeholder until HealthAndDamage player-death API is implemented.
func is_alive() -> bool:
	return true


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


func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO
	_is_invincible = false
	_dash_duration_timer = 0.0
	_dash_cooldown_timer = 0.0
	dash_cooldown_changed.emit(true)
	_footstep_timer = 0.0
	_footstep_bag.clear()


## TR-PC-007 stub: CAST_LOCKED movement sub-state. Full behaviour in SpellCastingEffects epic.
func _on_cast_hit_started(_lock_duration: float = 0.0) -> void:
	_cast_beam_timer = 0.20


func _on_player_died() -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO
