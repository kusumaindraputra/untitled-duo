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


# ── Hitstop / Screen shake / Procedural VFX ───────────────────────────────────

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

## Shake amplitude multiplier for a fired Cascade — a "power surge" cue at cast
## resolve that reinforces the HUD callout (ADR-0016 recognition layer).
const CASCADE_SHAKE_MULT: float = 1.2

## Hitstop duration multiplier for heavy hits (≥15 damage).
const HEAVY_HIT_HITSTOP_MULT: float = 2.0
## Shake amplitude multiplier for heavy hits.
const HEAVY_HIT_SHAKE_MULT: float = 2.0
## Opacity of the heavy-hit red flash at peak.
const HEAVY_FLASH_ALPHA: float = 0.18
## Duration of the heavy-hit red flash fade-out (seconds).
const HEAVY_FLASH_DURATION: float = 0.25
## Opacity of the REST-heal green screen wash at peak.
const HEAL_FLASH_ALPHA: float = 0.15
## Duration of the REST-heal green wash fade-out (seconds).
const HEAL_FLASH_DURATION: float = 0.5

## Tracked from chain_index_changed — true when the next hit is the final chain attack.
var _next_is_ender: bool = false

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

# ── REST heal wash state ──────────────────────────────────────────────────────
## CanvasLayer + ColorRect for the green REST-heal screen wash. Created lazily.
var _heal_flash_layer: CanvasLayer = null
var _heal_flash_rect: ColorRect = null
var _heal_flash_tween: Tween = null

## Active combo-window depleting ring; null when no combo window is open.
## Freed on combo expiry, new window open, preparation_started, or player_died.
var _combo_ring: _ComboRing = null

## Attack range cone indicator; null when not in combat.
## Spawned on cast_started, freed on preparation_started or player_died.
var _cone_indicator: _ConeIndicator = null


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	SpellCastingEffects.cast_started.connect(_on_cast_started)
	SpellCastingEffects.spell_hit_element.connect(_on_spell_hit_element)
	SpellCastingEffects.cast_hit_started.connect(_on_cast_hit_started)
	SpellCastingEffects.chain_index_changed.connect(_on_chain_index_changed)
	SpellCastingEffects.combo_window_opened.connect(_on_combo_window_opened)
	CombinationResolution.combo_resolved.connect(_on_combo_resolved)
	GameStateManager.preparation_started.connect(_on_preparation_started)
	HealthAndDamage.damage_taken.connect(_on_damage_taken)
	HealthAndDamage.heavy_hit.connect(_on_heavy_hit)
	HealthAndDamage.health_restored.connect(_on_health_restored)
	HealthAndDamage.player_died.connect(_on_player_died)
	HealthAndDamage.player_hp_zone_changed.connect(_on_hp_zone_changed)
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
	if HealthAndDamage.health_restored.is_connected(_on_health_restored):
		HealthAndDamage.health_restored.disconnect(_on_health_restored)
	if HealthAndDamage.player_died.is_connected(_on_player_died):
		HealthAndDamage.player_died.disconnect(_on_player_died)
	if HealthAndDamage.player_hp_zone_changed.is_connected(_on_hp_zone_changed):
		HealthAndDamage.player_hp_zone_changed.disconnect(_on_hp_zone_changed)
	if SpellCastingEffects.chain_index_changed.is_connected(_on_chain_index_changed):
		SpellCastingEffects.chain_index_changed.disconnect(_on_chain_index_changed)
	if SpellCastingEffects.combo_window_opened.is_connected(_on_combo_window_opened):
		SpellCastingEffects.combo_window_opened.disconnect(_on_combo_window_opened)
	if CombinationResolution.combo_resolved.is_connected(_on_combo_resolved):
		CombinationResolution.combo_resolved.disconnect(_on_combo_resolved)
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
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
	_show_range_cone(spell_effect)


