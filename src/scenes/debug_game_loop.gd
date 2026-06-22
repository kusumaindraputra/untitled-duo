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

## Total number of floors in a single run. Exported so alternate launch scenes
## (e.g. demo.tscn) can shorten the run — when _current_floor reaches this value
## the floor's boss defeat ends the run as a win instead of advancing a floor.
@export var total_floors: int = 3

## Engine.time_scale applied during hit-stop (Gamefeel Audit Issue 2.2).
## 0.05 = near-freeze for ~0.06s real time; restores automatically via timer.
const _HIT_STOP_SCALE: float = 0.05
## Real-time duration range for hit-stop based on damage magnitude.
const _HIT_STOP_DURATION_MIN: float = 0.04
const _HIT_STOP_DURATION_MAX: float = 0.08

## Engine.time_scale during the death slow-mo beat (Gamefeel Audit Issue 5.1).
const _DEATH_SLOW_SCALE: float = 0.15
## Real-time duration of the slow-mo before the death overlay appears.
const _DEATH_SLOW_DURATION: float = 0.75

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

## Guards hit-stop from stacking during the death slow-mo sequence.
var _in_death_sequence: bool = false

## Title-screen CanvasLayer shown at boot before the run starts. Freed on Begin.
var _title_layer: CanvasLayer = null

## First-prep coaching overlay. Shown once on Begin, auto-freed when combat starts.
var _tutorial_layer: CanvasLayer = null

## Between-room reward system. Created in _ready(); offers a boon after each
## combat/elite room clear.
var _boon_manager: BoonManager = null

## Run-scoped transient bag of Prana acquired from post-room rewards, awaiting
## placement into the grid during the next prep phase. Created in _ready().
var _prana_bag: PranaBag = null

## Persistent 9-slot Prana build carried across rooms. Seeded with the core at run
## start; the per-room PranaGrid restores/saves it. Created in _ready().
var _prana_loadout: PranaLoadout = null

## Core-pick CanvasLayer shown after Begin, before the run starts. Freed on pick.
var _core_pick_layer: CanvasLayer = null

## Pause overlay CanvasLayer. Built on game_paused (ESC during play), freed on
## game_resumed. PROCESS_MODE_ALWAYS so its buttons stay live while the tree is paused.
var _pause_layer: CanvasLayer = null

## Rooms entered on the current floor (1-based) — drives the HUD "Room X / Y" breadcrumb.
var _rooms_entered: int = 1

func _ready() -> void:
	Engine.time_scale = 1.0  # reset from any prior slow-mo (scene reload via R key)
	_register_input_actions()
	_load_pool_configs()
	HealthAndDamage.heavy_hit.connect(_on_heavy_hit)

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
	hud.set_room_progress(_rooms_entered, _dungeon_graph.room_count())
	# Boss-intro UI: WaveManager announces boss spawns; HUD shows name card + HP bar.
	$WaveManager.boss_spawned.connect(hud._on_boss_spawned)
	# Pause overlay: GameStateManager drives the paused/resumed transitions; we just
	# build/free the overlay in response so ESC works from PREP and COMBAT alike.
	GameStateManager.game_paused.connect(_on_game_paused)
	GameStateManager.game_resumed.connect(_on_game_resumed)
	# Between-room boons: created here so both main.tscn and demo.tscn get it.
	_boon_manager = BoonManager.new()
	_boon_manager.name = "BoonManager"
	add_child(_boon_manager)
	# Transient reward bag: Prana picked from post-room rewards land here, then the
	# prep grid places them. Found by BoonManager (writer) + PranaGrid (reader) via group.
	_prana_bag = PranaBag.new()
	_prana_bag.name = "PranaBag"
	add_child(_prana_bag)
	# Persistent Prana build (carried across rooms by PranaLoadout, restored by the grid).
	_prana_loadout = PranaLoadout.new()
	_prana_loadout.name = "PranaLoadout"
	add_child(_prana_loadout)
	GameStateManager.reset_to_main_menu()
	GameStateManager.set_is_final_floor(_current_floor >= total_floors)
	GameStateManager.run_ended.connect(_on_run_ended)
	GameStateManager.wave_ended.connect(_on_wave_ended)
	GameStateManager.floor_completed.connect(_on_floor_completed)

	# The full scene (arena, player, HUD) is now wired and visible. Gate the run
	# behind a title card so the demo opens with context instead of dropping the
	# player straight into combat. start_run() is deferred until the player begins.
	_show_title_screen()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif event.keycode == KEY_R:
			Engine.time_scale = 1.0  # cancel slow-mo before reload
			get_tree().reload_current_scene()
		elif event.keycode == KEY_F1:
			# DEBUG QA: toggle god mode (blocks ALL incoming damage) for full-loop playtest
			HealthAndDamage._debug_god_mode = not HealthAndDamage._debug_god_mode
		elif event.keycode == KEY_F2:
			# DEBUG QA: instantly kill all enemies to advance wave/floor
			HealthAndDamage.debug_kill_all_enemies()
		elif event.keycode == KEY_F3:
			# DEBUG QA: force-advance to next room in dungeon graph
			var rtm: RoomTransitionManager = $RoomTransitionManager
			var next_rooms: Array[int] = _dungeon_graph.get_outgoing(rtm.get_current_room_idx())
			if next_rooms.is_empty():
				# No outgoing edges = boss room completed, advance floor
				GameStateManager.floor_completed.emit()
			else:
				rtm.request_transition(next_rooms[0])


