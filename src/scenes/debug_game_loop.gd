## debug_game_loop.gd — Temporary launcher for the First Playable build.
##
## Wires the scene tree, registers input actions, and auto-starts the run.
## The player uses the PranaGrid UI to arrange fragments and confirm before
## combat begins — no keyboard bypass.
##
## Controls (in-game):
##   W / A / S / D  — Move Fayde
##   Left Shift      — Dash
##   Space           — Cast spell (registered by SpellCastingEffects)
##   R               — Reload scene (restart run)
##
## Remove when a proper game menu and run-start flow are implemented.
extends Node

func _ready() -> void:
	_register_input_actions()
	$WaveManager.spawn_points_container = $SubSceneRoot/IsometricRoom/SpawnMarkers
	$PlayerController.position = Vector2(0, 0)
	# Wire CombatHUD node references here — NodePath in .tscn can't resolve because
	# CombatHUD enters the tree before PlayerController (scene ordering in main.tscn).
	# debug_game_loop._ready() fires last (parent after all children), so both are ready.
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	hud.player_controller = $PlayerController
	hud.fayde_node = $PlayerController
	GameStateManager._active_state = GameEnums.GameState.MAIN_MENU
	GameStateManager.run_ended.connect(_on_run_ended)
	GameStateManager.wave_ended.connect(_on_wave_ended)
	GameStateManager.start_run()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()


# ── Private ───────────────────────────────────────────────────────────────────

func _register_input_actions() -> void:
	_ensure_key_action(&"move_left", KEY_A)
	_ensure_key_action(&"move_right", KEY_D)
	_ensure_key_action(&"move_up", KEY_W)
	_ensure_key_action(&"move_down", KEY_S)
	_ensure_key_action(&"dash", KEY_SHIFT)
	_ensure_joypad_action(&"prana_place", JOY_BUTTON_A)
	_ensure_joypad_action(&"prana_clear", JOY_BUTTON_B)
	_ensure_joypad_action(&"prana_confirm", JOY_BUTTON_Y)
	_ensure_key_action(&"prana_confirm", KEY_ENTER)
	_ensure_joypad_action(&"prana_type_cycle", JOY_BUTTON_RIGHT_SHOULDER)


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


## Room-clear warm wash overlay — gold flash on wave_ended (Art Bible §2.4).
## Flash in 0.15 s → hold 0.6 s → fade out 0.5 s. Auto-frees at tween end.
func _on_wave_ended() -> void:
	var wash := ColorRect.new()
	wash.color = Color(1.0, 0.85, 0.4, 0.0)
	wash.anchor_right = 1.0
	wash.anchor_bottom = 1.0
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(wash)
	var tw: Tween = create_tween()
	tw.tween_property(wash, "color:a", 0.18, 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(wash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(wash.queue_free)


func _ensure_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action, ev)


func _ensure_joypad_action(action: StringName, button: JoyButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
