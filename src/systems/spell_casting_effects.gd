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

## Timing judgement for a basic press (design/gdd/special-attack.md Rule 2).
enum CastTiming {
	NORMAL  = 0,  ## Chain start from READY, or a late press after the Perfect window.
	PERFECT = 1,  ## Inside the Perfect window after the cast lock ended.
	RUSHED  = 2,  ## Chaining, but before the Perfect window (mashing / buffered).
}


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

## Emitted when an armed Prana Reaction actually fires in combat (ADR-0016 application).
## [param world_pos] is where it happened; [param prana_type_id] colours the callout.
## SpellVFX floats the reaction name there so players see the grid pay off.
signal reaction_triggered(reaction_name: String, world_pos: Vector2, prana_type_id: int)

## Emitted when the wave's Cascade burst fires at the end of a chain (GDD Formula 10).
## [param radius] is the burst's reach in px (0.0 for chain-shaped bursts).
signal cascade_burst(lead_type: int, world_pos: Vector2, radius: float)

## Emitted when a basic attack lands inside the Perfect rhythm window.
## [param streak] counts consecutive Perfects (1 = first). SpellVFX floats the callout.
signal perfect_cast(world_pos: Vector2, streak: int)

## Emitted whenever the Special meter changes. CombatHUD draws the meter bar.
signal special_meter_changed(value: float, max_value: float)

## Emitted when the Special fires. [param radius] is the burst's reach in px
## (0.0 for the Stormgold chain). SpellVFX draws the burst.
signal special_fired(prana_type_id: int, world_pos: Vector2, radius: float)

## Emitted when an enemy bullet or hazard grazes Fayde (ADR-0018). [param meter_gain]
## is the Special meter it added. SpellVFX / CombatHUD may flash on it.
signal grazed(world_pos: Vector2, meter_gain: float)


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

## Secondary reaction and Cascade knobs (Detonate radius, Surge heal, Cascade facets).
## Each reaction's primary value lives on its ReactionDef.magnitude.
const REACTION_TUNING: ReactionTuning = preload("res://assets/data/reaction_tuning.tres")

## Perfect Cast window and Special attack knobs.
const ATTACK_TUNING: AttackTuning = preload("res://assets/data/attack_tuning.tres")

## Graze gain and bullet-cancel knobs (ADR-0018).
const BULLET_HELL_TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")

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

## Armed reactions for the current wave, keyed by GameEnums.ReactionKind (int) → ReactionDef.
## Built from SpellEffect.active_reactions in _on_combo_resolved; empty between waves.
var _armed_reactions: Dictionary = {}

## Enemy instance ids already hit during the current chain — Thermal Shock only
## boosts the first hit on each target per chain. Reset when a new chain starts.
var _chain_hit_ids: Dictionary = {}

## True once Short Circuit's second stun has fired this chain.
var _short_circuit_used: bool = false

## True once Detonate's kill-burst has fired this chain.
var _detonate_used: bool = false

## Primary target of the most recent attack (nearest enemy hit); null on a miss.
## The Cascade burst centres on it when the chain's final attack lands.
var _last_primary_target: Node = null

## Number of enemies the most recent attack hit. Surge only heals on a landed hit.
var _last_attack_hit_count: int = 0

## Damage multiplier for the attack currently firing — perfect_damage_mult on a
## Perfect, rushed_damage_mult on a Rushed press, else 1.0. Applied in _apply_hit Step 8c.
var _perfect_mult: float = 1.0

## Consecutive Perfect basic attacks. Resets on a non-Perfect press or chain expiry.
var _perfect_streak: int = 0

