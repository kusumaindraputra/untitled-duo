## spell_vfx.gd — SpellVFX Autoload #10.
## Visual routing layer for spell cast readiness and hit feedback (GDD Rule 1,
## Visual/Audio Requirements Quick Spec 2026-06-12).
##
## Listens to SC&E signals and routes them to the correct visual systems:
##   - cast_started      → modulate pulse on Fayde (cast readiness cue)
##   - spell_hit_element → per-type GPUParticles2D hit burst at target position
##   - cast_hit_started  → cast-lock tint (locked movement visual feedback)
##   - heavy_hit         → amplified hitstop + shake + red flash (GF-06 heavy-hit juice)
##   - player_died       → death cinematic: slow-motion + red vignette + death ring
##
## Also routes audio events to AudioSystem — fire-and-forget, null-safe.
##
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0015 (SpellVFX Particle Pool)
## Story: SC&E Story 005 — Prana Type Visual Differentiation (S5-03)
##        S7-05 — SpellVFX particle pre-pool (PERF-C1 fix)
##        GF-06 — Gamefeel Pass 2 (heavy-hit, death cinematic, audio routing)
##
## Registration: Autoload #10 in project.godot (after SpellCastingEffects).
## No class_name — Godot 4.6 rejects class_name matching the Autoload node name.
extends Node


# Pre-allocated pool: one GPUParticles2D per VfxBurstShape (indices 0–4).
# Shape params and materials are fully configured at _ready(). Hot path is zero-allocation:
# only modulate color and global_position change per hit.
var _pool: Dictionary = {}

# ── Hitstop / Screen shake / Procedural VFX ───────────────────────────────────

## [type_id][attack_index] — wall-clock duration per Prana type per attack (microseconds).
## Types: 0=Ashfire  1=Voidblue  2=Stormgold  3=Deepfrost  4=Verdant
const VFX_DURATION_US: Array = [
	[200_000, 300_000, 500_000],  ## 0 Ashfire
	[250_000, 350_000, 400_000],  ## 1 Voidblue
	[120_000, 180_000, 250_000],  ## 2 Stormgold — faster for sniper feel
	[300_000, 400_000, 500_000],  ## 3 Deepfrost
	[200_000, 300_000, 450_000],  ## 4 Verdant
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

## Hitstop duration multiplier for heavy hits (≥15 damage).
const HEAVY_HIT_HITSTOP_MULT: float = 2.0
## Shake amplitude multiplier for heavy hits.
const HEAVY_HIT_SHAKE_MULT: float = 2.0
## Opacity of the heavy-hit red flash at peak.
const HEAVY_FLASH_ALPHA: float = 0.18
## Duration of the heavy-hit red flash fade-out (seconds).
const HEAVY_FLASH_DURATION: float = 0.25

## Tracked from chain_index_changed — true when the next hit is the final chain attack.
var _next_is_ender: bool = false
## 0-based index of the current attack in the combo (0=first, 1=second, 2=ender).
var _last_attack_index: int = 0

## AudioSystem Autoload reference; null-safe — set in _ready(), overridable for tests.
## Variant (not Node) intentional — allows mock injection.
var _audio: Variant = null

# ── Death cinematic state ─────────────────────────────────────────────────────

## True while the death cinematic slow-motion is active.
var _dying: bool = false
## Countdown timer for death cinematic (real-time seconds, PROCESS_MODE_ALWAYS).
var _death_timer: float = 0.0
## Full-screen red vignette active during death cinematic.
var _death_vignette: ColorRect = null

# ── Desperate zone vignette state (Gamefeel Pass 3 #5) ──────────────────────────

## Persistent red vignette active when Fayde is in DESPERATE HP zone (≤20% HP).
## Fades in on zone enter, fades out on upward recovery. Heartbeat pulse via _process.
var _desperate_vignette: ColorRect = null
## True while the desperate vignette is active (zone == DESPERATE and not dying).
var _in_desperate_zone: bool = false
## Tween for vignette fade transitions. Killed on new zone signal or death.
var _desperate_tween: Tween = null

# ── Heavy-hit flash state ─────────────────────────────────────────────────────

## CanvasLayer + ColorRect for heavy-hit red flash. Created lazily on first heavy hit.
var _heavy_flash_layer: CanvasLayer = null
var _heavy_flash_rect: ColorRect = null
var _heavy_flash_tween: Tween = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	SpellCastingEffects.cast_started.connect(_on_cast_started)
	SpellCastingEffects.spell_hit_element.connect(_on_spell_hit_element)
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)
	SpellCastingEffects.chain_index_changed.connect(_on_chain_index_changed)
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	HealthAndDamage.heavy_hit.connect(_on_heavy_hit)
	HealthAndDamage.player_died.connect(_on_player_died)
	HealthAndDamage.player_hp_zone_changed.connect(_on_hp_zone_changed)
	_init_pool()
	_audio = get_node_or_null("/root/AudioSystem")
	# Camera is looked up lazily on first shake — autoload _ready() fires before
	# the game scene (and player) exist, so get_first_node_in_group would return null here.


