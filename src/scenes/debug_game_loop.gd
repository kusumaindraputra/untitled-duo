## debug_game_loop.gd — Temporary launcher for the First Playable build.
##
## Wires the scene tree, generates a DungeonGraph, and drives multi-room runs.
## The player uses the PranaGrid UI to arrange fragments and confirm before
## each combat. After clearing a room, exit doors unlock — the player walks
## through to trigger the next room transition.
##
## Controls (in-game):
##   W / A / S / D  — Move Fayde
##   Left Shift      — Dash
##   Space           — Cast spell (registered by SpellCastingEffects)
##   R               — Reload scene (restart run)
##
## Remove when a proper game menu and run-start flow are implemented.
extends Node

## Total number of floors in a single run.
const TOTAL_FLOORS: int = 3

var _dungeon_graph: DungeonGraph = null
var _gen: DungeonGenerator = DungeonGenerator.new()
var _current_floor: int = 1

func _ready() -> void:
	_register_input_actions()

	# Tell SceneManager about the initial room already in main.tscn so the first
	# room transition correctly frees it instead of leaving a duplicate.
	SceneManager.set_initial_scene($SubSceneRoot/IsometricRoom)

	# Generate floor 1 and give it to RoomTransitionManager.
	_dungeon_graph = _gen.generate(7, _current_floor)
	var rtm: RoomTransitionManager = $RoomTransitionManager
	rtm.setup(_dungeon_graph)
	rtm.room_transition_completed.connect(_on_room_transitioned)

	# Wire initial room: spawn markers + exit doors + is_final_room flag.
	var initial_room: IsometricRoom = $SubSceneRoot/IsometricRoom
	$WaveManager.spawn_points_container = initial_room.get_node("SpawnMarkers")
	_set_final_room_flag(_dungeon_graph.get_entry_room())
	rtm.wire_exit_doors(initial_room)

	$PlayerController.position = Vector2(0, 0)
	# Wire CombatHUD node references here — NodePath in .tscn can't resolve because
	# CombatHUD enters the tree before PlayerController (scene ordering in main.tscn).
	# debug_game_loop._ready() fires last (parent after all children), so both are ready.
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	hud.player_controller = $PlayerController
	hud.fayde_node = $PlayerController
	GameStateManager._active_state = GameEnums.GameState.MAIN_MENU
	GameStateManager.set_is_final_floor(_current_floor >= TOTAL_FLOORS)
	GameStateManager.run_ended.connect(_on_run_ended)
	GameStateManager.wave_ended.connect(_on_wave_ended)
	GameStateManager.floor_completed.connect(_on_floor_completed)
	GameStateManager.start_run()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()


# ── Private ───────────────────────────────────────────────────────────────────

## Called after each room transition completes. Rewires WaveManager to the new
## room's SpawnMarkers, updates the is_final_room flag, then restarts prep phase.
func _on_room_transitioned(new_room_idx: int) -> void:
	var new_room: Node = SceneManager.get_current_scene()
	if new_room == null:
		push_error("debug_game_loop: room_transition_completed but SceneManager has no scene")
		return
	var spawn_markers: Node = new_room.get_node_or_null("SpawnMarkers")
	if spawn_markers == null:
		push_error("debug_game_loop: new room has no SpawnMarkers node")
	$WaveManager.spawn_points_container = spawn_markers
	_set_final_room_flag(new_room_idx)
	GameStateManager.restart_preparation()


## Sets WaveManager.is_final_room based on the room type at [param room_idx].
func _set_final_room_flag(room_idx: int) -> void:
	if _dungeon_graph == null:
		return
	var room: Dictionary = _dungeon_graph.get_room(room_idx)
	$WaveManager.is_final_room = (room.get("type", DungeonGraph.ROOM_TYPE_COMBAT) == DungeonGraph.ROOM_TYPE_BOSS)

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


## Called when the boss of a non-final floor is defeated.
## Generates the next floor and loads it via RTM — _on_room_transitioned handles
## spawn rewiring + restart_preparation() when load_floor() completes.
func _on_floor_completed() -> void:
	_current_floor += 1
	_dungeon_graph = _gen.generate(7, _current_floor)
	GameStateManager.set_is_final_floor(_current_floor >= TOTAL_FLOORS)
	$RoomTransitionManager.load_floor(_dungeon_graph)


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
	var audio := get_node_or_null("/root/AudioSystem")
	if audio != null and audio.has_method(&"has_event") and audio.has_event(&"sfx_wave_clear"):
		audio.play_event(&"sfx_wave_clear")
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
