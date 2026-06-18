## spell_vfx.gd — SpellVFX Autoload #10.
## Visual routing layer for spell cast readiness and hit feedback (GDD Rule 1,
## Visual/Audio Requirements Quick Spec 2026-06-12).
##
## Listens to SC&E signals and routes them to the correct visual systems:
##   - cast_started      → modulate pulse on Fayde (cast readiness cue)
##   - spell_hit_element → per-type GPUParticles2D hit burst at target position
##   - cast_hit_started  → stub (FP; MVP: flash Fayde cast-lock indicator)
##
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0015 (SpellVFX Particle Pool)
## Story: SC&E Story 005 — Prana Type Visual Differentiation (S5-03)
##        S7-05 — SpellVFX particle pre-pool (PERF-C1 fix)
##
## Registration: Autoload #10 in project.godot (after SpellCastingEffects).
## No class_name — Godot 4.6 rejects class_name matching the Autoload node name.
extends Node


# Pre-allocated pool: one GPUParticles2D per VfxBurstShape (indices 0–4).
# Shape params and materials are fully configured at _ready(). Hot path is zero-allocation:
# only modulate color and global_position change per hit.
var _pool: Dictionary = {}

# ── Hitstop / Screen shake / Procedural VFX ───────────────────────────────────

## Wall-clock duration per Prana type (microseconds). Index matches GameEnums.DamageClass.
const VFX_DURATION_US: Array[int] = [
	300_000,   ## 0 Ashfire — radial burst around Fayde
	400_000,   ## 1 Voidblue — shadow ring expands then fades
	150_000,   ## 2 Stormgold — quick lightning snap
	350_000,   ## 3 Deepfrost — ice shards radiate from target
	400_000,   ## 4 Verdant — bloom circle from Fayde
]

## Seconds the game slows to on each spell hit.
const HITSTOP_DURATION_US: int = 80_000
## Near-freeze scale (not exactly 0 so _process still runs on PROCESS_MODE_ALWAYS nodes).
const HITSTOP_TIME_SCALE: float = 0.05
## Seconds of decaying camera shake per hit.
const SHAKE_DURATION_US: int = 180_000
## Max camera offset at shake peak (pixels).
const SHAKE_AMPLITUDE: float = 4.0

var _camera: Camera2D = null
var _in_hitstop: bool = false
var _hitstop_end_us: int = 0
var _shake_end_us: int = 0

## Multiplier applied to VFX, hitstop, and shake when the final chain attack lands.
const COMBO_ENDER_AMPLIFY: float = 1.5

## Tracked from chain_index_changed — true when the next hit is the final chain attack.
var _next_is_ender: bool = false


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	SpellCastingEffects.cast_started.connect(_on_cast_started)
	SpellCastingEffects.spell_hit_element.connect(_on_spell_hit_element)
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)
	SpellCastingEffects.chain_index_changed.connect(_on_chain_index_changed)
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	_init_pool()
	# Camera is looked up lazily on first shake — autoload _ready() fires before
	# the game scene (and player) exist, so get_first_node_in_group would return null here.


func _process(_delta: float) -> void:
	_tick_hitstop()
	_tick_shake()


func _exit_tree() -> void:
	if SpellCastingEffects.cast_started.is_connected(_on_cast_started):
		SpellCastingEffects.cast_started.disconnect(_on_cast_started)
	if SpellCastingEffects.spell_hit_element.is_connected(_on_spell_hit_element):
		SpellCastingEffects.spell_hit_element.disconnect(_on_spell_hit_element)
	if SpellCastingEffects.cast_hit_started.is_connected(_on_cast_hit_started):
		SpellCastingEffects.cast_hit_started.disconnect(_on_cast_hit_started)
	if HealthAndDamage.damage_taken.is_connected(_on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(_on_damage_taken)
	if SpellCastingEffects.chain_index_changed.is_connected(_on_chain_index_changed):
		SpellCastingEffects.chain_index_changed.disconnect(_on_chain_index_changed)
	if _in_hitstop:
		Engine.time_scale = 1.0


# ── Signal handlers ────────────────────────────────────────────────────────────

## Brief modulate pulse on Fayde when a cast begins.
## Uses a color tween (not alpha) so PlayerController._physics_process alpha-reset
## (guards the i-frame blink system) does not kill the pulse mid-flight.
## [param _spell_effect] reserved for per-type pulse color at MVP scope.
func _on_cast_started(_spell_effect: SpellEffect) -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is CanvasItem:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player as CanvasItem, "modulate", Color(1.5, 1.5, 2.5, 1.0), 0.05)
	tween.tween_property(player as CanvasItem, "modulate", Color.WHITE, 0.10)