## Spawns a hit impact VFX at the target, then triggers hitstop, screen shake, and audio.
func _on_spell_hit_element(target: Node, prana_type_id: int) -> void:
	var type_data: PranaType = PranaCatalog.get_type(prana_type_id)
	if type_data == null:
		push_warning("SpellVFX: PranaCatalog.get_type(%d) returned null — no impact." % prana_type_id)
		return
	var amplify: float = COMBO_ENDER_AMPLIFY if _next_is_ender else 1.0
	_next_is_ender = false
	if target is Node2D:
		_spawn_impact_vfx((target as Node2D).global_position, type_data.color)
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
	_spawn_swing_vfx()


## Tracks chain state so _on_spell_hit_element can detect and amplify the final attack.
## chain_index_changed fires before spell_hit_element in the same call stack — safe ordering.
func _on_chain_index_changed(combo_idx: int, combo_count: int) -> void:
	if combo_idx > 0 and combo_idx == combo_count:
		_next_is_ender = true
		_audio_play(&"sfx_combo_ender")
	# Free combo ring on expiry (combo_idx == 0 signals chain reset).
	if combo_idx == 0:
		_free_combo_ring()




## Handles preparation_started from GameStateManager.
## Frees the combo ring so it does not persist across waves.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	_free_combo_ring()
	_free_range_cone()


## Handles combo_window_opened from SpellCastingEffects.
## Spawns a depleting ring arc around Fayde showing the combo continuation window.
## No-op during death cinematic. Kills any existing ring before spawning a new one.
func _on_combo_window_opened(window_duration: float) -> void:
	if _dying:
		return
	_free_combo_ring()
	if get_tree() == null or get_tree().root == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is Node2D:
		return
	var color: Color = Color.WHITE
	var se: SpellEffect = SpellCastingEffects.get_cached_spell_effect()
	if se != null:
		var type_data: PranaType = PranaCatalog.get_type(se.primary_type)
		if type_data != null:
			color = type_data.color
	var ring := _ComboRing.new()
	ring.duration = window_duration
	ring.ring_color = color
	ring.top_level = true
	ring.global_position = (player as Node2D).global_position
	get_tree().root.add_child(ring)
	_combo_ring = ring


## Reinforces the recognition layer (ADR-0016) at cast resolve: a fired Cascade
## gets an audio stinger plus a "power surge" camera shake. The Combat HUD owns the
## text banner — this adds the audible/kinetic cue for the rare, big moment.
## Reaction-only and plain casts stay silent here to keep the cue meaningful.
## No-op during the death cinematic so it never fights the slow-mo beat.
func _on_combo_resolved(spell_effect: SpellEffect) -> void:
	if _dying or spell_effect == null:
		return
	if spell_effect.active_cascade != null:
		_audio_play(&"sfx_combo_ender")
		_start_shake(CASCADE_SHAKE_MULT)


## Frees the active combo window ring if one exists. Idempotent.
func _free_combo_ring() -> void:
	if _combo_ring != null:
		if is_instance_valid(_combo_ring):
			_combo_ring.queue_free()
		_combo_ring = null


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


# ── REST heal green wash ───────────────────────────────────────────────────────

## Handles health_restored from HealthAndDamage.
## Shows a brief green screen wash so the player perceives the REST room heal.
func _on_health_restored(target: Node, _healed_amount: int, _current_hp: int) -> void:
	if not target.is_in_group(&"player"):
		return
	_show_heal_wash()


## Shows a brief green flash overlay. Created lazily, reused across heals.
## Fades in instantly, then fades out over HEAL_FLASH_DURATION seconds.
func _show_heal_wash() -> void:
	if _heal_flash_layer == null:
		_heal_flash_layer = CanvasLayer.new()
		_heal_flash_layer.layer = 98  # below heavy-hit red (99), above HUD (10)
		add_child(_heal_flash_layer)
		_heal_flash_rect = ColorRect.new()
		_heal_flash_rect.color = Color(0.1, 1.0, 0.25, 0.0)
		_heal_flash_rect.anchor_right = 1.0
		_heal_flash_rect.anchor_bottom = 1.0
		_heal_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_heal_flash_layer.add_child(_heal_flash_rect)
	if _heal_flash_tween:
		_heal_flash_tween.kill()
	_heal_flash_rect.color.a = HEAL_FLASH_ALPHA
	_heal_flash_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_heal_flash_tween.tween_property(_heal_flash_rect, "color:a", 0.0, HEAL_FLASH_DURATION)


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
	_free_combo_ring()
	_free_range_cone()


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


