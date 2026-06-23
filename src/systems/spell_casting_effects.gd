## spell_casting_effects.gd — SpellCastingEffects Autoload #9.
## Sole owner of the wave's SpellEffect payload and wave-scoped stat broker (ADR-0009).
##
## Story: SC&E Story 001 — SpellEffect Resource, Stub CR, and Autoload Skeleton
## Story: SC&E Story 002 — Cast Input, Float Accumulators, and Chain Timing
## Story: SC&E Story 003 — FP Damage Formula, Targeting, and Status Stubs
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0004 (Float Accumulator Timers),
##      ADR-0009 (Wave-Scoped Stat Broker), ADR-0011 (StatusEffectsManager API)
##
## Operative states (TR-SC-001):
##   IDLE        — No active SpellEffect; cast input blocked.
##   READY       — SpellEffect cached; awaiting player cast press.
##   CHAINING    — Within the combo-continuation window after first hit.
##   CAST_LOCKED — Post-hit lock window; movement and new casts blocked.
##
## Responsibilities (Story 001 — skeleton):
##   - Declare four-state enum and initial field values
##   - Declare the three output signals: spell_hit_element, cast_hit_started,
##     chain_index_changed
##   - Connect to GameStateManager.preparation_started, combat_started,
##     and CombinationResolution.combo_resolved in _ready()
##   - Implement phase-gating: _on_combo_resolved rejects primary_type == -1
##   - Implement get_stat_bonus() as sole stat query interface (ADR-0009)
##   - Disconnect from all signals in _exit_tree() (ADR-0003 Rule 4)
##
## Responsibilities (Story 002 — cast input and chain timing):
##   - Register "cast" action in InputMap if not already present
##   - Float accumulator timers: _cast_lock_timer, _combo_window_timer (ADR-0004)
##   - _process(delta): decrement timers, handle CAST_LOCKED → CHAINING/READY
##     transitions, poll cast input when READY or CHAINING (TR-SC-002)
##   - _trigger_cast(): advance _combo_index, emit cast_hit_started and
##     chain_index_changed (TR-SC-006, TR-SC-008)
##
## Responsibilities (Story 003 — FP damage formula, targeting, and status stubs):
##   - ATTACK_DATA inline constant: tier_attack_modifier per type/tier/index
##   - Injectable seams: _rng, _health_and_damage (Variant), _status_effects
##     (Variant), _override_target, _fayde_ref
##   - _fire_attack(): Formula 3 (Steps 1–10); GDD Rule 7
##   - _apply_fp_status_stubs(): Formula 7 field-write stubs (GDD Rule 8)
##   - _fire_secondary_effect(): stub for tier_attack_modifier == 0.0 cases
##   - _select_primary_target(): physics ray for real game (headless-incompatible)
##
## Story 003 deviations (approved 2026-06-06):
##   Elemental strong/weakness (affiliation match multiplier) was cut from scope
##     2026-06-21. All hits are element-neutral; no per-element damage multiplier
##     is applied. Enemy prana_affiliation survives for death-burst VFX color only.
##   apply_status(): NOT called in _fire_attack at FP scope. GDD Rule 8 specifies
##     field-write stubs only (target.set()) at FP — SEM is not wired to enemies
##     at FP. apply_status() wired at MVP per ADR-0011.
##   apply_damage() element param: GameEnums.DamageClass.NONE (not the spell's
##     actual element). Damage delivery is element-neutral by design.
##
## Registration: Autoload #9 in project.godot (ADR-0002).
## No class_name — Godot 4 rejects class_name matching the Autoload node name.
## Access: SpellCastingEffects.get_stat_bonus(&"ASH_DMG")
## Access in tests: preload("res://src/systems/spell_casting_effects.gd").new()
extends Node


# ── State enum ────────────────────────────────────────────────────────────────

## Operative state machine for the spell casting lifecycle.
enum SCEState {
	IDLE        = 0,  ## No active SpellEffect. Initial state; reset on preparation_started.
	READY       = 1,  ## SpellEffect cached; awaiting player cast press.
	CHAINING    = 2,  ## Combo-continuation window active after first chain attack.
	CAST_LOCKED = 3,  ## Post-hit lock window; input blocked until timer expires.
}


# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted per hit — CombatHUD uses prana_type_id for damage-number coloring.
signal spell_hit_element(target: Node, prana_type_id: int)

