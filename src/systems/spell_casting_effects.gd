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
##   Step 9: uses int comparison (enemy_affiliation == pt) instead of
##     PranaCatalog.get_type(pt).damage_class — DamageClass enum values are 1:1
##     with primary_type integers. PranaCatalog requires a live Autoload (breaks
##     headless tests). Flagged for EA&W migration at MVP per GDD note.
##   apply_status(): NOT called in _fire_attack at FP scope. GDD Rule 8 specifies
##     field-write stubs only (target.set()) at FP — SEM is not wired to enemies
##     at FP. apply_status() wired at MVP per ADR-0011.
##   apply_damage() element param: GameEnums.DamageClass.NONE (not the spell's
##     actual element). SC&E owns the elemental multiplier at Step 9 to avoid
##     double-application by H&D's future elemental pipeline (ADR-0007). Once
##     H&D's elemental multiplier is implemented at MVP, Step 9 must be removed
##     and the correct DamageClass passed here instead.
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


# ── Constants ─────────────────────────────────────────────────────────────────

## Default cast lock duration after each hit (all Prana types except Ashfire). (TR-SC-002)
const CAST_LOCK_DURATION: float = 0.12

## Extended cast lock for Ashfire — dance identity requires longer recovery. (TR-SC-002)
const ASHFIRE_CAST_LOCK_DURATION: float = 0.20

## Seconds the player has to press the next chain attack before the chain resets. (TR-SC-002)
const COMBO_CONTINUATION_WINDOW: float = 2.0

## Reference damage constant for all spell calculations (GDD Formula 1).
## Tuning knob: safe range 10–30. At 20, Ashfire T1 deals round(20×1.25×1.00)=25.
const BASE_SPELL_DAMAGE: float = 20.0

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
	_fayde_ref = get_tree().get_first_node_in_group(&"player")
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	CombinationResolution.combo_resolved.connect(_on_combo_resolved)


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
## Handles CAST_LOCKED expiry, combo window expiry, and cast input polling. (TR-SC-002)
func _process(delta: float) -> void:
	if _cast_lock_timer > 0.0:
		_cast_lock_timer -= delta
		if _cast_lock_timer <= 0.0:
			_cast_lock_timer = 0.0
			if _state == SCEState.CAST_LOCKED:
				_state = SCEState.CHAINING if _combo_index > 0 else SCEState.READY

	if _state == SCEState.CHAINING:
		_combo_window_timer -= delta
		if _combo_window_timer <= 0.0:
			# Combo window expired — reset chain to READY
			_combo_index = 0
			_state = SCEState.READY
			chain_index_changed.emit(0, _current_spell_effect.combo_attack_count if _current_spell_effect else 0)

	if (_state == SCEState.READY or _state == SCEState.CHAINING) and _cast_lock_timer <= 0.0:
		if Input.is_action_just_pressed(&"cast"):
			_trigger_cast()


## Fires a single chain attack: advances _combo_index, calls _fire_attack,
## emits signals, and sets timers. (TR-SC-006, TR-SC-008)
func _trigger_cast() -> void:
	if _current_spell_effect == null:
		return
	var combo_count: int = _current_spell_effect.combo_attack_count
	if _combo_index >= combo_count:
		return

	_combo_index += 1
	chain_index_changed.emit(_combo_index, combo_count)

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

	# Select target. _override_target is non-null only in tests; production uses ray cast.
	var target: Node = _override_target if _override_target != null else _select_primary_target()

	# No-target path: combo index has already advanced; no damage or status (GDD Edge Case 1).
	if target == null:
		return

	# Step 1 — flat stat bonus (type-conditional; only Ashfire and Deepfrost get flat bonuses).
	var flat_stat: float = 0.0
	if pt == 0:
		flat_stat = se.aggregate_stat_bonus.get(&"ASH_DMG", 0.0)
	elif pt == 3:
		flat_stat = se.aggregate_stat_bonus.get(&"FROST_DMG", 0.0)

	# Step 2 — effective base damage.
	var eff_base: float = BASE_SPELL_DAMAGE + flat_stat

	# Step 3 — base_damage_modifier (burn_bonus via Ashfire NP — empty at FP; cap at 1.40).
	var eff_mod: float = clampf(se.base_damage_modifier, 0.0, 1.40)

	# Step 4 — core damage.
	var raw: float = eff_base * eff_mod * tier_mod

	# Step 5 — Shatter (ADR-0011): delegates to SEM.
	# At FP: check_and_apply_shatter returns raw unchanged (has_status returns false for stubs).
	raw = _status_effects.check_and_apply_shatter(target, raw)

	# Step 6 — Follow-Through: always 0.0 at FP (_followthrough_window not implemented at FP).
	# When _followthrough_window is added: if _followthrough_window > 0.0 → raw *= (1.30 + bonus).

	# Step 7 — Blind bonus.
	# At FP: has_status always returns false for field-write stubs — bonus inert.
	if _status_effects.has_status(target, GameEnums.BaseStatus.BLIND):
		raw *= (1.0 + se.aggregate_stat_bonus.get(&"VOID_DMG_VS_BLIND", 0.0))

	# Step 8 — ASH_CRIT (first chain attack only; any primary type).
	# _combo_index == 1 here means this is the first press (incremented before _fire_attack).
	if _combo_index == 1:
		var ash_crit: float = se.aggregate_stat_bonus.get(&"ASH_CRIT", 0.0)
		if ash_crit > 0.0 and _rng.randf() < ash_crit:
			raw *= 1.50

	# Step 9 — Elemental affiliation [FP inline — remove at MVP when EA&W implements this].
	# Step 9 — Elemental affiliation [FP inline — remove at MVP when EA&W implements this].
	# Deviation: uses int comparison (enemy_affiliation == pt) instead of
	# PranaCatalog.get_type(pt).damage_class. DamageClass enum values (FIRE=0,
	# SHADOW=1, LIGHTNING=2, ICE=3, NATURE=4) are 1:1 with primary_type integers.
	# PranaCatalog requires a live Autoload unavailable in headless tests.
	# Approved 2026-06-06; see file header for full note.
	var raw_affiliation = target.get(&"prana_affiliation")
	var enemy_affiliation: int = raw_affiliation if raw_affiliation != null else GameEnums.DamageClass.NONE
	if pt != GameEnums.DamageClass.NONE and enemy_affiliation == pt:
		raw *= 2.0

	# Step 10 — deliver damage through Health & Damage (ADR-0007).
	# element = DamageClass.NONE: SC&E owns the elemental multiplier above (Step 9)
	# to prevent double-application once H&D's elemental pipeline lands at MVP.
	# See file header deviation note for the migration plan.
	_health_and_damage.apply_damage(target, raw, GameEnums.DamageClass.NONE, GameEnums.DamageSource.DIRECT)

	# Emit spell_hit_element for CombatHUD damage-number coloring (GDD Rule 1, B-1).
	spell_hit_element.emit(target, pt)

	# FP status field-write stubs (GDD Rule 8 — field writes only; SEM not wired at FP).
	_apply_fp_status_stubs(target, pt, se)


