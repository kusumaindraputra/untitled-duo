## TutorialRoom — the guided lessons of the first run's first room (ADR-0055).
##
## Six lessons, shown one at a time in order on a TutorialRoomPanel: two while the grid
## is open (place a Prana from the bag, lock the grid) and four once the fight starts
## (move, dash, cast at a training target, Perfect Dodge a slow shot from a pylon).
## The room's real wave is held back by WaveManager.hold_wave until the lessons end;
## [signal finished] tells the parent to release it. Holding the skip action ends the
## lessons at once, from either phase.
##
## Lessons tick when the player actually does them, in any order; the card always
## shows the first unticked one. Grid lessons tick on their own when the fight starts,
## because confirming the grid is what starts it.
##
## Wiring lives in debug_game_loop._start_tutorial_room() (parent owns cross-node
## signals and the room's nodes). The bookkeeping (notify / current_step / hint_text /
## pick_spots) needs no scene tree, so tests drive it headless.
class_name TutorialRoom
extends Node

## Emitted once when the lessons end. [param skipped] is true when the player held skip.
signal finished(skipped: bool)

enum Phase { NONE, PREP, COMBAT }

## Lesson ids, in display order. Copy for each is UICopy.tutorial_steps_kb/_pad[i].
const STEPS: Array[StringName] = [
	&"place", &"confirm", &"move", &"dash", &"cast", &"perfect_dodge",
]
## Phase in which each lesson is shown (same order as STEPS).
const STEP_PHASES: Array[Phase] = [
	Phase.PREP, Phase.PREP, Phase.COMBAT, Phase.COMBAT, Phase.COMBAT, Phase.COMBAT,
]
## Action whose key/button fills the lesson's %s (&"" = none; "move" uses the move keys).
const STEP_ACTIONS: Array[StringName] = [
	&"", &"prana_confirm", &"move", &"dash", &"cast", &"dash",
]
## Input action held to skip the lessons (registered by the game loop).
const SKIP_ACTION: StringName = &"tutorial_skip"

const TUNING: TutorialRoomTuning = preload("res://assets/data/tutorial_room_tuning.tres")
const _COPY: UICopy = preload("res://assets/data/ui_copy.tres")

## Fayde, polled for movement and dashing. Set by the parent.
var player: Node2D = null
## Lesson card on the HUD layer; null in headless tests. Set by the parent.
var panel: TutorialRoomPanel = null
## Room entity layer that training targets and the pylon are added to. Set by the parent.
var arena: Node2D = null
## Candidate world positions for targets and the pylon (the room's spawn markers).
var spots: Array[Vector2] = []

var _done: Dictionary[StringName, bool] = {}
var _shown: StringName = &""
var _tick_hold: float = 0.0
var _last_player_pos: Vector2 = Vector2.INF
var _moved: float = 0.0
var _bag_size: int = -1
var _skip_held: float = 0.0
var _finished: bool = false
## Instance ids of every training target this room spawned, dead or alive.
var _target_ids: Dictionary[int, bool] = {}
var _targets: Array[DummyEnemy] = []
var _turret: TutorialTurret = null
## Seconds left before each destroyed target returns, and where it returns to.
var _respawn_timers: Array[float] = []
var _respawn_spots: Array[Vector2] = []


func _init() -> void:
	for id: StringName in STEPS:
		_done[id] = false


func _ready() -> void:
	InputPrompts.device_changed.connect(_on_device_changed)


func _exit_tree() -> void:
	if InputPrompts.device_changed.is_connected(_on_device_changed):
		InputPrompts.device_changed.disconnect(_on_device_changed)


func _process(delta: float) -> void:
	if _finished:
		return
	_tick_skip(delta)
	if _finished:
		return
	_tick_respawns(delta)
	var phase: Phase = _current_phase()
	if phase == Phase.COMBAT:
		_track_moves()
	else:
		_last_player_pos = Vector2.INF
	if _tick_hold > 0.0:
		_tick_hold -= delta
		return
	var step: StringName = current_step()
	if step != _shown:
		_show(step)
	if is_instance_valid(_turret):
		_turret.active = phase == Phase.COMBAT and step == &"perfect_dodge"
		if _turret.shots_fired >= TUNING.dodge_fallback_shots:
			notify(&"perfect_dodge")


## Ticks [param step]. Unknown or already-ticked lessons are ignored. Returns true
## when this call ticked one. Ticking the last lesson ends the room's tutorial.
func notify(step: StringName) -> bool:
	if _finished or not _done.has(step) or _done[step]:
		return false
	_done[step] = true
	if is_inside_tree():
		Sfx.play(&"sfx_orb_pickup")
	if step == _shown and panel != null:
		panel.tick()
		_tick_hold = TUNING.tick_hold_sec
	if is_done():
		_finish(false)
	return true