## Emitted after each hit — PlayerController enters CAST_LOCKED movement sub-state.
signal cast_hit_started(lock_duration: float)

## Emitted when _combo_index changes — drives CombatHUD chain-dot indicator.
signal chain_index_changed(combo_index: int, combo_attack_count: int)

## Emitted when SC&E transitions from IDLE → READY (SpellEffect cached, player may cast).
## SpellVFX listens to this to prime visual/audio readiness cues per GDD Rule 1.
signal cast_started(spell_effect: SpellEffect)

## Emitted when the combo continuation window opens (CAST_LOCKED → CHAINING transition).
## [param window_duration] is COMBO_CONTINUATION_WINDOW (2.0s). SpellVFX uses this to
## spawn a depleting ring arc around Fayde — Gamefeel Pass 4 #6.
signal combo_window_opened(window_duration: float)


# ── Constants ─────────────────────────────────────────────────────────────────

## Default cast lock duration after each hit (all Prana types except Ashfire). (TR-SC-002)
const CAST_LOCK_DURATION: float = 0.12

## Extended cast lock for Ashfire — dance identity requires longer recovery. (TR-SC-002)
const ASHFIRE_CAST_LOCK_DURATION: float = 0.20

## Seconds the player has to press the next chain attack before the chain resets. (TR-SC-002)
const COMBO_CONTINUATION_WINDOW: float = 2.0

## Base knockback distance in pixels per hit. Multiplied by tier_attack_modifier.
## Tuning knob: 60 gives ~1 character-width slide; T3 eruption pushes 60×1.50=90px.
const KNOCKBACK_BASE: float = 60.0

## Maximum knockback distance in pixels (hard cap regardless of modifier).
const KNOCKBACK_MAX: float = 90.0

## Input buffer window in seconds — early SPACE press within this window still fires.
const INPUT_BUFFER_WINDOW: float = 0.15

## Cone spread angle in degrees for melee-range types (Ashfire).
## Wider cone compensates for the short 80px range — melee should feel forgiving.
const CONE_ANGLE_MELEE: float = 90.0

## Cone spread angle in degrees for ranged types (all non-Ashfire).
## Narrower cone requires more precise facing at 150px range.
const CONE_ANGLE_RANGED: float = 45.0

## Cone spread angle for semi-melee types (Voidblue, Deepfrost) — medium range, medium spread.
const CONE_ANGLE_SEMI_MELEE: float = 75.0

## Cone spread angle for Stormgold sniper — long range, narrow precision cone.
const CONE_ANGLE_SNIPER: float = 30.0

## Cast range for pure melee types (Ashfire, Verdant).
const MELEE_RANGE: float = 80.0

## Cast range for semi-melee types (Voidblue, Deepfrost).
const SEMI_MELEE_RANGE: float = 110.0

## Cast range for Stormgold sniper attacks.
const STORMGOLD_SNIPER_RANGE: float = 220.0

## Maximum Fayde-to-target distance for Stormgold Follow-Through bonus (+30% damage).
## Player must sprint from sniper range into this zone during the Stun window.
## Deferred: requires Enemy AI _is_attacking flag; currently inert at FP scope.
const STORMGOLD_FOLLOW_THROUGH_MAX_DIST: float = 100.0

## Number of arc segments used to approximate the cone for intersect_shape queries.
const CONE_ARC_SEGMENTS: int = 8

## Reference damage constant for all spell calculations (GDD Formula 1).
## Tuning knob: safe range 10–30. At 20, Ashfire T1 deals round(20×1.25×1.00)=25.
const BASE_SPELL_DAMAGE: float = 20.0

## Instant heal amount applied to Fayde by the Verdant shield pulse (modifier==0.0 slot).
## Tuning knob: safe range 10–25. At 15, fully heals ~2 Rifter hits (6–8 dmg each).
const SHIELD_PULSE_HEAL: float = 15.0

## AoE radius in pixels for Deepfrost T3 glacial field (modifier==0.0 slot).
## At 200px the field covers roughly the central 60% of the default diamond arena.
const GLACIAL_FIELD_RADIUS: float = 200.0

