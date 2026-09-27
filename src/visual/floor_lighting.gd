## floor_lighting.gd — Light 2D lighting on the arena floor (ADR-0043).
##
## Each IsometricRoom owns one. It lights the floor around the things that glow (the
## combat dim that darkens the rest of the floor is ADR-0042's IsometricRoom.set_combat_dim):
##   - Fayde carries a warm E7 lantern light
##   - casts, hits, Cascades and Specials flash a short light in their Prana colour
##   - spawn glyphs flash in the enemy rim colour
##   - up to bullet_light_cap enemy bullets carry a small light in their core colour
## Every light uses range_item_cull_mask = FLOOR_LIGHT_MASK and only the floor tiles carry
## that bit, so characters, bullets and UI are never relit (art bible §6). Light counts are
## fixed pools, so the cost stays flat for the web build however busy the fight gets.
class_name FloorLighting
extends Node2D

const TUNING: FloorLightingTuning = preload("res://assets/data/floor_lighting_tuning.tres")
## Nodes in this group receive spawn light requests from WaveManager.
const GROUP: StringName = &"floor_lighting"
## CanvasItem.light_mask bit the floor lights reach. Only the floor tiles carry it.
const FLOOR_LIGHT_MASK: int = 2

## Overrides the tuning (tests); null = TUNING. Set before _ready().
var tuning: FloorLightingTuning = null
## The floor canvas item the lights reach. Set by the room.
var floor_item: CanvasItem = null

var _texture: GradientTexture2D = null
var _fayde_light: PointLight2D = null
var _player: Node2D = null
var _player_lookup_left: float = 0.0

var _pulses: Array[PointLight2D] = []
## Peak energy, seconds left and total seconds of each pulse slot.
var _pulse_peak: PackedFloat32Array = PackedFloat32Array()
var _pulse_left: PackedFloat32Array = PackedFloat32Array()
var _pulse_len: PackedFloat32Array = PackedFloat32Array()
## Order each slot was last fired in; the lowest is the oldest and is reused first.
var _pulse_stamp: PackedInt64Array = PackedInt64Array()
var _stamp: int = 0

var _bullet_lights: Array[PointLight2D] = []
## Bullet each light follows; null = free.
var _bullet_targets: Array[Node2D] = []
var _bullet_refresh_left: float = 0.0

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	if tuning == null:
		tuning = TUNING
	add_to_group(GROUP)
	if not tuning.enabled:
		return
	_texture = build_light_texture(tuning.texture_size, tuning.texture_bands)
	_fayde_light = _make_light(tuning.fayde_color, tuning.fayde_energy, tuning.fayde_radius)
	_fayde_light.visible = false
	for i: int in maxi(tuning.pulse_pool_size, 0):
		var l: PointLight2D = _make_light(Color.WHITE, 0.0, tuning.hit_radius)
		l.visible = false
		_pulses.append(l)
		_pulse_peak.append(0.0)
		_pulse_left.append(0.0)
		_pulse_len.append(1.0)
		_pulse_stamp.append(0)
	for i: int in maxi(tuning.bullet_light_cap, 0):
		var b: PointLight2D = _make_light(Color.WHITE, tuning.bullet_energy, tuning.bullet_radius)
		b.visible = false
		_bullet_lights.append(b)
		_bullet_targets.append(null)
	_connect_signals()
	if floor_item != null:
		attach_floor(floor_item)


func _exit_tree() -> void:
	_disconnect_signals()


func _process(delta: float) -> void:
	if not tuning.enabled:
		return
	_tick_fayde(delta)
	_tick_pulses(delta)
	_tick_bullets(delta)


# ── Public API ────────────────────────────────────────────────────────────────

## Makes [param item] the lit floor: adds FLOOR_LIGHT_MASK to its light mask.
func attach_floor(item: CanvasItem) -> void:
	floor_item = item
	if item == null or tuning == null or not tuning.enabled:
		return
	item.light_mask |= FLOOR_LIGHT_MASK


