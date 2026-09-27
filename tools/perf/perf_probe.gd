## perf_probe.gd — Scripted performance probe for the busiest fights (beta plan 4.3).
##
## Loads main.tscn, starts a run, jumps to Floor 3 and plays one scenario with a bot
## (Fayde circles the arena and casts on a beat, god mode on), then prints one
## "PERF_RESULT {json}" line with frame-time stats. Not part of the game flow.
##
## Scenarios: floor3 (a Floor 3 combat room) and keeper_p4 (Cipher Keeper, pinned in
## its last HP phase). Options come from user args (native: `-- scenario=keeper_p4`)
## or the page query string on the web build (`?scenario=keeper_p4&seconds=20`):
##   scenario, seconds (sample length), warmup (seconds skipped), variant (keeper
##   variant id), lights (0 = FloorLighting off), outline (1 = high-contrast bullets),
##   uncap (1 = Engine.max_fps 0 and vsync off, for headroom on native).
extends Node

const MAIN_SCENE: PackedScene = preload("res://src/scenes/main.tscn")
const FLOOR_LIGHTING_TUNING: FloorLightingTuning = preload("res://assets/data/floor_lighting_tuning.tres")
const KEEPER_TYPE_ID: int = 11
## Casts per second the bot presses.
const CAST_RATE: float = 3.0
## Seconds per bot orbit around the arena centre.
const ORBIT_SEC: float = 4.0

var _opts: Dictionary = {
	"scenario": "floor3", "seconds": "20", "warmup": "3", "variant": "tempest",
	"lights": "1", "outline": "0", "uncap": "0", "render": "1", "n": "200", "shot": "",
}
## Bullet stress scenario: the arena that holds the bullets and their pool.
var _arena: Node2D = null
var _stress_pool: BulletPool = null
var _stress_pattern: BulletPattern = null
var _main: Node = null
var _boss: Node2D = null
var _pin_ratio: float = 1.0
var _sampling: bool = false
var _t: float = 0.0
var _cast_acc: float = 0.0
var _frames: PackedFloat32Array = PackedFloat32Array()
var _proc_ms: PackedFloat32Array = PackedFloat32Array()
var _phys_ms: PackedFloat32Array = PackedFloat32Array()
var _bullets_max: int = 0
var _bullets_sum: int = 0
var _nodes_max: int = 0
var _draw_calls_max: int = 0
var _draw_calls_sum: int = 0
var _objects_max: int = 0
var _last_us: int = 0
var _cast_down: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_read_options()
	var lighting: FloorLightingTuning = FLOOR_LIGHTING_TUNING
	lighting.enabled = _opts["lights"] != "0"
	var s: GameSettings = GameSettings.active()
	s.bullet_outline = _opts["outline"] == "1"
	if _opts["render"] == "0":
		RenderingServer.render_loop_enabled = false
	if _opts["scenario"] == "bullets":
		_run_bullets.call_deferred()
	else:
		_run.call_deferred()


## Keeps n enemy bullets in flight around a stand-in Fayde, nothing else running.
## Isolates the per-bullet cost from enemies, HUD and lights.
func _run_bullets() -> void:
	seed(7)
	_arena = Node2D.new()
	add_child(_arena)
	var fake_player := Node2D.new()
	fake_player.position = Vector2(-5000, -5000)  # far away: no hits, no grazes
	fake_player.add_to_group(&"player")
	_arena.add_child(fake_player)
	_stress_pattern = BulletPattern.new()
	_stress_pattern.max_range = 100000.0
	_stress_pool = BulletPool.for_parent(_arena)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2.0, 2.0)
	_arena.add_child(cam)
	cam.make_current()
	await _frames_wait(3)
	await _seconds(float(_opts["warmup"]))
	_sampling = true
	_last_us = Time.get_ticks_usec()
	await _seconds(float(_opts["seconds"]))
	_sampling = false
	_report()


func _top_up_bullets() -> void:
	var want: int = int(_opts["n"])
	var have: int = get_tree().get_node_count_in_group(Projectile.GROUP)
	for i: int in want - have:
		var b: Projectile = _stress_pool.acquire()
		if b == null:
			return
		b.position = Vector2(randf_range(-200, 200), randf_range(-120, 120))
		# Slow orbit-ish drift keeps every bullet in flight for the whole sample.
		b.launch_pattern(Vector2.from_angle(randf() * TAU), 1.0, _stress_pattern, 20.0)