func is_step_done(step: StringName) -> bool:
	return _done.get(step, false)


func is_done() -> bool:
	for id: StringName in STEPS:
		if not _done[id]:
			return false
	return true


func is_finished() -> bool:
	return _finished


## First unticked lesson in display order; &"" when none is left.
func current_step() -> StringName:
	for id: StringName in STEPS:
		if not _done[id]:
			return id
	return &""


## Number of ticked lessons.
func done_count() -> int:
	var n: int = 0
	for id: StringName in STEPS:
		if _done[id]:
			n += 1
	return n


## True when [param instance_id] is one of this room's training targets, so the
## game loop keeps them out of the Spellbook and records.
func is_target(instance_id: int) -> bool:
	return _target_ids.has(instance_id)


## Ends the lessons now, as if the player held skip. No-op once finished.
func skip() -> void:
	_finish(true)


## Ends the lessons without [signal finished], e.g. when a tool or debug key moves
## Fayde out of the room mid-lesson. Nothing is saved; the caller frees this node.
func cancel() -> void:
	if _finished:
		return
	_finished = true
	_clear_training()
	if panel != null:
		panel.close()
		panel = null


## Lesson line for [param step] on the keyboard or the pad, with the bound key or
## button filled in. Empty for an unknown step.
static func hint_text(step: StringName, pad: bool) -> String:
	var i: int = STEPS.find(step)
	if i < 0:
		return ""
	var lines: Array[String] = _COPY.tutorial_steps_pad if pad else _COPY.tutorial_steps_kb
	var text: String = lines[i] if i < lines.size() else String(step)
	if step == &"place" and pad and text.count("%s") == 2:
		return text % [InputPrompts.pad_label(&"prana_type_cycle", "RB"),
			InputPrompts.pad_label(&"prana_place", "A")]
	if not text.contains("%s"):
		return text
	var action: StringName = STEP_ACTIONS[i]
	var label: String
	if action == &"move":
		label = InputPrompts.move_keys_label()
	elif pad:
		label = InputPrompts.pad_label(action)
	else:
		label = InputPrompts.key_label(action)
	return text % label


## Second, smaller line for [param step]; empty for an unknown step.
static func detail_text(step: StringName) -> String:
	var i: int = STEPS.find(step)
	var lines: Array[String] = _COPY.tutorial_details
	return lines[i] if i >= 0 and i < lines.size() else ""


## Skip prompt for the keyboard or the pad.
static func skip_text(pad: bool) -> String:
	var label: String = InputPrompts.pad_label(SKIP_ACTION, "Back") if pad \
		else InputPrompts.key_label(SKIP_ACTION, "Backspace")
	return _COPY.tutorial_skip_format % label


## Picks the pylon spot and up to [param count] target spots from [param candidates]:
## targets are the nearest spots at least [param min_dist] from [param origin]; the
## pylon takes the remaining spot whose distance is closest to [param turret_dist].
## Returns { "targets": Array[Vector2], "turret": Vector2 } (turret = origin when no
## spot is left). Pure, so tests cover it without a room.
static func pick_spots(origin: Vector2, candidates: Array[Vector2], count: int,
		min_dist: float, turret_dist: float) -> Dictionary:
	var far: Array[Vector2] = []
	for p: Vector2 in candidates:
		if p.distance_to(origin) >= min_dist:
			far.append(p)
	far.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_to(origin) < b.distance_to(origin))
	var targets: Array[Vector2] = []
	for p: Vector2 in far:
		if targets.size() >= count:
			break
		targets.append(p)
	var turret: Vector2 = origin
	var best: float = INF
	for p: Vector2 in far:
		if targets.has(p):
			continue
		var err: float = absf(p.distance_to(origin) - turret_dist)
		if err < best:
			best = err
			turret = p
	if best == INF and not targets.is_empty():
		# Too few spots: the pylon shares the farthest target's spot, nudged aside.
		turret = targets[targets.size() - 1] + Vector2(0.0, -40.0)
	return {"targets": targets, "turret": turret}


# ── Signal adapters (argument lists match the source signals) ─────────────────

## Starting the fight means the grid was locked: ticks both grid lessons and puts the
## training targets and the pylon in the room.
func on_combat_started(_is_boss: bool) -> void:
	notify(&"place")
	notify(&"confirm")
	if not _finished:
		_spawn_training()


## A Prana leaving the bag while the grid is open means one was placed.
func on_bag_changed(items: Array) -> void:
	var size: int = items.size()
	if _bag_size >= 0 and size < _bag_size and _current_phase() != Phase.COMBAT:
		notify(&"place")
	_bag_size = size