func _process(_delta: float) -> void:
	_tick_hitstop()
	_tick_shake()
	_tick_death()
	_tick_desperate_vignette()


func _exit_tree() -> void:
	if SpellCastingEffects.cast_started.is_connected(_on_cast_started):
		SpellCastingEffects.cast_started.disconnect(_on_cast_started)
	if SpellCastingEffects.spell_hit_element.is_connected(_on_spell_hit_element):
		SpellCastingEffects.spell_hit_element.disconnect(_on_spell_hit_element)
	if SpellCastingEffects.cast_hit_started.is_connected(_on_cast_hit_started):
		SpellCastingEffects.cast_hit_started.disconnect(_on_cast_hit_started)
	if HealthAndDamage.damage_taken.is_connected(_on_damage_taken):
		HealthAndDamage.damage_taken.disconnect(_on_damage_taken)
	if HealthAndDamage.heavy_hit.is_connected(_on_heavy_hit):
		HealthAndDamage.heavy_hit.disconnect(_on_heavy_hit)
	if HealthAndDamage.player_died.is_connected(_on_player_died):
		HealthAndDamage.player_died.disconnect(_on_player_died)
	if HealthAndDamage.player_hp_zone_changed.is_connected(_on_hp_zone_changed):
		HealthAndDamage.player_hp_zone_changed.disconnect(_on_hp_zone_changed)
	if SpellCastingEffects.chain_index_changed.is_connected(_on_chain_index_changed):
		SpellCastingEffects.chain_index_changed.disconnect(_on_chain_index_changed)
	if _in_hitstop:
		Engine.time_scale = 1.0
	if _dying:
		Engine.time_scale = 1.0
		_dying = false


# ── Signal handlers ────────────────────────────────────────────────────────────

## Brief modulate pulse on Fayde when a cast begins.
## Uses a color tween (not alpha) so PlayerController._physics_process alpha-reset
## (guards the i-frame blink system) does not kill the pulse mid-flight.
## Pulse color is brightened from the primary Prana type's canonical color.
func _on_cast_started(spell_effect: SpellEffect) -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is CanvasItem:
		return
	# Look up canonical type color; fall back to white if catalog unavailable.
	var pulse_color: Color = Color.WHITE
	if spell_effect != null:
		var type_data: PranaType = PranaCatalog.get_type(spell_effect.primary_type)
		if type_data != null:
			# Overbrighten the type color for a visible flash without losing hue identity.
			pulse_color = type_data.color * 2.2
			pulse_color.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(player as CanvasItem, "modulate", pulse_color, 0.05)
	tween.tween_property(player as CanvasItem, "modulate", Color.WHITE, 0.12)
	_audio_play(&"sfx_spell_cast")


## Zero-allocation hot path (ADR-0015): looks up pool node by shape,
## updates position and color, then restarts emission.
## Also triggers per-type procedural draw VFX, hitstop, screen shake, and audio.
func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	var type_data: PranaType = PranaCatalog.get_type(prana_type_id)
	if type_data == null:
		push_warning("SpellVFX: PranaCatalog.get_type(%d) returned null — no burst." % prana_type_id)
		return
	var amplify: float = COMBO_ENDER_AMPLIFY if _next_is_ender else 1.0
	_next_is_ender = false
	if target is Node2D:
		_reuse_from_pool((target as Node2D).global_position, type_data)
		_spawn_hit_vfx(target as Node2D, prana_type_id, _last_attack_index)
	_start_hitstop(amplify)
	_start_shake(amplify)
	_audio_play(&"sfx_spell_hit")