func _run() -> void:
	_main = MAIN_SCENE.instantiate()
	add_child(_main)
	await _frames_wait(3)
	_main.call(&"_begin_run")
	_main.call(&"_on_core_picked", 0)
	HealthAndDamage._debug_god_mode = true
	# After main.tscn applied the player's display settings (fps cap, vsync).
	if _opts["uncap"] == "1":
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await _seconds(1.5)
	await _jump_to_floor3()
	var wm: Node = _main.get_node(^"WaveManager")
	if _opts["scenario"] == "keeper_p4":
		wm.set(&"room_type", DungeonGraph.ROOM_TYPE_BOSS)
		wm.set(&"is_final_room", true)
		var variants: Dictionary = wm.get(&"boss_variants")
		var profile: BossProfile = BossDirector.ROSTER.profile_for(KEEPER_TYPE_ID)
		for v: BossVariant in profile.variants:
			if String(v.id) == _opts["variant"]:
				variants[KEEPER_TYPE_ID] = v
		wm.connect(&"boss_spawned", _on_boss_spawned)
		# Preparation already built a Floor 3 wave; rebuild it from the boss pool.
		wm.call(&"_build_wave_composition")
	await _confirm_grid()
	if _opts["scenario"] == "keeper_p4":
		while _boss == null:
			await get_tree().process_frame
		_pin_boss()
	await _seconds(float(_opts["warmup"]))
	_sampling = true
	_last_us = Time.get_ticks_usec()
	await _seconds(float(_opts["seconds"]))
	_sampling = false
	_release_inputs()
	_report()


func _process(delta: float) -> void:
	if _stress_pool != null:
		_top_up_bullets()
	elif _main == null or not _main.is_inside_tree():
		return
	else:
		_drive_bot(delta)
		if is_instance_valid(_boss):
			_hold_boss_hp()
	if not _sampling:
		return
	var now: int = Time.get_ticks_usec()
	_frames.append(float(now - _last_us) / 1000.0)
	_last_us = now
	_proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_phys_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	var bullets: int = get_tree().get_node_count_in_group(Projectile.GROUP)
	_bullets_max = maxi(_bullets_max, bullets)
	_bullets_sum += bullets
	_nodes_max = maxi(_nodes_max, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	var dc: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_draw_calls_max = maxi(_draw_calls_max, dc)
	_draw_calls_sum += dc
	_objects_max = maxi(_objects_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)))


# ── Scenario steps ────────────────────────────────────────────────────────────

func _jump_to_floor3() -> void:
	var rtm: RoomTransitionManager = _main.get_node(^"RoomTransitionManager") as RoomTransitionManager
	_main.set(&"_current_floor", 3)
	_main.call(&"_apply_floor_theme", rtm)
	var gen: DungeonGenerator = _main.get(&"_gen")
	var graph: DungeonGraph = gen.generate(int(_main.get(&"_floor_room_count")), 3)
	_main.set(&"_dungeon_graph", graph)
	GameStateManager.set_is_final_floor(true)
	_main.call(&"_apply_floor_pool_config")
	rtm.load_floor(graph)
	await rtm.room_transition_completed
	await _seconds(0.5)


func _confirm_grid() -> void:
	await _seconds(0.5)
	_send_action(&"prana_confirm", true)
	await _frames_wait(2)
	_send_action(&"prana_confirm", false)
	await _seconds(0.3)
	if GameStateManager.get_active_state() != GameEnums.GameState.COMBAT_PHASE:
		GameStateManager.receive_arrangement_confirmed()


func _on_boss_spawned(boss: Node) -> void:
	if int(boss.call(&"get_type_id")) == KEEPER_TYPE_ID:
		_boss = boss as Node2D


## Drops the Keeper just under its lowest phase threshold so every layer fires.
func _pin_boss() -> void:
	var lowest: float = 1.0
	for t: float in _boss.call(&"get_phase_thresholds"):
		lowest = minf(lowest, t)
	_pin_ratio = maxf(lowest - 0.04, 0.02)
	var max_hp: int = HealthAndDamage._get_max_hp(_boss)
	var cur: int = HealthAndDamage._get_current_hp(_boss)
	var dmg: int = cur - int(float(max_hp) * _pin_ratio)
	if dmg > 0:
		HealthAndDamage.apply_damage(_boss, float(dmg), GameEnums.DamageClass.NONE,
			GameEnums.DamageSource.CONTACT)


## Casts keep chipping the boss; heal it back so it never dies mid-sample.
func _hold_boss_hp() -> void:
	var max_hp: int = HealthAndDamage._get_max_hp(_boss)
	var want: int = int(float(max_hp) * _pin_ratio)
	var cur: int = HealthAndDamage._get_current_hp(_boss)
	if cur > 0 and cur < want - 2:
		HealthAndDamage.apply_heal(_boss, float(want - cur))


func _drive_bot(delta: float) -> void:
	if GameStateManager.get_active_state() != GameEnums.GameState.COMBAT_PHASE:
		return
	_t += delta
	var dir: Vector2 = Vector2.from_angle(_t / ORBIT_SEC * TAU)
	_press_axis(&"move_right", &"move_left", dir.x)
	_press_axis(&"move_down", &"move_up", dir.y)
	_cast_acc += delta * CAST_RATE
	if _cast_acc >= 1.0:
		_cast_acc -= 1.0
		_send_action(&"cast", true)
		_cast_down = true
	elif _cast_down:
		_send_action(&"cast", false)
		_cast_down = false


