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
## ADR-0042 juice timings (combat dim, crumple pose).
const _JUICE: HudJuiceTuning = preload("res://assets/data/hud_juice_tuning.tres")

## Whole-number scale for the Prana shape icon on a core-pick card (48 px, ADR-0036).
const CORE_PICK_ICON_SCALE: int = 4

## Paths to per-floor enemy pool configs. Index 0 = floor 1, etc.
const _FLOOR_POOL_PATHS: Array[String] = [
	"res://assets/data/enemy_pool_configs/enemy_pool_floor1.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_floor2.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_floor3.tres",
]
## Per-floor boss pool paths. F1=Sentinel, F2=WarpedWarden mid-boss, F3=Sentinel
## (its own config so the ADR-0019 difficulty curve can push it harder than F1).
## Per-floor identity (ADR-0020): template pools, floor tint, pillar colour.
const _FLOOR_THEME_PATHS: Array[String] = [
	"res://assets/data/floor_themes/floor_theme_1.tres",
	"res://assets/data/floor_themes/floor_theme_2.tres",
	"res://assets/data/floor_themes/floor_theme_3.tres",
]
const _BOSS_POOL_PATHS: Array[String] = [
	"res://assets/data/enemy_pool_configs/enemy_pool_boss.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_boss_f2.tres",
	"res://assets/data/enemy_pool_configs/enemy_pool_boss_f3.tres",
]

const _META: MetaTuning = preload("res://assets/data/meta_tuning.tres")
## ADR-0033 — the Cipher Cores offered on the core-pick screen.
const _CORES: CoreRoster = preload("res://assets/data/cores/core_roster.tres")
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")
## ADR-0055: coach hints the guided first room already teaches (tiers ride on the
## "place" lesson), ticked quietly when the coach takes over after the room.
const TUTORIAL_ROOM_COVERS: Array[StringName] = [
	&"confirm", &"move", &"cast", &"dash", &"tiers", &"perfect_dodge",
]

## Where between-run progress is read and written (ADR-0025).
var progress_path: String = MetaProgress.DEFAULT_PATH
## ADR-0048: where the run in progress is saved at each room start, and where
## finished runs are logged for playtests. Tests point these at temp files.
var run_save_path: String = RunSave.DEFAULT_PATH
var run_log_path: String = RunLog.DEFAULT_PATH
## Between-run progress: Heirloom, Hard Mode, shard payout at run end.
var _meta: MetaProgress = null
## Guards the shard payout so a run is only recorded once.
var _run_recorded: bool = false
## In-combat tutorial checklist; null once completed or when already done.
var _coach: TutorialCoach = null
## ADR-0055 guided first room; null outside the first run's first room.
var _tutorial_room: TutorialRoom = null

var _dungeon_graph: DungeonGraph = null
var _gen: DungeonGenerator = DungeonGenerator.new()
var _current_floor: int = 1
## Rooms in the current floor's graph, from its FloorTheme. 7 if the theme is missing.
var _floor_room_count: int = 7
var _floor_pool_configs: Array[EnemyPoolConfig] = []
var _boss_pool_configs: Array[EnemyPoolConfig] = []
## ADR-0026 room variety: the floor's combat pool before any Cursed tweak, the
## current room's RoomModifiers value, whether Fayde is unhit in it, and the bonus
## Cipher Shards earned by flawless Challenge rooms this run.
var _base_combat_cfg: EnemyPoolConfig = null
var _room_modifier: int = RoomModifiers.NONE
var _room_flawless: bool = true
var _bonus_shards: int = 0
## ADR-0046 corner toasts for sigils, memories and shards gained mid-run.
var _toaster: HudToaster = null
var _room_rng := RandomNumberGenerator.new()

## Guards hit-stop from stacking during the death slow-mo sequence.
var _in_death_sequence: bool = false
## ADR-0042: the Prana colour in Fayde's hands when she fell, for the defeat screen.
var _last_prana_color: Color = UIPalette.ACCENT

## Title-screen CanvasLayer shown at boot before the run starts. Freed on Begin.
var _title_layer: CanvasLayer = null

## Between-room reward system. Created in _ready(); offers a sigil after each
## combat/elite room clear.
var _sigil_manager: SigilManager = null

## Fast-pace layer (ADR-0019). Created in _ready(), wired to the player and HUD there.
var _pace_director: PaceDirector = null
## ADR-0041 — boss death beat; reward screens wait for it.
var _boss_cinematic: BossDeathCinematic = null
## ADR-0041 — CLEAR banner and slow-mo when a room is cleared.
var _room_clear_moment: RoomClearMoment = null
var _sigil_effects: SigilEffects = null
var _boss_director: BossDirector = null
## ADR-0028 — seed of this run; picks each floor boss's variant.
var _run_seed: int = 0

## Run-scoped transient bag of Prana acquired from post-room rewards, awaiting
## placement into the grid during the next prep phase. Created in _ready().
var _prana_bag: PranaBag = null

## Persistent 9-slot Prana build carried across rooms. Seeded with the core at run
## start; the per-room PranaGrid restores/saves it. Created in _ready().
var _prana_loadout: PranaLoadout = null

## Core-pick CanvasLayer shown after Begin, before the run starts. Freed on pick.
var _core_pick_layer: CanvasLayer = null
## ADR-0033 — the Cipher Core highlighted on the pick screen, and the one this run uses
## (null until the run starts).
var _selected_core: CoreFrame = null
var _core: CoreFrame = null

## Pause overlay CanvasLayer. Built on game_paused (ESC during play), freed on
## game_resumed. PROCESS_MODE_ALWAYS so its buttons stay live while the tree is paused.
var _pause_layer: CanvasLayer = null

## Rooms entered on the current floor (1-based) — drives the HUD "Room X / Y" breadcrumb.
var _rooms_entered: int = 1
## U5 run summary log: room ranks, sigil titles, floors cleared, memories at run start.
var _run_ranks: Array[String] = []
var _run_sigils: Array[Dictionary] = []
var _floors_cleared: int = 0
var _fragments_at_start: int = 0
## True once any Assist option was on during this run (F2); marks the summary.
var _assist_used: bool = false
## F3 records: game time since the current boss spawned, and records set this run.
var _boss_elapsed: float = 0.0
var _boss_timing: bool = false
var _new_records: Array[String] = []
## ADR-0048 run save and playtest log: non-Prana sigil ids in the order taken (replayed
## on resume), each fight's build, spells cast, times this run was resumed, and a
## guard so a run is logged once.
var _applied_sigils: Array[String] = []
var _log_builds: Array[Dictionary] = []
var _casts: int = 0
var _resumes: int = 0
var _run_logged: bool = false
## True while a resumed run replays its sigils, so they don't toast again.
var _replaying_sigils: bool = false