## Zero-allocation hot path (ADR-0015): looks up pool node by shape,
## updates position and color, then restarts emission.
## Also triggers per-type procedural draw VFX, hitstop, and screen shake.
func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	var type_data: PranaType = PranaCatalog.get_type(prana_type_id)
	if type_data == null:
		push_warning("SpellVFX: PranaCatalog.get_type(%d) returned null — no burst." % prana_type_id)
		return
	var amplify: float = COMBO_ENDER_AMPLIFY if _next_is_ender else 1.0
	_next_is_ender = false
	if target is Node2D:
		_reuse_from_pool((target as Node2D).global_position, type_data)
		_spawn_hit_vfx(target as Node2D, prana_type_id)
	_start_hitstop(amplify)
	_start_shake(amplify)


## Tints Fayde blue-grey for _lock_duration seconds to signal post-hit movement dampening.
## Uses color tween (alpha stays 1.0) so PlayerController alpha-reset does not interfere.
func _on_cast_hit_started(_lock_duration: float) -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is CanvasItem:
		return
	var tween: Tween = create_tween()
	tween.tween_property(player as CanvasItem, "modulate", Color(0.7, 0.7, 1.1, 1.0), 0.0)
	tween.tween_property(player as CanvasItem, "modulate", Color.WHITE, _lock_duration)


## Tracks chain state so _on_spell_hit_element can detect and amplify the final attack.
## When combo_idx == combo_count (the final attack just fired), mark _next_is_ender.
func _on_chain_index_changed(combo_idx: int, combo_count: int) -> void:
	if combo_idx > 0 and combo_idx == combo_count:
		_next_is_ender = true


## Flashes the damaged entity: red on player, white on enemy.
## Fires from HealthAndDamage.damage_taken — zero-allocation hot path via Tween.
## Enemies with an active _vfx_tween (contact/telegraph) would override a plain
## modulate tween — duck-type to request_hit_flash() to let the enemy manage its
## own VFX state correctly.
func _on_damage_taken(target: Node, _final_damage: int, _current_hp: int) -> void:
	if not target is CanvasItem:
		return
	var ci: CanvasItem = target as CanvasItem
	if target.is_in_group(&"player"):
		var tw: Tween = create_tween()
		tw.tween_property(ci, "modulate", Color(2.0, 0.25, 0.25, 1.0), 0.0)
		tw.tween_property(ci, "modulate", Color.WHITE, 0.18)
	else:
		if target.has_method(&"request_hit_flash"):
			target.request_hit_flash()
		else:
			_flash_enemy_white(ci)


# ── Pool ──────────────────────────────────────────────────────────────────────

## Pre-creates one GPUParticles2D + ParticleProcessMaterial per VfxBurstShape.
## All shape params configured here — nothing created on the hot path after this.
func _init_pool() -> void:
	for shape: int in GameEnums.VfxBurstShape.values():
		var node := GPUParticles2D.new()
		var mat := ParticleProcessMaterial.new()
		node.one_shot = true
		node.emitting = false
		node.process_material = mat
		mat.gravity = Vector3(0.0, 0.0, 0.0)
		_apply_burst_shape_params(node, mat, shape)
		add_child(node)
		_pool[shape] = node


## Hot path: teleport pool node, update color, restart.
## No allocation. Concurrent same-shape hits restart the previous burst.
func _reuse_from_pool(pos: Vector2, type_data: PranaType) -> void:
	var shape: int = type_data.vfx_burst_shape
	if not _pool.has(shape):
		push_warning("SpellVFX: no pool node for shape %d — skipping burst." % shape)
		return
	var node: GPUParticles2D = _pool[shape]
	node.global_position = pos
	node.modulate = type_data.color
	node.restart()
	node.emitting = true


# ── Private helpers ────────────────────────────────────────────────────────────

