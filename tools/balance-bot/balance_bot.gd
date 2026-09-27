## BalanceBot — plays main.tscn headless to measure run length and boss fights (ADR-0051).
##
## Run from the project root (one run per process; the shell script loops):
##   godot --headless --fixed-fps 60 --path . res://tools/balance-bot/BalanceBot.tscn -- \
##       --seed=3 --god --out=user://balance_bot/run_3.json
##
## The bot drives the real game: it picks a core, confirms the Prana grid (placing any
## reward Prana first), fights with the real input actions (move, cast, dash, special),
## takes the first card on every sigil screen, skips story cards and walks to an exit
## door once a room is clear. Time is counted in fixed 1/60 s frames, so a report says
## how long the same run would take a player at full speed, pauses included.
##
## A human also spends time reading the grid, the sigil cards and the story cards, which
## the bot does instantly. [member _CFG] adds that overhead per screen, so the report
## carries both the measured bot time and an estimated player time.
##
## Flags: --god (Fayde takes no damage: measures pace, not survival), --seed=N,
## --hard (Hard Mode), --ascension=N (ADR-0052), --out=PATH, --max-min=N (abort after N
## simulated minutes). This is a dev tool: nothing in the shipped game loads it.
extends Node

const _MAIN: PackedScene = preload("res://src/scenes/main.tscn")
const _CFG: BalanceBotConfig = preload("res://tools/balance-bot/balance_bot_config.tres")
const _FPS: float = 60.0
const _PROGRESS_PATH: String = "user://balance_bot/progress.cfg"

var _game: Node = null
var _frame: int = 0
var _seed: int = 1
var _god: bool = false
var _hard: bool = false
var _ascension: int = 0
var _out_path: String = "user://balance_bot/run.json"
var _max_frames: int = 0
var _rng := RandomNumberGenerator.new()

var _finished: bool = false
var _started: bool = false
var _cast_held: bool = false
var _ui_cooldown: int = 0
var _door_target: RoomExitDoor = null
var _door_frames: int = 0
var _door_best_dist: float = INF
## Per-chain roll for landing the Perfect window (-1 = not rolled yet).
var _perfect_roll: float = -1.0
## Boss fight timing: spawn time of the live boss (-1 = none), damage taken since.
var _boss_start: float = -1.0
var _boss_damage: int = 0
var _bosses: Array = []
## Stall guard state (see _stalled) and how often it fired this run.
var _stall_hp: int = -1
var _stall_frames: int = 0
var _stalls: int = 0
## Pillar detour state (see _unstick).
var _stuck_frames: int = 0
var _stuck_from: Vector2 = Vector2.ZERO
var _detour_frames: int = 0
var _detour_dir: Vector2 = Vector2.ZERO

## Per-room log: {floor, type, prep_sec, combat_sec, damage, exit_sec, boss_id, boss_hp}.
var _rooms: Array[Dictionary] = []
var _room: Dictionary = {}
var _screens: int = 0
var _sigils: int = 0
var _damage_total: int = 0
var _hp_low: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_rng.seed = _seed
	seed(_seed)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://balance_bot"))
	var meta := MetaProgress.new()
	meta.tutorial_done = true
	meta.wins = maxi(_ascension + 1, 1) if (_hard or _ascension > 0) else 0
	meta.hard_mode = _hard or _ascension > 0
	if meta.get(&"ascension") != null:
		meta.set(&"ascension_unlocked", _ascension)
		meta.set(&"ascension", _ascension)
	meta.save_to(_PROGRESS_PATH)

	_game = _MAIN.instantiate()
	_game.set(&"progress_path", _PROGRESS_PATH)
	add_child(_game)
	HealthAndDamage._debug_god_mode = _god
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	GameStateManager.combat_started.connect(_on_combat_started)
	GameStateManager.room_cleared.connect(_on_room_cleared)
	GameStateManager.run_ended.connect(_on_run_ended)
	GameStateManager.preparation_started.connect(_on_prep_started)
	_hp_low = HealthAndDamage.get_fayde_hp()
	var wm: Node = _game.get_node(^"WaveManager")
	wm.boss_spawned.connect(func(_boss: Node) -> void:
		_boss_start = _now()
		_boss_damage = 0)
	wm.boss_defeated.connect(_on_boss_defeated)