# ── Title screen ──────────────────────────────────────────────────────────────

## Builds the demo title card over the already-wired scene and pauses the tree so
## Fayde stays put until the player begins. The overlay runs in PROCESS_MODE_ALWAYS
## so its Begin button stays interactive while the rest of the tree is paused.
## Reuses the CanvasLayer-overlay pattern from the end screen (_on_run_ended).
func _show_title_screen() -> void:
	get_tree().paused = true

	_title_layer = CanvasLayer.new()
	_title_layer.layer = 30
	_title_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.92)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_title_layer.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_layer.add_child(vbox)

	var title := Label.new()
	title.text = "THE LAST CIPHER"
	title.add_theme_font_size_override(&"font_size", 72)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _make_subtitle_text()
	subtitle.add_theme_font_size_override(&"font_size", 22)
	subtitle.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.78))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_make_spacer(40))

	var controls := Label.new()
	controls.text = "WASD  Move      Shift  Dash      Space  Cast      Enter  Confirm Loadout"
	controls.add_theme_font_size_override(&"font_size", 18)
	controls.add_theme_color_override(&"font_color", Color(0.6, 0.6, 0.66))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(controls)

	vbox.add_child(_make_spacer(48))

	var begin := Button.new()
	begin.text = "BEGIN RUN"
	begin.custom_minimum_size = Vector2(240, 56)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	begin.add_theme_font_size_override(&"font_size", 26)
	begin.pressed.connect(_begin_run)
	vbox.add_child(begin)

	add_child(_title_layer)
	# Focus the button so keyboard (Enter/Space) and gamepad (ui_accept) start the run.
	begin.grab_focus()


## Builds the title-card subtitle, adapting the goal text to the run length so
## the demo (single floor) doesn't promise "three floors".
func _make_subtitle_text() -> String:
	if total_floors <= 1:
		return "Arrange Prana. Cast. Defeat the floor boss."
	var words: Array[String] = ["one", "two", "three", "four", "five"]
	var count_word: String = words[total_floors - 1] if total_floors <= words.size() else str(total_floors)
	return "Arrange Prana. Cast. Survive %s floors." % count_word


## Adds a label|value row to the end-screen stat [param grid].
## Label is dim grey and left-aligned; value is bright and right-aligned.
func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override(&"font_size", 22)
	name_label.add_theme_color_override(&"font_color", Color(0.62, 0.62, 0.68))
	grid.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override(&"font_size", 22)
	value_label.add_theme_color_override(&"font_color", Color(1.0, 0.92, 0.7))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value_label)