## Attack data per [primary_type][primary_tier][attack_index].
## Key "modifier" = tier_attack_modifier used in Formula 3 Step 4.
## FP inline — migrate to Resource at MVP (TR-SC-003).
const ATTACK_DATA: Dictionary = {
	0: {  # Ashfire — base_damage_modifier = 1.25
		1: [{"modifier": 1.00}],
		2: [{"modifier": 1.00}, {"modifier": 1.25}],
		3: [{"modifier": 1.00}, {"modifier": 1.25}, {"modifier": 1.50}],
	},
	1: {  # Voidblue — base_damage_modifier = 0.90
		1: [{"modifier": 1.00}],
		2: [{"modifier": 1.00}, {"modifier": 1.10}],
		3: [{"modifier": 1.00}, {"modifier": 1.10}, {"modifier": 1.30}],
	},
	2: {  # Stormgold — base_damage_modifier = 1.15
		1: [{"modifier": 1.00}],
		2: [{"modifier": 1.00}, {"modifier": 1.20}],
		3: [{"modifier": 1.00}, {"modifier": 1.20}, {"modifier": 1.00}],
	},
	3: {  # Deepfrost — base_damage_modifier = 0.80
		1: [{"modifier": 1.00}],
		2: [{"modifier": 1.00}, {"modifier": 0.80}],
		3: [{"modifier": 1.00}, {"modifier": 0.80}, {"modifier": 0.00}],  # T3 index 2 = glacial field
	},
	4: {  # Verdant — base_damage_modifier = 0.70
		1: [{"modifier": 1.00}],
		2: [{"modifier": 1.00}, {"modifier": 0.00}],  # T2 index 1 = SELF shield pulse
		3: [{"modifier": 1.00}, {"modifier": 0.00}, {"modifier": 1.20}],
	},
}


# ── Injectable seams (Story 003) ──────────────────────────────────────────────

## RandomNumberGenerator for crit rolls. Auto-created in _ready(); assign directly
## in tests for deterministic results (GDD Acceptance Criteria test harness requirement).
## Not @export — RandomNumberGenerator is not a Resource/Node; Godot 4.6 parse error.
var _rng: RandomNumberGenerator = null

## HealthAndDamage Autoload reference. Set in _ready(); injectable for tests
## without H&D Autoload being live (same Variant pattern as SEM._health_and_damage).
var _health_and_damage: Variant = null

## StatusEffectsManager Autoload reference. Set in _ready(); injectable for tests.
var _status_effects: Variant = null

## When non-null, bypasses _select_primary_target() — tests set this to a MockEnemy.
## Set to null in production (ray cast is used). Never persists across tests.
var _override_target: Node = null

## Cached reference to Fayde (player node). Resolved in _ready() via player group.
var _fayde_ref: Node = null

## Run-wide sigil damage multiplier (1.0 = no sigil). Multiplied into every hit's
## raw damage at step 8b. Set by sigils via apply_damage_mult(); persists for the run.
var _run_damage_mult: float = 1.0


# ── Private state ─────────────────────────────────────────────────────────────

## Current operative state.
var _state: SCEState = SCEState.IDLE

## Index of the next chain attack to fire (0 = first, increments on each press).
var _combo_index: int = 0

## Cached SpellEffect for the current wave. Null between waves. (ADR-0009)
var _current_spell_effect: SpellEffect = null

## True while the GameStateManager is in COMBAT phase.
## Required so _on_combo_resolved can guard the IDLE→READY transition.
var _in_combat: bool = false

## Counts down after each hit; blocks cast input when > 0. (ADR-0004, TR-SC-002)
var _cast_lock_timer: float = 0.0

## Counts down between chain presses; resets to COMBO_CONTINUATION_WINDOW on each cast. (ADR-0004, TR-SC-002)
var _combo_window_timer: float = 0.0

## True when the player pressed cast during cast lock — buffered for INPUT_BUFFER_WINDOW seconds.
var _buffer_pressed: bool = false

## Countdown for the input buffer. Positive = buffer active; expires at 0.
var _buffer_timer: float = 0.0

## AudioSystem reference; null-safe — set in _ready().
var _audio: Variant = null