func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--god":
			_god = true
		elif arg == "--hard":
			_hard = true
		elif arg.begins_with("--seed="):
			_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--ascension="):
			_ascension = int(arg.get_slice("=", 1))
		elif arg.begins_with("--out="):
			_out_path = arg.get_slice("=", 1)
		elif arg.begins_with("--max-min="):
			_max_frames = int(float(arg.get_slice("=", 1)) * 60.0 * _FPS)
	if _max_frames <= 0:
		_max_frames = int(_CFG.max_run_minutes * 60.0 * _FPS)


func _physics_process(_delta: float) -> void:
	if _finished:
		return
	_frame += 1
	if _frame >= _max_frames:
		_finish(false, "timeout")
		return
	if not _started:
		if _frame == 5:
			_game._begin_run()
		elif _frame == 10:
			_game._on_core_picked(_rng.randi_range(0, 4))
			_started = true
		return
	_release_taps()
	if _frame % int(_CFG.log_every_sec * _FPS) == 0:
		print("BOT t=%.0fs floor=%d rooms=%d hp=%d state=%d paused=%s enemies=%d cleared=%s door=%s" % [
			_now(), int(_game.get(&"_current_floor")), _rooms.size(), HealthAndDamage.get_fayde_hp(),
			GameStateManager.get_active_state(), get_tree().paused,
			get_tree().get_nodes_in_group(&"enemy").size(), _room.get("cleared", false),
			_door_target.global_position if is_instance_valid(_door_target) else "-"])
	if _ui_cooldown > 0:
		_ui_cooldown -= 1
	if get_tree().paused:
		_handle_modal()
		return
	match GameStateManager.get_active_state():
		GameEnums.GameState.PREPARATION_PHASE:
			_handle_prep()
		GameEnums.GameState.COMBAT_PHASE:
			if _room.get("cleared", false):
				_walk_to_door()
			else:
				_fight()


# ── Screens ──────────────────────────────────────────────────────────────────

## Any pausing screen: story cards close, everything else presses its focused button
## (the first sigil card, "walk on" at a Wayshrine, Continue).
func _handle_modal() -> void:
	_set_move(Vector2.ZERO)
	if _ui_cooldown > 0:
		return
	_ui_cooldown = int(_CFG.bot_ui_delay_sec * _FPS)
	for card: Node in get_tree().root.find_children("*", "MemoryFragmentModal", true, false):
		var modal := card as MemoryFragmentModal
		if modal.can_dismiss():
			modal.finish_typing()
			modal.close()
			_screens += 1
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	var btn := focus as BaseButton
	if btn == null or not btn.is_visible_in_tree() or btn.disabled:
		btn = _first_button()
	if btn != null:
		if btn.get_parent() != null and String(btn.get_parent().get_class()) == "HBoxContainer":
			_sigils += 1
		_screens += 1
		btn.pressed.emit()


func _first_button() -> BaseButton:
	for n: Node in get_tree().root.find_children("*", "BaseButton", true, false):
		var b := n as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.can_process():
			return b
	return null


func _handle_prep() -> void:
	_set_move(Vector2.ZERO)
	if _ui_cooldown > 0:
		return
	_ui_cooldown = int(_CFG.bot_ui_delay_sec * _FPS)
	var grid: PranaGrid = get_tree().get_first_node_in_group(&"prana_grid") as PranaGrid
	if grid == null:
		return
	# Reward Prana goes into the first empty slots, centre first.
	var bag: PranaBag = get_tree().get_first_node_in_group(&"prana_bag") as PranaBag
	if bag != null:
		for type_id: int in bag.get_items().duplicate():
			var slots: Array = grid.get_slot_types()
			var order: Array[int] = [4, 1, 3, 5, 7, 0, 2, 6, 8]
			for idx: int in order:
				if slots[idx] == null:
					grid._place_from_bag(idx, type_id)
					break
	grid._on_confirm_pressed()