func _ready() -> void:
	_apply_assist()  # also resets Engine.time_scale from any prior slow-mo (reload via R)
	_register_input_actions()
	_meta = MetaProgress.load_from(progress_path)
	_fragments_at_start = _meta.fragments_found
	GameSettings.active().apply_display_once()
	_load_pool_configs()
	HealthAndDamage.heavy_hit.connect(_on_heavy_hit)
	HealthAndDamage.damage_taken.connect(_on_damage_taken)

	# Tell SceneManager about the initial room already in main.tscn so the first
	# room transition correctly frees it instead of leaving a duplicate.
	SceneManager.set_initial_scene($SubSceneRoot/IsometricRoom)

	# Generate floor 1 and give it to RoomTransitionManager.
	var rtm: RoomTransitionManager = $RoomTransitionManager
	_apply_floor_theme(rtm)
	_dungeon_graph = _gen.generate(_floor_room_count, _current_floor)
	_room_rng.randomize()
	_run_seed = int(_room_rng.seed)
	RoomModifiers.assign(_dungeon_graph, _room_rng)
	rtm.setup(_dungeon_graph)
	rtm.room_transition_completed.connect(_on_room_transitioned)

	_apply_floor_pool_config()

	# Wire initial room: spawn markers + exit doors + room type flags.
	var initial_room: IsometricRoom = $SubSceneRoot/IsometricRoom
	# ADR-0038: main.tscn builds this room before the floor theme is known.
	if rtm.floor_theme != null:
		initial_room.apply_floor_look(rtm.floor_theme)
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
	hud.set_room_progress(_rooms_entered, PathBuilder.rooms_per_run(_dungeon_graph))
	_update_minimap()
	# Edge arrows for off-screen enemies (combat camera shows less than the room).
	# Index 0 on the HUD layer so HUD panels draw over the arrows.
	var indicators := OffscreenIndicators.new()
	indicators.name = "OffscreenIndicators"
	indicators.player = $PlayerController
	$CanvasLayer.add_child(indicators)
	$CanvasLayer.move_child(indicators, 0)
	# ADR-0046: corner toasts and the optional run clock, beside the HUD.
	_toaster = HudToaster.new()
	_toaster.name = "HudToaster"
	$CanvasLayer.add_child(_toaster)
	var run_timer := RunTimerLabel.new()
	run_timer.name = "RunTimer"
	run_timer.clock = RunManager.get_elapsed_sec
	$CanvasLayer.add_child(run_timer)
	_toaster.bottom_inset = run_timer.corner_height
	# Boss-intro UI: WaveManager announces boss spawns; HUD shows name card + HP bar.
	$WaveManager.boss_spawned.connect(hud._on_boss_spawned)
	# ADR-0028: every floor boss changes the arena at each phase, and each plays one
	# of its variants, picked once per run from the run seed.
	$WaveManager.boss_variants = BossDirector.ROSTER.pick_all(_run_seed)
	_boss_director = BossDirector.new()
	_boss_director.name = "BossDirector"
	_boss_director.hud = hud
	add_child(_boss_director)
	$WaveManager.boss_spawned.connect(func(boss: Node) -> void:
		_boss_director.attach(boss, SceneManager.get_current_scene() as Node2D))
	$WaveManager.boss_spawned.connect(func(_boss: Node) -> void:
		_boss_elapsed = 0.0
		_boss_timing = true)
	# Pause overlay: GameStateManager drives the paused/resumed transitions; we just
	# build/free the overlay in response so ESC works from PREP and COMBAT alike.
	GameStateManager.game_paused.connect(_on_game_paused)
	GameStateManager.game_resumed.connect(_on_game_resumed)
	# Between-room sigils: created here so both main.tscn and demo.tscn get it.
	_sigil_manager = SigilManager.new()
	_sigil_manager.name = "SigilManager"
	add_child(_sigil_manager)
	# ADR-0019 fast-pace layer: Perfect Dodge, kill orbs, style rank, kill hitstop.
	# Wired here (parent _ready) because it needs both the player and the HUD.
	_pace_director = PaceDirector.new()
	_pace_director.name = "PaceDirector"
	add_child(_pace_director)
	_pace_director.set_player($PlayerController)
	_pace_director.style_changed.connect(hud.set_style)
	_pace_director.room_ranked.connect(hud.show_room_rank)
	_pace_director.room_ranked.connect(_log_room_rank)
	_pace_director.perfect_dodge_triggered.connect(hud.show_perfect_dodge)
	# ADR-0031 rumble for big moves (impacts rumble through camera trauma).
	_pace_director.perfect_dodge_triggered.connect(Rumble.on_perfect_dodge)
	if not SpellCastingEffects.special_fired.is_connected(Rumble.on_special_fired):
		SpellCastingEffects.special_fired.connect(Rumble.on_special_fired)
	# ADR-0041 big moments: the boss death cinematic and the room clear payoff.
	# Wired here because the room clear needs the WaveManager and the HUD layer.
	_boss_cinematic = BossDeathCinematic.new()
	_boss_cinematic.name = "BossDeathCinematic"
	add_child(_boss_cinematic)
	_room_clear_moment = RoomClearMoment.new()
	_room_clear_moment.name = "RoomClearMoment"
	_room_clear_moment.wave_manager = $WaveManager
	_room_clear_moment.banner_layer = $CanvasLayer
	add_child(_room_clear_moment)
	# ADR-0026 behaviour sigils: effects hang off gameplay signals; SigilManager adds stacks.
	_sigil_effects = SigilEffects.new()
	_sigil_effects.name = "SigilEffects"
	_sigil_effects.player = $PlayerController
	add_child(_sigil_effects)
	_sigil_manager.effects = _sigil_effects
	_sigil_manager.sigil_applied.connect(_log_sigil)
	# ADR-0045: a behaviour sigil's chip lights up on the HUD when it fires.
	_sigil_effects.effect_fired.connect(func(id: StringName, _pos: Vector2) -> void:
		hud.get_sigil_strip().pulse(id))
	# F1 Spellbook: the build cast each room and every enemy type defeated.
	GameStateManager.combat_started.connect(_log_build_discoveries)
	# ADR-0042: the room's ambient dims at wave start and lifts once the fight is over.
	GameStateManager.combat_started.connect(_on_combat_dim_in)
	GameStateManager.room_cleared.connect(_on_combat_dim_out)
	GameStateManager.wave_ended.connect(_on_combat_dim_out)
	HealthAndDamage.enemy_killed.connect(_log_enemy_discovery)
	_pace_director.perfect_dodge_triggered.connect(_sigil_effects.on_perfect_dodge)
	# Transient reward bag: Prana picked from post-room rewards land here, then the
	# prep grid places them. Found by SigilManager (writer) + PranaGrid (reader) via group.
	_prana_bag = PranaBag.new()
	_prana_bag.name = "PranaBag"
	add_child(_prana_bag)
	# Persistent Prana build (carried across rooms by PranaLoadout, restored by the grid).
	_prana_loadout = PranaLoadout.new()
	_prana_loadout.name = "PranaLoadout"
	add_child(_prana_loadout)
	# ADR-0055: Prana dropped in the bag while the grid is open show up in its tray.
	var grid: PranaGrid = get_tree().get_first_node_in_group(&"prana_grid") as PranaGrid
	if grid != null:
		_prana_bag.bag_changed.connect(grid.on_bag_changed)
	GameStateManager.reset_to_main_menu()
	GameStateManager.set_is_final_floor(_current_floor >= total_floors)
	GameStateManager.run_ended.connect(_on_run_ended)
	GameStateManager.wave_ended.connect(_on_wave_ended)
	GameStateManager.floor_completed.connect(_on_floor_completed)
	SpellCastingEffects.cast_started.connect(_on_cast_started)

	# ADR-0048: Continue on the main menu resumes the saved run at its last room.
	if RunSave.take_resume_request():
		var saved: Dictionary = RunSave.read(run_save_path)
		if not saved.is_empty() and int(saved["total_floors"]) == total_floors:
			_resume_run(saved)
			return

	# The full scene (arena, player, HUD) is now wired and visible. Gate the run
	# behind a title card so the demo opens with context instead of dropping the
	# player straight into combat. start_run() is deferred until the player begins.
	_show_title_screen()