## Injectable enemy-list getter for Deepfrost T3 glacial field.
## Production: set in _ready() to get_tree().get_nodes_in_group(&"enemy").
## Tests: inject a Callable returning a controlled list before calling _fire_attack().
var _get_enemies: Callable = Callable()


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	if not InputMap.has_action(&"cast"):
		InputMap.add_action(&"cast")
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		InputMap.action_add_event(&"cast", ev)
	# Injectable seam initialisation — only set if not already injected by a test.
	# _rng is typed as RandomNumberGenerator; tests may assign a seeded real RNG for
	# deterministic rolls. Duck-typed Variant injection (like _health_and_damage) is
	# not needed here because RandomNumberGenerator's randf() cannot be safely overridden
	# in GDScript subclasses (warning-as-error in Godot 4.6).
	if _rng == null:
		_rng = RandomNumberGenerator.new()
	if _health_and_damage == null:
		_health_and_damage = HealthAndDamage
	if _status_effects == null:
		_status_effects = StatusEffectsManager
	if not _get_enemies.is_valid():
		_get_enemies = func() -> Array[Node]: return get_tree().get_nodes_in_group(&"enemy")
	_fayde_ref = get_tree().get_first_node_in_group(&"player")
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	CombinationResolution.combo_resolved.connect(_on_combo_resolved)
	_audio = get_node_or_null("/root/AudioSystem")


func _exit_tree() -> void:
	# ADR-0003 Rule 4: Autoloads must disconnect from all signals in _exit_tree().
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if CombinationResolution.combo_resolved.is_connected(_on_combo_resolved):
		CombinationResolution.combo_resolved.disconnect(_on_combo_resolved)


# ── Frame update ──────────────────────────────────────────────────────────────

## Drives all SC&E float accumulator timers per ADR-0004.
## Handles CAST_LOCKED expiry, combo window expiry, input buffer, and cast input polling. (TR-SC-002)
func _process(delta: float) -> void:
	# ── Input buffer countdown ─────────────────────────────────────────────────
	if _buffer_timer > 0.0:
		_buffer_timer -= delta
		if _buffer_timer <= 0.0:
			_buffer_timer = 0.0
			_buffer_pressed = false

	if _cast_lock_timer > 0.0:
		_cast_lock_timer -= delta
		if _cast_lock_timer <= 0.0:
			_cast_lock_timer = 0.0
			if _state == SCEState.CAST_LOCKED:
				_state = SCEState.CHAINING if _combo_index > 0 else SCEState.READY
				if _state == SCEState.CHAINING:
					combo_window_opened.emit(COMBO_CONTINUATION_WINDOW)
			# Auto-fire if input was buffered during lock
			if _buffer_pressed and _state != SCEState.IDLE:
				_buffer_pressed = false
				_buffer_timer = 0.0
				_trigger_cast()
				return

	if _state == SCEState.CHAINING:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			# Combo window expired — reset chain to READY
			_combo_index = 0
			_buffer_pressed = false
			_buffer_timer = 0.0
			_state = SCEState.READY
			chain_index_changed.emit(0, _current_spell_effect.combo_attack_count if _current_spell_effect else 0)

	# ── Cast input polling ────────────────────────────────────────────────────
	# Buffer early presses during cast lock; process normally when ready.
	if Input.is_action_just_pressed(&"cast"):
		if _cast_lock_timer > 0.0:
			# Buffer this press — it fires when lock expires
			_buffer_pressed = true
			_buffer_timer = INPUT_BUFFER_WINDOW
		elif _state == SCEState.READY or _state == SCEState.CHAINING:
			_trigger_cast()


## Fires a single chain attack: advances _combo_index, calls _fire_attack,
## emits signals, and sets timers. (TR-SC-006, TR-SC-008)
func _trigger_cast() -> void:
	if _current_spell_effect == null:
		return
	var combo_count: int = _current_spell_effect.combo_attack_count
	if _combo_index >= combo_count:
		# Combo exhausted — reset and start a fresh chain immediately.
		# Prevents the silent-no-op that made Fayde feel unresponsive
		# between combo cycles (Gamefeel Pass 4 fluidity fix).
		_combo_index = 0
		chain_index_changed.emit(0, combo_count)
		_buffer_pressed = false
		_buffer_timer = 0.0

	_combo_index += 1
	chain_index_changed.emit(_combo_index, combo_count)

	# Audio: combo step sound (null-safe).
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_combo_advance"):
		_audio.play_event(&"sfx_combo_advance")

	# Story 003: fire the attack for the just-advanced index.
	# current_index is _combo_index - 1 because _combo_index was already incremented above.
	var current_index: int = _combo_index - 1
	_fire_attack(current_index)

	var lock_dur: float = ASHFIRE_CAST_LOCK_DURATION if _current_spell_effect.primary_type == GameEnums.DamageClass.FIRE \
		else CAST_LOCK_DURATION
	cast_hit_started.emit(lock_dur)
	_cast_lock_timer = lock_dur
	_state = SCEState.CAST_LOCKED
	_combo_window_timer = COMBO_CONTINUATION_WINDOW