# ── Combat ───────────────────────────────────────────────────────────────────

func _fight() -> void:
	var player := _game.get_node(^"PlayerController") as PlayerController
	var me: Vector2 = player.global_position
	var enemies: Array[Node2D] = []
	var hp_sum: int = 0
	for n: Node in get_tree().get_nodes_in_group(&"enemy"):
		var e := n as Node2D
		if e != null and e.has_method(&"is_alive") and e.is_alive():
			enemies.append(e)
			var rec: Variant = HealthAndDamage._enemy_registry.get(e.get_instance_id())
			hp_sum += int(rec.current_hp) if rec != null else 0
	if _stalled(hp_sum, enemies, me):
		return
	var target: Node2D = null
	var best: float = INF
	for e: Node2D in enemies:
		var d: float = me.distance_to(e.global_position)
		if d < best:
			best = d
			target = e

	# Dodge: push away from bullets closing in, weighted by closeness.
	var push := Vector2.ZERO
	var threat: bool = false
	for n: Node in get_tree().get_nodes_in_group(Projectile.GROUP):
		var b := n as Node2D
		if b == null:
			continue
		var off: Vector2 = me - b.global_position
		var d: float = off.length()
		if d < _CFG.dodge_radius and d > 0.1:
			push += off.normalized() * (1.0 - d / _CFG.dodge_radius)
			if d < _CFG.dash_radius:
				threat = true
	for n: Node in get_tree().get_nodes_in_group(&"enemy_hazard"):
		var h := n as Node2D
		if h != null and me.distance_to(h.global_position) < _CFG.hazard_radius:
			push += (me - h.global_position).normalized() * 0.6

	# Spells aim along Fayde's facing (her last move input, snapped to 8 directions),
	# so the bot closes to a share of the spell's reach and steers at its target.
	var reach: float = _spell_reach()
	var move := Vector2.ZERO
	var in_reach: bool = false
	if target != null:
		var to_t: Vector2 = target.global_position - me
		in_reach = to_t.length() < reach * _CFG.reach_share
		if in_reach:
			# Close enough: a light nudge keeps her facing the target while she dodges.
			move = to_t.normalized() * _CFG.aim_nudge
		else:
			move = _unstick(me, to_t.normalized())
	move += push * _CFG.dodge_weight
	_set_move(move)

	if threat and player.get_dash_charges() > 0 and _rng.randf() < _CFG.dash_chance:
		Input.action_press(&"dash")
	if target == null:
		return
	var facing: Vector2 = player.get_facing_direction()
	var aim_ok: bool = absf(facing.angle_to(target.global_position - me)) < deg_to_rad(_CFG.aim_tolerance_deg)
	if aim_ok and target.global_position.distance_to(me) < reach and _wants_cast():
		Input.action_press(&"cast")
		_cast_held = true
	if aim_ok and SpellCastingEffects.is_special_ready() and target.global_position.distance_to(me) < reach:
		Input.action_press(&"special")


## A room where no enemy loses HP for [member BalanceBotConfig.stall_sec] means the bot
## cannot reach the last enemies (a player would find them). It logs the stall and
## clears the room with the F2 debug kill, so one bad spot cannot eat a whole run.
func _stalled(hp_sum: int, enemies: Array[Node2D], me: Vector2) -> bool:
	if hp_sum != _stall_hp or enemies.is_empty():
		_stall_hp = hp_sum
		_stall_frames = 0
		return false
	_stall_frames += 1
	if _stall_frames < int(_CFG.stall_sec * _FPS):
		return false
	_stall_frames = 0
	_stalls += 1
	for e: Node2D in enemies:
		print("BOT stall: %s at %s, Fayde at %s, reach %.0f" % [e.get(&"_enemy_name"),
			e.global_position, me, _spell_reach()])
	HealthAndDamage.debug_kill_all_enemies()
	return true