func _press_axis(pos_action: StringName, neg_action: StringName, v: float) -> void:
	if v > 0.2:
		Input.action_press(pos_action, v)
		Input.action_release(neg_action)
	elif v < -0.2:
		Input.action_press(neg_action, -v)
		Input.action_release(pos_action)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


## Feeds a real action event, so both _input handlers and Input polling see it.
func _send_action(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _release_inputs() -> void:
	for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"cast"]:
		Input.action_release(a)


# ── Report ────────────────────────────────────────────────────────────────────

func _report() -> void:
	if _opts["shot"] != "" and _opts["render"] != "0":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_opts["shot"])
	var n: int = _frames.size()
	var sorted: PackedFloat32Array = _frames.duplicate()
	sorted.sort()
	var total: float = 0.0
	for f: float in _frames:
		total += f
	var result: Dictionary = {
		"scenario": _opts["scenario"],
		"variant": _opts["variant"] if _opts["scenario"] == "keeper_p4" else "",
		"lights": _opts["lights"], "outline": _opts["outline"],
		"platform": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"frames": n,
		"avg_fps": snappedf(1000.0 * float(n) / maxf(total, 0.001), 0.1),
		"avg_ms": snappedf(total / maxf(float(n), 1.0), 0.01),
		"p50_ms": snappedf(_pct(sorted, 0.50), 0.01),
		"p95_ms": snappedf(_pct(sorted, 0.95), 0.01),
		"p99_ms": snappedf(_pct(sorted, 0.99), 0.01),
		"max_ms": snappedf(sorted[n - 1] if n > 0 else 0.0, 0.01),
		"frames_over_16_7": _count_over(_frames, 16.7),
		"frames_over_33_3": _count_over(_frames, 33.3),
		"process_ms_avg": snappedf(_avg(_proc_ms), 0.01),
		"physics_ms_avg": snappedf(_avg(_phys_ms), 0.01),
		"process_ms_p95": snappedf(_pct_of(_proc_ms, 0.95), 0.01),
		"bullets_max": _bullets_max,
		"bullets_avg": snappedf(float(_bullets_sum) / maxf(float(n), 1.0), 0.1),
		"nodes_max": _nodes_max,
		"draw_calls_max": _draw_calls_max,
		"draw_calls_avg": snappedf(float(_draw_calls_sum) / maxf(float(n), 1.0), 0.1),
		"objects_max": _objects_max,
		"boss_found": is_instance_valid(_boss),
		"boss_phase": int(_boss.get(&"_active_layer_count")) if is_instance_valid(_boss) else -1,
		"boss_pin_ratio": snappedf(_pin_ratio, 0.01),
	}
	print("PERF_RESULT ", JSON.stringify(result))
	print("PERF_CENSUS ", JSON.stringify(_census()))
	get_tree().quit()


## Visible CanvasItems grouped by script file (or class), largest groups first.
func _census() -> Array:
	var counts: Dictionary = {}
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var ci: CanvasItem = n as CanvasItem
		if ci == null or not ci.is_visible_in_tree():
			continue
		var scr: Script = ci.get_script() as Script
		var key: String = ci.get_class()
		if scr != null:
			key += ":" + scr.resource_path.get_file()
		counts[key] = int(counts.get(key, 0)) + 1
	var rows: Array = []
	for k: String in counts:
		rows.append([k, counts[k]])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[1] > b[1])
	return rows.slice(0, 15)


static func _pct(sorted: PackedFloat32Array, q: float) -> float:
	if sorted.is_empty():
		return 0.0
	return sorted[clampi(int(float(sorted.size() - 1) * q), 0, sorted.size() - 1)]


static func _pct_of(values: PackedFloat32Array, q: float) -> float:
	var s: PackedFloat32Array = values.duplicate()
	s.sort()
	return _pct(s, q)


static func _avg(values: PackedFloat32Array) -> float:
	if values.is_empty():
		return 0.0
	var t: float = 0.0
	for v: float in values:
		t += v
	return t / float(values.size())


static func _count_over(values: PackedFloat32Array, limit: float) -> int:
	var c: int = 0
	for v: float in values:
		if v > limit:
			c += 1
	return c


# ── Helpers ───────────────────────────────────────────────────────────────────

func _read_options() -> void:
	var pairs: PackedStringArray = OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if q is String and (q as String).length() > 1:
			pairs.append_array((q as String).substr(1).split("&"))
	for pair: String in pairs:
		var kv: PackedStringArray = pair.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2 and _opts.has(kv[0]):
			_opts[kv[0]] = kv[1]


func _seconds(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _frames_wait(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