## Tints Fayde with a dimmed primary type color for _lock_duration seconds.
## Signals post-hit movement dampening with hue identity (not generic blue-grey).
## Uses color tween (alpha stays 1.0) so PlayerController alpha-reset does not interfere.
func _on_cast_hit_started(_lock_duration: float) -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is CanvasItem:
		return
	# Derive tint from the current wave's primary type — dimmed to 60% so it reads
	# as "locked" rather than "glowing." Falls back to neutral grey if no spell cached.
	var tint: Color = Color(0.7, 0.7, 0.7, 1.0)
	var se: SpellEffect = SpellCastingEffects.get_cached_spell_effect()
	if se != null:
		var type_data: PranaType = PranaCatalog.get_type(se.primary_type)
		if type_data != null:
			tint = type_data.color * 0.65
			tint.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(player as CanvasItem, "modulate", tint, 0.0)
	tween.tween_property(player as CanvasItem, "modulate", Color.WHITE, _lock_duration)
	_audio_play(&"sfx_fayde_cast_locked")


## Tracks chain state so _on_spell_hit_element can detect and amplify the final attack.
## Sets _last_attack_index (0-based) so _spawn_hit_vfx selects the correct shape.
## chain_index_changed fires before spell_hit_element in the same call stack — safe ordering.
func _on_chain_index_changed(combo_idx: int, combo_count: int) -> void:
	if combo_idx > 0 and combo_idx == combo_count:
		_next_is_ender = true
		_audio_play(&"sfx_combo_ender")
	_last_attack_index = clampi(combo_idx - 1, 0, 2)


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
		_audio_play(&"sfx_fayde_hit")
	else:
		if target.has_method(&"request_hit_flash"):
			target.request_hit_flash()
		else:
			_flash_enemy_white(ci)
		_audio_play(&"sfx_enemy_hit")


# ── Heavy hit ──────────────────────────────────────────────────────────────────

## Handles heavy_hit from HealthAndDamage (≥15 damage).
## Amplifies hitstop 2×, shake 2×, and shows a brief red screen flash.
## Audio: sfx_heavy_hit for both player and enemy hits.
func _on_heavy_hit(target: Node, _final_damage: int) -> void:
	_start_hitstop(HEAVY_HIT_HITSTOP_MULT)
	_start_shake(HEAVY_HIT_SHAKE_MULT)
	_show_heavy_flash()
	_audio_play(&"sfx_heavy_hit")


## Shows a brief red flash overlay. Creates the CanvasLayer + ColorRect lazily
## on first call, then reuses them. Fades in instantly, then fades out over 0.25 s.
func _show_heavy_flash() -> void:
	# Lazy-init the flash layer on first heavy hit.
	if _heavy_flash_layer == null:
		_heavy_flash_layer = CanvasLayer.new()
		_heavy_flash_layer.layer = 99  # above HUD (10), below combat flash (100)
		add_child(_heavy_flash_layer)
		_heavy_flash_rect = ColorRect.new()
		_heavy_flash_rect.color = Color(1.0, 0.15, 0.1, 0.0)
		_heavy_flash_rect.anchor_right = 1.0
		_heavy_flash_rect.anchor_bottom = 1.0
		_heavy_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_heavy_flash_layer.add_child(_heavy_flash_rect)
	if _heavy_flash_tween:
		_heavy_flash_tween.kill()
	_heavy_flash_rect.color.a = HEAVY_FLASH_ALPHA
	_heavy_flash_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_heavy_flash_tween.tween_property(_heavy_flash_rect, "color:a", 0.0, HEAVY_FLASH_DURATION)


# ── Low-HP desperate vignette (Gamefeel Pass 3 #5) ───────────────────────────────

## Base opacity of the desperate-zone red vignette (below death vignette at 0.35).
const DESPERATE_VIGNETTE_ALPHA: float = 0.18
## Heartbeat pulse amplitude (added to base alpha at peak).
const DESPERATE_PULSE_AMPLITUDE: float = 0.07
## Heartbeat rate in beats per second. 1.2 Hz = slightly elevated, anxious rhythm.
const DESPERATE_HEARTBEAT_RATE: float = 1.2
## Duration of the fade-in / fade-out tween for the desperate vignette (seconds).
const DESPERATE_VIGNETTE_FADE: float = 0.5

