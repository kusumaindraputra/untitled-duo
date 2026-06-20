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

## Paths to per-floor enemy pool configs. Index 0 = floor 1, etc.
const _FLOOR_POOL_PATHS: Array[String] = [
	"res://assets/data/enemy_pool_configs/enemy_pool_floor1.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_floor2.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_floor3.tres",
]
## Per-floor boss pool paths. F1=Sentinel, F2=WarpedWarden mid-boss, F3=Sentinel.
const _BOSS_POOL_PATHS: Array[String] = [
	"res://assets/data/enemy_pool_configs/enemy_pool_boss.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_boss_f2.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_boss.tres",
]

var _dungeon_graph: DungeonGraph = null
var _gen: DungeonGenerator = DungeonGenerator.new()
var _current_floor: int = 1
var _floor_pool_configs: Array[EnemyPoolConfig] = []
var _boss_pool_configs: Array[EnemyPoolConfig] = []

func _ready() -> void:
	_register_input_actions()
	_load_pool_configs()

	# Tell SceneManager about the initial room already in main.tscn so the first
	# room transition correctly frees it instead of leaving a duplicate.
	SceneManager.set_initial_scene($SubSceneRoot/IsometricRoom)

	# Generate floor 1 and give it to RoomTransitionManager.
	_dungeon_graph = _gen.generate(7, _current_floor)
	var rtm: RoomTransitionManager = $RoomTransitionManager
	rtm.setup(_dungeon_graph)
	rtm.room_transition_completed.connect(_on_room_transitioned)

	_apply_floor_pool_config()

	# Wire initial room: spawn markers + exit doors + room type flags.
	var initial_room: IsometricRoom = $SubSceneRoot/IsometricRoom
	$WaveManager.spawn_points_container = initial_room.get_node("SpawnMarkers")
	_configure_wave_manager_for_room(_dungeon_graph.get_entry_room())
	rtm.wire_exit_doors(initial_room)

	$PlayerController.position = initial_room.get_player_spawn_position()
	# Wire CombatHUD node references here — NodePath in .tscn can't resolve because
	# CombatHUD enters the tree before PlayerController (scene ordering in main.tscn).
	# debug_game_loop._ready() fires last (parent after all children), so both are ready.
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	hud.player_controller = $PlayerController
	hud.fayde_node = $PlayerController
	GameStateManager.reset_to_main_menu()
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
## room's SpawnMarkers, updates room type flags, then restarts prep phase.
func _on_room_transitioned(new_room_idx: int) -> void:
	var new_room: Node = SceneManager.get_current_scene()
	if new_room == null:
		push_error("debug_game_loop: room_transition_completed but SceneManager has no scene")
		return
	var spawn_markers: Node = new_room.get_node_or_null("SpawnMarkers")
	if spawn_markers == null:
		push_error("debug_game_loop: new room has no SpawnMarkers node")
	$WaveManager.spawn_points_container = spawn_markers
	_configure_wave_manager_for_room(new_room_idx)
	if new_room is IsometricRoom:
		$PlayerController.position = (new_room as IsometricRoom).get_player_spawn_position()
	GameStateManager.restart_preparation()


## Configures WaveManager for the room at [param room_idx]: sets room_type and is_final_room.
func _configure_wave_manager_for_room(room_idx: int) -> void:
	if _dungeon_graph == null:
		return
	var room: Dictionary = _dungeon_graph.get_room(room_idx)
	var rtype: int = room.get("type", DungeonGraph.ROOM_TYPE_COMBAT)
	$WaveManager.room_type = rtype
	$WaveManager.is_final_room = (rtype == DungeonGraph.ROOM_TYPE_BOSS)