# ── Range cone indicator ──────────────────────────────────────────────────────

## Spawns (or replaces) the attack range cone for the current spell.
## Range and angle come directly from SpellCastingEffects constants so the VFX
## always matches the actual targeting cone used in _select_primary_target().
func _show_range_cone(spell_effect: SpellEffect) -> void:
	if get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is Node2D:
		return
	_free_range_cone()
	var pt: int = spell_effect.primary_type if spell_effect != null else -1
	var cast_range: float
	var cone_angle: float
	match pt:
		0, 4:  # Ashfire / Verdant — pure melee
			cast_range = SpellCastingEffects.MELEE_RANGE
			cone_angle = SpellCastingEffects.CONE_ANGLE_MELEE
		1, 3:  # Voidblue / Deepfrost — semi-melee
			cast_range = SpellCastingEffects.SEMI_MELEE_RANGE
			cone_angle = SpellCastingEffects.CONE_ANGLE_SEMI_MELEE
		2:  # Stormgold — sniper
			cast_range = SpellCastingEffects.STORMGOLD_SNIPER_RANGE
			cone_angle = SpellCastingEffects.CONE_ANGLE_SNIPER
		_:
			cast_range = 150.0
			cone_angle = SpellCastingEffects.CONE_ANGLE_RANGED
	var color: Color = Color.WHITE
	if spell_effect != null:
		var type_data: PranaType = PranaCatalog.get_type(spell_effect.primary_type)
		if type_data != null:
			color = type_data.color
	var cone := _ConeIndicator.new()
	cone.cone_color = color
	cone.cast_range = cast_range
	cone.half_angle = deg_to_rad(cone_angle * 0.5)
	cone.fayde_node = player as Node2D
	cone.top_level = true
	cone.global_position = (player as Node2D).global_position
	get_tree().root.add_child(cone)
	_cone_indicator = cone


## Frees the active range cone. Idempotent.
func _free_range_cone() -> void:
	if _cone_indicator != null:
		if is_instance_valid(_cone_indicator):
			_cone_indicator.queue_free()
		_cone_indicator = null


## Spawns a per-Prana swing VFX at Fayde's current position and facing.
## Called on every cast_hit_started (every attack press). The node is top_level
## and self-frees — no tracking needed. No-op during death cinematic or if player absent.
func _spawn_swing_vfx() -> void:
	if _dying or get_tree() == null:
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null or not player is Node2D:
		return
	var se: SpellEffect = SpellCastingEffects.get_cached_spell_effect()
	if se == null:
		return
	var type_data: PranaType = PranaCatalog.get_type(se.primary_type)
	if type_data == null:
		return
	var facing: Vector2 = Vector2.RIGHT
	if player.has_method(&"get_facing_direction"):
		facing = player.get_facing_direction()
	var vfx := _SwingVFX.new()
	vfx.prana_type = se.primary_type
	vfx.swing_color = type_data.color
	vfx.facing = facing
	vfx.top_level = true
	vfx.global_position = (player as Node2D).global_position
	get_tree().root.add_child(vfx)


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


# ── Impact VFX ────────────────────────────────────────────────────────────────

## Spawns a _ImpactVFX node at world position [param pos] with [param color].
## Always top_level — position is in world space.
func _spawn_impact_vfx(pos: Vector2, color: Color) -> void:
	if get_tree() == null or get_tree().root == null:
		return
	var vfx := _ImpactVFX.new()
	vfx.impact_color = color
	vfx.top_level = true
	get_tree().root.add_child(vfx)
	vfx.global_position = pos


# ── Inner class: combo window depleting ring (Gamefeel Pass 4 #6) ───────────────