## Handles player_hp_zone_changed from HealthAndDamage.
## DESPERATE: shows a persistent red vignette with heartbeat pulse.
## CAREFUL / FULL: fades out and frees the vignette on upward recovery.
## Guard: does not activate if the death cinematic is already playing.
func _on_hp_zone_changed(zone: GameEnums.HPZone) -> void:
	if _dying:
		return
	if zone == GameEnums.HPZone.DESPERATE:
		_show_desperate_vignette()
	else:
		_hide_desperate_vignette()


## Creates (or reuses) a full-screen red vignette for the DESPERATE HP zone.
## Fades in over DESPERATE_VIGNETTE_FADE seconds. Silently no-ops if already active.
func _show_desperate_vignette() -> void:
	if _desperate_vignette != null:
		return
	if get_tree() == null or get_tree().root == null:
		return
	_desperate_vignette = ColorRect.new()
	_desperate_vignette.color = Color(0.85, 0.08, 0.08, 0.0)
	_desperate_vignette.anchor_right = 1.0
	_desperate_vignette.anchor_bottom = 1.0
	_desperate_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().root.add_child(_desperate_vignette)
	_in_desperate_zone = true
	if _desperate_tween:
		_desperate_tween.kill()
	_desperate_tween = _desperate_vignette.create_tween().set_ease(Tween.EASE_OUT)
	_desperate_tween.tween_property(_desperate_vignette, "color:a", DESPERATE_VIGNETTE_ALPHA, DESPERATE_VIGNETTE_FADE)


## Fades out and frees the desperate vignette. No-op if not active.
func _hide_desperate_vignette() -> void:
	if _desperate_vignette == null:
		return
	_in_desperate_zone = false
	if _desperate_tween:
		_desperate_tween.kill()
	_desperate_tween = _desperate_vignette.create_tween().set_ease(Tween.EASE_OUT)
	_desperate_tween.tween_property(_desperate_vignette, "color:a", 0.0, DESPERATE_VIGNETTE_FADE)
	_desperate_tween.tween_callback(_desperate_vignette.queue_free)
	_desperate_vignette = null


## Applies a heartbeat pulse to the desperate vignette alpha.
## Called every frame from _process() with PROCESS_MODE_ALWAYS.
func _tick_desperate_vignette() -> void:
	if not _in_desperate_zone or _desperate_vignette == null:
		return
	var pulse: float = 1.0 + sin(Time.get_ticks_usec() * 0.000001 * DESPERATE_HEARTBEAT_RATE * TAU) * (DESPERATE_PULSE_AMPLITUDE / DESPERATE_VIGNETTE_ALPHA)
	_desperate_vignette.color.a = DESPERATE_VIGNETTE_ALPHA * pulse

# ── Player death cinematic ─────────────────────────────────────────────────────

## Death cinematic constants.
## Full slow-motion duration in real-time seconds (PROCESS_MODE_ALWAYS).
const DEATH_SLOWMO_DURATION: float = 2.0
## Time scale during death cinematic.
const DEATH_TIME_SCALE: float = 0.25
## Peak opacity of the red death vignette.
const DEATH_VIGNETTE_ALPHA: float = 0.35
## Death ring initial radius (pixels).
const DEATH_RING_START: float = 10.0
## Death ring final radius (pixels).
const DEATH_RING_END: float = 300.0

