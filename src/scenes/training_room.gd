## training_room.gd — Training Room scene manager.
##
## Standalone scene for testing spell combos against a stationary dummy.
## NOT a production scene — dev-only tool, no WaveManager, no run progression.
##
## Controls:
##   W / A / S / D  — Move Fayde
##   Left Shift      — Dash
##   Space           — Cast spell
##   Tab             — Return to prana loadout screen (re-edit combo freely)
##   R               — Reload scene (full reset)
extends Node

# ── Constants ─────────────────────────────────────────────────────────────────

## World position where the dummy spawns. Y=0 aligns with Fayde's default facing ray.
## X=80: dummy edge at ~66px — within Ashfire range (80px) AND all other types (150px).
const _DUMMY_POSITION: Vector2 = Vector2(80, 0)

## Seconds to wait before respawning the dummy after it dies.
const _RESPAWN_DELAY: float = 1.2

# ── State ─────────────────────────────────────────────────────────────────────

var _dummy: DummyEnemy = null
var _respawn_timer: float = 0.0
var _waiting_respawn: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_register_input_actions()
	$PlayerController.position = Vector2.ZERO
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	hud.player_controller = $PlayerController
	hud.fayde_node = $PlayerController
	GameStateManager.run_ended.connect(_on_run_ended)
	# Standard first-run flow: MAIN_MENU → start_run() → PREP_PHASE.
	GameStateManager.reset_to_main_menu()
	GameStateManager.start_run()
	_spawn_dummy()


func _process(delta: float) -> void:
	if _waiting_respawn:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_waiting_respawn = false
			_spawn_dummy()


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.echo or not event.pressed:
		return
	match event.keycode:
		KEY_R:
			get_tree().reload_current_scene()
		KEY_TAB:
			_go_to_prep()

# ── Private ───────────────────────────────────────────────────────────────────

## Instantiates and registers a fresh dummy, then places it in the arena.
## Follows ADR-0007 spawn contract: register_enemy() → add_child() → set position.
func _spawn_dummy() -> void:
	_dummy = DummyEnemy.new()
	# Register before add_child so H&D HP pool is live when _ready() fires.
	HealthAndDamage.register_enemy(_dummy, DummyEnemy.DUMMY_TYPE_ID)
	# EntityLayer renders after TileMapLayer in scene order — entities draw on top of floor.
	$SubSceneRoot/IsometricRoom/EntityLayer.add_child(_dummy)
	_dummy.global_position = _DUMMY_POSITION
	_dummy.dummy_killed.connect(_on_dummy_killed, CONNECT_ONE_SHOT)


## Returns to PREPARATION_PHASE so the player can re-arrange prana freely.
## Emits run_ended(false) first so RunManager resets cleanly before the new run.
func _go_to_prep() -> void:
	# End current run + reset to MAIN_MENU (required by start_run() guard).
	GameStateManager.reset_to_main_menu()
	GameStateManager.start_run()
	# run_started clears H&D registry — re-register dummy so it's hittable again.
	if is_instance_valid(_dummy):
		HealthAndDamage.register_enemy(_dummy, DummyEnemy.DUMMY_TYPE_ID)
		_dummy.reset_hp()


## Schedules a dummy respawn after _RESPAWN_DELAY seconds.
func _on_dummy_killed() -> void:
	_dummy = null
	_waiting_respawn = true
	_respawn_timer = _RESPAWN_DELAY


## Training room never ends (no win/lose state), so we swallow run_ended.
func _on_run_ended(_win: bool) -> void:
	pass


# ── Input registration ────────────────────────────────────────────────────────

func _register_input_actions() -> void:
	_ensure_key_action(&"move_left",  KEY_A)
	_ensure_key_action(&"move_right", KEY_D)
	_ensure_key_action(&"move_up",    KEY_W)
	_ensure_key_action(&"move_down",  KEY_S)
	_ensure_key_action(&"dash",       KEY_SHIFT)
	# Gamepad: left analog stick for movement (JOY_AXIS_LEFT_X/Y)
	_ensure_joypad_motion_action(&"move_left",  JOY_AXIS_LEFT_X, -1.0)
	_ensure_joypad_motion_action(&"move_right", JOY_AXIS_LEFT_X,  1.0)
	_ensure_joypad_motion_action(&"move_up",    JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joypad_motion_action(&"move_down",  JOY_AXIS_LEFT_Y,  1.0)
	# Gamepad: West face button (X / Square) for dash
	_ensure_joypad_action(&"dash", JOY_BUTTON_WEST)
	_ensure_joypad_action(&"prana_place",      JOY_BUTTON_A)
	_ensure_joypad_action(&"prana_clear",      JOY_BUTTON_B)
	_ensure_joypad_action(&"prana_confirm",    JOY_BUTTON_Y)
	_ensure_key_action(&"prana_confirm",       KEY_ENTER)
	_ensure_joypad_action(&"prana_type_cycle", JOY_BUTTON_RIGHT_SHOULDER)


func _ensure_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).keycode == keycode:
			return
	InputMap.action_add_event(action, ev)


func _ensure_joypad_action(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton \
				and (existing as InputEventJoypadButton).button_index == button:
			return
	InputMap.action_add_event(action, ev)


## Registers an analog stick axis direction to an action. Safe to call multiple times.
func _ensure_joypad_motion_action(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion:
			var m := existing as InputEventJoypadMotion
			if m.axis == axis and sign(m.axis_value) == sign(axis_value):
				return
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	InputMap.action_add_event(action, ev)