# ── Damage formula (Story 003) ────────────────────────────────────────────────

## Executes Formula 3 for one attack in the chain. (GDD Rule 7, TR-SC-003)
##
## [param attack_index] is zero-based: 0 = first attack, 1 = second, etc.
## Precondition: _combo_index must already be incremented before this call
## (as done by _trigger_cast()). Step 8 ASH_CRIT guard reads _combo_index == 1
## to detect "first attack" — callers that invoke _fire_attack() directly must
## pre-set _combo_index accordingly.
func _fire_attack(attack_index: int) -> void:
	var se: SpellEffect = _current_spell_effect
	var tier: int = se.primary_tier
	var pt: int = se.primary_type

	if attack_index >= ATTACK_DATA[pt][tier].size():
		push_error("SpellCastingEffects._fire_attack(): attack_index %d out of bounds for type %d tier %d (max %d)" % [attack_index, pt, tier, ATTACK_DATA[pt][tier].size() - 1])
		return
	var attack_entry: Dictionary = ATTACK_DATA[pt][tier][attack_index]
	var tier_mod: float = attack_entry["modifier"]

	# tier_attack_modifier == 0.0 guard: skip damage chain entirely; fire secondary only.
	# Covers Verdant T2/T3 SELF shield pulse and Deepfrost T3 glacial field (GDD Edge Cases).
	if tier_mod == 0.0:
		_fire_secondary_effect(pt, tier, attack_index)
		return

	# Steps 1–4: per-cast base damage. Captured as step4_raw before per-target adjustments
	# so the original Step-4 value is available for Burn DoT tick calculations (GDD Rule 8).
	var flat_stat: float = 0.0
	if pt == 0:
		flat_stat = se.aggregate_stat_bonus.get(&"ASH_DMG", 0.0)
	elif pt == 3:
		flat_stat = se.aggregate_stat_bonus.get(&"FROST_DMG", 0.0)
	var eff_base: float = BASE_SPELL_DAMAGE + flat_stat
	var eff_mod: float = clampf(se.base_damage_modifier, 0.0, 1.40)
	var step4_raw: float = eff_base * eff_mod * tier_mod

	# Step 8 — ASH_CRIT: rolled once per cast so all targets receive the same crit outcome.
	# _combo_index == 1 means this is the first press (incremented before _fire_attack).
	var crit_mult: float = 1.0
	if _combo_index == 1:
		var ash_crit: float = se.aggregate_stat_bonus.get(&"ASH_CRIT", 0.0)
		if ash_crit > 0.0 and _rng.randf() < ash_crit:
			crit_mult = 1.50

	if pt == 2:
		# Stormgold — single-target projectile: disappears on the first enemy hit.
		var target: Node = _override_target if _override_target != null else _select_primary_target()
		if target == null:
			return
		_apply_hit(target, pt, tier_mod, se, step4_raw, crit_mult)
	else:
		# All other types — every enemy inside the facing cone takes damage.
		# _override_target != null is the test-mode path (single injected target as array).
		var targets: Array[Node] = []
		if _override_target != null:
			targets = [_override_target]
		else:
			targets = _select_all_targets_in_cone()
		for target: Node in targets:
			_apply_hit(target, pt, tier_mod, se, step4_raw, crit_mult)


## Applies Steps 5–9 of Formula 3 to [param target] and emits spell_hit_element.
## [param step4_raw] is the pre-shatter base for Burn DoT tick calcs (GDD Rule 8).
## [param crit_mult] is the per-cast ASH_CRIT factor (1.0 or 1.50); applied after per-target steps.
func _apply_hit(target: Node, pt: int, tier_mod: float, se: SpellEffect,
		step4_raw: float, crit_mult: float) -> void:
	var raw: float = step4_raw

	# Step 5 — Shatter (per-target).
	raw = _status_effects.check_and_apply_shatter(target, raw)

	# Step 6 — Follow-Through: always 0.0 at FP.

	# Step 7 — Blind bonus (per-target).
	if _status_effects.has_status(target, GameEnums.BaseStatus.BLIND):
		raw *= (1.0 + se.aggregate_stat_bonus.get(&"VOID_DMG_VS_BLIND", 0.0))

	# Step 8 — apply crit multiplier (rolled once per cast, applied after per-target steps).
	raw *= crit_mult

	# Step 8b — apply run-wide sigil damage multiplier (1.0 = no sigil).
	raw *= _run_damage_mult

	# Step 9 — deliver damage (element-neutral; affiliation cut 2026-06-21).
	_health_and_damage.apply_damage(target, raw, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)

	spell_hit_element.emit(target, pt)

	_apply_status_effects(target, pt, se, step4_raw)

	if _fayde_ref != null:
		_apply_knockback(target, tier_mod)