## Flashes a short light at [param pos] that fades out over [param sec]. Reuses the
## oldest pulse when every slot is busy. Returns the light, or null when lighting is off.
func pulse(pos: Vector2, color: Color, energy: float, radius: float, sec: float) -> PointLight2D:
	if _pulses.is_empty():
		return null
	var slot: int = _free_or_oldest_pulse()
	var l: PointLight2D = _pulses[slot]
	l.global_position = pos
	l.color = color
	l.texture_scale = texture_scale_for(radius, tuning.texture_size)
	_stamp += 1
	_pulse_stamp[slot] = _stamp
	_pulse_peak[slot] = energy
	_pulse_len[slot] = maxf(sec, 0.01)
	_pulse_left[slot] = _pulse_len[slot]
	l.energy = pulse_energy(energy, _pulse_left[slot], _pulse_len[slot], GameSettings.flash_multiplier())
	l.visible = true
	return l


## Spawn-glyph light in the enemy rim colour, called by WaveManager as an enemy rises.
func pulse_spawn(pos: Vector2, color: Color, size_mult: float = 1.0) -> void:
	pulse(pos, color, tuning.spawn_energy, tuning.spawn_radius * maxf(size_mult, 1.0), tuning.spawn_sec)


## Number of pulse lights still fading.
func active_pulse_count() -> int:
	var n: int = 0
	for i: int in _pulses.size():
		if _pulse_left[i] > 0.0:
			n += 1
	return n


## Hands free bullet lights to unlit bullets in [param bullets] (Node2D, in order) until
## the cap is reached; drops lights from bullets that are gone. Returns how many bullets
## are lit afterwards.
func assign_bullet_lights(bullets: Array) -> int:
	var lit: Dictionary = {}
	for i: int in _bullet_targets.size():
		var t: Node2D = _bullet_targets[i]
		if t != null and _bullet_alive(t):
			lit[t.get_instance_id()] = true
		else:
			_release_bullet(i)
	var free_idx: int = 0
	for n: Variant in bullets:
		var b: Node2D = n as Node2D
		if b == null or lit.has(b.get_instance_id()) or not _bullet_alive(b):
			continue
		while free_idx < _bullet_targets.size() and _bullet_targets[free_idx] != null:
			free_idx += 1
		if free_idx >= _bullet_targets.size():
			break
		_bullet_targets[free_idx] = b
		var l: PointLight2D = _bullet_lights[free_idx]
		l.color = _bullet_color(b)
		l.global_position = b.global_position
		l.visible = true
		lit[b.get_instance_id()] = true
	return lit.size()


## The Fayde light (tests, screenshots).
func get_fayde_light() -> PointLight2D:
	return _fayde_light


# ── Pure helpers ──────────────────────────────────────────────────────────────

## Energy of a pulse with [param left] of [param length] seconds to go.
static func pulse_energy(peak: float, left: float, length: float, flash_mult: float) -> float:
	if length <= 0.0:
		return 0.0
	return peak * flash_mult * clampf(left / length, 0.0, 1.0)


## PointLight2D.texture_scale that makes a [param size] px texture cover [param radius].
static func texture_scale_for(radius: float, size: int) -> float:
	return maxf(radius, 1.0) * 2.0 / float(maxi(size, 1))