## Writes FP status stub fields to [param target] per GDD Rule 8 Formula 7.
##
## These are field-write stubs only — no Enemy AI behavior reads them at FP scope,
## and StatusEffectsManager is not wired to them. They reserve the interface for MVP.
## Uses target.set() to avoid GDScript type errors on nodes without these fields.
func _apply_fp_status_stubs(target: Node, pt: int, se: SpellEffect) -> void:
	match pt:
		0:  # Ashfire — STATUS_BURN stub
			target.set(&"status_burned", true)
		1:  # Voidblue — STATUS_BLIND stub
			var blind_dur: float = 2.0 + se.aggregate_stat_bonus.get(&"VOID_BLIND_DUR", 0.0)
			target.set(&"status_blinded_timer", blind_dur)
		2:  # Stormgold — STATUS_STUN stub
			var stun_dur: float = 0.8 + se.aggregate_stat_bonus.get(&"STORM_STUN_DUR", 0.0)
			target.set(&"status_stun_timer", stun_dur)
		3:  # Deepfrost — STATUS_FREEZE stub
			var freeze_dur: float = 2.0 + se.aggregate_stat_bonus.get(&"FROST_FREEZE_DUR", 0.0)
			target.set(&"status_freeze_timer", freeze_dur)
		4:  # Verdant — STATUS_REGEN stub (applies to Fayde, not target; field reserved for MVP)
			pass  # Regen is on Fayde — handled by Verdant NP rules (not in FP scope at Story 003)


## Stub for tier_attack_modifier == 0.0 secondary effects (Verdant T2 shield pulse,
## Deepfrost T3 glacial field). Logs a warning — these effects are out of FP scope.
func _fire_secondary_effect(pt: int, tier: int, attack_index: int) -> void:
	push_warning(
		"SpellCastingEffects._fire_secondary_effect(): secondary effect not implemented at FP "
		+ "(type=%d tier=%d index=%d). No crash — field reserved for MVP." % [pt, tier, attack_index]
	)


## Selects a primary target via physics ray cast (real game only — headless-incompatible).
## Returns null if no enemy is hit within cast range or if the player node is missing.
## Tests bypass this entirely via _override_target.
func _select_primary_target() -> Node:
	if _fayde_ref == null:
		_fayde_ref = get_tree().get_first_node_in_group(&"player")
	if _fayde_ref == null:
		return null
	var space: PhysicsDirectSpaceState2D = get_viewport().get_world_2d().direct_space_state
	var origin: Vector2 = _fayde_ref.global_position
	var facing: Vector2 = _fayde_ref.get_facing_direction() if _fayde_ref.has_method(&"get_facing_direction") else Vector2.RIGHT
	var cast_range: float = 80.0 if _current_spell_effect != null and _current_spell_effect.primary_type == 0 \
		else 150.0
	var query := PhysicsRayQueryParameters2D.create(origin, origin + facing * cast_range)
	# Mask: walls (1) + enemies (4) = 5. Excludes half-cover debris (16) — Prana passes through.
	query.collision_mask = 5
	var result: Dictionary = space.intersect_ray(query)
	if result.is_empty():
		return null
	var collider: Node = result.get("collider")
	if collider != null and collider.is_in_group(&"enemy"):
		return collider
	return null


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the additive stat delta for [param stat_id] from the current wave's SpellEffect.
## Returns 0.0 when no SpellEffect is cached (between waves or preparation_started).
## Callers: HealthAndDamage (VER_HEAL_FLAT), StatusEffectsManager (duration bonuses).
## No other system may read aggregate_stat_bonus directly (ADR-0009).
func get_stat_bonus(stat_id: StringName) -> float:
	if _current_spell_effect == null:
		return 0.0
	return _current_spell_effect.aggregate_stat_bonus.get(stat_id, 0.0)


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
		push_error("SpellCastingEffects: combo_resolved received null SpellEffect. Staying IDLE.")
		return
	if spell_effect.primary_type == GameEnums.DamageClass.NONE:
		push_error("SpellCastingEffects: combo_resolved received invalid SpellEffect (primary_type == NONE). Staying IDLE.")
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