## Applies per-shape physics parameters. Called once per pool slot at init.
func _apply_burst_shape_params(burst: GPUParticles2D, mat: ParticleProcessMaterial, shape: int) -> void:
	match shape:
		GameEnums.VfxBurstShape.BURST_FLAME:
			burst.amount = 12
			burst.lifetime = 0.3
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 90.0
			mat.initial_velocity_min = 120.0
			mat.initial_velocity_max = 180.0
			mat.gravity = Vector3(0.0, 40.0, 0.0)
		GameEnums.VfxBurstShape.BURST_SPIRAL:
			burst.amount = 8
			burst.lifetime = 0.35
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 180.0
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 80.0
		GameEnums.VfxBurstShape.BURST_LIGHTNING:
			burst.amount = 6
			burst.lifetime = 0.15
			mat.direction = Vector3(1.0, 0.0, 0.0)
			mat.spread = 30.0
			mat.initial_velocity_min = 200.0
			mat.initial_velocity_max = 300.0
		GameEnums.VfxBurstShape.BURST_CRYSTAL:
			burst.amount = 8
			burst.lifetime = 0.4
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 180.0
			mat.initial_velocity_min = 40.0
			mat.initial_velocity_max = 80.0
		GameEnums.VfxBurstShape.BURST_VINE:
			burst.amount = 10
			burst.lifetime = 0.3
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 90.0
			mat.initial_velocity_min = 60.0
			mat.initial_velocity_max = 100.0
			mat.gravity = Vector3(0.0, 20.0, 0.0)
		_:
			burst.amount = 8
			burst.lifetime = 0.3
			mat.direction = Vector3(0.0, -1.0, 0.0)
			mat.spread = 180.0
			mat.initial_velocity_min = 80.0
			mat.initial_velocity_max = 120.0


## Overbrightens [param ci] to white then returns it to normal over 0.1 s.
## Called for enemy nodes — reuses any existing modulate without conflict because
## the tween immediately sets Color.WHITE as its final state.
func _flash_enemy_white(ci: CanvasItem) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(ci, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.0)
	tw.tween_property(ci, "modulate", Color.WHITE, 0.10)


# ── Hitstop ───────────────────────────────────────────────────────────────────

func _start_hitstop(amplify: float = 1.0) -> void:
	# No early-return guard — rapid hits reset/extend the timer so every hit lands.
	Engine.time_scale = HITSTOP_TIME_SCALE
	_in_hitstop = true
	_hitstop_end_us = Time.get_ticks_usec() + int(HITSTOP_DURATION_US * amplify)


func _tick_hitstop() -> void:
	if _in_hitstop and Time.get_ticks_usec() >= _hitstop_end_us:
		Engine.time_scale = 1.0
		_in_hitstop = false


# ── Screen shake ──────────────────────────────────────────────────────────────

func _start_shake(amplify: float = 1.0) -> void:
	_shake_end_us = Time.get_ticks_usec() + int(SHAKE_DURATION_US * amplify)


func _tick_shake() -> void:
	if _camera == null:
		# Lazy lookup — autoload _ready() fires before the player exists.
		if get_tree() != null:
			var player: Node = get_tree().get_first_node_in_group(&"player")
			if player != null and player is Node2D:
				_camera = (player as Node2D).get_node_or_null("Camera2D") as Camera2D
	if _camera == null:
		return
	var now: int = Time.get_ticks_usec()
	if now < _shake_end_us:
		var progress: float = float(_shake_end_us - now) / float(SHAKE_DURATION_US)
		var strength: float = SHAKE_AMPLITUDE * progress
		_camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


# ── Procedural per-type draw VFX ──────────────────────────────────────────────

## Spawns a _HitVFX node that draws procedurally for its configured duration.
## Ashfire (0) and Verdant (4) radiate from Fayde — children of the player so
## they inherit world position. All other types anchor to target via top_level.
func _spawn_hit_vfx(target: Node2D, type_id: int) -> void:
	if type_id < 0 or type_id >= VFX_DURATION_US.size():
		return
	if get_tree() == null:
		return
	var vfx := _HitVFX.new()
	vfx.type_id = type_id
	vfx.duration_us = VFX_DURATION_US[type_id]
	if type_id == 0 or type_id == 4:
		# Ashfire / Verdant: radiate from Fayde
		var player: Node = get_tree().get_first_node_in_group(&"player")
		if player != null and player is Node2D:
			(player as Node2D).add_child(vfx)
			vfx.position = Vector2.ZERO
		else:
			vfx.free()
			return
	else:
		# Other types: anchor to target world position
		vfx.top_level = true
		if get_tree().root != null:
			get_tree().root.add_child(vfx)
		else:
			vfx.free()
			return
		vfx.global_position = target.global_position


