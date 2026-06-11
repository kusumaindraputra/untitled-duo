## debug_game_loop.gd — Temporary launcher for the S3-11 First Playable internal playtest.
##
## Wires the scene tree, registers input actions, injects a default Ashfire grid
## so SpellCastingEffects enters READY state, and auto-starts the run.
## Remove when a proper game menu, PranaGrid, and run-start flow are implemented.
##
## Controls (in-game):
##   W / A / S / D  — Move Fayde
##   Left Shift      — Dash
##   Space           — Cast spell (registered by SpellCastingEffects)
##   Enter           — Start combat (triggers arrangement_confirmed)
extends Node

func _ready() -> void:
	_register_input_actions()
	_inject_debug_fragments()
	$WaveManager.spawn_points_container = $SubSceneRoot/IsometricRoom/SpawnMarkers
	$PlayerController.position = Vector2(0, -200)
	GameStateManager._active_state = GameEnums.GameState.MAIN_MENU
	GameStateManager.run_ended.connect(_on_run_ended)
	GameStateManager.start_run()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.pressed:
		if event.keycode == KEY_ENTER:
			GameStateManager._on_arrangement_confirmed()
		elif event.keycode == KEY_R:
			get_tree().reload_current_scene()


# ── Private ───────────────────────────────────────────────────────────────────

func _register_input_actions() -> void:
	_ensure_key_action(&"move_left", KEY_A)
	_ensure_key_action(&"move_right", KEY_D)
	_ensure_key_action(&"move_up", KEY_W)
	_ensure_key_action(&"move_down", KEY_S)
	_ensure_key_action(&"dash", KEY_SHIFT)


## Injects a minimal Ashfire grid (centre slot only) so CombinationResolution
## emits a valid SpellEffect when combat_started fires without a real PranaGrid.
## This lets SpellCastingEffects enter READY state and accept cast input.
func _inject_debug_fragments() -> void:
	var center := PranaFragment.new()
	center.type_id = 0  # Ashfire
	center.level = 1
	var slots: Array = []
	for i in 9:
		slots.append(null)
	slots[4] = center
	CombinationResolution.set_test_fragments(slots)


func _on_run_ended(win: bool) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.75)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	overlay.add_child(bg)
	var label := Label.new()
	label.text = "YOU WIN\nPress R to restart" if win else "YOU DIED\nPress R to restart"
	label.add_theme_font_size_override(&"font_size", 48)
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(label)
	add_child(overlay)


func _ensure_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)