## Special meter, 0..ATTACK_TUNING.special_meter_max. Resets each preparation phase.
var _special_meter: float = 0.0


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = PROCESS_MODE_PAUSABLE
	if not InputMap.has_action(&"cast"):
		InputMap.add_action(&"cast")
		var ev := InputEventKey.new()
		ev.keycode = KEY_SPACE
		InputMap.action_add_event(&"cast", ev)
	if not InputMap.has_action(&"special"):
		InputMap.add_action(&"special")
		var key := InputEventKey.new()
		key.keycode = KEY_F
		InputMap.action_add_event(&"special", key)
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(&"special", mouse)
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
					combo_window_opened.emit(_combo_window_duration())
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
			_perfect_streak = 0
			_buffer_pressed = false
			_buffer_timer = 0.0
			_state = SCEState.READY
			chain_index_changed.emit(0, _current_spell_effect.combo_attack_count if _current_spell_effect else 0)

	# ── Special input ─────────────────────────────────────────────────────────
	# The Special overrides cast lock, so it never feels swallowed mid-chain.
	if InputMap.has_action(&"special") and Input.is_action_just_pressed(&"special"):
		_trigger_special()
		return

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
	if _combo_index == 1:
		_reset_chain_reaction_state()
	chain_index_changed.emit(_combo_index, combo_count)

	# Audio: combo step sound (null-safe).
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_combo_advance"):
		_audio.play_event(&"sfx_combo_advance")

	# Story 003: fire the attack for the just-advanced index.
	# current_index is _combo_index - 1 because _combo_index was already incremented above.
	var current_index: int = _combo_index - 1
	var timing: CastTiming = get_cast_timing()
	var perfect: bool = timing == CastTiming.PERFECT
	var rushed: bool = timing == CastTiming.RUSHED
	_perfect_mult = ATTACK_TUNING.perfect_damage_mult if perfect \
		else (ATTACK_TUNING.rushed_damage_mult if rushed else 1.0)
	_fire_attack(current_index)
	_perfect_mult = 1.0
	_apply_surge_heal()
	var is_secondary: bool = ATTACK_DATA[_current_spell_effect.primary_type][_current_spell_effect.primary_tier][current_index]["modifier"] == 0.0
	var landed: bool = _last_attack_hit_count > 0 or is_secondary
	if perfect and landed:
		_perfect_streak += 1
		var at: Node = _last_primary_target if _is_live(_last_primary_target) else _fayde_ref
		perfect_cast.emit(_pos_of(at), _perfect_streak)
	else:
		_perfect_streak = 0
	if landed and not rushed:
		_add_special_meter(ATTACK_TUNING.special_gain_perfect if perfect else ATTACK_TUNING.special_gain_hit)
	if _combo_index == combo_count and not rushed:
		_fire_cascade(_last_primary_target, ATTACK_TUNING.perfect_cascade_mult if perfect else 1.0)

	var lock_dur: float = ASHFIRE_CAST_LOCK_DURATION if _current_spell_effect.primary_type == GameEnums.DamageClass.FIRE \
		else CAST_LOCK_DURATION
	cast_hit_started.emit(lock_dur)
	_cast_lock_timer = lock_dur
	_state = SCEState.CAST_LOCKED
	_combo_window_timer = _combo_window_duration()


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
		# Keeps _last_primary_target from the chain's previous hit so a secondary
		# final attack (Deepfrost T3 glacial field) still anchors the Cascade burst.
		_last_attack_hit_count = 0
		_fire_secondary_effect(pt, tier, attack_index)
		return

	_last_primary_target = null
	_last_attack_hit_count = 0

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
		_last_primary_target = target
		_last_attack_hit_count = 1
		_apply_hit(target, pt, tier_mod, se, step4_raw, crit_mult)
		_try_superconduct(target, [target], step4_raw)
	else:
		# All other types — every enemy inside the facing cone takes damage.
		# _override_target != null is the test-mode path (single injected target as array).
		var targets: Array[Node] = []
		if _override_target != null:
			targets = [_override_target]
		else:
			targets = _select_all_targets_in_cone()
		if targets.is_empty():
			return
		var primary: Node = _nearest_to_fayde(targets)
		_last_primary_target = primary
		_last_attack_hit_count = targets.size()
		for target: Node in targets:
			_apply_hit(target, pt, tier_mod, se, step4_raw, crit_mult)
		_try_superconduct(primary, targets, step4_raw)