# ── Inner class: single procedural VFX instance ───────────────────────────────

class _HitVFX extends Node2D:
	var type_id: int = 0
	var duration_us: int = 300_000
	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 100
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= duration_us:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var p: float = clampf(float(Time.get_ticks_usec() - _start_us) / float(duration_us), 0.0, 1.0)
		match type_id:
			0: _draw_ashfire(p)
			1: _draw_voidblue(p)
			2: _draw_stormgold(p)
			3: _draw_deepfrost(p)
			4: _draw_verdant(p)

	## Ashfire: 6 orange spokes radiating from Fayde — melee burst identity (80px range).
	func _draw_ashfire(p: float) -> void:
		var alpha: float = 1.0 - p
		var inner: float = 8.0 + p * 12.0
		var outer: float = 22.0 + p * 48.0
		for i: int in 6:
			var angle: float = (TAU / 6.0) * float(i)
			var dir: Vector2 = Vector2.from_angle(angle)
			draw_line(dir * inner, dir * outer, Color(1.0, 0.45, 0.0, alpha), 3.0, true)
		draw_arc(Vector2.ZERO, inner + (outer - inner) * 0.3, 0.0, TAU, 18,
				Color(1.0, 0.7, 0.1, alpha * 0.5), 2.0, true)

	## Voidblue: expanding ring that fades — shadow presence pulse.
	func _draw_voidblue(p: float) -> void:
		var alpha: float = 1.0 - p
		var radius: float = p * 32.0
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 20, Color(0.4, 0.1, 0.8, alpha), 2.5, true)
		draw_arc(Vector2.ZERO, radius * 0.55, 0.0, TAU, 16, Color(0.6, 0.2, 1.0, alpha * 0.4), 1.5, true)

	## Stormgold: 4 jagged lightning spokes with center flash — instant snap identity.
	func _draw_stormgold(p: float) -> void:
		var alpha: float = 1.0 - p
		var total_len: float = 28.0 + p * 8.0
		for i: int in 4:
			var angle: float = (TAU / 4.0) * float(i) + PI / 8.0
			var dir: Vector2 = Vector2.from_angle(angle)
			var perp: Vector2 = dir.rotated(PI / 2.0)
			var pts: PackedVector2Array = PackedVector2Array()
			for s: int in 5:
				var t: float = float(s) / 4.0
				var zigzag: float = 4.0 * (1.0 if s % 2 == 0 else -1.0) * (1.0 - t)
				pts.append(dir * (t * total_len) + perp * zigzag)
			draw_polyline(pts, Color(1.0, 0.92, 0.15, alpha), 2.0, true)
		draw_circle(Vector2.ZERO, 4.0 * (1.0 - p), Color(1.0, 1.0, 0.5, alpha))

	## Deepfrost: 4 ice shard triangles shooting out from impact point.
	func _draw_deepfrost(p: float) -> void:
		var alpha: float = 1.0 - p
		for i: int in 4:
			var angle: float = (TAU / 4.0) * float(i)
			var dir: Vector2 = Vector2.from_angle(angle)
			var perp: Vector2 = dir.rotated(PI / 2.0)
			var tip: Vector2 = dir * (12.0 + p * 28.0)
			var base_c: Vector2 = dir * (4.0 + p * 8.0)
			var hw: float = 5.0 * (1.0 - p * 0.6)
			draw_colored_polygon(
				PackedVector2Array([tip, base_c + perp * hw, base_c - perp * hw]),
				Color(0.3, 0.75, 1.0, alpha)
			)
		draw_arc(Vector2.ZERO, 6.0 + p * 10.0, 0.0, TAU, 16, Color(0.6, 0.9, 1.0, alpha * 0.4), 1.5, true)

	## Verdant: expanding circle bloom from Fayde — growth/healing identity.
	func _draw_verdant(p: float) -> void:
		var alpha: float = 1.0 - p
		var radius: float = 8.0 + p * 44.0
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(0.1, 0.85, 0.2, alpha), 2.5, true)
		for i: int in 5:
			var angle: float = (TAU / 5.0) * float(i)
			draw_line(Vector2.ZERO, Vector2.from_angle(angle) * radius * 0.65,
					Color(0.3, 1.0, 0.4, alpha * 0.5), 1.5, true)
