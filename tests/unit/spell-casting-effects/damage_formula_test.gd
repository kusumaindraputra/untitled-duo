## damage_formula_test.gd — Unit tests for SC&E Story 003: FP Damage Formula,
## Targeting, and Status Stubs.
##
## Coverage:
##   AC-SC-08:  No-target cast — apply_damage never called; _combo_index advances
##   AC-SC-11:  Stormgold T2 index 1 with _followthrough_window=0 → raw ≈ 28 (no ×1.30)
##   AC-SC-12:  Formula 1: Ashfire T1 neutral → apply_damage(25.0)
##   AC-SC-13:  Formula 3 Step 1 type branch: Ashfire/Deepfrost/Stormgold flat stat keys
##   AC-SC-14:  Formula 3 Step 5 Shatter: Deepfrost T1 vs Frozen → raw ≈ 20
##   AC-SC-15:  Formula 3 Step 9 Elemental affiliation: Ashfire T1 vs fire enemy → raw ≈ 50
##   AC-SC-19:  Formula 7 FP status stubs: Deepfrost freeze_timer=2.0; Stormgold stun_timer=0.8
##   AC-SC-20:  tier_attack_modifier==0.0 suppresses apply_damage (Verdant T2, Deepfrost T3)
##   AC-SC-23:  ASH_CRIT at _combo_index==1 only; suppressed at index 2+
##   AC-SC-25:  Formula 7 with stat bonuses: freeze_timer=2.5; stun_timer=1.2
##   AC-SC-26:  spell_hit_element emitted once per hit with correct args; not on miss
##   AC-SC-27:  Verdant T2 secondary → apply_heal called with SHIELD_PULSE_HEAL (15.0)
##   AC-SC-28:  Deepfrost T3 glacial field → FREEZE on enemy in radius; not on enemy outside
##   AC-SC-29:  Verdant T3 index 1 secondary → apply_heal called (same as T2 path)
##
## Step 9 deviation note: implementation uses GameEnums.DamageClass(pt) instead of
## PranaCatalog.get_type(pt).damage_class (approved 2026-06-06; see SCE Story 003).
##
## Test harness:
##   - SC&E instantiated with SCEScript.new() and added via add_child(); set_process(false)
##     to prevent real _process() from advancing timers during tests.
##   - _rng, _health_and_damage, _status_effects injected as mocks.
##   - _override_target set to MockEnemy node (avoids physics ray dependency).
##   - Teardown: remove_child() + free() (not queue_free — headless exit 101).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")


# ── Inner mocks ───────────────────────────────────────────────────────────────