## Applies Steps 5–9 of Formula 3 to [param target] and emits spell_hit_element.
## [param step4_raw] is the pre-shatter base for Burn DoT tick calcs (GDD Rule 8).
## [param crit_mult] is the per-cast ASH_CRIT factor (1.0 or 1.50); applied after per-target steps.
func _apply_hit(target: Node, pt: int, tier_mod: float, se: SpellEffect,
		step4_raw: float, crit_mult: float) -> void:
	var raw: float = step4_raw

	# Step 5 — Shatter (per-target).
	raw = _status_effects.check_and_apply_shatter(target, raw)

	# Step 5b — Thermal Shock: first hit on each target per chain. Never stacks with
	# Shatter on the same hit — the larger single bonus wins (GDD Edge Cases).
	var target_id: int = target.get_instance_id()
	var thermal: ReactionDef = _armed(GameEnums.ReactionKind.THERMAL_SHOCK)
	if thermal != null and not _chain_hit_ids.has(target_id):
		var thermal_raw: float = step4_raw * (1.0 + thermal.magnitude)
		if thermal_raw > raw:
			raw = thermal_raw
			_emit_reaction(thermal, target, GameEnums.DamageClass.FIRE)
	_chain_hit_ids[target_id] = true

	# Step 6 — Follow-Through: always 0.0 at FP.

	# Step 7 — Blind bonus (per-target).
	var target_blinded: bool = _status_effects.has_status(target, GameEnums.BaseStatus.BLIND)
	if target_blinded:
		raw *= (1.0 + se.aggregate_stat_bonus.get(&"VOID_DMG_VS_BLIND", 0.0))

	# Step 8 — apply crit multiplier (rolled once per cast, applied after per-target steps).
	raw *= crit_mult

	# Step 8b — apply run-wide sigil damage multiplier (1.0 = no sigil).
	raw *= _run_damage_mult

	# Step 8c — Perfect Cast bonus (1.0 unless this attack landed in the rhythm window).
	raw *= _perfect_mult

	# Step 9 — deliver damage (element-neutral; affiliation cut 2026-06-21).
	_health_and_damage.apply_damage(target, raw, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)

	spell_hit_element.emit(target, pt)

	# Siphon — damage dealt to a Blinded enemy heals Fayde.
	var siphon: ReactionDef = _armed(GameEnums.ReactionKind.SIPHON)
	if siphon != null and target_blinded and _fayde_ref != null:
		_health_and_damage.apply_heal(_fayde_ref, raw * siphon.magnitude)
		_emit_reaction(siphon, target, GameEnums.DamageClass.NATURE)

	# Detonate — the first kill of the chain bursts at the kill position.
	_try_detonate(target)

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
			_apply_burn(target, 2.0, step4_raw)
		1:  # Voidblue — Blind.
			var dur: float = 2.0 + se.aggregate_stat_bonus.get(&"VOID_BLIND_DUR", 0.0)
			_status_effects.apply_status(target, GameEnums.BaseStatus.BLIND, dur)
		2:  # Stormgold — Stun. SEM calls target.apply_stun(dur) → STUNNED state.
			var dur: float = 0.8 + se.aggregate_stat_bonus.get(&"STORM_STUN_DUR", 0.0)
			_apply_stun(target, dur)
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


# ── Reaction & Cascade application (ADR-0016, GDD Formulas 9–10) ─────────────
#
# CombinationResolution arms reactions and the Cascade from the grid; SC&E is the
# sole applier. "Chain" scopes (Thermal Shock, Short Circuit, Detonate) reset when
# a new chain starts, so each chain gets one of each. Bonus damage from reactions
# goes through _deal_bonus_damage(), which never re-triggers reactions.
# Whiteout is armed but inert: Blind has no miss-chance mechanic yet to raise.

## Returns the armed ReactionDef for [param kind] this wave, or null.
func _armed(kind: GameEnums.ReactionKind) -> ReactionDef:
	return _armed_reactions.get(int(kind), null)


## Indexes [param spell_effect]'s active reactions by kind and resets chain state.
## Tests call this directly to arm reactions without going through combo_resolved.
func _arm_reactions(spell_effect: SpellEffect) -> void:
	_armed_reactions.clear()
	for rdef: ReactionDef in spell_effect.active_reactions:
		if rdef != null:
			_armed_reactions[int(rdef.effect_kind)] = rdef
	_reset_chain_reaction_state()


## Clears the per-chain reaction bookkeeping. Called when a chain's first attack fires.
func _reset_chain_reaction_state() -> void:
	_chain_hit_ids.clear()
	_short_circuit_used = false
	_detonate_used = false
	_last_primary_target = null


## Returns the combo continuation window, extended by Surge when armed.
func _combo_window_duration() -> float:
	var surge: ReactionDef = _armed(GameEnums.ReactionKind.SURGE)
	return COMBO_CONTINUATION_WINDOW + (surge.magnitude if surge != null else 0.0)