## Applies a knockback push to [param target] away from Fayde.
## Distance scales with tier_attack_modifier, capped at KNOCKBACK_MAX.
## No-op if target lacks the apply_knockback duck-type method.
func _apply_knockback(target: Node, tier_mod: float) -> void:
	if _fayde_ref == null:
		return
	var distance: float = minf(KNOCKBACK_BASE * tier_mod, KNOCKBACK_MAX)
	if distance <= 0.0:
		return
	# Direction FROM Fayde TO target = away from Fayde. direction_to gives from→to vector.
	var dir: Vector2 = _fayde_ref.global_position.direction_to(target.global_position) if target is Node2D \
		else Vector2.RIGHT
	# Duck-type: call apply_knockback if the method exists (works for EnemyInstance, DummyEnemy, MockEnemy).
	if target.has_method(&"apply_knockback"):
		target.apply_knockback(dir, distance)


## Applies the primary Prana type's status via StatusEffectsManager (ADR-0011).
## [param step4_raw] is the Step-4 core damage (before Shatter/Follow-Through) —
## used as spell_base_damage for Burn DoT tick calculations (GDD Rule 8).
## Verdant Regen targets _fayde_ref (not the enemy); guarded for null in tests.
func _apply_status_effects(target: Node, pt: int, se: SpellEffect, step4_raw: float) -> void:
	match pt:
		0:  # Ashfire — Burn DoT; step4_raw drives tick magnitude.
			_status_effects.apply_status(target, GameEnums.BaseStatus.BURN, 2.0, step4_raw)
		1:  # Voidblue — Blind.
			var dur: float = 2.0 + se.aggregate_stat_bonus.get(&"VOID_BLIND_DUR", 0.0)
			_status_effects.apply_status(target, GameEnums.BaseStatus.BLIND, dur)
		2:  # Stormgold — Stun. SEM calls target.apply_stun(dur) → STUNNED state.
			var dur: float = 0.8 + se.aggregate_stat_bonus.get(&"STORM_STUN_DUR", 0.0)
			_status_effects.apply_status(target, GameEnums.BaseStatus.STUN, dur)
		3:  # Deepfrost — Freeze. SEM calls target.apply_speed_modifier(0.50).
			var dur: float = 2.0 + se.aggregate_stat_bonus.get(&"FROST_FREEZE_DUR", 0.0)
			_status_effects.apply_status(target, GameEnums.BaseStatus.FREEZE, dur)
		4:  # Verdant — Regen on Fayde (not on the enemy target).
			if _fayde_ref != null:
				_status_effects.apply_status(_fayde_ref, GameEnums.BaseStatus.REGENERATE, 3.0)


## Fires the secondary effect for a tier_attack_modifier == 0.0 attack slot.
## Verdant (pt=4): instant heal (shield pulse) to Fayde — SHIELD_PULSE_HEAL HP.
## Deepfrost T3 index 2 (pt=3, tier=3, attack_index=2): glacial field via _apply_glacial_field().
## Any other unimplemented combination: push_error (explicit caller error).
func _fire_secondary_effect(pt: int, tier: int, attack_index: int) -> void:
	match pt:
		4:  # Verdant — shield pulse: instant heal to Fayde
			if _fayde_ref != null:
				_health_and_damage.apply_heal(_fayde_ref, SHIELD_PULSE_HEAL)
		3:  # Deepfrost — only T3 index 2 is defined as glacial field in ATTACK_DATA
			if tier == 3 and attack_index == 2:
				_apply_glacial_field()
			else:
				push_error(
					"SpellCastingEffects._fire_secondary_effect(): Deepfrost secondary "
					+ "not implemented at tier=%d index=%d" % [tier, attack_index]
				)
		_:
			push_error(
				"SpellCastingEffects._fire_secondary_effect(): unimplemented secondary "
				+ "(type=%d tier=%d index=%d)" % [pt, tier, attack_index]
			)