## Procedural ring arc that depletes around Fayde during the combo continuation window.
## Arc shrinks from 360° to 0° over [member duration] seconds. Color from Prana type.
## Self-frees when duration expires. World-space, PROCESS_MODE_ALWAYS.
class _ComboRing extends Node2D:
	## Total duration of the combo window in seconds (COMBO_CONTINUATION_WINDOW = 2.0).
	var duration: float = 2.0
	## Prana type color for the ring.
	var ring_color: Color = Color.WHITE
	## Microsecond timestamp of ring creation.
	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 100
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= int(duration * 1_000_000.0):
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var elapsed: float = float(Time.get_ticks_usec() - _start_us) / 1_000_000.0
		var remaining: float = clampf(1.0 - elapsed / duration, 0.0, 1.0)
		# Alpha fades from 0.60 (peak) to 0.15 (near-expiry) — ring becomes fainter as urgency rises.
		var alpha: float = 0.15 + remaining * 0.45
		# Arc sweeps clockwise from top (−PI/2) — standard clock-face metaphor.
		var end_angle: float = -PI / 2.0 + remaining * TAU
		draw_arc(Vector2.ZERO, 50.0, -PI / 2.0, end_angle, 32,
				Color(ring_color, alpha), 3.5, true)


# ── Inner class: hit impact VFX ──────────────────────────────────────────────

## Expanding ring burst at the enemy's position on hit.
## Inner pop fades fast (≤0.4 normalized). Outer ring expands for full duration.
## Color = Prana type color. Self-frees after DURATION_US microseconds.
class _ImpactVFX extends Node2D:
	var impact_color: Color = Color.WHITE
	const DURATION_US: int = 200_000  # 0.20 s
	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 150
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= DURATION_US:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var p: float = clampf(float(Time.get_ticks_usec() - _start_us) / float(DURATION_US), 0.0, 1.0)
		# Outer shockwave ring — expands outward, fades.
		draw_arc(Vector2.ZERO, 10.0 + p * 45.0, 0.0, TAU, 24,
				Color(impact_color, 1.0 - p), 3.5, true)
		# Inner pop — bright circle that shrinks and disappears by p=0.4.
		var pop_p: float = minf(p / 0.4, 1.0)
		var pop_r: float = lerpf(14.0, 0.0, pop_p)
		if pop_r > 0.5:
			draw_circle(Vector2.ZERO, pop_r, Color(impact_color * 1.5, 1.0 - pop_p))


# ── Inner class: attack range cone indicator ──────────────────────────────────

## Persistent attack range cone shown during combat.
## Follows Fayde (top_level + global_position update), draws transparent cone
## whose angle and radius match the actual SC&E cone query for the current Prana type.
## Color = Prana type color. Spawned on cast_started; freed on preparation_started / player_died.
class _ConeIndicator extends Node2D:
	## Prana type color for the cone outline and fill.
	var cone_color: Color = Color.WHITE
	## Attack range in pixels — matches SC&E MELEE/SEMI_MELEE/STORMGOLD constants.
	var cast_range: float = 80.0
	## Half-angle of the cone in radians (cone_angle_deg * 0.5 converted to rad).
	var half_angle: float = PI / 4.0
	## Reference to the player node. Updated each frame for position + facing.
	var fayde_node: Node2D = null

	const SEGMENTS: int = 12
	const FILL_ALPHA: float = 0.08
	const OUTLINE_ALPHA: float = 0.28
	const OUTLINE_WIDTH: float = 1.5

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 50

	func _process(_delta: float) -> void:
		if is_instance_valid(fayde_node):
			global_position = fayde_node.global_position
		queue_redraw()

	func _draw() -> void:
		var facing: Vector2 = Vector2.RIGHT
		if is_instance_valid(fayde_node) and fayde_node.has_method(&"get_facing_direction"):
			facing = fayde_node.get_facing_direction()
		var base_angle: float = facing.angle()
		# Build cone polygon: origin tip + arc points.
		var pts := PackedVector2Array()
		pts.append(Vector2.ZERO)
		for i: int in range(SEGMENTS + 1):
			var t: float = float(i) / float(SEGMENTS)
			var a: float = base_angle - half_angle + t * half_angle * 2.0
			pts.append(Vector2.from_angle(a) * cast_range)
		# Filled transparent wedge.
		draw_polygon(pts, PackedColorArray([Color(cone_color, FILL_ALPHA)]))
		# Side edges (origin to arc extremes).
		draw_line(Vector2.ZERO, pts[1], Color(cone_color, OUTLINE_ALPHA), OUTLINE_WIDTH, true)
		draw_line(Vector2.ZERO, pts[pts.size() - 1], Color(cone_color, OUTLINE_ALPHA), OUTLINE_WIDTH, true)
		# Arc edge.
		draw_arc(Vector2.ZERO, cast_range,
				base_angle - half_angle, base_angle + half_angle,
				SEGMENTS, Color(cone_color, OUTLINE_ALPHA), OUTLINE_WIDTH, true)