func _register_input_actions() -> void:
	_ensure_key_action(&"move_left",  KEY_A)
	_ensure_key_action(&"move_right", KEY_D)
	_ensure_key_action(&"move_up",    KEY_W)
	_ensure_key_action(&"move_down",  KEY_S)
	_ensure_key_action(&"dash",       KEY_SHIFT)
	# Gamepad: A / Cross = cast (free during combat; prana_place is prep-only)
	_ensure_joypad_action(&"cast", JOY_BUTTON_A)
	# Gamepad: left analog stick for movement (JOY_AXIS_LEFT_X/Y)
	_ensure_joypad_motion_action(&"move_left",  JOY_AXIS_LEFT_X, -1.0)
	_ensure_joypad_motion_action(&"move_right", JOY_AXIS_LEFT_X,  1.0)
	_ensure_joypad_motion_action(&"move_up",    JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joypad_motion_action(&"move_down",  JOY_AXIS_LEFT_Y,  1.0)
	# Gamepad: X / Square face button for dash
	_ensure_joypad_action(&"dash", JOY_BUTTON_X)
	_ensure_joypad_action(&"prana_place",      JOY_BUTTON_A)
	_ensure_joypad_action(&"prana_clear",      JOY_BUTTON_B)
	_ensure_joypad_action(&"prana_confirm",    JOY_BUTTON_Y)
	_ensure_key_action(&"prana_confirm",       KEY_ENTER)
	_ensure_joypad_action(&"prana_type_cycle", JOY_BUTTON_RIGHT_SHOULDER)


## Called when the boss of a non-final floor is defeated.
## Generates the next floor and loads it via RTM — _on_room_transitioned handles
## spawn rewiring + restart_preparation() when load_floor() completes.
func _on_floor_completed() -> void:
	_current_floor += 1
	_dungeon_graph = _gen.generate(7, _current_floor)
	GameStateManager.set_is_final_floor(_current_floor >= TOTAL_FLOORS)
	_apply_floor_pool_config()
	$RoomTransitionManager.load_floor(_dungeon_graph)


## Loads per-floor EnemyPoolConfig resources into _floor_pool_configs and _boss_pool_configs.
func _load_pool_configs() -> void:
	_floor_pool_configs.clear()
	for path: String in _FLOOR_POOL_PATHS:
		var res: Resource = load(path)
		_floor_pool_configs.append(res as EnemyPoolConfig if res is EnemyPoolConfig else null)
	_boss_pool_configs.clear()
	for path: String in _BOSS_POOL_PATHS:
		var res: Resource = load(path)
		_boss_pool_configs.append(res as EnemyPoolConfig if res is EnemyPoolConfig else null)


## Sets WaveManager pool configs for the current floor (combat + boss).
func _apply_floor_pool_config() -> void:
	var floor_idx: int = clampi(_current_floor - 1, 0, _floor_pool_configs.size() - 1)
	if not _floor_pool_configs.is_empty():
		$WaveManager.enemy_pool_config = _floor_pool_configs[floor_idx]
	if not _boss_pool_configs.is_empty():
		var boss_idx: int = clampi(_current_floor - 1, 0, _boss_pool_configs.size() - 1)
		$WaveManager.boss_pool_config = _boss_pool_configs[boss_idx]


func _on_run_ended(win: bool) -> void:
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null and audio.has_method(&"has_event"):
		var evt: StringName = &"sfx_run_win" if win else &"sfx_run_lose"
		if audio.has_event(evt):
			audio.play_event(evt)

	var run_data: Dictionary = RunManager.get_run_data()
	var floor_reached: int = run_data.get("current_floor", 1)
	var rooms_cleared: int = run_data.get("rooms_cleared", 0)

	var overlay := CanvasLayer.new()
	overlay.layer = 20

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.05, 0.02, 0.88) if win else Color(0.12, 0.02, 0.02, 0.88)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "RUN COMPLETE" if win else "YOU DIED"
	title.add_theme_font_size_override(&"font_size", 64)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3) if win else Color(0.9, 0.25, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vbox.add_child(spacer)

	var stats := Label.new()
	stats.text = "Floor %d  ·  %d Room%s Cleared" % [floor_reached, rooms_cleared, "" if rooms_cleared == 1 else "s"]
	stats.add_theme_font_size_override(&"font_size", 28)
	stats.add_theme_color_override(&"font_color", Color(0.8, 0.8, 0.8))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(spacer2)

	var hint := Label.new()
	hint.text = "Press R to play again"
	hint.add_theme_font_size_override(&"font_size", 20)
	hint.add_theme_color_override(&"font_color", Color(0.55, 0.55, 0.55))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

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