## Formats [param seconds] as "M:SS" (e.g. 252.0 → "4:12").
func _format_run_time(seconds: float) -> String:
	var total: int = int(seconds)
	return "%d:%02d" % [total / 60, total % 60]


## Returns a fixed-height invisible spacer Control for VBox layout.
func _make_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


## Dismisses the title card, unpauses the tree, and starts the run.
## No-op if the title has already been dismissed (guards double-press).
func _begin_run() -> void:
	if _title_layer == null:
		return
	_title_layer.queue_free()
	_title_layer = null
	# Pick the core Prana before the run starts. The tree stays paused until a core
	# is chosen; _on_core_picked() seeds the loadout and starts the run.
	_show_core_pick()


## Builds the "choose your core Prana" overlay (5 element cards). Tree remains paused
## (PROCESS_MODE_ALWAYS overlay) until a card is picked.
func _show_core_pick() -> void:
	_core_pick_layer = CanvasLayer.new()
	_core_pick_layer.layer = 30
	_core_pick_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.95)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_core_pick_layer.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 18)
	_core_pick_layer.add_child(vbox)

	var title := Label.new()
	title.text = "CHOOSE YOUR CORE PRANA"
	title.add_theme_font_size_override(&"font_size", 38)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "It anchors the centre slot. Build the rest from room rewards."
	sub.add_theme_font_size_override(&"font_size", 18)
	sub.add_theme_color_override(&"font_color", Color(0.7, 0.7, 0.78))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	vbox.add_child(row)

	var first_button: Button = null
	for type_id in PranaTypeToken.TYPE_NAMES.size():
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 110)
		card.add_theme_font_size_override(&"font_size", 22)
		card.text = PranaTypeToken.TYPE_NAMES[type_id]
		if type_id < PranaTypeToken.TYPE_COLORS.size():
			card.add_theme_color_override(&"font_color", PranaTypeToken.TYPE_COLORS[type_id])
		var captured_id: int = type_id
		card.pressed.connect(func() -> void: _on_core_picked(captured_id))
		row.add_child(card)
		if first_button == null:
			first_button = card

	add_child(_core_pick_layer)
	if first_button != null:
		first_button.grab_focus()


## Seeds the loadout with the chosen core, dismisses the picker, and starts the run.
func _on_core_picked(type_id: int) -> void:
	if _prana_loadout != null:
		_prana_loadout.seed_core(type_id)
	if _core_pick_layer != null:
		_core_pick_layer.queue_free()
		_core_pick_layer = null
	get_tree().paused = false
	GameStateManager.start_run()
	_show_tutorial_overlay()


## Builds a one-time coaching panel on the LEFT (the Prana grid sits on the right,
## so it stays clear) explaining the core loop during the first Preparation phase.
## Non-blocking — the player can arrange while reading. Auto-dismisses when the
## first combat starts, or via the "Got it" button.
func _show_tutorial_overlay() -> void:
	_tutorial_layer = CanvasLayer.new()
	_tutorial_layer.layer = 25

	var panel := PanelContainer.new()
	panel.anchor_top = 0.5
	panel.offset_top = -150.0
	panel.offset_left = 24.0
	panel.add_theme_constant_override(&"margin_left", 18)
	panel.add_theme_constant_override(&"margin_right", 18)
	panel.add_theme_constant_override(&"margin_top", 14)
	panel.add_theme_constant_override(&"margin_bottom", 14)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.05, 0.04, 0.08, 0.92)
	pstyle.border_color = Color(1.0, 0.85, 0.4, 0.7)
	pstyle.set_border_width_all(2)
	pstyle.set_corner_radius_all(6)
	panel.add_theme_stylebox_override(&"panel", pstyle)
	_tutorial_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 8)
	panel.add_child(vbox)

	var heading := Label.new()
	heading.text = "HOW TO FIGHT"
	heading.add_theme_font_size_override(&"font_size", 22)
	heading.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(heading)

	var steps: Array[String] = [
		"1.  Your CORE Prana sits centre — it's your primary element.",
		"2.  Clear rooms to earn Prana, then add them to your grid.",
		"3.  3+ of one type = a stronger spell Tier.",
		"4.  Press ENTER to confirm, then SPACE to cast in battle.",
	]
	for line: String in steps:
		var step := Label.new()
		step.text = line
		step.add_theme_font_size_override(&"font_size", 16)
		step.add_theme_color_override(&"font_color", Color(0.82, 0.82, 0.88))
		vbox.add_child(step)

	var dismiss := Button.new()
	dismiss.text = "Got it"
	dismiss.add_theme_font_size_override(&"font_size", 16)
	dismiss.pressed.connect(_dismiss_tutorial)
	vbox.add_child(dismiss)

	add_child(_tutorial_layer)
	# Auto-dismiss the moment the player confirms their first loadout.
	GameStateManager.combat_started.connect(_dismiss_tutorial, CONNECT_ONE_SHOT)