## Walls and cover pillars block a straight approach. When the bot has barely moved
## for [member BalanceBotConfig.stuck_sec] it sidesteps for a moment, like a player
## walking round a pillar.
func _unstick(me: Vector2, dir: Vector2) -> Vector2:
	if _detour_frames > 0:
		_detour_frames -= 1
		return _detour_dir
	_stuck_frames += 1
	if _stuck_frames >= int(_CFG.stuck_sec * _FPS):
		var moved: float = me.distance_to(_stuck_from)
		_stuck_frames = 0
		_stuck_from = me
		if moved < _CFG.stuck_px:
			var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
			_detour_dir = (dir.orthogonal() * side + dir * 0.2).normalized()
			_detour_frames = int(_CFG.detour_sec * _FPS)
			return _detour_dir
	return dir


## Reach of the current primary spell, from the same ranges SpellCastingEffects uses.
func _spell_reach() -> float:
	var se: SpellEffect = SpellCastingEffects.get(&"_current_spell_effect") as SpellEffect
	var pt: int = se.primary_type if se != null else -1
	match pt:
		0, 4:
			return SpellCastingEffects.MELEE_RANGE
		1, 3:
			return SpellCastingEffects.SEMI_MELEE_RANGE
		2:
			return SpellCastingEffects.STORMGOLD_SNIPER_RANGE
	return 150.0


## Presses on a fresh chain, and mid-chain only outside the Rushed window: in the
## Perfect window with the bot's skill chance, otherwise once it turns Normal.
func _wants_cast() -> bool:
	var st: int = int(SpellCastingEffects.get(&"_state"))
	if st == 1:  # READY
		return true
	if st != 2:  # only CHAINING beyond this point
		return false
	match SpellCastingEffects.get_cast_timing():
		SpellCastingEffects.CastTiming.PERFECT:
			if _perfect_roll < 0.0:
				_perfect_roll = _rng.randf()
			if _perfect_roll < _CFG.perfect_rate:
				_perfect_roll = -1.0
				return true
			return false
		SpellCastingEffects.CastTiming.NORMAL:
			_perfect_roll = -1.0
			return true
	return false


func _walk_to_door() -> void:
	var player := _game.get_node(^"PlayerController") as PlayerController
	var rtm: RoomTransitionManager = _game.get_node(^"RoomTransitionManager")
	if rtm.is_transitioning():
		_set_move(Vector2.ZERO)
		return
	if not is_instance_valid(_door_target):
		var doors: Array[RoomExitDoor] = []
		var room: Node = SceneManager.get_current_scene()
		if room != null:
			for n: Node in room.find_children("*", "RoomExitDoor", true, false):
				var d := n as RoomExitDoor
				if d.visible and d.destination_idx >= 0:
					doors.append(d)
		if doors.is_empty():
			_set_move(Vector2.ZERO)
			return
		_door_target = doors[_rng.randi_range(0, doors.size() - 1)]
		_door_frames = 0
		_door_best_dist = INF
	_door_frames += 1
	var to_d: Vector2 = _door_target.global_position - player.global_position
	_set_move(to_d)
	if to_d.length() < _door_best_dist - 2.0:
		_door_best_dist = to_d.length()
		_door_frames = 0
	# Stuck on a pillar or a wall corner: take the door the way the F3 debug key does.
	if _door_frames > int(_CFG.door_stuck_sec * _FPS):
		var dest: int = _door_target.destination_idx
		_door_target = null
		rtm.request_transition(dest)


