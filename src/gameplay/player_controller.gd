## player_controller.gd — Fayde's CharacterBody2D controller.
## Layer: Core | Stories: PC-001, PC-002, PC-003 — Skeleton, state machine, WASD movement,
##   friction, dash system, I-frame, and interface getters.
class_name PlayerController
extends CharacterBody2D

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

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group(&"player")
	assert(get_tree().get_nodes_in_group(&"player").size() == 1,
		"PlayerController: exactly one 'player' node expected")
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)


func _exit_tree() -> void:
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)


func _physics_process(delta: float) -> void:
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
		if _dash_cooldown_timer < 0.0:
			_dash_cooldown_timer = 0.0

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

# ── Signal callbacks ──────────────────────────────────────────────────────────

func _on_combat_started(_is_boss: bool = false) -> void:
	_controller_state = ControllerState.ENABLED


func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO
	_is_invincible = false
	_dash_duration_timer = 0.0
	_dash_cooldown_timer = 0.0