## Triggers the player death cinematic: slow-motion, red vignette, expanding ring.
## Fires from HealthAndDamage.player_died. The death overlay (debug_game_loop)
## appears on top — the cinematic adds dramatic weight underneath it.
func _on_player_died() -> void:
	if _desperate_vignette != null:
		if _desperate_tween:
			_desperate_tween.kill()
		_desperate_vignette.queue_free()
		_desperate_vignette = null
		_in_desperate_zone = false
	_dying = true
	_death_timer = DEATH_SLOWMO_DURATION
	Engine.time_scale = DEATH_TIME_SCALE
	# Spawn the death vignette as a child of the scene root so it covers everything.
	if get_tree() != null and get_tree().root != null:
		_death_vignette = ColorRect.new()
		_death_vignette.color = Color(1.0, 0.05, 0.05, 0.0)
		_death_vignette.anchor_right = 1.0
		_death_vignette.anchor_bottom = 1.0
		_death_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		get_tree().root.add_child(_death_vignette)
		# Fade vignette in over 0.4 s.
		var tw: Tween = _death_vignette.create_tween().set_ease(Tween.EASE_OUT)
		tw.tween_property(_death_vignette, "color:a", DEATH_VIGNETTE_ALPHA, 0.4)
	# Spawn the death ring — top_level so it stays in world space during slow-mo.
	var player: Node = get_tree().get_first_node_in_group(&"player") if get_tree() != null else null
	if player != null and player is Node2D:
		var ring := _DeathRing.new()
		ring.top_level = true
		ring.global_position = (player as Node2D).global_position
		get_tree().root.add_child(ring)
	_audio_play(&"sfx_fayde_death")


## Counts down the death cinematic timer and restores normal time on expiry.
## Called every frame from _process() with PROCESS_MODE_ALWAYS.
func _tick_death() -> void:
	if not _dying:
		return
	if _death_vignette != null:
		# Heartbeat pulse on the vignette: 2 beats/sec, 0.05 amplitude.
		var pulse: float = 1.0 + sin(Time.get_ticks_usec() * 0.000004 * TAU) * 0.05
		_death_vignette.color.a = DEATH_VIGNETTE_ALPHA * pulse
	_death_timer -= get_process_delta_time()
	if _death_timer <= 0.0:
		Engine.time_scale = 1.0
		_dying = false
		# Fade out and free the vignette.
		if _death_vignette != null:
			var tw: Tween = _death_vignette.create_tween()
			tw.tween_property(_death_vignette, "color:a", 0.0, 0.4)
			tw.tween_callback(_death_vignette.queue_free)
			_death_vignette = null


## Inner class: procedural death ring that expands from Fayde's death position.
## A single red ring that grows from 10→300 px over DEATH_SLOWMO_DURATION seconds.
class _DeathRing extends Node2D:
	const RING_DURATION: float = 2.0
	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 200
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= int(RING_DURATION * 1_000_000.0):
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed: float = float(Time.get_ticks_usec() - _start_us) / 1_000_000.0
		var p: float = clampf(elapsed / RING_DURATION, 0.0, 1.0)
		var alpha: float = 1.0 - p
		var ring_r: float = lerpf(10.0, 300.0, p)
		draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32,
				Color(1.0, 0.1, 0.1, alpha * 0.7), 3.0, true)
		# Secondary thinner ring at 60% radius.
		draw_arc(Vector2.ZERO, ring_r * 0.6, 0.0, TAU, 24,
				Color(1.0, 0.3, 0.2, alpha * 0.4), 1.5, true)


# ── Audio routing ──────────────────────────────────────────────────────────────

## Plays an audio event through AudioSystem. Null-safe — silent no-op when
## AudioSystem is not available (headless tests, missing autoload).
func _audio_play(event_name: StringName) -> void:
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(event_name):
		_audio.play_event(event_name)


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
func _spawn_hit_vfx(target: Node2D, type_id: int, attack_index: int = 0) -> void:
	if type_id < 0 or type_id >= VFX_DURATION_US.size():
		return
	if get_tree() == null:
		return
	var vfx := _HitVFX.new()
	vfx.type_id = type_id
	vfx.attack_index = clampi(attack_index, 0, 2)
	vfx.duration_us = VFX_DURATION_US[type_id][vfx.attack_index]
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
		# Calculate shot direction (player→target, world space = local space for top_level).
		var player_node: Node = get_tree().get_first_node_in_group(&"player")
		if player_node != null and player_node is Node2D:
			var diff: Vector2 = target.global_position - (player_node as Node2D).global_position
			vfx.shot_direction = diff.normalized() if diff.length_squared() > 0.0 else Vector2.RIGHT
		if get_tree().root != null:
			get_tree().root.add_child(vfx)
		else:
			vfx.free()
			return
		vfx.global_position = target.global_position


# ── Inner class: single procedural VFX instance ───────────────────────────────