func _input(event: InputEvent) -> void:
	# U8: Start pauses / resumes on a gamepad, like Esc on the keyboard.
	var joy := event as InputEventJoypadButton
	if joy != null and joy.pressed and joy.button_index == JOY_BUTTON_START:
		_toggle_pause()
		return
	if event is InputEventKey and not event.echo and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()
		elif event.keycode == KEY_R:
			_restart_from_pause()
		elif OS.is_debug_build() and event.keycode == KEY_F1:
			# DEBUG QA: toggle god mode (blocks ALL incoming damage) for full-loop playtest.
			# Gated to debug builds so an exported demo build can't trip these by accident.
			HealthAndDamage._debug_god_mode = not HealthAndDamage._debug_god_mode
		elif OS.is_debug_build() and event.keycode == KEY_F2:
			# DEBUG QA: instantly kill all enemies to advance wave/floor (debug builds only).
			HealthAndDamage.debug_kill_all_enemies()
		elif OS.is_debug_build() and event.keycode == KEY_F3:
			# DEBUG QA: force-advance to next room in dungeon graph (debug builds only).
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
	title.text = _COPY.menu_title
	title.add_theme_font_size_override(&"font_size", 72)
	title.add_theme_color_override(&"font_color", UIPalette.ACCENT)
	title.add_child(TitleGlow.new())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = _make_subtitle_text()
	subtitle.add_theme_font_size_override(&"font_size", 22)
	subtitle.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)

	vbox.add_child(_make_spacer(40))

	var controls := Label.new()
	controls.text = _title_controls_text()
	InputPrompts.device_changed.connect(func(_pad: bool) -> void:
		if is_instance_valid(controls):
			controls.text = _title_controls_text())
	controls.add_theme_font_size_override(&"font_size", 18)
	controls.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
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

	vbox.add_child(_make_spacer(12))

	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(240, 44)
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.add_theme_font_size_override(&"font_size", 20)
	quit.pressed.connect(_quit_game)
	vbox.add_child(quit)

	add_child(_title_layer)
	# Focus the button so keyboard (Enter/Space) and gamepad (ui_accept) start the run.
	begin.grab_focus()


## Quits the game. Web/exported builds honour this; in the editor it stops the run.
func _quit_game() -> void:
	_save_progress()
	get_tree().quit()


## Returns to the main menu scene. Unpauses and resets time scale first so the menu
## (and any subsequent run) starts from a clean state.
func _to_main_menu() -> void:
	_save_progress()
	HealthAndDamage.player_damage_mult = 1.0
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://src/scenes/MainMenu.tscn")


## Builds the title-card subtitle, adapting the goal text to the run length so
## the demo (single floor) doesn't promise "three floors".
func _make_subtitle_text() -> String:
	if total_floors <= 1:
		return "Arrange Prana. Cast. Defeat the floor boss."
	var words: Array[String] = ["one", "two", "three", "four", "five"]
	var count_word: String = words[total_floors - 1] if total_floors <= words.size() else str(total_floors)
	return "Arrange Prana. Cast. Survive %s floors." % count_word


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


## Builds the core-pick overlay: a Cipher Core row (ADR-0033, a run-long passive) above
## the 5 core Prana cards. Picking a Prana starts the run with the highlighted Core.
## Tree remains paused (PROCESS_MODE_ALWAYS overlay) until a Prana is picked.
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
	vbox.add_theme_constant_override(&"separation", 14)
	_core_pick_layer.add_child(vbox)

	var title := Label.new()
	title.text = _COPY.core_pick_heading
	title.add_theme_font_size_override(&"font_size", 38)
	title.add_theme_color_override(&"font_color", UIPalette.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var heirloom: StringName = _meta.run_heirloom() if _meta != null else &""
	if heirloom != &"":
		var info: Dictionary = MetaProgress.heirloom_info(heirloom)
		var hl := Label.new()
		hl.text = _COPY.heirloom_active_format % str(info.get("title", heirloom))
		hl.add_theme_font_size_override(&"font_size", 18)
		hl.add_theme_color_override(&"font_color", UIPalette.ACCENT)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(hl)

	vbox.add_child(_make_pick_label(_COPY.core_pick_core_label))
	var core_row := HBoxContainer.new()
	core_row.alignment = BoxContainer.ALIGNMENT_CENTER
	core_row.add_theme_constant_override(&"separation", 12)
	vbox.add_child(core_row)
	var core_desc := Label.new()
	core_desc.add_theme_font_size_override(&"font_size", 18)
	core_desc.add_theme_color_override(&"font_color", UIPalette.TEXT)
	core_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_desc.custom_minimum_size = Vector2(0, 28)
	vbox.add_child(core_desc)

	var last_id: StringName = _meta.last_core if _meta != null else &""
	_selected_core = _CORES.get_core(last_id)
	var group := ButtonGroup.new()
	for v: Variant in _CORES.cores:  # a const-preloaded typed array iterates as Variant
		var core: CoreFrame = v as CoreFrame
		var btn := Button.new()
		btn.toggle_mode = true
		btn.button_group = group
		btn.custom_minimum_size = Vector2(170, 52)
		btn.add_theme_font_size_override(&"font_size", 20)
		btn.text = _core_title(core)
		btn.add_theme_color_override(&"font_color", core.accent)
		btn.add_theme_color_override(&"font_pressed_color", Color(1.0, 0.95, 0.7))
		btn.button_pressed = core == _selected_core
		var captured: CoreFrame = core
		btn.pressed.connect(func() -> void:
			_selected_core = captured
			core_desc.text = _core_desc(captured))
		btn.focus_entered.connect(func() -> void: core_desc.text = _core_desc(captured))
		btn.focus_exited.connect(func() -> void: core_desc.text = _core_desc(_selected_core))
		core_row.add_child(btn)
	core_desc.text = _core_desc(_selected_core)

	vbox.add_child(_make_spacer(6))
	vbox.add_child(_make_pick_label(_COPY.core_pick_prana_label))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 14)
	vbox.add_child(row)

	var first_button: Button = null
	for type_id in PranaTypeToken.type_count():
		var card := Button.new()
		card.custom_minimum_size = Vector2(150, 110)
		card.add_theme_font_size_override(&"font_size", 22)
		card.text = PranaTypeToken.type_abbrev(type_id)
		card.add_theme_color_override(&"font_color", PranaTypeToken.type_color(type_id))
		# Shape icon above the name so the pick reads without colour (ADR-0036).
		PranaIcon.apply_to_button(card, type_id, CORE_PICK_ICON_SCALE)
		card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		var captured_id: int = type_id
		card.pressed.connect(func() -> void: _on_core_picked(captured_id))
		row.add_child(card)
		if first_button == null:
			first_button = card

	add_child(_core_pick_layer)
	if first_button != null:
		first_button.grab_focus()