## Spy on apply_damage and apply_heal: records call count and last argument values.
class MockHealthAndDamage:
	var call_count: int = 0
	var last_raw_damage: float = 0.0
	var last_target: Node = null
	var heal_call_count: int = 0
	var last_heal_amount: float = 0.0

	func apply_damage(target: Node, raw_damage: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		call_count += 1
		last_raw_damage = raw_damage
		last_target = target

	func apply_heal(_target: Node, amount: float) -> void:
		heal_call_count += 1
		last_heal_amount = amount


## Passthrough SEM stub: check_and_apply_shatter returns base_damage unchanged;
## has_status always returns false. Records apply_status calls for assertion.
class MockStatusEffectsPassthrough:
	var apply_status_calls: Array = []

	func apply_status(_target: Node, status_type: GameEnums.BaseStatus, duration: float, spell_base_damage: float = 0.0) -> void:
		apply_status_calls.append({"status_type": status_type, "duration": duration, "spell_base_damage": spell_base_damage})

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage

	func has_status(_target: Node, _status_type: GameEnums.BaseStatus) -> bool:
		return false


## Shatter SEM stub: check_and_apply_shatter returns base_damage × 1.25 unconditionally.
## Used by AC-SC-14 to simulate a Frozen target without needing a real SEM registry.
class MockStatusEffectsShatter:
	func apply_status(_target: Node, _status_type: GameEnums.BaseStatus, _duration: float, _spell_base: float = 0.0) -> void:
		pass

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage * 1.25

	func has_status(_target: Node, _status_type: GameEnums.BaseStatus) -> bool:
		return false


## Minimal enemy node with all fields that SC&E may read or write.
## prana_affiliation defaults to DamageClass.NONE (neutral — no affiliation match).
class MockEnemy extends Node2D:
	var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
	var status_freeze_timer: float = 0.0
	var status_stun_timer: float = 0.0
	var status_burned: bool = false
	var status_blinded_timer: float = 0.0
	var status_stagger_timer: float = 0.0

	func is_alive() -> bool: return true
	func apply_speed_modifier(_mult: float) -> void: pass
	func apply_stun(_duration: float) -> void: pass


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates an SC&E instance with process disabled and mocks injected.
## _override_target is NOT set here — set it per-test when needed.
## [param rng_seed] seeds a real RandomNumberGenerator. Defaults to 12345 (deterministic).
## ASH_CRIT tests use rng_seed=0 — any seed works when ASH_CRIT=1.0 (all randf() < 1.0).
## GDScript 4.6 forbids overriding built-in methods in subclasses (warning-as-error),
## so MockRNG is omitted; a seeded real RNG is used instead.
func _make_sce(
	mock_hd: MockHealthAndDamage = null,
	mock_sem: Object = null,
	rng_seed: int = 12345
) -> Node:
	var sce: Node = SCEScript.new()
	sce._health_and_damage = mock_hd if mock_hd != null else MockHealthAndDamage.new()
	sce._status_effects = mock_sem if mock_sem != null else MockStatusEffectsPassthrough.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	sce._rng = rng
	add_child(sce)
	sce.set_process(false)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


## Builds a minimal SpellEffect with the given primary_type, tier, bdm, and bonus dict.
func _make_spell_effect(
	pt: int,
	tier: int = 1,
	bdm: float = 1.0,
	combo_count: int = -1,
	stat_bonus: Dictionary[StringName, float] = {}
) -> SpellEffect:
	var se: SpellEffect = SpellEffect.new()
	se.primary_type = pt
	se.primary_tier = tier
	se.base_damage_modifier = bdm
	se.combo_attack_count = combo_count if combo_count >= 0 else tier
	se.aggregate_stat_bonus = stat_bonus
	return se


## Puts SC&E into READY state with the given SpellEffect cached and a MockEnemy as override target.
func _ready_sce(sce: Node, se: SpellEffect, target: MockEnemy = null) -> void:
	sce._on_combat_started(false)
	sce._on_combo_resolved(se)
	if target != null:
		sce._override_target = target


# ── AC-SC-08: No-target cast — combo advances, no damage ─────────────────────

## GIVEN SC&E in READY, valid Ashfire T1 SpellEffect, _override_target = null (no ray hit)
## WHEN _trigger_cast() called
## THEN apply_damage never called; _combo_index == 1
func test_sce_no_target_cast_never_calls_apply_damage_and_combo_index_advances() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1
	_ready_sce(sce, se)
	# _override_target is null — no target injected

	sce._trigger_cast()

	assert_int(hd.call_count).is_equal(0)
	assert_int(sce._combo_index).is_equal(1)

	_teardown_sce(sce)


# ── AC-SC-11: Follow-Through suppressed (Stormgold T2 index 1) ───────────────

## GIVEN Stormgold T2 SpellEffect (bdm=1.15, combo_attack_count=2); _followthrough_window=0.0
##       (no follow-through at FP); cast advances to index 1 (attack_index=1, modifier=1.20)
## WHEN _fire_attack(1) called directly
## THEN apply_damage called with raw ≈ round(20 × 1.15 × 1.20) = 28; no ×1.30
func test_sce_stormgold_t2_index1_no_followthrough_applies_correct_raw_damage() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(2, 2, 1.15, 2)  # Stormgold T2
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	# Manually advance _combo_index to 2 (mimics post-increment state before _fire_attack(1))
	sce._combo_index = 2

	sce._fire_attack(1)

	# round(20 * 1.15 * 1.20) = round(27.6) = 28
	assert_float(hd.last_raw_damage).is_equal_approx(27.6, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-12: Formula 1 — Ashfire T1 neutral = 25 ───────────────────────────

## GIVEN Ashfire T1 SpellEffect (primary_type=0, primary_tier=1, bdm=1.25), empty aggregate
## WHEN _fire_attack(0) called (first attack, no stat bonuses, no status conditions)
## THEN apply_damage called with raw ≈ 25.0 (round(20 × 1.25 × 1.00))
func test_sce_ashfire_t1_neutral_damage_is_25() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1  # First attack (incremented before _fire_attack in _trigger_cast)

	sce._fire_attack(0)

	# round(20 * 1.25 * 1.00) = 25.0 exactly
	assert_float(hd.last_raw_damage).is_equal_approx(25.0, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-13: Formula 3 Step 1 type branch ───────────────────────────────────

## (a) primary_type=0 (Ashfire) with ASH_DMG=5.0 → effective_base=25.0
##     apply_damage raw ≈ round(25.0 × 1.25 × 1.00) = 31.25
func test_sce_step1_ashfire_reads_ash_dmg_stat() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25, 1, {&"ASH_DMG": 5.0})
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# effective_base = 20 + 5 = 25; raw = 25 * 1.25 * 1.00 = 31.25
	assert_float(hd.last_raw_damage).is_equal_approx(31.25, 0.01)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


## (b) primary_type=3 (Deepfrost) with FROST_DMG=3.0 → effective_base=23.0
##     apply_damage raw ≈ round(23.0 × 0.80 × 1.00) = 18.4
func test_sce_step1_deepfrost_reads_frost_dmg_stat() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(3, 1, 0.80, 1, {&"FROST_DMG": 3.0})
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# effective_base = 20 + 3 = 23; raw = 23 * 0.80 * 1.00 = 18.4
	assert_float(hd.last_raw_damage).is_equal_approx(18.4, 0.01)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


## (c) primary_type=2 (Stormgold) with ASH_DMG=5.0, FROST_DMG=3.0 → flat_stat=0.0 (Stormgold gets none)
##     apply_damage raw ≈ round(20.0 × 1.15 × 1.00) = 23.0
func test_sce_step1_stormgold_gets_zero_flat_bonus_even_with_ash_frost_stats() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(2, 1, 1.15, 1, {&"ASH_DMG": 5.0, &"FROST_DMG": 3.0})
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# effective_base = 20 + 0 = 20; raw = 20 * 1.15 * 1.00 = 23.0
	assert_float(hd.last_raw_damage).is_equal_approx(23.0, 0.01)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-14: Formula 3 Step 5 Shatter ───────────────────────────────────────

## GIVEN Deepfrost T1 SpellEffect (bdm=0.80, tier_mod=1.00); MockSEM returns raw×1.25
## WHEN _fire_attack(0) called
## THEN apply_damage called with raw ≈ round(20 × 0.80 × 1.00 × 1.25) = 20
func test_sce_deepfrost_t1_shatter_multiplies_raw_damage_to_20() -> void:
	var hd := MockHealthAndDamage.new()
	var shatter_sem := MockStatusEffectsShatter.new()
	var sce = _make_sce(hd, shatter_sem)
	var se := _make_spell_effect(3, 1, 0.80)  # Deepfrost T1
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# raw = 20 * 0.80 * 1.00 = 16.0; after shatter: 16.0 * 1.25 = 20.0
	assert_float(hd.last_raw_damage).is_equal_approx(20.0, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-15: Formula 3 Step 9 Elemental affiliation ─────────────────────────

## GIVEN Ashfire T1 SpellEffect; MockEnemy with prana_affiliation = DamageClass.FIRE (matches)
## WHEN _fire_attack(0) called
## THEN apply_damage called with raw ≈ round(25.0 × 2.0) = 50
func test_sce_ashfire_t1_vs_fire_affiliated_enemy_doubles_damage_to_50() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1
	var enemy := MockEnemy.new()
	enemy.prana_affiliation = GameEnums.DamageClass.FIRE  # Matches Ashfire element
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# raw = 20 * 1.25 * 1.00 = 25.0; after 2× affiliation: 50.0
	assert_float(hd.last_raw_damage).is_equal_approx(50.0, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-19: Status effects applied via SEM — default durations ─────────────

## GIVEN Deepfrost T1, empty aggregate; MockEnemy target
## WHEN _fire_attack(0) called
## THEN SEM.apply_status(FREEZE, 2.0) called once
func test_sce_deepfrost_t1_applies_freeze_status_2_seconds() -> void:
	var hd := MockHealthAndDamage.new()
	var sem := MockStatusEffectsPassthrough.new()
	var sce = _make_sce(hd, sem)
	var se := _make_spell_effect(3, 1, 0.80)  # Deepfrost T1
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	assert_int(sem.apply_status_calls.size()).is_equal(1)
	assert_int(sem.apply_status_calls[0]["status_type"]).is_equal(GameEnums.BaseStatus.FREEZE)
	assert_float(sem.apply_status_calls[0]["duration"]).is_equal_approx(2.0, 0.001)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


## GIVEN Stormgold T1, empty aggregate; MockEnemy target
## WHEN _fire_attack(0) called
## THEN SEM.apply_status(STUN, 0.8) called once
func test_sce_stormgold_t1_applies_stun_status_0_8_seconds() -> void:
	var hd := MockHealthAndDamage.new()
	var sem := MockStatusEffectsPassthrough.new()
	var sce = _make_sce(hd, sem)
	var se := _make_spell_effect(2, 1, 1.15)  # Stormgold T1
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	assert_int(sem.apply_status_calls.size()).is_equal(1)
	assert_int(sem.apply_status_calls[0]["status_type"]).is_equal(GameEnums.BaseStatus.STUN)
	assert_float(sem.apply_status_calls[0]["duration"]).is_equal_approx(0.8, 0.001)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-20: tier_attack_modifier == 0.0 suppresses apply_damage ─────────────

## GIVEN Verdant T2 SpellEffect (combo_attack_count=2); cast at index 1 (modifier=0.00)
## WHEN _fire_attack(1) called
## THEN apply_damage never called
func test_sce_verdant_t2_index1_zero_modifier_never_calls_apply_damage() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(4, 2, 0.70, 2)  # Verdant T2
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 2  # Second attack (incremented before call)

	sce._fire_attack(1)

	assert_int(hd.call_count).is_equal(0)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


## GIVEN Deepfrost T3 SpellEffect; cast at index 2 (glacial field, modifier=0.00)
## WHEN _fire_attack(2) called
## THEN apply_damage never called
func test_sce_deepfrost_t3_index2_glacial_field_zero_modifier_never_calls_apply_damage() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(3, 3, 0.80, 3)  # Deepfrost T3
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 3  # Third attack

	sce._fire_attack(2)

	assert_int(hd.call_count).is_equal(0)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-23: ASH_CRIT applies at _combo_index==1 only ───────────────────────

## GIVEN aggregate={"ASH_CRIT": 1.0} (guaranteed crit — any randf() in [0,1) is < 1.0);
##       Stormgold T2 SpellEffect (combo_attack_count=2); seed=0 for determinism
## WHEN _fire_attack(0) called with _combo_index=1 (first attack)
## THEN apply_damage raw_damage includes ×1.50 crit multiplier
##      (round(20 × 1.15 × 1.00 × 1.50) = 34.5)
func test_sce_ash_crit_applies_at_first_attack_index_0() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd, null, 0)  # seed=0, ASH_CRIT=1.0 → guaranteed crit
	var se := _make_spell_effect(2, 2, 1.15, 2, {&"ASH_CRIT": 1.0})  # Stormgold T2, ASH_CRIT=1.0
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1  # First attack

	sce._fire_attack(0)

	# raw = 20 * 1.15 * 1.00 = 23.0; after crit: 23.0 * 1.50 = 34.5
	assert_float(hd.last_raw_damage).is_equal_approx(34.5, 0.01)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


## GIVEN same setup (ASH_CRIT=1.0, seed=0); _combo_index=2 (second attack)
## WHEN _fire_attack(1) called
## THEN apply_damage raw_damage does NOT include ×1.50 (Step 8 guard skipped at _combo_index > 1)
##      (round(20 × 1.15 × 1.20) = 27.6 with no crit — Step 8 never runs)
func test_sce_ash_crit_suppressed_at_second_attack_index_1() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd, null, 0)  # seed=0; if Step 8 ran it would crit — verifies guard
	var se := _make_spell_effect(2, 2, 1.15, 2, {&"ASH_CRIT": 1.0})  # Stormgold T2
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 2  # Second attack — crit guard must NOT fire

	sce._fire_attack(1)

	# raw = 20 * 1.15 * 1.20 = 27.6; NO crit (guard skipped at _combo_index > 1)
	assert_float(hd.last_raw_damage).is_equal_approx(27.6, 0.01)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-25: Status effects with stat bonuses ────────────────────────────────

## GIVEN Deepfrost T1, aggregate={"FROST_FREEZE_DUR": 0.5}
## WHEN _fire_attack(0) called
## THEN SEM.apply_status(FREEZE, 2.5) called once
func test_sce_deepfrost_t1_with_freeze_dur_bonus_applies_2_5_seconds() -> void:
	var hd := MockHealthAndDamage.new()
	var sem := MockStatusEffectsPassthrough.new()
	var sce = _make_sce(hd, sem)
	var se := _make_spell_effect(3, 1, 0.80, 1, {&"FROST_FREEZE_DUR": 0.5})
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	assert_int(sem.apply_status_calls.size()).is_equal(1)
	assert_int(sem.apply_status_calls[0]["status_type"]).is_equal(GameEnums.BaseStatus.FREEZE)
	assert_float(sem.apply_status_calls[0]["duration"]).is_equal_approx(2.5, 0.001)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


## GIVEN Stormgold T1, aggregate={"STORM_STUN_DUR": 0.4}
## WHEN _fire_attack(0) called
## THEN SEM.apply_status(STUN, 1.2) called once
func test_sce_stormgold_t1_with_stun_dur_bonus_applies_1_2_seconds() -> void:
	var hd := MockHealthAndDamage.new()
	var sem := MockStatusEffectsPassthrough.new()
	var sce = _make_sce(hd, sem)
	var se := _make_spell_effect(2, 1, 1.15, 1, {&"STORM_STUN_DUR": 0.4})
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	assert_int(sem.apply_status_calls.size()).is_equal(1)
	assert_int(sem.apply_status_calls[0]["status_type"]).is_equal(GameEnums.BaseStatus.STUN)
	assert_float(sem.apply_status_calls[0]["duration"]).is_equal_approx(1.2, 0.001)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-26: spell_hit_element emitted once per hit; not on miss ─────────────

## GIVEN Ashfire T1 SpellEffect (primary_type=0); valid MockEnemy target
## WHEN _fire_attack(0) called
## THEN spell_hit_element emitted exactly once with args (enemy, 0)
## NOTE: lambda captures use Dictionary (reference type) to work around GDScript 4
## int-by-value capture semantics — local ints captured in lambdas are copies.
func test_sce_spell_hit_element_emitted_once_per_hit_with_correct_prana_type() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	var results := {"count": 0, "target": null, "type_id": -1}
	sce.spell_hit_element.connect(func(t: Node, tid: int) -> void:
		results["count"] += 1
		results["target"] = t
		results["type_id"] = tid
	)

	sce._fire_attack(0)

	assert_int(results["count"]).is_equal(1)
	assert_object(results["target"]).is_equal(enemy)
	assert_int(results["type_id"]).is_equal(0)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


## GIVEN same setup; _override_target = null (no target)
## WHEN _fire_attack(0) called
## THEN spell_hit_element NOT emitted (emit_count == 0)
func test_sce_spell_hit_element_not_emitted_on_miss_no_target() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1
	_ready_sce(sce, se, null)  # No target — _override_target stays null
	sce._combo_index = 1

	var results := {"count": 0}
	sce.spell_hit_element.connect(func(_t: Node, _tid: int) -> void:
		results["count"] += 1
	)

	sce._fire_attack(0)

	assert_int(results["count"]).is_equal(0)

	_teardown_sce(sce)


# ── AC-SC-27: Verdant T2 secondary → apply_heal called ──────────────────────

## GIVEN Verdant T2 SpellEffect; _fayde_ref set to a MockEnemy at (0,0)
## WHEN _fire_attack(1) called (modifier==0.0 slot)
## THEN apply_heal called once with SHIELD_PULSE_HEAL (15.0); apply_damage never called
func test_sce_verdant_t2_secondary_calls_apply_heal_on_fayde() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(4, 2, 0.70, 2)  # Verdant T2
	var fayde := MockEnemy.new()
	add_child(fayde)
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._fayde_ref = fayde
	sce._combo_index = 2  # Second attack

	sce._fire_attack(1)

	assert_int(hd.call_count).is_equal(0)
	assert_int(hd.heal_call_count).is_equal(1)
	assert_float(hd.last_heal_amount).is_equal(15.0)

	remove_child(fayde)
	fayde.free()
	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-SC-28: Deepfrost T3 glacial field → FREEZE in radius, skip outside ───

## GIVEN Deepfrost T3 SpellEffect; _fayde_ref at (0,0); two enemies:
##       enemy_near at (100,0) — inside 200px; enemy_far at (300,0) — outside
## WHEN _fire_attack(2) called (modifier==0.0 glacial field slot)
## THEN apply_status FREEZE called for enemy_near only; apply_damage never called
func test_sce_deepfrost_t3_glacial_field_freezes_enemies_in_radius_only() -> void:
	var hd := MockHealthAndDamage.new()
	var sem := MockStatusEffectsPassthrough.new()
	var sce = _make_sce(hd, sem)
	var se := _make_spell_effect(3, 3, 0.80, 3)  # Deepfrost T3

	var fayde := MockEnemy.new()
	fayde.position = Vector2(0.0, 0.0)
	add_child(fayde)

	var enemy_near := MockEnemy.new()
	enemy_near.position = Vector2(100.0, 0.0)
	add_child(enemy_near)

	var enemy_far := MockEnemy.new()
	enemy_far.position = Vector2(300.0, 0.0)
	add_child(enemy_far)

	_ready_sce(sce, se, enemy_near)
	sce._fayde_ref = fayde
	var enemies_list: Array[Node] = [enemy_near, enemy_far]
	sce._get_enemies = func() -> Array[Node]: return enemies_list
	sce._combo_index = 3  # Third attack

	sce._fire_attack(2)

	assert_int(hd.call_count).is_equal(0)
	var freeze_calls: Array = sem.apply_status_calls.filter(
		func(c: Dictionary) -> bool: return c["status_type"] == GameEnums.BaseStatus.FREEZE
	)
	assert_int(freeze_calls.size()).is_equal(1)

	remove_child(fayde)
	fayde.free()
	remove_child(enemy_near)
	enemy_near.free()
	remove_child(enemy_far)
	enemy_far.free()
	_teardown_sce(sce)


# ── AC-SC-29: Verdant T3 index 1 secondary → same heal path as T2 ───────────

## GIVEN Verdant T3 SpellEffect; _fayde_ref set
## WHEN _fire_attack(1) called (modifier==0.0 slot — same as T2)
## THEN apply_heal called with 15.0 (SHIELD_PULSE_HEAL)
func test_sce_verdant_t3_index1_secondary_calls_apply_heal() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(4, 3, 0.70, 3)  # Verdant T3
	var fayde := MockEnemy.new()
	add_child(fayde)
	var enemy := MockEnemy.new()
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._fayde_ref = fayde
	sce._combo_index = 2  # Index 1 fires on second press

	sce._fire_attack(1)

	assert_int(hd.heal_call_count).is_equal(1)
	assert_float(hd.last_heal_amount).is_equal(15.0)

	remove_child(fayde)
	fayde.free()
	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)