# ── Inner class: per-Prana swing / whiff VFX ─────────────────────────────────

## Short-lived attack swing drawn at Fayde's position on every cast press.
## Appears on both hits and misses — on hits it underlays the ImpactVFX burst.
## Each Prana type has a distinct shape reflecting its semantic identity.
## Captured [member facing] at spawn time (no live tracking).
class _SwingVFX extends Node2D:
	## DamageClass int (FIRE=0, SHADOW=1, LIGHTNING=2, ICE=3, NATURE=4).
	var prana_type: int = 0
	## Prana type color (from PranaCatalog).
	var swing_color: Color = Color.WHITE
	## Facing direction captured at spawn — fixed for the lifetime of this node.
	var facing: Vector2 = Vector2.RIGHT
	const DURATION_US: int = 200_000  # 0.20 s

	var _start_us: int = 0

	func _ready() -> void:
		process_mode = PROCESS_MODE_ALWAYS
		z_index = 80  # above cone (50), below combo ring (100) and impact (150)
		_start_us = Time.get_ticks_usec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_usec() - _start_us >= DURATION_US:
			queue_free()
		else:
			queue_redraw()

	func _draw() -> void:
		var p: float = clampf(float(Time.get_ticks_usec() - _start_us) / float(DURATION_US), 0.0, 1.0)
		match prana_type:
			0: _draw_ashfire(p)
			1: _draw_voidblue(p)
			2: _draw_stormgold(p)
			3: _draw_deepfrost(p)
			4: _draw_verdant(p)

	## Ashfire — wide sweeping arc (130°), thick, like a fire whip.
	func _draw_ashfire(p: float) -> void:
		var alpha: float = 1.0 - p
		var span: float = deg_to_rad(130.0)
		var base_angle: float = facing.angle()
		# Outer arc: thick, overbright.
		draw_arc(Vector2.ZERO, 65.0, base_angle - span * 0.5, base_angle + span * 0.5,
				20, Color(swing_color * 1.6, alpha * 0.9), 4.0, true)
		# Inner thinner trace at 60% radius, narrower span.
		draw_arc(Vector2.ZERO, 40.0, base_angle - span * 0.4, base_angle + span * 0.4,
				14, Color(swing_color, alpha * 0.5), 2.0, true)

	## Voidblue — 3 parallel lunge lines stabbing forward, precise and silent.
	func _draw_voidblue(p: float) -> void:
		var alpha: float = 1.0 - p
		# Lines grow outward quickly then hold.
		var length: float = lerpf(10.0, 80.0, minf(p * 2.5, 1.0))
		var dir: Vector2 = facing.normalized()
		var perp: Vector2 = dir.orthogonal()
		# Center line (brightest), two flanking lines (dimmer).
		draw_line(Vector2.ZERO, dir * length,
				Color(swing_color * 1.4, alpha * 1.0), 2.5, true)
		draw_line(perp * 8.0, perp * 8.0 + dir * length * 0.85,
				Color(swing_color, alpha * 0.55), 1.5, true)
		draw_line(perp * -8.0, perp * -8.0 + dir * length * 0.85,
				Color(swing_color, alpha * 0.55), 1.5, true)

	## Stormgold — straight bolt forward, bright gold, snap fade.
	func _draw_stormgold(p: float) -> void:
		# Fades faster than other types — lightning is instantaneous.
		var alpha: float = clampf(1.0 - p * 1.8, 0.0, 1.0)
		var dir: Vector2 = facing.normalized()
		# Main bolt.
		draw_line(Vector2.ZERO, dir * 100.0,
				Color(swing_color * 2.2, alpha), 3.5, true)
		# Secondary thinner bolt (short inner glow).
		draw_line(dir * 8.0, dir * 75.0,
				Color(swing_color, alpha * 0.6), 1.5, true)

	## Deepfrost — 5 crystal shards fanning 90°, geometric and cold.
	func _draw_deepfrost(p: float) -> void:
		var alpha: float = 1.0 - p
		var span: float = deg_to_rad(90.0)
		var base_angle: float = facing.angle()
		var shard_len: float = lerpf(18.0, 58.0, minf(p * 2.0, 1.0))
		for i: int in range(5):
			var t: float = float(i) / 4.0
			var angle: float = base_angle - span * 0.5 + t * span
			var shard_dir: Vector2 = Vector2.from_angle(angle)
			var tip: Vector2 = shard_dir * shard_len
			var perp_s: Vector2 = shard_dir.orthogonal() * 4.5
			# Brightness falls off toward outer shards.
			var brightness: float = 1.0 - absf(t - 0.5) * 0.55
			# Main shard line.
			draw_line(Vector2.ZERO, tip,
					Color(swing_color * 1.5, alpha * brightness), 2.5, true)
			# Crystal facet edges.
			draw_line(perp_s * 0.4, tip,
					Color(swing_color, alpha * brightness * 0.45), 1.0, true)
			draw_line(-perp_s * 0.4, tip,
					Color(swing_color, alpha * brightness * 0.45), 1.0, true)

	## Verdant — 2 organic vine curves sweeping from the flanks to forward.
	func _draw_verdant(p: float) -> void:
		var alpha: float = 1.0 - p
		var dir: Vector2 = facing.normalized()
		var perp: Vector2 = dir.orthogonal()
		for side: int in range(2):
			var s: float = 1.0 if side == 0 else -1.0
			# Cubic bezier control points: start at flank, arc to forward tip.
			var cp0: Vector2 = perp * s * 32.0
			var cp1: Vector2 = perp * s * 20.0 + dir * 28.0
			var cp2: Vector2 = perp * s * 5.0  + dir * 58.0
			var cp3: Vector2 = dir * 72.0
			var pts := PackedVector2Array()
			for i: int in range(9):
				var t: float = float(i) / 8.0
				var q0: Vector2 = cp0.lerp(cp1, t)
				var q1: Vector2 = cp1.lerp(cp2, t)
				var q2: Vector2 = cp2.lerp(cp3, t)
				var r0: Vector2 = q0.lerp(q1, t)
				var r1: Vector2 = q1.lerp(q2, t)
				pts.append(r0.lerp(r1, t))
			draw_polyline(pts, Color(swing_color * 1.4, alpha * 0.9), 2.5, true)
			# Outer tendril — wider arc, thinner, dimmer.
			var op0: Vector2 = perp * s * 48.0
			var op1: Vector2 = perp * s * 32.0 + dir * 18.0
			var op2: Vector2 = perp * s * 10.0 + dir * 52.0
			var op3: Vector2 = dir * 68.0 + perp * s * 6.0
			var pts2 := PackedVector2Array()
			for i: int in range(9):
				var t: float = float(i) / 8.0
				var q0: Vector2 = op0.lerp(op1, t)
				var q1: Vector2 = op1.lerp(op2, t)
				var q2: Vector2 = op2.lerp(op3, t)
				var r0: Vector2 = q0.lerp(q1, t)
				var r1: Vector2 = q1.lerp(q2, t)
				pts2.append(r0.lerp(r1, t))
			draw_polyline(pts2, Color(swing_color, alpha * 0.5), 1.5, true)