func _set_move(v: Vector2) -> void:
	var dir: Vector2 = v.normalized() if v.length() > 0.15 else Vector2.ZERO
	_axis(&"move_left", maxf(-dir.x, 0.0))
	_axis(&"move_right", maxf(dir.x, 0.0))
	_axis(&"move_up", maxf(-dir.y, 0.0))
	_axis(&"move_down", maxf(dir.y, 0.0))


func _axis(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _release_taps() -> void:
	if _cast_held:
		Input.action_release(&"cast")
		_cast_held = false
	Input.action_release(&"dash")
	Input.action_release(&"special")


# ── Logging ──────────────────────────────────────────────────────────────────

func _now() -> float:
	return float(_frame) / _FPS


func _on_prep_started(_wave_index: int = 0, _waves_remaining: int = 0) -> void:
	_door_target = null
	_room = {
		"floor": int(_game.get(&"_current_floor")),
		"type": int(_game.get_node(^"WaveManager").get(&"room_type")),
		"prep_start": _now(),
	}


func _on_combat_started(_is_boss: bool) -> void:
	_room["combat_start"] = _now()
	_room["damage"] = 0


func _on_room_cleared() -> void:
	_room["cleared"] = true
	_room["clear_at"] = _now()
	_rooms.append(_room)


## Boss fights are timed from the boss spawning to its death, not from the room's
## combat start (the boss room also holds the pre-boss wave).
func _on_boss_defeated() -> void:
	if _boss_start >= 0.0:
		_bosses.append({"floor": int(_game.get(&"_current_floor")),
			"combat_sec": snappedf(_now() - _boss_start, 0.1), "damage": _boss_damage})
	_boss_start = -1.0


func _on_damage_taken(target: Node, final_damage: int, current_hp: int) -> void:
	if target == null or not target.is_in_group(&"player"):
		return
	_damage_total += final_damage
	_room["damage"] = int(_room.get("damage", 0)) + final_damage
	if _boss_start >= 0.0:
		_boss_damage += final_damage
	_hp_low = mini(_hp_low, current_hp)


func _on_run_ended(win: bool) -> void:
	# A boss room never emits room_cleared on the last floor; log it here.
	if not _room.get("cleared", false) and _room.has("combat_start"):
		_room["clear_at"] = _now()
		_rooms.append(_room)
	_finish(win, "win" if win else "death")


func _finish(win: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	var report: Dictionary = _build_report(win, reason)
	var f := FileAccess.open(_out_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("BALANCE_BOT ", JSON.stringify(report))
	HealthAndDamage._debug_god_mode = false
	get_tree().quit(0)


func _build_report(win: bool, reason: String) -> Dictionary:
	var rooms: Array = []
	var combat_sec: float = 0.0
	var boss_fights: Array = _bosses
	for r: Dictionary in _rooms:
		var c: float = float(r.get("clear_at", _now())) - float(r.get("combat_start", r.get("prep_start", 0.0)))
		combat_sec += c
		var row: Dictionary = {"floor": r.get("floor", 0), "type": r.get("type", 0),
			"combat_sec": snappedf(c, 0.1), "damage": r.get("damage", 0)}
		rooms.append(row)
	var sim_sec: float = _now()
	var overhead: float = _CFG.human_prep_sec * _rooms.size() \
		+ _CFG.human_screen_sec * _screens + _CFG.human_sigil_sec * _sigils
	return {
		"seed": _seed, "god": _god, "hard": _hard, "ascension": _ascension,
		"outcome": reason, "win": win,
		"floor_reached": int(_game.get(&"_current_floor")),
		"rooms": rooms.size(),
		"sim_sec": snappedf(sim_sec, 0.1),
		"combat_sec": snappedf(combat_sec, 0.1),
		"est_player_sec": snappedf(sim_sec + overhead, 0.1),
		"screens": _screens, "sigils": _sigils, "stalls": _stalls, "stall_sec": _CFG.stall_sec,
		"damage_taken": _damage_total, "hp_low": _hp_low,
		"boss_fights": boss_fights, "room_log": rooms,
	}