## Applies FREEZE to every enemy within GLACIAL_FIELD_RADIUS of Fayde's position.
## Called by _fire_secondary_effect() for the Deepfrost T3 index-2 glacial field slot.
## No-op when _fayde_ref is null or _get_enemies is invalid.
func _apply_glacial_field() -> void:
	if _fayde_ref == null or not _get_enemies.is_valid():
		return
	var origin: Vector2 = (_fayde_ref as Node2D).global_position \
		if _fayde_ref is Node2D else Vector2.ZERO
	for enemy: Node in _get_enemies.call():
		if not (enemy is Node2D):
			continue
		if origin.distance_to((enemy as Node2D).global_position) <= GLACIAL_FIELD_RADIUS:
			_status_effects.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.5)


## Selects a primary target via cone overlap query (replaces raycast for combo game feel).
## 5-tier range system: Ashfire/Verdant 80px 90°, Voidblue/Deepfrost 110px 75°, Stormgold 220px 30°.
## Returns the nearest enemy within the cone, or null if none found.
## Tests bypass this entirely via _override_target.
func _select_primary_target() -> Node:
	if _fayde_ref == null:
		_fayde_ref = get_tree().get_first_node_in_group(&"player")
	if _fayde_ref == null:
		return null
	var space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var origin: Vector2 = _fayde_ref.global_position
	var facing: Vector2 = _fayde_ref.get_facing_direction() if _fayde_ref.has_method(&"get_facing_direction") else Vector2.RIGHT
	# 5-tier range system: pure melee (80px) / semi-melee (110px) / sniper (220px).
	# Cone widens at shorter ranges to compensate for reduced reach.
	var pt: int = _current_spell_effect.primary_type if _current_spell_effect != null else -1
	var cast_range: float
	var cone_angle: float
	match pt:
		0, 4:  # Ashfire, Verdant — pure melee
			cast_range = MELEE_RANGE
			cone_angle = CONE_ANGLE_MELEE
		1, 3:  # Voidblue, Deepfrost — semi-melee
			cast_range = SEMI_MELEE_RANGE
			cone_angle = CONE_ANGLE_SEMI_MELEE
		2:  # Stormgold — sniper
			cast_range = STORMGOLD_SNIPER_RANGE
			cone_angle = CONE_ANGLE_SNIPER
		_:
			cast_range = 150.0
			cone_angle = CONE_ANGLE_RANGED

	# Build a ConvexPolygonShape2D approximating a cone sector in the facing direction.
	# Points: origin (0,0) + arc points spread across cone_angle, centred on facing.
	var half_angle: float = deg_to_rad(cone_angle * 0.5)
	var base_angle: float = facing.angle()
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)  # cone tip at origin
	for i in range(CONE_ARC_SEGMENTS + 1):
		var t: float = float(i) / float(CONE_ARC_SEGMENTS)
		var a: float = base_angle - half_angle + t * half_angle * 2.0
		points.append(Vector2.from_angle(a) * cast_range)
	var cone_shape := ConvexPolygonShape2D.new()
	cone_shape.points = points

	# Offset the query transform to Fayde's world position.
	var query_transform := Transform2D(0.0, origin)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = cone_shape
	query.transform = query_transform
	query.collision_mask = 5  # walls (1) + enemies (4)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results: Array[Dictionary] = space.intersect_shape(query)
	if results.is_empty():
		return null

	# Return the nearest enemy (by distance from Fayde).
	var nearest: Node = null
	var nearest_dist: float = INF
	for result in results:
		var collider: Node = result.get("collider")
		if collider != null and collider.is_in_group(&"enemy") and collider.has_method(&"is_alive") and collider.is_alive():
			var dist: float = origin.distance_squared_to((collider as Node2D).global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = collider
	return nearest


## Returns ALL living enemies within the facing cone for AoE Prana types (non-Stormgold).
## Uses the same range/angle as [method _select_primary_target] for the current primary_type.
## Never called for pt==2 (Stormgold); tests use _override_target instead.
func _select_all_targets_in_cone() -> Array[Node]:
	if _fayde_ref == null:
		_fayde_ref = get_tree().get_first_node_in_group(&"player")
	if _fayde_ref == null:
		return []
	var space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var origin: Vector2 = _fayde_ref.global_position
	var facing: Vector2 = _fayde_ref.get_facing_direction() if _fayde_ref.has_method(&"get_facing_direction") else Vector2.RIGHT
	var pt: int = _current_spell_effect.primary_type if _current_spell_effect != null else -1
	var cast_range: float
	var cone_angle: float
	match pt:
		0, 4:
			cast_range = MELEE_RANGE
			cone_angle = CONE_ANGLE_MELEE
		1, 3:
			cast_range = SEMI_MELEE_RANGE
			cone_angle = CONE_ANGLE_SEMI_MELEE
		_:
			cast_range = 150.0
			cone_angle = CONE_ANGLE_RANGED

	var half_angle: float = deg_to_rad(cone_angle * 0.5)
	var base_angle: float = facing.angle()
	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in range(CONE_ARC_SEGMENTS + 1):
		var t: float = float(i) / float(CONE_ARC_SEGMENTS)
		var a: float = base_angle - half_angle + t * half_angle * 2.0
		points.append(Vector2.from_angle(a) * cast_range)
	var cone_shape := ConvexPolygonShape2D.new()
	cone_shape.points = points

	var query_transform := Transform2D(0.0, origin)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = cone_shape
	query.transform = query_transform
	query.collision_mask = 5
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var results: Array[Dictionary] = space.intersect_shape(query)
	var targets: Array[Node] = []
	for result in results:
		var collider: Node = result.get("collider")
		if collider != null and collider.is_in_group(&"enemy") and collider.has_method(&"is_alive") and collider.is_alive():
			targets.append(collider)
	return targets


# ── Public API ────────────────────────────────────────────────────────────────

## Sigil: multiplies the run-wide spell damage multiplier by [param factor]
## (e.g. 1.20 = +20% damage). Stacks multiplicatively; persists for the run.
func apply_damage_mult(factor: float) -> void:
	_run_damage_mult *= factor


## Returns the current run-wide damage multiplier. Exposed for tests and sigil UI.
func get_damage_mult() -> float:
	return _run_damage_mult


## Returns the additive stat delta for [param stat_id] from the current wave's SpellEffect.
## Returns 0.0 when no SpellEffect is cached (between waves or preparation_started).
## Callers: HealthAndDamage (VER_HEAL_FLAT), StatusEffectsManager (duration bonuses).
## No other system may read aggregate_stat_bonus directly (ADR-0009).
func get_stat_bonus(stat_id: StringName) -> float:
	if _current_spell_effect == null:
		return 0.0
	return _current_spell_effect.aggregate_stat_bonus.get(stat_id, 0.0)


## Read-only access to the cached SpellEffect for the current wave.
## Returns null between waves. Used by SpellVFX and CombatHUD for per-type visual routing.
func get_cached_spell_effect() -> SpellEffect:
	return _current_spell_effect


# ── Signal handlers ───────────────────────────────────────────────────────────

## Resets all wave state when a new preparation phase begins.
func _on_preparation_started(_idx: int, _rem: int) -> void:
	_state = SCEState.IDLE
	_combo_index = 0
	_in_combat = false
	_current_spell_effect = null
	_cast_lock_timer = 0.0
	_combo_window_timer = 0.0


## Marks SC&E as in-combat so the next combo_resolved can transition to READY.
func _on_combat_started(_is_boss: bool) -> void:
	_in_combat = true


## Caches the wave SpellEffect and transitions to READY (when in combat).
## Rejects payloads with primary_type == -1 via push_error — stays IDLE.
func _on_combo_resolved(spell_effect: SpellEffect) -> void:
	if spell_effect == null:
		push_warning("SpellCastingEffects: combo_resolved received null SpellEffect. Staying IDLE.")
		return
	if spell_effect.primary_type == GameEnums.DamageClass.NONE:
		push_warning("SpellCastingEffects: combo_resolved received invalid SpellEffect (primary_type == NONE). Staying IDLE.")
		return
	# Allow through if _in_combat (set by SCE's own handler) OR if GSM is already
	# in COMBAT_PHASE. The latter handles the case where CR fires combo_resolved
	# synchronously inside combat_started before SCE's own _on_combat_started runs
	# (Autoload ordering: CR=#8, SCE=#9).
	if not (_in_combat or GameStateManager.get_active_state() == GameEnums.GameState.COMBAT_PHASE):
		return
	_current_spell_effect = spell_effect
	_state = SCEState.READY
	_combo_index = 0
	cast_started.emit(spell_effect)