## Radial light texture with [param bands] flat brightness steps (pixel-art falloff).
static func build_light_texture(size: int, bands: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var n: int = maxi(bands, 1)
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i: int in n:
		var f: float = float(i) / float(n)
		offsets.append(f)
		colors.append(Color(1.0, 1.0, 1.0, pow(1.0 - f, 1.5)))
	offsets.append(1.0)
	colors.append(Color(1.0, 1.0, 1.0, 0.0))
	g.offsets = offsets
	g.colors = colors
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = maxi(size, 2)
	tex.height = maxi(size, 2)
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


# ── Internals ─────────────────────────────────────────────────────────────────

func _make_light(color: Color, energy: float, radius: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _texture
	l.texture_scale = texture_scale_for(radius, tuning.texture_size)
	l.color = color
	l.energy = energy
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.range_item_cull_mask = FLOOR_LIGHT_MASK
	l.shadow_enabled = false
	add_child(l)
	return l


func _free_or_oldest_pulse() -> int:
	var best: int = 0
	for i: int in _pulses.size():
		if _pulse_left[i] <= 0.0:
			return i
		if _pulse_stamp[i] < _pulse_stamp[best]:
			best = i
	return best


func _tick_fayde(delta: float) -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = null
		_player_lookup_left -= delta
		if _player_lookup_left <= 0.0 and is_inside_tree():
			_player_lookup_left = 0.5
			_player = get_tree().get_first_node_in_group(&"player") as Node2D
	_fayde_light.visible = _player != null
	if _player != null:
		_fayde_light.global_position = _player.global_position


func _tick_pulses(delta: float) -> void:
	var flash: float = GameSettings.flash_multiplier()
	for i: int in _pulses.size():
		if _pulse_left[i] <= 0.0:
			continue
		_pulse_left[i] = maxf(_pulse_left[i] - delta, 0.0)
		var l: PointLight2D = _pulses[i]
		l.energy = pulse_energy(_pulse_peak[i], _pulse_left[i], _pulse_len[i], flash)
		l.visible = _pulse_left[i] > 0.0


func _tick_bullets(delta: float) -> void:
	if _bullet_lights.is_empty():
		return
	# Reduce motion: no lights chasing bullets across the floor.
	if GameSettings.motion_reduced():
		for i: int in _bullet_targets.size():
			_release_bullet(i)
		return
	_bullet_refresh_left -= delta
	if _bullet_refresh_left <= 0.0 and is_inside_tree():
		_bullet_refresh_left = tuning.bullet_refresh_sec
		assign_bullet_lights(get_tree().get_nodes_in_group(Projectile.GROUP))
	for i: int in _bullet_targets.size():
		var t: Node2D = _bullet_targets[i]
		if t == null:
			continue
		if not _bullet_alive(t):
			_release_bullet(i)
			continue
		_bullet_lights[i].global_position = t.global_position


func _release_bullet(i: int) -> void:
	_bullet_targets[i] = null
	_bullet_lights[i].visible = false


func _bullet_alive(b: Node2D) -> bool:
	if not is_instance_valid(b) or not b.is_inside_tree():
		return false
	if b.has_method(&"is_live"):
		return bool(b.call(&"is_live"))
	return true


func _bullet_color(b: Node2D) -> Color:
	if b.has_method(&"core_color"):
		return b.call(&"core_color") as Color
	return Projectile.PALETTE.rim


func _prana_color(prana_type_id: int) -> Color:
	var pc: Node = get_node_or_null(^"/root/PranaCatalog")
	if pc != null and prana_type_id >= 0:
		return pc.call(&"get_type_color", prana_type_id) as Color
	return Color.WHITE


func _pos_of(n: Node) -> Vector2:
	var n2: Node2D = n as Node2D
	return n2.global_position if n2 != null and n2.is_inside_tree() else Vector2.ZERO


# ── Signals ───────────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	var sce: Node = get_node_or_null(^"/root/SpellCastingEffects")
	if sce != null:
		sce.connect(&"cast_started", _on_cast_started)
		sce.connect(&"spell_hit_element", _on_spell_hit_element)
		sce.connect(&"cascade_burst", _on_cascade_burst)
		sce.connect(&"special_fired", _on_special_fired)


func _disconnect_signals() -> void:
	var sce: Node = get_node_or_null(^"/root/SpellCastingEffects")
	if sce != null:
		for pair: Array in [[&"cast_started", _on_cast_started],
				[&"spell_hit_element", _on_spell_hit_element],
				[&"cascade_burst", _on_cascade_burst], [&"special_fired", _on_special_fired]]:
			if sce.is_connected(pair[0], pair[1]):
				sce.disconnect(pair[0], pair[1])


func _on_cast_started(spell_effect: SpellEffect) -> void:
	if _player == null:
		return
	var pt: int = spell_effect.primary_type if spell_effect != null else -1
	pulse(_player.global_position, _prana_color(pt), tuning.cast_energy, tuning.cast_radius, tuning.cast_sec)


func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	if not is_instance_valid(target):
		return
	pulse(_pos_of(target), _prana_color(prana_type_id), tuning.hit_energy, tuning.hit_radius, tuning.hit_sec)


func _on_cascade_burst(lead_type: int, world_pos: Vector2, radius: float) -> void:
	_burst(lead_type, world_pos, radius)


func _on_special_fired(prana_type_id: int, world_pos: Vector2, radius: float) -> void:
	_burst(prana_type_id, world_pos, radius)


func _burst(prana_type_id: int, world_pos: Vector2, radius: float) -> void:
	var r: float = radius * tuning.burst_radius_mult if radius > 0.0 else tuning.burst_fallback_radius
	pulse(world_pos, _prana_color(prana_type_id), tuning.burst_energy, r, tuning.burst_sec)