class _HitVFX extends Node2D:
	var type_id: int = 0
	var attack_index: int = 0
	var duration_us: int = 300_000
	## World-space direction from player to target. Used by directional types (Stormgold).
	var shot_direction: Vector2 = Vector2.RIGHT
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
			0: _draw_ashfire(p, attack_index)
			1: _draw_voidblue(p, attack_index)
			2: _draw_stormgold(p, attack_index)
			3: _draw_deepfrost(p, attack_index)
			4: _draw_verdant(p, attack_index)

	# ── Ashfire (orange #F24C1D, spawns at Fayde) ─────────────────────────────

	func _draw_ashfire(p: float, atk: int) -> void:
		match atk:
			0: _draw_ashfire_atk0(p)
			1: _draw_ashfire_atk1(p)
			_: _draw_ashfire_atk2(p)

	## atk0 — palm strike: 3 filled flame wedges pointing upward.
	func _draw_ashfire_atk0(p: float) -> void:
		var alpha: float = 1.0 - p
		var outer: float = 25.0 + p * 55.0
		var c: Color = Color(1.0, 0.3, 0.07, alpha)
		for i: int in 3:
			var angle: float = -PI / 2.0 + (float(i) - 1.0) * 0.52
			var dir: Vector2 = Vector2.from_angle(angle)
			var perp: Vector2 = dir.rotated(PI / 2.0)
			var half_w: float = 13.8 - p * 5.0
			draw_polygon(PackedVector2Array([dir * outer, perp * half_w, -perp * half_w]),
					PackedColorArray([c]))

	## atk1 — sweeping kick: 5 filled wedges in a 140° fan + arc.
	func _draw_ashfire_atk1(p: float) -> void:
		var alpha: float = 1.0 - p
		var outer: float = 50.0 + p * 75.0
		var c: Color = Color(1.0, 0.45, 0.0, alpha)
		for i: int in 5:
			var angle: float = -PI * 0.7 + float(i) * (PI * 1.4 / 4.0)
			var dir: Vector2 = Vector2.from_angle(angle)
			var perp: Vector2 = dir.rotated(PI / 2.0)
			var half_w: float = 17.5 - p * 7.5
			draw_polygon(PackedVector2Array([dir * outer, perp * half_w, -perp * half_w]),
					PackedColorArray([c]))
		draw_arc(Vector2.ZERO, outer * 0.6, -PI * 0.7, PI * 0.7, 16,
				Color(1.0, 0.7, 0.1, alpha * 0.4), 2.0, true)

	## atk2 — 360° eruption: 8 filled wedges + outer ring.
	func _draw_ashfire_atk2(p: float) -> void:
		var alpha: float = 1.0 - p
		var outer: float = 60.0 + p * 120.0
		var c: Color = Color(1.0, 0.4, 0.0, alpha)
		for i: int in 8:
			var angle: float = (TAU / 8.0) * float(i)
			var dir: Vector2 = Vector2.from_angle(angle)
			var perp: Vector2 = dir.rotated(PI / 2.0)
			var half_w: float = 20.0 - p * 10.0
			draw_polygon(PackedVector2Array([dir * outer, perp * half_w, -perp * half_w]),
					PackedColorArray([c]))
		draw_arc(Vector2.ZERO, outer * 0.7, 0.0, TAU, 24,
				Color(1.0, 0.7, 0.1, alpha * 0.5), 2.5, true)

	# ── Voidblue (blue-purple #4A5EF5, spawns at target) ─────────────────────

	func _draw_voidblue(p: float, atk: int) -> void:
		match atk:
			0: _draw_voidblue_atk0(p)
			1: _draw_voidblue_atk1(p)
			_: _draw_voidblue_atk2(p)

	## atk0 — absorb: thick shrinking ring + inner glow circle.
	func _draw_voidblue_atk0(p: float) -> void:
		var alpha: float = 1.0 - p
		var radius: float = 70.0 * (1.0 - p) + 10.0
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24,
				Color(0.29, 0.37, 0.96, alpha), 10.0, true)
		draw_circle(Vector2.ZERO, radius * 0.35, Color(0.55, 0.4, 1.0, alpha * 0.3))

	## atk1 — shadow pull: triskelion arcs + growing filled center dot.
	func _draw_voidblue_atk1(p: float) -> void:
		var alpha: float = 1.0 - p
		var radius: float = 50.0 - p * 20.0
		var c: Color = Color(0.29, 0.37, 0.96, alpha)
		for i: int in 3:
			var start_a: float = (TAU / 3.0) * float(i)
			draw_arc(Vector2.ZERO, radius, start_a,
					start_a + TAU / 3.0 * 0.7, 14, c, 7.5, true)
		draw_circle(Vector2.ZERO, 5.0 + p * 20.0, Color(0.55, 0.4, 1.0, alpha))

	## atk2 — void collapse: 3 phase-staggered expanding rings.
	func _draw_voidblue_atk2(p: float) -> void:
		for i: int in 3:
			var phase: float = clampf(p - float(i) * 0.15, 0.0, 1.0)
			if phase <= 0.0:
				continue
			var width: float = maxf(8.8 - float(i) * 2.0, 3.8)
			draw_arc(Vector2.ZERO, phase * (70.0 + float(i) * 25.0), 0.0, TAU, 24,
					Color(0.29, 0.37, 0.96, 1.0 - phase), width, true)

	# ── Stormgold (yellow #FFCC00, spawns at target, directional) ────────────

	func _draw_stormgold(p: float, atk: int) -> void:
		match atk:
			0: _draw_stormgold_atk0(p)
			1: _draw_stormgold_atk1(p)
			_: _draw_stormgold_atk2(p)

	## atk0 — snap shot: short bullet streak + impact diamond at center.
	func _draw_stormgold_atk0(p: float) -> void:
		var alpha: float = 1.0 - p
		var len: float = 35.0 + p * 15.0
		var sd: Vector2 = shot_direction
		var perp: Vector2 = sd.rotated(PI / 2.0)
		draw_line(-sd * 10.0, sd * len, Color(1.0, 0.9, 0.0, alpha), 10.0, true)
		var flash: float = 12.5 * (1.0 - p)
		var c_flash: Color = Color(1.0, 1.0, 0.6, alpha)
		draw_polygon(PackedVector2Array([sd * (flash * 1.5), perp * flash,
				-sd * (flash * 0.5), -perp * flash]),
				PackedColorArray([c_flash]))

	## atk1 — precision shot: medium streak + bright core + exit sparks.
	func _draw_stormgold_atk1(p: float) -> void:
		var alpha: float = 1.0 - p
		var len: float = 70.0 + p * 20.0
		var sd: Vector2 = shot_direction
		draw_line(-sd * 15.0, sd * len, Color(1.0, 0.85, 0.0, alpha), 11.2, true)
		draw_line(-sd * 10.0, sd * len * 0.65, Color(1.0, 1.0, 0.8, alpha * 0.7), 5.0, true)
		var impact: Vector2 = sd * len
		for sign in [1.0, -1.0]:
			draw_line(impact, impact + sd.rotated(sign * 0.7) * (22.5 * (1.0 - p)),
					Color(1.0, 0.9, 0.2, alpha * 0.7), 5.0, true)

	## atk2 — critical beam: long streak + impact ring + exit sparks.
	func _draw_stormgold_atk2(p: float) -> void:
		var alpha: float = 1.0 - p
		var len: float = 105.0 + p * 35.0
		var sd: Vector2 = shot_direction
		draw_line(-sd * 20.0, sd * len, Color(1.0, 0.85, 0.0, alpha), 15.0, true)
		draw_line(-sd * 12.5, sd * len * 0.8, Color(1.0, 1.0, 0.9, alpha * 0.7), 6.2, true)
		draw_arc(Vector2.ZERO, 25.0 + p * 55.0, 0.0, TAU, 20,
				Color(1.0, 0.9, 0.0, alpha * 0.7), 6.2, true)
		var impact: Vector2 = sd * len
		for sign in [1.0, -1.0]:
			draw_line(impact, impact + sd.rotated(sign * 0.65) * (35.0 * (1.0 - p)),
					Color(1.0, 0.9, 0.2, alpha * 0.6), 5.0, true)

	# ── Deepfrost (cyan #3DD9F0, spawns at target) ────────────────────────────

	func _draw_deepfrost(p: float, atk: int) -> void:
		match atk:
			0: _draw_deepfrost_atk0(p)
			1: _draw_deepfrost_atk1(p)
			_: _draw_deepfrost_atk2(p)

	## atk0 — push: filled hexagon expanding and fading.
	func _draw_deepfrost_atk0(p: float) -> void:
		var radius: float = 12.5 + p * 45.0
		var alpha: float = 1.0 - p
		_draw_hexagon_filled(Vector2.ZERO, radius,
				Color(0.24, 0.85, 0.94, alpha * 0.35),
				Color(0.24, 0.85, 0.94, alpha), 2.5)

	## atk1 — frost line: 3 filled hexagons in horizontal line.
	func _draw_deepfrost_atk1(p: float) -> void:
		var alpha: float = 1.0 - p
		var radius: float = 15.0 + p * 25.0
		for i: int in 3:
			_draw_hexagon_filled(Vector2((float(i) - 1.0) * 70.0, 0.0), radius,
					Color(0.24, 0.85, 0.94, alpha * 0.35),
					Color(0.24, 0.85, 0.94, alpha), 2.0)

	## atk2 — glacial field: filled inner circle + two expanding rings.
	func _draw_deepfrost_atk2(p: float) -> void:
		var alpha: float = 1.0 - p
		var inner_r: float = 20.0 + p * 65.0
		draw_circle(Vector2.ZERO, inner_r, Color(0.24, 0.85, 0.94, alpha * 0.22))
		draw_arc(Vector2.ZERO, 40.0 + p * 110.0, 0.0, TAU, 28,
				Color(0.24, 0.85, 0.94, alpha * 0.85), 3.0, true)
		draw_arc(Vector2.ZERO, inner_r, 0.0, TAU, 20,
				Color(0.6, 0.95, 1.0, alpha * 0.55), 2.0, true)

	## Shared helper: filled hexagon (flat-top) + outline.
	func _draw_hexagon_filled(center: Vector2, radius: float, fill_color: Color,
			outline_color: Color, width: float) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for i: int in 6:
			pts.push_back(center + Vector2.from_angle((TAU / 6.0) * float(i) - PI / 6.0) * radius)
		draw_polygon(pts, PackedColorArray([fill_color]))
		pts.push_back(pts[0])
		draw_polyline(pts, outline_color, width, true)

	# ── Verdant (green #1AC953, spawns at Fayde) ──────────────────────────────

	func _draw_verdant(p: float, atk: int) -> void:
		match atk:
			0: _draw_verdant_atk0(p)
			1: _draw_verdant_atk1(p)
			_: _draw_verdant_atk2(p)

	## atk0 — bloom strike: 5 filled diamond petals radiating outward.
	func _draw_verdant_atk0(p: float) -> void:
		var alpha: float = 1.0 - p
		_draw_petals_filled(5, lerp(70.0, 20.0, p), Color(0.1, 0.79, 0.33, alpha))

	## atk1 — shield pulse: expanding ring with inner fill.
	func _draw_verdant_atk1(p: float) -> void:
		var alpha: float = 1.0 - p
		var r: float = 30.0 + p * 120.0
		draw_circle(Vector2.ZERO, r * 0.55, Color(0.1, 0.79, 0.33, alpha * 0.2))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 28,
				Color(0.1, 0.79, 0.33, alpha), 3.5, true)

	## atk2 — rejuvenating strike: 5 filled petals + 4 rising heal dots.
	func _draw_verdant_atk2(p: float) -> void:
		var alpha: float = 1.0 - p
		_draw_petals_filled(5, lerp(85.0, 25.0, p), Color(0.1, 0.79, 0.33, alpha))
		for i: int in 4:
			draw_circle(
				Vector2((float(i) - 1.5) * 30.0, -p * 70.0 - float(i) * 10.0),
				8.8 * (1.0 - p),
				Color(0.35, 1.0, 0.5, alpha * 0.9)
			)

	## Shared helper: n filled diamond petals radiating from origin.
	func _draw_petals_filled(count: int, outer: float, color: Color) -> void:
		var half_w: float = outer * 0.28
		var inner: float = -outer * 0.2
		for i: int in count:
			var angle: float = (TAU / float(count)) * float(i)
			var dir: Vector2 = Vector2.from_angle(angle)
			var perp: Vector2 = dir.rotated(PI / 2.0)
			draw_polygon(PackedVector2Array([dir * outer, perp * half_w,
					dir * inner, -perp * half_w]),
					PackedColorArray([color]))