## Emits [signal reaction_triggered] for [param rdef] at [param at]'s position.
func _emit_reaction(rdef: ReactionDef, at: Node, prana_type_id: int) -> void:
	reaction_triggered.emit(rdef.name, _pos_of(at), prana_type_id)


## World position of [param node], falling back to Vector2.ZERO for non-2D nodes.
func _pos_of(node: Node) -> Vector2:
	return (node as Node2D).global_position if node is Node2D else Vector2.ZERO


## Returns true when [param node] is a live enemy (valid, and alive when it can say so).
func _is_live(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	return not node.has_method(&"is_alive") or node.is_alive()


## Living enemies as Node2D, from the injectable _get_enemies seam.
func _living_enemies() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if not _get_enemies.is_valid():
		return out
	for enemy: Node in _get_enemies.call():
		if enemy is Node2D and _is_live(enemy):
			out.append(enemy as Node2D)
	return out


## Up to [param count] living enemies nearest [param origin] within [param max_range],
## skipping any in [param exclude]. Sorted nearest first.
func _nearest_enemies(origin: Vector2, exclude: Array, count: int,
		max_range: float = INF) -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	for enemy: Node2D in _living_enemies():
		if exclude.has(enemy):
			continue
		if origin.distance_to(enemy.global_position) <= max_range:
			candidates.append(enemy)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	return candidates.slice(0, count)


## Living enemies within [param radius] of [param origin].
func _enemies_within(origin: Vector2, radius: float) -> Array[Node2D]:
	return _nearest_enemies(origin, [], 1 << 20, radius)


## The target in [param targets] nearest Fayde; the first entry when Fayde is unknown.
func _nearest_to_fayde(targets: Array[Node]) -> Node:
	if not (_fayde_ref is Node2D):
		return targets[0]
	var origin: Vector2 = (_fayde_ref as Node2D).global_position
	var best: Node = targets[0]
	var best_dist: float = INF
	for target: Node in targets:
		var d: float = origin.distance_squared_to(_pos_of(target))
		if d < best_dist:
			best_dist = d
			best = target
	return best


## Deals reaction/Cascade damage: sigil multiplier applied, hit feedback emitted,
## but no Shatter, crit, or further reactions (bonus hits never chain into more bonuses).
func _deal_bonus_damage(target: Node, amount: float, prana_type_id: int) -> void:
	if amount <= 0.0 or not _is_live(target):
		return
	_health_and_damage.apply_damage(target, amount * _run_damage_mult,
		GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	spell_hit_element.emit(target, prana_type_id)


## Applies Burn, then Witchfire (Burn also Blinds) and Wildfire (Burn spreads once to
## the nearest other enemy in range). The spread itself is a plain Burn — no recursion.
func _apply_burn(target: Node, duration: float, spell_base: float) -> void:
	_status_effects.apply_status(target, GameEnums.BaseStatus.BURN, duration, spell_base)
	var witchfire: ReactionDef = _armed(GameEnums.ReactionKind.WITCHFIRE)
	if witchfire != null:
		_status_effects.apply_status(target, GameEnums.BaseStatus.BLIND, witchfire.magnitude)
		_emit_reaction(witchfire, target, GameEnums.DamageClass.SHADOW)
	var wildfire: ReactionDef = _armed(GameEnums.ReactionKind.WILDFIRE)
	if wildfire != null:
		var spread: Array[Node2D] = _nearest_enemies(_pos_of(target), [target], 1, wildfire.magnitude)
		if not spread.is_empty():
			_status_effects.apply_status(spread[0], GameEnums.BaseStatus.BURN,
				REACTION_TUNING.wildfire_burn_duration, spell_base)
			_emit_reaction(wildfire, spread[0], GameEnums.DamageClass.FIRE)


## Applies Stun, then Short Circuit: the chain's first Stun also stuns the nearest other enemy.
func _apply_stun(target: Node, duration: float) -> void:
	_status_effects.apply_status(target, GameEnums.BaseStatus.STUN, duration)
	var short_circuit: ReactionDef = _armed(GameEnums.ReactionKind.SHORT_CIRCUIT)
	if short_circuit == null or _short_circuit_used:
		return
	_short_circuit_used = true
	var second: Array[Node2D] = _nearest_enemies(_pos_of(target), [target], 1)
	if not second.is_empty():
		_status_effects.apply_status(second[0], GameEnums.BaseStatus.STUN, short_circuit.magnitude)
		_emit_reaction(short_circuit, second[0], GameEnums.DamageClass.LIGHTNING)


## Superconduct: when the attack's primary target is Frozen or Chilled, the hit arcs to
## the nearest enemy not already hit, for magnitude × the attack's base damage.
func _try_superconduct(primary: Node, already_hit: Array, step4_raw: float) -> void:
	var superconduct: ReactionDef = _armed(GameEnums.ReactionKind.SUPERCONDUCT)
	if superconduct == null or not is_instance_valid(primary):
		return
	if not (_status_effects.has_status(primary, GameEnums.BaseStatus.FREEZE)
			or _status_effects.has_status(primary, GameEnums.BaseStatus.CHILL)):
		return
	var arc: Array[Node2D] = _nearest_enemies(_pos_of(primary), already_hit, 1)
	if arc.is_empty():
		return
	_deal_bonus_damage(arc[0], step4_raw * superconduct.magnitude, GameEnums.DamageClass.LIGHTNING)
	_emit_reaction(superconduct, arc[0], GameEnums.DamageClass.LIGHTNING)


## Detonate: the chain's first kill bursts for magnitude × BASE_SPELL_DAMAGE to every
## other enemy within detonate_radius of the kill.
func _try_detonate(target: Node) -> void:
	var detonate: ReactionDef = _armed(GameEnums.ReactionKind.DETONATE)
	if detonate == null or _detonate_used or not is_instance_valid(target):
		return
	if not target.has_method(&"is_alive") or target.is_alive():
		return
	_detonate_used = true
	var origin: Vector2 = _pos_of(target)
	for enemy: Node2D in _enemies_within(origin, REACTION_TUNING.detonate_radius):
		_deal_bonus_damage(enemy, BASE_SPELL_DAMAGE * detonate.magnitude, GameEnums.DamageClass.FIRE)
	_emit_reaction(detonate, target, GameEnums.DamageClass.FIRE)


## Surge: each chain attack that lands heals Fayde a flat amount.
func _apply_surge_heal() -> void:
	var surge: ReactionDef = _armed(GameEnums.ReactionKind.SURGE)
	if surge == null or _last_attack_hit_count <= 0 or _fayde_ref == null:
		return
	_health_and_damage.apply_heal(_fayde_ref, REACTION_TUNING.surge_heal)


## Adds [param amount] to the Special meter (capped) and notifies listeners.
func _add_special_meter(amount: float) -> void:
	var cap: float = ATTACK_TUNING.special_meter_max
	var before: float = _special_meter
	_special_meter = minf(_special_meter + amount, cap)
	if _special_meter != before:
		special_meter_changed.emit(_special_meter, cap)


## Fires the Special (design/gdd/special-attack.md). The core type sets the shape and
## signature; each non-primary Prana in the grid infuses its facet; armed reactions ride
## on the same primitives (Burn, Blind, Stun, Freeze) so they trigger too.
## No-op unless a SpellEffect is cached and the meter is full.
func _trigger_special() -> void:
	var se: SpellEffect = _current_spell_effect
	if se == null or _state == SCEState.IDLE or not is_special_ready():
		return
	var t: AttackTuning = ATTACK_TUNING
	_special_meter = 0.0
	special_meter_changed.emit(_special_meter, t.special_meter_max)
	# The Special is its own "cast" for once-per-chain reactions (Detonate, Short Circuit,
	# Thermal Shock), then ends the basic chain.
	_reset_chain_reaction_state()
	_combo_index = 0
	_perfect_streak = 0
	_buffer_pressed = false
	_buffer_timer = 0.0
	chain_index_changed.emit(0, se.combo_attack_count)

	var pt: int = se.primary_type
	var damage: float = get_special_damage()
	var origin: Vector2 = _pos_of(_fayde_ref)
	var radius: float = t.special_radius
	var hit: Array[Node2D] = []
	match pt:
		GameEnums.DamageClass.SHADOW, GameEnums.DamageClass.LIGHTNING:
			radius = t.special_wide_radius
	if pt == GameEnums.DamageClass.LIGHTNING:
		hit = _nearest_enemies(origin, [], t.special_chain_targets, radius)
	else:
		hit = _enemies_within(origin, radius)

	var dealt_total: float = 0.0
	for enemy: Node2D in hit:
		var amount: float = damage
		if pt == GameEnums.DamageClass.FIRE and _status_effects.has_status(enemy, GameEnums.BaseStatus.BURN):
			amount *= t.eruption_burning_mult  # Eruption consumes existing fire
		dealt_total += _special_hit(enemy, amount, pt)
		match pt:
			GameEnums.DamageClass.FIRE:
				_apply_burn(enemy, t.special_burn_duration, BASE_SPELL_DAMAGE * se.base_damage_modifier)
			GameEnums.DamageClass.SHADOW:
				_status_effects.apply_status(enemy, GameEnums.BaseStatus.BLIND, t.special_blind_duration)
				_pull_toward(enemy, origin, t.eclipse_pull_distance)
			GameEnums.DamageClass.LIGHTNING:
				_apply_stun(enemy, t.special_stun_duration)
			GameEnums.DamageClass.ICE:
				_status_effects.apply_status(enemy, GameEnums.BaseStatus.FREEZE, t.special_freeze_duration)
	if pt == GameEnums.DamageClass.LIGHTNING and not hit.is_empty():
		_try_superconduct(hit[0], hit, damage)

	if pt == GameEnums.DamageClass.NATURE and _fayde_ref != null:
		if not hit.is_empty():
			_health_and_damage.apply_heal(_fayde_ref, damage * t.special_heal_ratio)
		_status_effects.apply_status(_fayde_ref, GameEnums.BaseStatus.REGENERATE, t.sanctuary_regen_duration)

	_apply_special_infusions(se, origin, hit)

	special_fired.emit(pt, origin, 0.0 if pt == GameEnums.DamageClass.LIGHTNING else radius)
	cast_hit_started.emit(t.special_lock_duration)
	_cast_lock_timer = t.special_lock_duration
	_state = SCEState.CAST_LOCKED
	_combo_window_timer = _combo_window_duration()


## One Special hit: Shatter, Thermal Shock, sigil mult, then Siphon and Detonate —
## the reaction hooks of _apply_hit without the basic attack's knockback or crit.
## Returns the damage dealt.
func _special_hit(target: Node, amount: float, pt: int) -> float:
	if not _is_live(target):
		return 0.0
	var raw: float = _status_effects.check_and_apply_shatter(target, amount)
	var target_id: int = target.get_instance_id()
	var thermal: ReactionDef = _armed(GameEnums.ReactionKind.THERMAL_SHOCK)
	if thermal != null and not _chain_hit_ids.has(target_id):
		var thermal_raw: float = amount * (1.0 + thermal.magnitude)
		if thermal_raw > raw:
			raw = thermal_raw
			_emit_reaction(thermal, target, GameEnums.DamageClass.FIRE)
	_chain_hit_ids[target_id] = true
	var target_blinded: bool = _status_effects.has_status(target, GameEnums.BaseStatus.BLIND)
	raw *= _run_damage_mult
	_health_and_damage.apply_damage(target, raw, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)
	spell_hit_element.emit(target, pt)
	var siphon: ReactionDef = _armed(GameEnums.ReactionKind.SIPHON)
	if siphon != null and target_blinded and _fayde_ref != null:
		_health_and_damage.apply_heal(_fayde_ref, raw * siphon.magnitude)
		_emit_reaction(siphon, target, GameEnums.DamageClass.NATURE)
	_try_detonate(target)
	return raw


## Applies each non-primary Prana's facet to the Special. Tier 2 non-primaries
## scale the facet by infusion_tier2_mult. Unknown or primary-typed entries are skipped.
func _apply_special_infusions(se: SpellEffect, origin: Vector2, hit: Array[Node2D]) -> void:
	var t: AttackTuning = ATTACK_TUNING
	for entry: Variant in se.non_primary_modifiers:
		var npm: NonPrimaryModifier = entry as NonPrimaryModifier
		if npm == null or npm.type_id == se.primary_type:
			continue
		var scale: float = t.infusion_tier2_mult if npm.tier >= 2 else 1.0
		match npm.type_id:
			GameEnums.DamageClass.FIRE:
				for enemy: Node2D in hit:
					if _is_live(enemy):
						_apply_burn(enemy, t.infusion_burn_duration * scale, BASE_SPELL_DAMAGE)
			GameEnums.DamageClass.SHADOW:
				for enemy: Node2D in hit:
					if _is_live(enemy):
						_status_effects.apply_status(enemy, GameEnums.BaseStatus.BLIND, t.infusion_blind_duration * scale)
			GameEnums.DamageClass.LIGHTNING:
				var arcs: Array[Node2D] = _nearest_enemies(origin, hit,
					roundi(t.infusion_arc_targets * scale), t.special_wide_radius)
				for enemy: Node2D in arcs:
					_special_hit(enemy, get_special_damage() * 0.5, GameEnums.DamageClass.LIGHTNING)
					if _is_live(enemy):
						_apply_stun(enemy, t.infusion_arc_stun_duration)
			GameEnums.DamageClass.ICE:
				for enemy: Node2D in hit:
					if _is_live(enemy):
						_status_effects.apply_status(enemy, GameEnums.BaseStatus.FREEZE, t.infusion_freeze_duration * scale)
			GameEnums.DamageClass.NATURE:
				if _fayde_ref != null:
					_health_and_damage.apply_heal(_fayde_ref, t.infusion_heal * scale)


## Pulls [param enemy] up to [param distance] px toward [param origin], never past it.
## Duck-typed on apply_knockback (negative direction = pull).
func _pull_toward(enemy: Node2D, origin: Vector2, distance: float) -> void:
	if not _is_live(enemy) or not enemy.has_method(&"apply_knockback"):
		return
	var to_origin: Vector2 = origin - enemy.global_position
	var dist: float = minf(distance, maxf(to_origin.length() - 24.0, 0.0))
	if dist > 0.0:
		enemy.apply_knockback(to_origin, dist)


## Fires the wave's Cascade burst after the chain's final attack (GDD Formula 10).
## The lead (core type) sets the shape; each modifier adds its facet to every enemy hit.
## [param origin_target] is the chain's last primary target; without one only a Verdant
## lead (a Fayde-centred bloom) still fires.
func _fire_cascade(origin_target: Node, perfect_mult: float = 1.0) -> void:
	var se: SpellEffect = _current_spell_effect
	if se == null or se.active_cascade == null:
		return
	var cascade: CascadeEffect = se.active_cascade
	var lead: int = cascade.lead_type
	var has_origin: bool = _is_live(origin_target) and origin_target is Node2D
	if not has_origin and lead != GameEnums.DamageClass.NATURE:
		return
	var tuning: ReactionTuning = REACTION_TUNING
	var origin: Vector2 = _pos_of(origin_target) if has_origin else _pos_of(_fayde_ref)
	var burst_damage: float = roundf(BASE_SPELL_DAMAGE * se.base_damage_modifier * cascade.cascade_mult * perfect_mult)

	# Lead shape — who the burst reaches.
	var hit: Array[Node2D] = []
	var radius: float = tuning.aoe_radius
	match lead:
		GameEnums.DamageClass.FIRE, GameEnums.DamageClass.ICE:  # nova / field
			hit = _enemies_within(origin, tuning.aoe_radius)
		GameEnums.DamageClass.SHADOW:  # collapse — wide cluster
			radius = tuning.collapse_radius
			hit = _enemies_within(origin, radius)
		GameEnums.DamageClass.LIGHTNING:  # chain — primary, then nearest jumps
			radius = 0.0
			hit.append(origin_target as Node2D)
			hit.append_array(_nearest_enemies(origin, hit, tuning.lead_chain_targets))
		GameEnums.DamageClass.NATURE:  # bloom — no damage; facets reach nearby enemies
			if has_origin:
				hit = _enemies_within(origin, tuning.aoe_radius)
	if cascade.modifiers.has(GameEnums.DamageClass.LIGHTNING):
		hit.append_array(_nearest_enemies(origin, hit, tuning.arc_targets))

	var dealt: float = 0.0
	for enemy: Node2D in hit:
		if lead != GameEnums.DamageClass.NATURE:
			_deal_bonus_damage(enemy, burst_damage, lead)
			dealt += burst_damage * _run_damage_mult
		if lead == GameEnums.DamageClass.ICE or cascade.modifiers.has(GameEnums.DamageClass.ICE):
			_status_effects.apply_status(enemy, GameEnums.BaseStatus.FREEZE, tuning.freeze_duration)
		if cascade.modifiers.has(GameEnums.DamageClass.FIRE):
			_status_effects.apply_status(enemy, GameEnums.BaseStatus.BURN, tuning.burn_duration, burst_damage)
		if cascade.modifiers.has(GameEnums.DamageClass.SHADOW):
			_status_effects.apply_status(enemy, GameEnums.BaseStatus.BLIND, tuning.blind_duration)

	# Nourish — a Verdant lead heals from the burst's strength; a Verdant facet from damage dealt.
	if _fayde_ref != null:
		var heal: float = 0.0
		if lead == GameEnums.DamageClass.NATURE:
			heal = burst_damage * tuning.lifesteal
		elif cascade.modifiers.has(GameEnums.DamageClass.NATURE):
			heal = dealt * tuning.lifesteal
		if heal > 0.0:
			_health_and_damage.apply_heal(_fayde_ref, heal)

	cascade_burst.emit(lead, origin, radius)


# ── Public API ────────────────────────────────────────────────────────────────

## Permafrost: multiplier for Fayde's Regen ticks — the reaction's magnitude while at
## least one enemy is Frozen, else 1.0. Queried by StatusEffectsManager on each Regen tick.
func get_regen_multiplier() -> float:
	var permafrost: ReactionDef = _armed(GameEnums.ReactionKind.PERMAFROST)
	if permafrost == null:
		return 1.0
	for enemy: Node2D in _living_enemies():
		if _status_effects.has_status(enemy, GameEnums.BaseStatus.FREEZE):
			return permafrost.magnitude
	return 1.0


## True when the time since the cast lock ended falls inside the Perfect window
## (AttackTuning.perfect_window_start..end). Only true while CHAINING, so buffered
## presses — which fire the instant the lock ends — never count.
func is_in_perfect_window() -> bool:
	return get_cast_timing() == CastTiming.PERFECT


## Judges a basic press made right now. Only presses while CHAINING are judged:
## a chain start from READY is always NORMAL.
func get_cast_timing() -> CastTiming:
	if _state != SCEState.CHAINING:
		return CastTiming.NORMAL
	var elapsed: float = _combo_window_duration() - _combo_window_timer
	if elapsed < ATTACK_TUNING.perfect_window_start:
		return CastTiming.RUSHED
	if elapsed <= ATTACK_TUNING.perfect_window_end:
		return CastTiming.PERFECT
	return CastTiming.NORMAL


## Registers a graze at [param world_pos] (ADR-0018): an enemy bullet or hazard passed
## inside Fayde's graze ring without hitting her. Adds
## BulletHellTuning.graze_meter_gain × [param mult] to the Special meter, so dodging
## close feeds the Special just like landing hits does.
func register_graze(world_pos: Vector2, mult: float = 1.0) -> void:
	var gain: float = BULLET_HELL_TUNING.graze_meter_gain * maxf(mult, 0.0)
	if gain <= 0.0:
		return
	_add_special_meter(gain)
	grazed.emit(world_pos, gain)


## Current Special meter value (0..AttackTuning.special_meter_max).
func get_special_meter() -> float:
	return _special_meter


## True when the Special meter is full.
func is_special_ready() -> bool:
	return _special_meter >= ATTACK_TUNING.special_meter_max


## Per-enemy Special damage before Shatter, reactions, and sigils:
## BASE × base_damage_modifier × special_damage_mult × (1 + tier_bonus × (tier − 1)).
## Returns 0.0 when no SpellEffect is cached.
func get_special_damage() -> float:
	var se: SpellEffect = _current_spell_effect
	if se == null:
		return 0.0
	var t: AttackTuning = ATTACK_TUNING
	return BASE_SPELL_DAMAGE * clampf(se.base_damage_modifier, 0.0, 1.40) * t.special_damage_mult \
		* (1.0 + t.special_tier_bonus * float(se.primary_tier - 1))


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
	_armed_reactions.clear()
	_reset_chain_reaction_state()
	_perfect_streak = 0
	_special_meter = 0.0
	special_meter_changed.emit(_special_meter, ATTACK_TUNING.special_meter_max)


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
	_arm_reactions(spell_effect)
	_state = SCEState.READY
	_combo_index = 0
	cast_started.emit(spell_effect)
