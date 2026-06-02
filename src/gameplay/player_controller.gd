## player_controller.gd — Fayde's CharacterBody2D controller.
## Layer: Core | Story: PC-001 — Skeleton, group registration, state machine
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
const FOOTSTEP_INTERVAL_SEC: float = 0.38
const FOOTSTEP_VELOCITY_THRESHOLD: float = 10.0

# ── Private variables ─────────────────────────────────────────────────────────

var _controller_state: ControllerState = ControllerState.DISABLED
var _is_invincible: bool = false
var _last_facing_dir: Vector2 = Vector2.RIGHT

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	add_to_group(&"player")
	assert(get_tree().get_nodes_in_group(&"player").size() == 1,
		"PlayerController: exactly one 'player' node expected")
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.preparation_started.connect(_on_preparation_started)


func _exit_tree() -> void:
	GameStateManager.combat_started.disconnect(_on_combat_started)
	GameStateManager.preparation_started.disconnect(_on_preparation_started)


func _physics_process(_delta: float) -> void:
	if _controller_state == ControllerState.DISABLED:
		velocity = Vector2.ZERO
		return
	# Movement and dash logic implemented in Stories 002–003.

# ── Public methods ────────────────────────────────────────────────────────────

## Returns the current controller state (DISABLED, ENABLED, or DASHING).
func get_controller_state() -> ControllerState:
	return _controller_state


## Returns true when the player is currently invincible (e.g. during a dash).
func is_invincible() -> bool:
	return _is_invincible


## Returns true when the player is alive.
## Required by ADR-0011 (StatusEffectsManager Public API Contract).
## Placeholder until HealthAndDamage player-death API is implemented.
func is_alive() -> bool:
	return true

# ── Signal callbacks ──────────────────────────────────────────────────────────

func _on_combat_started(_is_boss: bool = false) -> void:
	_controller_state = ControllerState.ENABLED


func _on_preparation_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_controller_state = ControllerState.DISABLED
	velocity = Vector2.ZERO
	_is_invincible = false