func on_damage_taken(target: Node, _final_damage: int, _current_hp: int) -> void:
	if is_instance_valid(target) and is_target(target.get_instance_id()):
		notify(&"cast")


func on_perfect_dodge(_world_pos: Vector2) -> void:
	notify(&"perfect_dodge")


# ── Private ───────────────────────────────────────────────────────────────────

func _track_moves() -> void:
	if not is_instance_valid(player):
		return
	if not _done[&"move"]:
		if _last_player_pos != Vector2.INF:
			_moved += player.global_position.distance_to(_last_player_pos)
			if _moved >= TUNING.move_distance:
				notify(&"move")
		_last_player_pos = player.global_position
	if not _done[&"dash"] and player.has_method(&"is_dashing") and player.is_dashing():
		notify(&"dash")


func _tick_skip(delta: float) -> void:
	if InputMap.has_action(SKIP_ACTION) and Input.is_action_pressed(SKIP_ACTION):
		_skip_held += delta
	else:
		_skip_held = 0.0
	if panel != null:
		panel.set_skip_progress(_skip_held / maxf(TUNING.skip_hold_sec, 0.01))
	if _skip_held >= TUNING.skip_hold_sec:
		skip()


func _tick_respawns(delta: float) -> void:
	for i: int in range(_respawn_timers.size() - 1, -1, -1):
		_respawn_timers[i] -= delta
		if _respawn_timers[i] <= 0.0:
			var pos: Vector2 = _respawn_spots[i]
			_respawn_timers.remove_at(i)
			_respawn_spots.remove_at(i)
			_spawn_target(pos)


func _spawn_training() -> void:
	if not is_instance_valid(arena) or not is_instance_valid(player):
		return
	var picked: Dictionary = pick_spots(player.global_position, spots, TUNING.target_count,
		TUNING.target_min_distance, TUNING.turret_distance)
	for p: Vector2 in picked["targets"]:
		_spawn_target(p)
	_turret = TutorialTurret.new()
	_turret.name = "TutorialTurret"
	_turret.player = player
	arena.add_child(_turret)
	_turret.global_position = picked["turret"]


## ADR-0007 spawn contract: register with H&D before add_child.
func _spawn_target(pos: Vector2) -> void:
	if not is_instance_valid(arena):
		return
	var t := DummyEnemy.new()
	t.hp_mult = TUNING.target_hp_mult
	HealthAndDamage.register_enemy(t, DummyEnemy.DUMMY_TYPE_ID, TUNING.target_hp_mult)
	_target_ids[t.get_instance_id()] = true
	arena.add_child(t)
	t.global_position = pos
	t.dummy_killed.connect(_on_target_killed.bind(t, pos), CONNECT_ONE_SHOT)
	_targets.append(t)


func _on_target_killed(t: DummyEnemy, pos: Vector2) -> void:
	_targets.erase(t)
	if not _finished:
		_respawn_timers.append(TUNING.target_respawn_sec)
		_respawn_spots.append(pos)


func _finish(skipped: bool) -> void:
	if _finished:
		return
	_finished = true
	_clear_training()
	if panel != null:
		if skipped:
			panel.close()
		else:
			panel.show_done(_COPY.tutorial_done, TUNING.done_hold_sec)
	finished.emit(skipped)


## Removes the targets and the pylon. Live targets leave the H&D registry first so
## nothing counts them afterwards.
func _clear_training() -> void:
	_respawn_timers.clear()
	_respawn_spots.clear()
	for t: DummyEnemy in _targets:
		if is_instance_valid(t):
			HealthAndDamage.unregister_enemy(t.get_instance_id())
			t.remove_from_group(&"enemy")
			t.queue_free()
	_targets.clear()
	if is_instance_valid(_turret):
		_turret.queue_free()
	_turret = null


func _on_device_changed(_using_pad: bool) -> void:
	if not _finished and _tick_hold <= 0.0:
		_show(_shown)


func _show(step: StringName) -> void:
	_shown = step
	if panel == null or step == &"":
		return
	var pad: bool = InputPrompts.using_pad
	panel.show_step(_COPY.tutorial_heading % [done_count() + 1, STEPS.size()],
		hint_text(step, pad), detail_text(step), skip_text(pad))


func _current_phase() -> Phase:
	if not is_inside_tree():
		return Phase.NONE
	var gsm: Node = get_node_or_null(^"/root/GameStateManager")
	if gsm == null:
		return Phase.NONE
	match gsm.get_active_state():
		GameEnums.GameState.PREPARATION_PHASE:
			return Phase.PREP
		GameEnums.GameState.COMBAT_PHASE:
			return Phase.COMBAT
	return Phase.NONE