## A centred section label on the core-pick screen.
func _make_pick_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", 18)
	label.add_theme_color_override(&"font_color", UIPalette.TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Player-facing name and passive of [param core] (UICopy, by id).
func _core_title(core: CoreFrame) -> String:
	return str(_COPY.core_titles.get(String(core.id), core.id)) if core != null else ""


func _core_desc(core: CoreFrame) -> String:
	return str(_COPY.core_descs.get(String(core.id), "")) if core != null else ""


## Seeds the loadout with the chosen core, dismisses the picker, and starts the run
## with the highlighted Cipher Core (ADR-0033; the default Core when none was shown).
func _on_core_picked(type_id: int) -> void:
	if _prana_loadout != null:
		_prana_loadout.seed_core(type_id)
	if _core_pick_layer != null:
		_core_pick_layer.queue_free()
		_core_pick_layer = null
	get_tree().paused = false
	# ADR-0055: the first run's first room holds its wave back for the lessons.
	var guided: bool = _wants_tutorial_room()
	$WaveManager.hold_wave = guided
	GameStateManager.start_run()
	_start_core()
	# ADR-0025: the equipped Heirloom is a stat sigil granted before the first room.
	if _meta != null and _sigil_manager != null and _meta.run_heirloom() != &"":
		_sigil_manager.apply_sigil(_meta.run_heirloom())
	$CanvasLayer/CombatHUD.show_floor_intro(_current_floor)
	if guided:
		_start_tutorial_room(type_id)
	elif _meta == null or not _meta.tutorial_done:
		_start_coach()
	_write_run_save()


## ADR-0033: applies the run's Cipher Core after run_started reset the run state, and
## remembers the pick for the next run.
func _start_core() -> void:
	_core = _selected_core if _selected_core != null else _CORES.default_core()
	if _core == null:
		return
	_core.apply($PlayerController, SpellCastingEffects, _sigil_manager)
	_apply_assist()
	var strip: SigilStrip = ($CanvasLayer/CombatHUD as CombatHUD).get_sigil_strip()
	strip.reset()  # ADR-0045: the Core heads the HUD chip strip.
	strip.set_core(_core.id, _core_title(_core), _core.accent)
	if _meta != null and _meta.last_core != _core.id:
		_meta.last_core = _core.id
		_meta.save_to(progress_path)


## Spawns the tutorial hints (ADR-0031) and wires them to the moves they teach.
## No-op when one is already running.
func _start_coach() -> void:
	if is_instance_valid(_coach):
		return
	_coach = TutorialCoach.new()
	_coach.name = "TutorialCoach"
	_coach.player = $PlayerController
	$CanvasLayer.add_child(_coach)
	SpellCastingEffects.cast_started.connect(_coach.on_cast_started)
	SpellCastingEffects.perfect_cast.connect(_coach.on_perfect_cast)
	SpellCastingEffects.special_fired.connect(_coach.on_special_fired)
	_pace_director.perfect_dodge_triggered.connect(_coach.on_perfect_dodge)
	GameStateManager.combat_started.connect(_coach.on_combat_started)
	_coach.completed.connect(_on_coach_completed)


## ADR-0055: true when this run should open with the guided first room.
func _wants_tutorial_room() -> bool:
	return _meta != null and not _meta.tutorial_room_done and _current_floor == 1


## ADR-0055: starts the guided lessons in the room Fayde is standing in. The parent
## owns the wiring: lesson Prana into the bag, the lesson card on the HUD layer, the
## room's spawn markers as target spots, and every signal the lessons listen to.
func _start_tutorial_room(core_type_id: int) -> void:
	if is_instance_valid(_tutorial_room):
		return
	var room: Node2D = SceneManager.get_current_scene() as Node2D
	_tutorial_room = TutorialRoom.new()
	_tutorial_room.name = "TutorialRoom"
	_tutorial_room.player = $PlayerController
	if room != null:
		var entities: Node2D = room.get_node_or_null(^"EntityLayer") as Node2D
		_tutorial_room.arena = entities if entities != null else room
	var markers: Node = $WaveManager.spawn_points_container
	if markers != null:
		for m: Node in markers.get_children():
			if m is Node2D:
				_tutorial_room.spots.append((m as Node2D).global_position)
	var panel := TutorialRoomPanel.new()
	panel.name = "TutorialRoomPanel"
	$CanvasLayer.add_child(panel)
	_tutorial_room.panel = panel
	add_child(_tutorial_room)
	GameStateManager.combat_started.connect(_tutorial_room.on_combat_started)
	HealthAndDamage.damage_taken.connect(_tutorial_room.on_damage_taken)
	_pace_director.perfect_dodge_triggered.connect(_tutorial_room.on_perfect_dodge)
	_prana_bag.bag_changed.connect(_tutorial_room.on_bag_changed)
	_tutorial_room.finished.connect(_on_tutorial_room_finished)
	for i: int in TutorialRoom.TUNING.bag_prana:
		_prana_bag.add(core_type_id)


## ADR-0055: leaving the room mid-lesson (debug room skip, perf probe, balance bot)
## drops the lessons without saving and stops holding waves. Players cannot leave:
## the doors stay shut until the room's wave is cleared.
func _cancel_tutorial_room() -> void:
	if not is_instance_valid(_tutorial_room):
		return
	var tut: TutorialRoom = _tutorial_room
	_tutorial_room = null
	if GameStateManager.combat_started.is_connected(tut.on_combat_started):
		GameStateManager.combat_started.disconnect(tut.on_combat_started)
	if HealthAndDamage.damage_taken.is_connected(tut.on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(tut.on_damage_taken)
	tut.cancel()
	tut.queue_free()
	$WaveManager.hold_wave = false


## ADR-0055: the lessons ended. Saves the flags, unhooks the lessons and lets the
## room's wave in: at once when skipped, after the "training complete" line otherwise.
func _on_tutorial_room_finished(skipped: bool) -> void:
	if _meta != null:
		_meta.tutorial_room_done = true
		if skipped:
			_meta.tutorial_done = true
		_meta.save_to(progress_path)
	var tut: TutorialRoom = _tutorial_room
	if GameStateManager.combat_started.is_connected(tut.on_combat_started):
		GameStateManager.combat_started.disconnect(tut.on_combat_started)
	if HealthAndDamage.damage_taken.is_connected(tut.on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(tut.on_damage_taken)
	tut.queue_free()
	_tutorial_room = null
	if skipped:
		_release_tutorial_wave(true)
	else:
		# Pausable timer: the wave waits for the card, and for the player in the pause menu.
		get_tree().create_timer(TutorialRoom.TUNING.done_hold_sec + 0.45, false) \
			.timeout.connect(_release_tutorial_wave.bind(false))


## ADR-0055: spawns the held wave (or shows its preview while the grid is open) and,
## after a finished lesson run, hands over to the coach for the advanced hints.
func _release_tutorial_wave(skipped: bool) -> void:
	$WaveManager.release_wave()
	if GameStateManager.get_active_state() == GameEnums.GameState.COMBAT_PHASE:
		_pace_director.style.begin_room()  # the lessons don't count toward the room rank
		($CanvasLayer/CombatHUD as CombatHUD).show_room_banner(_COPY.tutorial_now_real,
			UIPalette.ACCENT)
	if skipped or (_meta != null and _meta.tutorial_done):
		return
	_start_coach()
	_coach.pretick(TUTORIAL_ROOM_COVERS)


## Marks the tutorial done in the saved progress so later runs skip it.
func _on_coach_completed() -> void:
	if _meta != null:
		_meta.tutorial_done = true
		_meta.save_to(progress_path)


## Pause-menu action: clears the saved flag and shows the coach again.
func _replay_tutorial() -> void:
	if _meta != null:
		_meta.tutorial_done = false
		_meta.tutorial_room_done = false  # ADR-0055: the next run opens with the lessons
		_meta.save_to(progress_path)
	if is_instance_valid(_tutorial_room):
		GameStateManager.resume_game()
		return
	if is_instance_valid(_coach):
		_coach.queue_free()
		_coach = null
	_start_coach()
	GameStateManager.resume_game()


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


## Title-card controls for the last-used device (U8): moves and actions, then the grid.
func _title_controls_text() -> String:
	return InputPrompts.controls_line() + "\n" + InputPrompts.pick(_COPY.grid_controls_kb, _COPY.grid_controls_pad)


## Builds the pause overlay (PausePanel, U6) in response to GameStateManager.game_paused.
## PROCESS_MODE_ALWAYS keeps the buttons interactive while the tree is paused.
func _on_game_paused() -> void:
	if _pause_layer != null:
		return
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 28
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PausePanel.new()
	_pause_layer.add_child(panel)
	panel.setup(_build_pause_data())
	panel.resume_pressed.connect(GameStateManager.resume_game)
	panel.restart_pressed.connect(_restart_from_pause)
	panel.tutorial_pressed.connect(_replay_tutorial)
	panel.spellbook_pressed.connect(func() -> void:
		panel.menu_box.visible = false
		var book := SpellbookPanel.new()
		book.progress = _meta if _meta != null else MetaProgress.new()
		book.closed.connect(func() -> void:
			panel.menu_box.visible = true
			panel.spellbook_button.grab_focus())
		_pause_layer.add_child(book))
	panel.main_menu_pressed.connect(_to_main_menu)
	panel.quit_pressed.connect(_quit_game)
	# ADR-0026: volume, display, comfort and keys live in the Settings panel.
	panel.settings_pressed.connect(func() -> void:
		panel.menu_box.visible = false
		var settings := SettingsPanel.new()
		settings.closed.connect(func() -> void:
			panel.menu_box.visible = true
			panel.settings_button.grab_focus())
		_pause_layer.add_child(settings))
	add_child(_pause_layer)
	panel.resume_button.grab_focus()


## Data for the pause build view: the live grid, its spell card and the sigils taken.
func _build_pause_data() -> Dictionary:
	var sigils: Array[Dictionary] = []
	if _core != null:  # ADR-0033: the run's Core heads the build list.
		sigils.append({"title": _COPY.core_active_format % _core_title(_core), "desc": _core_desc(_core)})
	sigils.append_array(_run_sigils)
	var data: Dictionary = {"sigils": sigils, "abbrevs": _COPY.type_abbrevs}
	var grid: PranaGrid = get_tree().get_first_node_in_group(&"prana_grid") as PranaGrid
	if grid != null:
		data["grid"] = grid.get_slot_types()
		data["spell_card"] = grid.build_spell_card()
		data["colors"] = grid.get_type_colors()
	var hud: CombatHUD = get_node_or_null(^"CanvasLayer/CombatHUD") as CombatHUD
	if hud != null:
		data["map"] = hud.get_floor_map_data()
	return data


## Frees the pause overlay in response to GameStateManager.game_resumed.
func _on_game_resumed() -> void:
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null
	_apply_assist()  # Settings may have changed while paused


## Applies the Assist options (F2): damage share, game speed and auto-dash. Called at
## run start and after pause, since Settings can change them mid-run.
func _apply_assist() -> void:
	var s: GameSettings = GameSettings.active()
	_assist_used = _assist_used or s.assist_active()
	# ADR-0033: the Core's damage-taken share stacks with the Assist share.
	var core_share: float = _core.damage_taken_mult if _core != null else 1.0
	HealthAndDamage.player_damage_mult = s.effective_damage() * core_share
	# ADR-0052: Ascension can cut healing.
	HealthAndDamage.player_heal_mult = _ascension_level().heal_mult
	var pc: Node = get_node_or_null(^"PlayerController")
	if pc != null and &"auto_dash" in pc:
		pc.set(&"auto_dash", s.effective_auto_dash())
	if not _in_death_sequence:
		Engine.time_scale = GameSettings.base_time_scale()


## Restart button: unpause, reset time scale, reload the scene for a fresh run.
func _restart_from_pause() -> void:
	# ADR-0048: Restart abandons the run, so its save goes and the log notes it.
	if _run_in_progress():
		_log_run(RunLog.OUTCOME_ABANDONED, RunManager.snapshot())
	RunSave.clear(run_save_path)
	_save_progress()
	get_tree().paused = false
	Engine.time_scale = GameSettings.base_time_scale()
	get_tree().reload_current_scene()


# ── Private ───────────────────────────────────────────────────────────────────

## ADR-0042 (art bible §2.3): a 0.3 s ambient dim marks "thinking" → "fighting".
func _on_combat_dim_in(_is_boss: bool) -> void:
	var room := SceneManager.get_current_scene() as IsometricRoom
	if room != null:
		room.set_combat_dim(_JUICE.combat_dim, _JUICE.dim_in_sec)


## ADR-0042: the room brightens again when the wave or the room is over.
func _on_combat_dim_out() -> void:
	var room := SceneManager.get_current_scene() as IsometricRoom
	if room != null:
		room.set_combat_dim(0.0, _JUICE.dim_out_sec)


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
	_cancel_tutorial_room()
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	hud.set_room_progress(_rooms_entered, PathBuilder.rooms_per_run(_dungeon_graph))
	_update_minimap()
	GameStateManager.restart_preparation()
	_write_run_save()


## Pushes the current floor's room layout to the HUD minimap. Builds plain type/state
## arrays from the graph (no graph reference leaks into the HUD) and marks the room the
## player currently occupies. No-op before the graph exists.
func _update_minimap() -> void:
	if _dungeon_graph == null:
		return
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	var rtm: RoomTransitionManager = $RoomTransitionManager
	var types: Array[int] = []
	var states: Array[int] = []
	var mods: Array[int] = []
	for i: int in _dungeon_graph.room_count():
		var room: Dictionary = _dungeon_graph.get_room(i)
		types.append(int(room.get("type", DungeonGraph.ROOM_TYPE_COMBAT)))
		states.append(int(room.get("state", DungeonGraph.ROOM_STATE_UNVISITED)))
		mods.append(int(room.get(RoomModifiers.KEY, RoomModifiers.NONE)))
	var edges: Array = []
	for i: int in _dungeon_graph.room_count():
		for j: int in _dungeon_graph.get_outgoing(i):
			edges.append(Vector2i(i, j))
	hud.set_minimap(types, states, rtm.get_current_room_idx(), mods, edges,
		_dungeon_graph.get_entry_room())
	# The prep panel sits under the floor map on the right (parent wires siblings).
	var grid: PranaGrid = get_tree().get_first_node_in_group(&"prana_grid") as PranaGrid
	if grid != null:
		grid.set_panel_top(hud.get_floor_map_bottom() + 8.0)


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
	# ADR-0026: Cursed rooms get a harder copy of the floor pool; Challenge tracks hits.
	_room_modifier = RoomModifiers.of(_dungeon_graph, room_idx)
	_room_flawless = true
	if _base_combat_cfg != null:
		$WaveManager.enemy_pool_config = RoomModifiers.apply_cursed(_base_combat_cfg) \
			if _room_modifier == RoomModifiers.CURSED else _base_combat_cfg
	var hud: CombatHUD = get_node_or_null(^"CanvasLayer/CombatHUD") as CombatHUD
	if hud != null:
		if _room_modifier == RoomModifiers.CHALLENGE:
			hud.show_room_banner(_COPY.challenge_banner, Color(1.0, 1.0, 1.0))
		elif _room_modifier == RoomModifiers.CURSED:
			hud.show_room_banner(_COPY.cursed_banner, UIPalette.MAP_CURSED)


## Picks the combat-state music cue for [param rtype] via AudioSystem.
## Boss/elite/rest rooms each get a dedicated track; all other rooms reset to the
## current floor's own loop (ADR-0049). No-op if AudioSystem is unavailable (e.g. headless tests).
func _select_room_music(rtype: int) -> void:
	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio == null or not audio.has_method(&"override_combat_cue"):
		return
	if audio.has_method(&"set_music_floor"):
		audio.set_music_floor(_current_floor)
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
	# Gamepad: Y / Triangle = Special (free during combat; prana_confirm is prep-only)
	_ensure_joypad_action(&"special", JOY_BUTTON_Y)
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
	# Keyboard grid controls (arrows move the cursor via built-in ui_* actions):
	# E places the selected Prana, Q discards a slot, C cycles the selected type.
	# Chosen to avoid conflicts (Space=cast, R=reload, Enter=confirm, WASD=move).
	_ensure_key_action(&"prana_place",      KEY_E)
	_ensure_key_action(&"prana_clear",      KEY_Q)
	_ensure_key_action(&"prana_type_cycle", KEY_C)
	# ADR-0055: held to skip the guided first room (Back is never offered for rebinding).
	_ensure_key_action(&"tutorial_skip", KEY_BACKSPACE)
	_ensure_joypad_action(&"tutorial_skip", JOY_BUTTON_BACK)
	# ADR-0026: player key bindings replace the defaults registered above.
	GameSettings.active().apply_keys()


## Called when the boss of a non-final floor is defeated.
## Generates the next floor and loads it via RTM — _on_room_transitioned handles
## spawn rewiring + restart_preparation() when load_floor() completes.
func _on_floor_completed() -> void:
	await _await_boss_cinematic()
	# ADR-0027: a cleared floor recovers the next memory before the next floor loads.
	var card: MemoryFragmentModal = _recover_memory(StoryRules.Beat.FLOOR_CLEAR, 0)
	if card != null:
		_toast(_COPY.toast_memory_format % [_meta.fragments_found, StoryRules.total()], UIPalette.COOL)
		await card.closed
	_floors_cleared += 1
	_current_floor += 1
	# Reset to 0 so the entry-room transition of the new floor increments it back to 1.
	_rooms_entered = 0
	_apply_floor_theme($RoomTransitionManager)
	_dungeon_graph = _gen.generate(_floor_room_count, _current_floor)
	RoomModifiers.assign(_dungeon_graph, _room_rng)
	GameStateManager.set_is_final_floor(_current_floor >= total_floors)
	_apply_floor_pool_config()
	$CanvasLayer/CombatHUD.show_floor_intro(_current_floor)
	$RoomTransitionManager.load_floor(_dungeon_graph)


## Applies the current floor's FloorTheme (ADR-0020): its template pools go to the
## generator, and [param rtm] hands its look to every room it loads.
func _apply_floor_theme(rtm: RoomTransitionManager) -> void:
	var idx: int = clampi(_current_floor - 1, 0, _FLOOR_THEME_PATHS.size() - 1)
	var theme: FloorTheme = load(_FLOOR_THEME_PATHS[idx]) as FloorTheme
	if theme == null:
		push_warning("debug_game_loop: floor theme missing at %s" % _FLOOR_THEME_PATHS[idx])
		return
	_gen.apply_floor_theme(theme)
	rtm.floor_theme = theme
	_floor_room_count = theme.room_count


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
		_base_combat_cfg = _run_pool(_floor_pool_configs[floor_idx])
		$WaveManager.enemy_pool_config = _base_combat_cfg
	if not _boss_pool_configs.is_empty():
		var boss_idx: int = clampi(_current_floor - 1, 0, _boss_pool_configs.size() - 1)
		$WaveManager.boss_pool_config = _run_pool(_boss_pool_configs[boss_idx])


## [param cfg] with this run's Hard Mode and Ascension (ADR-0052) applied, as a copy.
func _run_pool(cfg: EnemyPoolConfig) -> EnemyPoolConfig:
	if _meta == null or not _meta.hard_mode_active(_META):
		return cfg
	return _meta.apply_ascension(MetaProgress.apply_hard_mode(cfg, _META), _META)


## The stacked Ascension changes in effect this run (neutral values when none).
func _ascension_level() -> AscensionLevel:
	if _meta == null or _META.ascension == null:
		return AscensionLevel.new()
	return _META.ascension.stacked(_meta.active_ascension(_META))


## Death slow-mo: brief 0.15× time-scale window so the player can read the final
## board state before the overlay appears (Gamefeel Audit Issue 5.1).
## Uses ignore_time_scale=true so the timer ticks in real seconds regardless of time_scale.
func _on_run_ended(win: bool) -> void:
	# ADR-0048: the run is over, so there is nothing to continue. Cleared before the
	# death slow-mo so closing the game during it can't bring the run back.
	RunSave.clear(run_save_path)
	if win:
		await _await_boss_cinematic()
	if not win and not _in_death_sequence:
		_in_death_sequence = true
		_crumple_fayde()
		Engine.time_scale = _DEATH_SLOW_SCALE
		await get_tree().create_timer(_DEATH_SLOW_DURATION, true, false, true).timeout
		Engine.time_scale = GameSettings.base_time_scale()

	var audio: Node = get_node_or_null("/root/AudioSystem")
	if audio != null and audio.has_method(&"has_event"):
		var evt: StringName = &"sfx_run_win" if win else &"sfx_run_lose"
		if audio.has_event(evt):
			audio.play_event(evt)

	var run_data: Dictionary = RunManager.get_run_data()
	_log_run(RunLog.OUTCOME_WIN if win else RunLog.OUTCOME_DEATH, run_data)
	# ADR-0025: pay Cipher Shards once per run and save before building the overlay.
	var shards_earned: int = 0
	var hard_newly_unlocked: bool = false
	var ascension_opened: int = 0
	if _meta != null and not _run_recorded:
		_run_recorded = true
		var was_unlocked: bool = _meta.is_hard_mode_unlocked(_META)
		var was_ascension: int = _meta.ascension_unlocked
		run_data["bonus_shards"] = _bonus_shards
		shards_earned = _meta.record_run(_META, run_data, win)
		hard_newly_unlocked = not was_unlocked and _meta.is_hard_mode_unlocked(_META)
		if _meta.ascension_unlocked > was_ascension:
			ascension_opened = _meta.ascension_unlocked
		var run_sec: float = float(run_data.get("run_time_sec", 0.0))
		if win and not _assist_used and _meta.record_win_time(run_sec):
			_new_records.push_front(Records.new_run_line(run_sec))
		_meta.save_to(progress_path)
		await _play_run_end_story(win, run_data)

	# U5 — run summary screen, built from plain data (RunSummaryPanel owns no state).
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	var panel := RunSummaryPanel.new()
	overlay.add_child(panel)
	add_child(overlay)
	var summary: Dictionary = _build_summary_data(win, run_data, shards_earned, hard_newly_unlocked)
	summary["ascension_unlocked"] = ascension_opened
	summary["ascension"] = _meta.active_ascension(_META) if _meta != null else 0
	panel.setup(summary)
	panel.run_again_pressed.connect(_restart_from_pause)
	panel.main_menu_pressed.connect(_to_main_menu)
	panel.run_again_button.grab_focus()


## ADR-0041: lets a running boss death cinematic finish before any reward screen.
func _await_boss_cinematic() -> void:
	if is_instance_valid(_boss_cinematic) and _boss_cinematic.is_playing():
		await _boss_cinematic.finished


## ADR-0042 (art bible §5.3): Fayde's sprite gives way to the crumple pose where she
## fell. The live sprite is only hidden, never changed, and the run restart rebuilds it.
func _crumple_fayde() -> void:
	var pc: PixelCharacter = $PlayerController.get_node_or_null(^"PixelCharacter") as PixelCharacter
	if pc == null:
		return
	_last_prana_color = pc.glow_color
	var crumple := CrumplePose.new()
	crumple.name = "CrumplePose"
	crumple.scale = Vector2(pc.pixel_scale, pc.pixel_scale)
	var face: Vector2 = $PlayerController.get_facing_direction()
	crumple.setup(pc.glow_color, Color.WHITE, face.x < 0.0)
	pc.visible = false
	$PlayerController.add_child(crumple)


## U5 — the run summary's data: RunManager stats plus what this loop logged during the
## run (room ranks, sigils, floors cleared) and memories recovered since the run began.
func _build_summary_data(win: bool, run_data: Dictionary, shards: int, hard_unlocked: bool) -> Dictionary:
	var found: int = _meta.fragments_found if _meta != null else 0
	return {
		"win": win,
		"floor": int(run_data.get("current_floor", 1)),
		"rooms": int(run_data.get("rooms_cleared", 0)),
		"time_sec": float(run_data.get("run_time_sec", 0.0)),
		"enemies": int(run_data.get("enemies_killed", 0)),
		"best_combo": int(run_data.get("best_combo", 0)),
		"bosses": _floors_cleared + (1 if win else 0),
		"ranks": _run_ranks,
		"shards": shards,
		"sigils": _run_sigils.map(func(x: Dictionary) -> String: return str(x["title"])),
		"memories_new": maxi(found - _fragments_at_start, 0),
		"memories_found": found,
		"memories_total": StoryRules.total(),
		"hard_unlocked": hard_unlocked,
		"assist": _assist_used,
		"records": _new_records + _revealed_heirloom_lines(found),
		"death": "" if win else DeathRecap.line(HealthAndDamage.last_player_hit, _COPY),
		"prana_color": _last_prana_color,
	}


## U5 — logs a room's clear rank for the run summary.
func _log_room_rank(rank_letter: String, _heal: float, _meter_bonus: float) -> void:
	_run_ranks.append(rank_letter)


## U5 — logs a taken sigil's title for the run summary (Prana rewards are not sigils).
func _log_sigil(sigil_id: StringName) -> void:
	if String(sigil_id).begins_with("prana_"):
		return
	_applied_sigils.append(String(sigil_id))
	if _meta != null:
		_meta.discover_sigil(sigil_id)
	for sigil: Dictionary in _sigil_manager.get_catalog():
		if sigil.get("id", &"") == sigil_id:
			_run_sigils.append({"title": str(sigil.get("title", sigil_id)), "desc": str(sigil.get("desc", ""))})
			if not _replaying_sigils:
				_toast(_COPY.toast_sigil_format % str(sigil.get("title", sigil_id)), UIPalette.GOOD)
			var hud: CombatHUD = get_node_or_null(^"CanvasLayer/CombatHUD") as CombatHUD
			if hud != null:  # ADR-0045 chip strip
				hud.get_sigil_strip().add_sigil(sigil_id, str(sigil.get("title", sigil_id)),
					bool(sigil.get("behaviour", false)))
			return


## ADR-0046 — pushes a corner toast. The toaster is pausable, so one pushed under a
## modal (sigil offer, memory card) waits and shows once play resumes.
func _toast(text: String, color: Color) -> void:
	if is_instance_valid(_toaster):
		_toaster.push(text, color)


## F4: summary lines for Heirlooms that this run's memories made available.
func _revealed_heirloom_lines(found: int) -> Array[String]:
	var lines: Array[String] = []
	for id: StringName in _META.heirlooms_revealed_between(_fragments_at_start, found):
		lines.append(_COPY.heirloom_revealed_format % str(MetaProgress.heirloom_info(id).get("title", id)))
	return lines


## F1: records the confirmed grid's core spell and armed reactions in the Spellbook.
func _log_build_discoveries(_is_boss: bool) -> void:
	var grid: PranaGrid = get_tree().get_first_node_in_group(&"prana_grid") as PranaGrid
	if grid == null:
		return
	_log_builds.append(RunLog.build_entry(_current_floor, _rooms_entered, grid.get_slot_types()))
	if _meta == null:
		return
	var found: Dictionary = Spellbook.discoveries_from_grid(grid.get_slot_types())
	_meta.discover_spell(int(found["core"]))
	for id: StringName in found["reactions"]:
		_meta.discover_reaction(id)


## F1: records a defeated enemy type in the Spellbook. F3: a boss kill stops the boss
## timer and may set a record (never with Assist on).
func _log_enemy_discovery(_instance_id: int, type_id: int, _affiliation: GameEnums.DamageClass) -> void:
	if _meta == null:
		return
	# ADR-0055: training targets borrow a catalog type; they are not a discovery.
	if is_instance_valid(_tutorial_room) and _tutorial_room.is_target(_instance_id):
		return
	_meta.discover_enemy(type_id)
	if not _boss_timing or not Records.boss_ids().has(type_id):
		return
	_boss_timing = false
	if not _assist_used and _meta.record_boss_time(type_id, _boss_elapsed):
		_new_records.append(Records.new_boss_line(type_id, _boss_elapsed))


func _process(delta: float) -> void:
	if _boss_timing:
		_boss_elapsed += delta


## Saves progress (Spellbook discoveries) when leaving a run early.
func _save_progress() -> void:
	if _meta != null:
		_meta.save_to(progress_path)


## ADR-0027: recovers the next memory fragment for [param beat], saves progress and
## shows the card. Returns the open card, or null when nothing was recovered.
func _recover_memory(beat: StoryRules.Beat, rooms_cleared: int) -> MemoryFragmentModal:
	if _meta == null or not StoryRules.beat_recovers(beat, rooms_cleared):
		return null
	var idx: int = _meta.recover_fragment(StoryRules.total())
	if idx < 0:
		return null
	_meta.save_to(progress_path)
	var card := MemoryFragmentModal.new()
	card.name = "MemoryFragmentModal"
	card.setup_fragment(StoryRules.fragment_at(idx), idx, StoryRules.total())
	add_child(card)
	return card


## ADR-0027: the story beats at the end of a run, shown before the summary overlay.
## A death recovers a memory; a win recovers one and then plays an ending, which is
## the true ending once every fragment is found.
func _play_run_end_story(win: bool, run_data: Dictionary) -> void:
	var beat: StoryRules.Beat = StoryRules.Beat.WIN if win else StoryRules.Beat.DEATH
	var card: MemoryFragmentModal = _recover_memory(beat, int(run_data.get("rooms_cleared", 0)))
	if card != null:
		await card.closed
	if not win or not StoryRules.plays_ending(int(run_data.get("current_floor", 1))):
		return
	var is_true: bool = StoryRules.is_complete(_meta.fragments_found)
	_meta.record_ending(is_true)
	_meta.save_to(progress_path)
	var ending := MemoryFragmentModal.new()
	ending.name = "EndingModal"
	ending.setup_ending(StoryRules.ending_for(_meta.fragments_found), is_true,
		_meta.fragments_found, StoryRules.total())
	add_child(ending)
	await ending.closed


## Room-clear warm wash overlay — gold flash on wave_ended (Art Bible §2.4).
## Flash in 0.15 s → hold 0.6 s → fade out 0.5 s. Auto-frees at tween end.
func _on_wave_ended() -> void:
	var audio := get_node_or_null("/root/AudioSystem")
	if audio != null and audio.has_method(&"has_event") and audio.has_event(&"sfx_wave_clear"):
		audio.play_event(&"sfx_wave_clear")
	var wash := ColorRect.new()
	wash.color = Color(UIPalette.ACCENT, 0.0)
	wash.anchor_right = 1.0
	wash.anchor_bottom = 1.0
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$CanvasLayer.add_child(wash)
	var tw: Tween = create_tween()
	tw.tween_property(wash, "color:a", 0.18 * GameSettings.flash_multiplier(), 0.15).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6)
	tw.tween_property(wash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(wash.queue_free)

	# Between-room reward: offer a sigil after combat/elite clears (skip rest/boss).
	# wave_ended also fires in the boss room, but its room_type is BOSS so it's skipped.
	var rtype: int = $WaveManager.room_type
	if _sigil_manager != null \
			and (rtype == DungeonGraph.ROOM_TYPE_COMBAT or rtype == DungeonGraph.ROOM_TYPE_ELITE):
		# ADR-0026: Cursed and flawless Challenge rooms owe two picks.
		var picks: int = RoomModifiers.picks_for(_room_modifier, _room_flawless)
		var bonus: int = RoomModifiers.bonus_shards(_room_modifier, _room_flawless)
		if bonus > 0:
			_bonus_shards += bonus
			_toast(_COPY.toast_shards_format % [bonus, _bonus_shards], UIPalette.ACCENT)
			$CanvasLayer/CombatHUD.show_room_banner(_COPY.challenge_won_format % bonus,
				UIPalette.ACCENT)
		# ADR-0041: the sigil offer waits until the CLEAR banner has had its beat.
		await get_tree().create_timer(RoomClearMoment.reward_delay_sec(), true, false, true).timeout
		_sigil_manager.offer_sigils(picks)
	elif _sigil_manager != null and rtype == DungeonGraph.ROOM_TYPE_REST:
		await get_tree().create_timer(0.5).timeout
		_open_wayshrine()


## ADR-0026: Rest rooms are Wayshrines — trade HP for one sigil pick, or walk on.
func _open_wayshrine() -> void:
	var cost: int = RoomModifiers.TUNING.wayshrine_hp_cost
	var panel := WayshrinePanel.new()
	panel.name = "WayshrinePanel"
	panel.setup(cost, RoomModifiers.can_pay_wayshrine(HealthAndDamage.get_fayde_hp()))
	panel.trade_chosen.connect(func() -> void:
		if HealthAndDamage.pay_fayde_hp(cost):
			_sigil_manager.offer_sigils.call_deferred(1))
	add_child(panel)


## ADR-0026: the first hit taken in a Challenge room loses its bonus.
func _on_damage_taken(target: Node, _final_damage: int, _current_hp: int) -> void:
	if _room_modifier != RoomModifiers.CHALLENGE or not _room_flawless:
		return
	if not target.is_in_group(&"player") \
			or GameStateManager.get_active_state() != GameEnums.GameState.COMBAT_PHASE:
		return
	_room_flawless = false
	$CanvasLayer/CombatHUD.show_room_banner(_COPY.challenge_lost, Color(1.0, 0.45, 0.4))


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
		Engine.time_scale = GameSettings.base_time_scale()


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


# ── Run save and playtest log (ADR-0048) ──────────────────────────────────────

func _on_cast_started(_effect: SpellEffect) -> void:
	if _run_in_progress():
		_casts += 1


## True while a run is being played: past the core pick, not over and not logged.
func _run_in_progress() -> bool:
	if _run_logged or _run_recorded or _in_death_sequence:
		return false
	var state: GameEnums.GameState = GameStateManager.get_active_state()
	return state == GameEnums.GameState.PREPARATION_PHASE \
		or state == GameEnums.GameState.COMBAT_PHASE \
		or state == GameEnums.GameState.PAUSED


## Everything a resumed run needs, as of the start of the current room.
func _run_snapshot() -> Dictionary:
	var rtm: RoomTransitionManager = $RoomTransitionManager
	return {
		"floor": _current_floor,
		"total_floors": total_floors,
		"run_seed": _run_seed,
		"rng_seed": _room_rng.seed,
		"rng_state": _room_rng.state,
		"graph": _dungeon_graph.to_data(),
		"room_idx": rtm.get_current_room_idx(),
		"rooms_entered": _rooms_entered,
		"core": String(_core.id) if _core != null else "",
		"loadout": _prana_loadout.get_slots(),
		"bag": _prana_bag.get_items(),
		"sigils": _applied_sigils.duplicate(),
		"hp": HealthAndDamage.get_fayde_hp(),
		"run": RunManager.snapshot(),
		"ranks": _run_ranks.duplicate(),
		"floors_cleared": _floors_cleared,
		"fragments_at_start": _fragments_at_start,
		"bonus_shards": _bonus_shards,
		"assist_used": _assist_used,
		"new_records": _new_records.duplicate(),
		"hard": _meta != null and _meta.hard_mode,
		"ascension": _meta.ascension if _meta != null else 0,
		"log_builds": _log_builds.duplicate(true),
		"casts": _casts,
		"resumes": _resumes,
	}


## Saves the run at the start of a room (and right after the core pick).
func _write_run_save() -> void:
	if not _run_in_progress() or _dungeon_graph == null \
			or _prana_loadout == null or _prana_bag == null:
		return
	var err: Error = RunSave.write(_run_snapshot(), run_save_path)
	if err != OK:
		push_warning("debug_game_loop: run save failed (%s)" % error_string(err))


## Rebuilds the saved run instead of showing the title: same floor and graph, Core,
## build, bag, sigils, HP and run stats, then loads the saved room in its prep phase.
func _resume_run(data: Dictionary) -> void:
	_resumes = int(data.get("resumes", 0)) + 1
	_current_floor = int(data["floor"])
	_run_seed = int(data.get("run_seed", _run_seed))
	_room_rng.seed = int(data.get("rng_seed", _room_rng.seed))
	_room_rng.state = int(data.get("rng_state", _room_rng.state))
	$WaveManager.boss_variants = BossDirector.ROSTER.pick_all(_run_seed)
	# Hard Mode and Ascension stay as the run started, whatever the menu says now.
	if _meta != null:
		_meta.hard_mode = bool(data.get("hard", false))
		_meta.ascension = int(data.get("ascension", 0))
	var rtm: RoomTransitionManager = $RoomTransitionManager
	_apply_floor_theme(rtm)
	_dungeon_graph = DungeonGraph.from_data(data["graph"] as Dictionary)
	GameStateManager.set_is_final_floor(_current_floor >= total_floors)
	_apply_floor_pool_config()
	_floors_cleared = int(data.get("floors_cleared", 0))
	_fragments_at_start = int(data.get("fragments_at_start", _fragments_at_start))
	_bonus_shards = int(data.get("bonus_shards", 0))
	_assist_used = bool(data.get("assist_used", false))
	_casts = int(data.get("casts", 0))
	for v: Variant in data.get("ranks", []):
		_run_ranks.append(str(v))
	for v: Variant in data.get("new_records", []):
		_new_records.append(str(v))
	for v: Variant in data.get("log_builds", []):
		_log_builds.append(v as Dictionary)

	_prana_loadout.set_slots(data["loadout"] as Array)
	GameStateManager.start_run()  # run_started resets HP, bag, sigil stacks, run stats
	_selected_core = _CORES.get_core(StringName(str(data.get("core", ""))))
	_start_core()
	for v: Variant in data.get("bag", []):
		_prana_bag.add(int(v))
	# Sigils are replayed in the order taken; _log_sigil rebuilds the lists and HUD chips.
	var sigils: Array = data.get("sigils", []) as Array
	_applied_sigils.clear()
	_run_sigils.clear()
	_replaying_sigils = true
	for v: Variant in sigils:
		_sigil_manager.apply_sigil(StringName(str(v)))
	_replaying_sigils = false
	HealthAndDamage.restore_fayde_hp(int(data["hp"]))
	var hud: CombatHUD = $CanvasLayer/CombatHUD
	hud.sync_hp(HealthAndDamage.get_fayde_hp())
	RunManager.restore_snapshot(data.get("run", {}) as Dictionary)
	# _on_room_transitioned counts the room again, and saves once it is loaded.
	_rooms_entered = int(data["rooms_entered"]) - 1
	hud.show_room_banner(_COPY.run_resumed_banner, UIPalette.ACCENT)
	if _meta == null or not _meta.tutorial_done:
		_start_coach()
	rtm.load_floor(_dungeon_graph, int(data["room_idx"]))


## Appends this run to the playtest log once: outcome, floor, rooms, time, cause of
## death and the spells cast.
func _log_run(outcome: String, run_data: Dictionary) -> void:
	if _run_logged:
		return
	_run_logged = true
	var died: bool = outcome == RunLog.OUTCOME_DEATH
	var death: Dictionary = HealthAndDamage.last_player_hit if died else {}
	var run: Dictionary = {
		"floor": _current_floor,
		"rooms": int(run_data.get("rooms_cleared", 0)),
		"run_sec": float(run_data.get("run_time_sec", 0.0)),
		"core": String(_core.id) if _core != null else "",
		"sigils": _applied_sigils.duplicate(),
		"casts": _casts,
		"assist": _assist_used,
		"hard": _meta != null and _meta.hard_mode_active(_META),
		"resumes": _resumes,
	}
	var e: Dictionary = RunLog.entry(outcome, run, death,
		DeathRecap.line(death, _COPY) if died else "", _log_builds,
		Time.get_datetime_string_from_system(true) + "Z",
		str(ProjectSettings.get_setting("application/config/version", "dev")))
	var err: Error = RunLog.append(e, run_log_path)
	if err != OK:
		push_warning("debug_game_loop: run log write failed (%s)" % error_string(err))