## Frees the tutorial overlay if present. Safe to call multiple times.
func _dismiss_tutorial(_is_boss: bool = false) -> void:
	if _tutorial_layer != null:
		_tutorial_layer.queue_free()
		_tutorial_layer = null


# ── Pause ───────────────────────────────────────────────────────────────────

## ESC handler. Resumes if already paused, otherwise asks GameStateManager to pause.
## Ignored while the title/core-pick overlays are up (the tree is already paused there).
## pause_game() no-ops outside PREPARATION/COMBAT, so this is safe to call any time.
func _toggle_pause() -> void:
	if _title_layer != null or _core_pick_layer != null:
		return
	if _pause_layer != null:
		GameStateManager.resume_game()
	else:
		GameStateManager.pause_game()


## Builds the pause overlay in response to GameStateManager.game_paused.
## PROCESS_MODE_ALWAYS keeps the buttons interactive while the tree is paused.
func _on_game_paused() -> void:
	if _pause_layer != null:
		return
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 28
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06, 0.85)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_pause_layer.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 18)
	_pause_layer.add_child(vbox)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override(&"font_size", 56)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume := Button.new()
	resume.text = "Resume  (Esc)"
	resume.custom_minimum_size = Vector2(240, 52)
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.add_theme_font_size_override(&"font_size", 22)
	resume.pressed.connect(GameStateManager.resume_game)
	vbox.add_child(resume)

	var restart := Button.new()
	restart.text = "Restart Run  (R)"
	restart.custom_minimum_size = Vector2(240, 52)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.add_theme_font_size_override(&"font_size", 22)
	restart.pressed.connect(_restart_from_pause)
	vbox.add_child(restart)

	add_child(_pause_layer)
	resume.grab_focus()


## Frees the pause overlay in response to GameStateManager.game_resumed.
func _on_game_resumed() -> void:
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null


## Restart button: unpause, reset time scale, reload the scene for a fresh run.
func _restart_from_pause() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
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
	_rooms_entered += 1
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	hud.set_room_progress(_rooms_entered, _dungeon_graph.room_count())
	GameStateManager.restart_preparation()


## Configures WaveManager for the room at [param room_idx]: sets room_type and is_final_room.
## Also selects the per-room-type music track so boss/elite/rest rooms get their own
## cue instead of all playing mus_combat_floor. The override is applied before the
## room's combat_started fires, so AudioSystem crossfades the correct track in.
func _configure_wave_manager_for_room(room_idx: int) -> void:
	if _dungeon_graph == null:
		return
	var room: Dictionary = _dungeon_graph.get_room(room_idx)
	var rtype: int = room.get("type", DungeonGraph.ROOM_TYPE_COMBAT)
	$WaveManager.room_type = rtype
	$WaveManager.is_final_room = (rtype == DungeonGraph.ROOM_TYPE_BOSS)
	_select_room_music(rtype)


