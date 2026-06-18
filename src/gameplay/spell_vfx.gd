## spell_vfx.gd — Procedural game-feel VFX for each Prana type hit.
## Per-type hit effects, screen shake, near-freeze hitstop, and enemy hit flash.
## Attached as Node2D child of PlayerController — inherits player world position,
## so Ashfire (radial burst) and Verdant (bloom) originate naturally from Fayde.
## Other types use top_level=true so they stay at the target's world position.
## All timing uses Time.get_ticks_usec() (wall-clock) — immune to Engine.time_scale.
## References: design/gdd/spell-casting-effects.md (per-type identity table)
class_name SpellVFX
extends Node2D


# ── Tuning knobs ──────────────────────────────────────────────────────────────

## Seconds the game slows to HITSTOP_TIME_SCALE on each spell hit.
const HITSTOP_DURATION_US: int = 50_000
## Near-freeze scale (not exactly 0 so _process still runs on PROCESS_MODE_ALWAYS nodes).
const HITSTOP_TIME_SCALE: float = 0.05
## Seconds of decaying camera shake per hit.
const SHAKE_DURATION_US: int = 180_000
## Max camera offset at shake peak (pixels).
const SHAKE_AMPLITUDE: float = 4.0
## Seconds the enemy modulate is overbrightened on hit.
const FLASH_DURATION_US: int = 100_000

## Wall-clock duration per Prana type (microseconds). Index matches GameEnums.DamageClass.
const VFX_DURATION_US: Array[int] = [
	300_000,   ## 0 Ashfire — radial burst around Fayde
	400_000,   ## 1 Voidblue — shadow ring expands then fades
	150_000,   ## 2 Stormgold — quick lightning snap
	350_000,   ## 3 Deepfrost — ice shards radiate from target
	400_000,   ## 4 Verdant — bloom circle from Fayde
]


# ── Inner class: single VFX instance ─────────────────────────────────────────

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


# ── Private state ─────────────────────────────────────────────────────────────

var _camera: Camera2D = null
var _in_hitstop: bool = false
var _hitstop_end_us: int = 0
var _shake_end_us: int = 0
## [{target: CanvasItem, end_us: int}] — pending flash restores
var _flash_entries: Array = []


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_camera = get_parent().get_node_or_null(&"Camera2D")
	SpellCastingEffects.spell_hit_element.connect(_on_spell_hit_element)


func _process(_delta: float) -> void:
	_tick_hitstop()
	_tick_shake()
	_tick_flashes()


func _exit_tree() -> void:
	if SpellCastingEffects.spell_hit_element.is_connected(_on_spell_hit_element):
		SpellCastingEffects.spell_hit_element.disconnect(_on_spell_hit_element)
	if _in_hitstop:
		Engine.time_scale = 1.0


# ── Signal handler ────────────────────────────────────────────────────────────

func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	_spawn_hit_vfx(target, prana_type_id)
	_flash_target(target)
	_start_hitstop()
	_start_shake()


# ── VFX spawn ─────────────────────────────────────────────────────────────────

func _spawn_hit_vfx(target: Node, type_id: int) -> void:
	if type_id < 0 or type_id >= VFX_DURATION_US.size():
		return
	var vfx := _HitVFX.new()
	vfx.type_id = type_id
	vfx.duration_us = VFX_DURATION_US[type_id]
	## Ashfire (0) and Verdant (4) radiate from Fayde — inherit PlayerController transform.
	## All other types anchor to the target's world position via top_level.
	if type_id == 0 or type_id == 4:
		add_child(vfx)
		vfx.position = Vector2.ZERO
	else:
		vfx.top_level = true
		add_child(vfx)
		if target is Node2D:
			vfx.global_position = (target as Node2D).global_position


# ── Hitstop ───────────────────────────────────────────────────────────────────

func _start_hitstop() -> void:
	if _in_hitstop:
		return
	_in_hitstop = true
	Engine.time_scale = HITSTOP_TIME_SCALE
	_hitstop_end_us = Time.get_ticks_usec() + HITSTOP_DURATION_US


func _tick_hitstop() -> void:
	if _in_hitstop and Time.get_ticks_usec() >= _hitstop_end_us:
		Engine.time_scale = 1.0
		_in_hitstop = false


# ── Screen shake ──────────────────────────────────────────────────────────────

func _start_shake() -> void:
	_shake_end_us = Time.get_ticks_usec() + SHAKE_DURATION_US


func _tick_shake() -> void:
	if _camera == null:
		return
	var now: int = Time.get_ticks_usec()
	if now < _shake_end_us:
		var progress: float = float(_shake_end_us - now) / float(SHAKE_DURATION_US)
		var strength: float = SHAKE_AMPLITUDE * progress
		_camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


# ── Hit flash ─────────────────────────────────────────────────────────────────

func _flash_target(target: Node) -> void:
	if not target is CanvasItem:
		return
	var ci := target as CanvasItem
	ci.modulate = Color(2.5, 2.5, 2.5, 1.0)
	_flash_entries.append({"target": ci, "end_us": Time.get_ticks_usec() + FLASH_DURATION_US})


func _tick_flashes() -> void:
	var now: int = Time.get_ticks_usec()
	var i: int = _flash_entries.size() - 1
	while i >= 0:
		var entry: Dictionary = _flash_entries[i]
		if now >= entry.end_us:
			if is_instance_valid(entry.target):
				(entry.target as CanvasItem).modulate = Color.WHITE
			_flash_entries.remove_at(i)
		i -= 1