## Picks the combat-state music cue for [param rtype] via AudioSystem.
## Boss/elite/rest rooms each get a dedicated track; all other rooms reset to the
## default floor track. No-op if AudioSystem is unavailable (e.g. headless tests).
func _select_room_music(rtype: int) -> void:
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio == null or not audio.has_method(&"override_combat_cue"):
		return
	match rtype:
		DungeonGraph.ROOM_TYPE_BOSS:
			audio.override_combat_cue(&"mus_combat_boss")
		DungeonGraph.ROOM_TYPE_ELITE:
			audio.override_combat_cue(&"mus_combat_elite")
		DungeonGraph.ROOM_TYPE_REST:
			audio.override_combat_cue(&"mus_rest")
		_:
			audio.reset_combat_cue()

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
	# Reset to 0 so the entry-room transition of the new floor increments it back to 1.
	_rooms_entered = 0
	_dungeon_graph = _gen.generate(7, _current_floor)
	GameStateManager.set_is_final_floor(_current_floor >= total_floors)
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


## Death slow-mo: brief 0.15× time-scale window so the player can read the final
## board state before the overlay appears (Gamefeel Audit Issue 5.1).
## Uses ignore_time_scale=true so the timer ticks in real seconds regardless of time_scale.
func _on_run_ended(win: bool) -> void:
	if not win and not _in_death_sequence:
		_in_death_sequence = true
		Engine.time_scale = _DEATH_SLOW_SCALE
		await get_tree().create_timer(_DEATH_SLOW_DURATION, true, false, true).timeout
		Engine.time_scale = 1.0

	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null and audio.has_method(&"has_event"):
		var evt: StringName = &"sfx_run_win" if win else &"sfx_run_lose"
		if audio.has_event(evt):
			audio.play_event(evt)

	var run_data: Dictionary = RunManager.get_run_data()
	var floor_reached: int = run_data.get("current_floor", 1)
	var rooms_cleared: int = run_data.get("rooms_cleared", 0)
	var enemies_killed: int = run_data.get("enemies_killed", 0)
	var best_combo: int = run_data.get("best_combo", 0)
	var run_time_sec: float = run_data.get("run_time_sec", 0.0)

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
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	var subtitle := Label.new()
	subtitle.text = "Floor %d  ·  %d Room%s Cleared" % [floor_reached, rooms_cleared, "" if rooms_cleared == 1 else "s"]
	subtitle.add_theme_font_size_override(&"font_size", 26)
	subtitle.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.85))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	var stat_spacer := Control.new()
	stat_spacer.custom_minimum_size = Vector2(0, 22)
	vbox.add_child(stat_spacer)

	# Stat breakdown — a centered 2-column grid (label | value) for replay appeal.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override(&"h_separation", 36)
	grid.add_theme_constant_override(&"v_separation", 8)
	vbox.add_child(grid)
	_add_stat_row(grid, "Enemies Slain", str(enemies_killed))
	_add_stat_row(grid, "Best Combo", "x%d" % best_combo)
	_add_stat_row(grid, "Time", _format_run_time(run_time_sec))

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

	# Between-room reward: offer a boon after combat/elite clears (skip rest/boss).
	# wave_ended also fires in the boss room, but its room_type is BOSS so it's skipped.
	var rtype: int = $WaveManager.room_type
	if _boon_manager != null \
			and (rtype == DungeonGraph.ROOM_TYPE_COMBAT or rtype == DungeonGraph.ROOM_TYPE_ELITE):
		await get_tree().create_timer(0.5).timeout
		_boon_manager.offer_boons()


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
## Hit-stop: briefly freezes time on heavy hits so impacts feel weighty (Gamefeel Audit Issue 2.2).
## Guarded against re-entry during death slow-mo and while a hit-stop is already active.
## Uses ignore_time_scale=true timer so real-time duration is independent of time_scale.
func _on_heavy_hit(_target: Node, final_damage: int) -> void:
	if Engine.time_scale < 0.5 or _in_death_sequence:
		return
	var duration: float = lerpf(
		_HIT_STOP_DURATION_MIN, _HIT_STOP_DURATION_MAX,
		clampf((float(final_damage) - float(HealthAndDamage.HEAVY_HIT_THRESHOLD)) / 30.0, 0.0, 1.0)
	)
	Engine.time_scale = _HIT_STOP_SCALE
	await get_tree().create_timer(duration, true, false, true).timeout
	if not _in_death_sequence:  # death slow-mo may have started while we awaited
		Engine.time_scale = 1.0


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
