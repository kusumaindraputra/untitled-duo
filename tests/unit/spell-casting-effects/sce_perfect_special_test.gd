## sce_perfect_special_test.gd — Unit tests for Perfect Cast timing and the Special attack
## (design/gdd/special-attack.md, ADR-0017).
##
## Coverage:
##   - Perfect window: only while CHAINING, inside [start, end] after the lock ends
##   - Perfect hit: damage × perfect_damage_mult; mashed/buffered press gets no bonus
##   - Perfect streak signal; Perfect final hit powers the Cascade
##   - Special meter: gain per landed attack (more on Perfect), capped, reset in prep
##   - Special: blocked until full; per-core shape + signature (5 cores); tier scaling
##   - Infusions from non-primary Prana (tiered); armed reactions ride on the Special
##
## Harness mirrors sce_reaction_application_test: SC&E added via add_child() then
## set_process(false); H&D / SEM / enemy list / Fayde injected. Values come from the
## real attack_tuning.tres so expectations follow the knobs, not duplicated numbers.
## Teardown: remove_child() + free() (not queue_free — headless exit 101).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")
const AT: AttackTuning = preload("res://assets/data/attack_tuning.tres")
const RT: ReactionTuning = preload("res://assets/data/reaction_tuning.tres")
const WITCHFIRE: ReactionDef = preload("res://assets/data/reactions/react_witchfire.tres")
const SIPHON: ReactionDef = preload("res://assets/data/reactions/react_siphon.tres")


# ── Inner mocks ───────────────────────────────────────────────────────────────

## Records every damage and heal call. Marks a MockEnemy dead when it is flagged lethal.
class MockHealthAndDamage:
	var damage_calls: Array = []  # [{target, amount}]
	var heal_calls: Array[float] = []

	func apply_damage(target: Node, amount: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		damage_calls.append({"target": target, "amount": amount})
		if target is MockEnemy and target.dies_on_hit:
			target.alive = false

	func apply_heal(_target: Node, amount: float) -> void:
		heal_calls.append(amount)

	func damage_to(target: Node) -> Array[float]:
		var out: Array[float] = []
		for c: Dictionary in damage_calls:
			if c["target"] == target:
				out.append(c["amount"])
		return out


## Status registry stub: apply_status records and stores, has_status reads it back.
## [member shatter_mult] simulates a Frozen target's Shatter bonus when != 1.0.
class MockStatusEffects:
	var applied: Array = []  # [{target, status, duration}]
	var statuses: Dictionary = {}  # instance_id -> Array[int]
	var shatter_mult: float = 1.0

	func apply_status(target: Node, status: GameEnums.BaseStatus, duration: float, _base: float = 0.0) -> void:
		applied.append({"target": target, "status": status, "duration": duration})
		give(target, status)

	func give(target: Node, status: GameEnums.BaseStatus) -> void:
		var list: Array = statuses.get(target.get_instance_id(), [])
		list.append(int(status))
		statuses[target.get_instance_id()] = list

	func has_status(target: Node, status: GameEnums.BaseStatus) -> bool:
		return statuses.get(target.get_instance_id(), []).has(int(status))

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage * shatter_mult

	func applied_to(target: Node, status: GameEnums.BaseStatus) -> Array[float]:
		var out: Array[float] = []
		for c: Dictionary in applied:
			if c["target"] == target and c["status"] == status:
				out.append(c["duration"])
		return out


class MockEnemy extends Node2D:
	var alive: bool = true
	var dies_on_hit: bool = false

	func is_alive() -> bool: return alive
	func apply_speed_modifier(_mult: float) -> void: pass
	func apply_stun(_duration: float) -> void: pass
	var pulls: Array[Vector2] = []
	func apply_knockback(direction: Vector2, distance: float) -> void:
		pulls.append(direction.normalized() * distance)


# ── Helpers ───────────────────────────────────────────────────────────────────

var _hd: MockHealthAndDamage
var _sem: MockStatusEffects
var _enemies: Array[Node] = []
var _fayde: Node2D


func before_test() -> void:
	_hd = MockHealthAndDamage.new()
	_sem = MockStatusEffects.new()
	_enemies = []
	_fayde = Node2D.new()
	add_child(_fayde)


func after_test() -> void:
	for enemy: Node in _enemies:
		remove_child(enemy)
		enemy.free()
	_enemies.clear()
	remove_child(_fayde)
	_fayde.free()


func _enemy(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.position = pos
	add_child(e)
	_enemies.append(e)
	return e


func _make_sce(se: SpellEffect, target: Node = null) -> Node:
	var sce: Node = SCEScript.new()
	sce._health_and_damage = _hd
	sce._status_effects = _sem
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	sce._rng = rng
	add_child(sce)
	sce.set_process(false)
	sce._fayde_ref = _fayde
	sce._get_enemies = func() -> Array[Node]: return _enemies
	sce._on_combat_started(false)
	sce._on_combo_resolved(se)
	sce._override_target = target
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


func _spell(pt: int, tier: int, bdm: float, reactions: Array[ReactionDef] = []) -> SpellEffect:
	var se := SpellEffect.new()
	se.primary_type = pt
	se.primary_tier = tier
	se.base_damage_modifier = bdm
	se.combo_attack_count = tier
	se.active_reactions = reactions
	return se


func _npm(type_id: int, tier: int) -> NonPrimaryModifier:
	var m := NonPrimaryModifier.new()
	m.type_id = type_id
	m.tier = tier
	return m


## Puts [param sce] in CHAINING with [param elapsed] seconds since the lock ended.
func _chaining_at(sce: Node, elapsed: float) -> void:
	sce._state = SCEScript.SCEState.CHAINING
	sce._cast_lock_timer = 0.0
	sce._combo_window_timer = sce._combo_window_duration() - elapsed


func _mid_window() -> float:
	return (AT.perfect_window_start + AT.perfect_window_end) * 0.5


func _full_meter(sce: Node) -> void:
	sce._special_meter = AT.special_meter_max


# ── Perfect window ────────────────────────────────────────────────────────────

func test_perfect_window_only_inside_bounds_while_chaining() -> void:
	var sce := _make_sce(_spell(0, 1, 1.25))
	assert_bool(sce.is_in_perfect_window()).is_false()  # READY, not CHAINING
	_chaining_at(sce, 0.0)
	assert_bool(sce.is_in_perfect_window()).is_false()  # buffered press moment
	_chaining_at(sce, AT.perfect_window_start + 0.001)
	assert_bool(sce.is_in_perfect_window()).is_true()
	_chaining_at(sce, AT.perfect_window_end - 0.001)
	assert_bool(sce.is_in_perfect_window()).is_true()
	_chaining_at(sce, AT.perfect_window_end + 0.05)
	assert_bool(sce.is_in_perfect_window()).is_false()
	_teardown_sce(sce)


func test_perfect_hit_multiplies_damage() -> void:
	var target := _enemy(Vector2(10, 0))
	var sce := _make_sce(_spell(1, 1, 0.9), target)
	_chaining_at(sce, _mid_window())

	sce._trigger_cast()

	assert_float(_hd.damage_to(target)[0]).is_equal_approx(18.0 * AT.perfect_damage_mult, 0.001)
	_teardown_sce(sce)


func test_rushed_press_is_weaker_and_gains_no_meter() -> void:
	var target := _enemy(Vector2(10, 0))
	var sce := _make_sce(_spell(1, 1, 0.9), target)
	_chaining_at(sce, 0.0)  # buffered press fires the instant the lock ends

	sce._trigger_cast()

	assert_float(_hd.damage_to(target)[0]).is_equal_approx(18.0 * AT.rushed_damage_mult, 0.001)
	assert_float(sce.get_special_meter()).is_equal(0.0)
	_teardown_sce(sce)


func test_late_press_after_window_is_normal() -> void:
	var target := _enemy(Vector2(10, 0))
	var sce := _make_sce(_spell(1, 1, 0.9), target)
	_chaining_at(sce, AT.perfect_window_end + 0.2)

	sce._trigger_cast()

	assert_float(_hd.damage_to(target)[0]).is_equal_approx(18.0, 0.001)
	assert_float(sce.get_special_meter()).is_equal_approx(AT.special_gain_hit, 0.001)
	_teardown_sce(sce)


func test_chain_start_from_ready_is_normal() -> void:
	var sce := _make_sce(_spell(1, 1, 0.9))
	assert_int(sce.get_cast_timing()).is_equal(SCEScript.CastTiming.NORMAL)
	_teardown_sce(sce)


func test_rushed_final_hit_skips_cascade() -> void:
	var target := _enemy(Vector2(10, 0))
	var se := _spell(1, 1, 0.9)
	var c := CascadeEffect.new()
	c.lead_type = 1
	c.modifiers = [0, 2]
	c.cascade_mult = 1.2
	se.active_cascade = c
	var sce := _make_sce(se, target)
	var bursts: Array[int] = []
	sce.cascade_burst.connect(func(lead: int, _p: Vector2, _r: float) -> void: bursts.append(lead))
	_chaining_at(sce, 0.0)

	sce._trigger_cast()

	assert_array(bursts).is_empty()
	_teardown_sce(sce)


func test_perfect_streak_counts_consecutive_and_resets_on_miss_timing() -> void:
	var target := _enemy(Vector2(10, 0))
	var sce := _make_sce(_spell(1, 1, 0.9), target)
	var streaks: Array[int] = []
	sce.perfect_cast.connect(func(_pos: Vector2, streak: int) -> void: streaks.append(streak))

	_chaining_at(sce, _mid_window())
	sce._trigger_cast()
	_chaining_at(sce, _mid_window())
	sce._trigger_cast()
	_chaining_at(sce, 0.0)
	sce._trigger_cast()
	_chaining_at(sce, _mid_window())
	sce._trigger_cast()

	assert_array(streaks).is_equal([1, 2, 1])
	_teardown_sce(sce)


func test_perfect_final_hit_powers_cascade() -> void:
	var target := _enemy(Vector2(10, 0))
	var se := _spell(1, 1, 0.9)
	var c := CascadeEffect.new()
	c.lead_type = 1
	c.modifiers = [0, 2]
	c.cascade_mult = 1.2
	se.active_cascade = c
	var sce := _make_sce(se, target)
	_chaining_at(sce, _mid_window())

	sce._trigger_cast()

	var burst: float = roundf(SCEScript.BASE_SPELL_DAMAGE * 0.9 * 1.2 * AT.perfect_cascade_mult)
	assert_float(_hd.damage_to(target)[1]).is_equal_approx(burst, 0.001)
	_teardown_sce(sce)


# ── Special meter ─────────────────────────────────────────────────────────────

func test_meter_gains_per_landed_attack_more_on_perfect() -> void:
	var target := _enemy(Vector2(10, 0))
	var sce := _make_sce(_spell(1, 1, 0.9), target)

	sce._trigger_cast()
	assert_float(sce.get_special_meter()).is_equal_approx(AT.special_gain_hit, 0.001)
	_chaining_at(sce, _mid_window())
	sce._trigger_cast()
	assert_float(sce.get_special_meter()).is_equal_approx(AT.special_gain_hit + AT.special_gain_perfect, 0.001)
	_teardown_sce(sce)


func test_meter_ignores_misses_and_caps_at_max() -> void:
	var sce := _make_sce(_spell(2, 1, 1.15))  # Stormgold, no target → miss
	sce._trigger_cast()
	assert_float(sce.get_special_meter()).is_equal(0.0)
	sce._add_special_meter(AT.special_meter_max * 3.0)
	assert_float(sce.get_special_meter()).is_equal(AT.special_meter_max)
	assert_bool(sce.is_special_ready()).is_true()
	_teardown_sce(sce)


func test_preparation_resets_meter() -> void:
	var sce := _make_sce(_spell(0, 1, 1.25))
	_full_meter(sce)
	sce._on_preparation_started(0, 0)
	assert_float(sce.get_special_meter()).is_equal(0.0)
	_teardown_sce(sce)


# ── Special: gating and scaling ───────────────────────────────────────────────

func test_special_blocked_until_meter_full() -> void:
	var near := _enemy(Vector2(20, 0))
	var sce := _make_sce(_spell(0, 1, 1.25))
	sce._special_meter = AT.special_meter_max - 1.0

	sce._trigger_special()

	assert_array(_hd.damage_to(near)).is_empty()
	assert_float(sce.get_special_meter()).is_equal(AT.special_meter_max - 1.0)
	_teardown_sce(sce)


func test_special_damage_scales_with_tier() -> void:
	var t1 := _make_sce(_spell(0, 1, 1.25))
	var t3 := _make_sce(_spell(0, 3, 1.25))
	var base: float = SCEScript.BASE_SPELL_DAMAGE * 1.25 * AT.special_damage_mult
	assert_float(t1.get_special_damage()).is_equal_approx(base, 0.001)
	assert_float(t3.get_special_damage()).is_equal_approx(base * (1.0 + 2.0 * AT.special_tier_bonus), 0.001)
	_teardown_sce(t1)
	_teardown_sce(t3)


func test_special_spends_meter_and_ends_chain() -> void:
	var sce := _make_sce(_spell(0, 2, 1.25))
	sce._combo_index = 1
	_full_meter(sce)
	var fired: Array[int] = []
	sce.special_fired.connect(func(pt: int, _p: Vector2, _r: float) -> void: fired.append(pt))

	sce._trigger_special()

	assert_float(sce.get_special_meter()).is_equal(0.0)
	assert_int(sce._combo_index).is_equal(0)
	assert_array(fired).is_equal([0])
	assert_float(sce._cast_lock_timer).is_equal(AT.special_lock_duration)
	_teardown_sce(sce)


# ── Special: per-core shape and signature ─────────────────────────────────────

func test_ashfire_eruption_hits_radius_burns_and_consumes_burning() -> void:
	var inside := _enemy(Vector2(AT.special_radius - 10.0, 0))
	var burning := _enemy(Vector2(0, 30))
	var outside := _enemy(Vector2(AT.special_radius + 30.0, 0))
	_sem.give(burning, GameEnums.BaseStatus.BURN)
	var sce := _make_sce(_spell(0, 1, 1.25))
	_full_meter(sce)
	var dmg: float = sce.get_special_damage()

	sce._trigger_special()

	assert_array(_hd.damage_to(inside)).is_equal([dmg])
	assert_array(_hd.damage_to(burning)).is_equal([dmg * AT.eruption_burning_mult])
	assert_array(_hd.damage_to(outside)).is_empty()
	assert_array(_sem.applied_to(inside, GameEnums.BaseStatus.BURN)).is_equal([AT.special_burn_duration])
	_teardown_sce(sce)


func test_voidblue_eclipse_wide_blinds_and_pulls() -> void:
	var far := _enemy(Vector2(AT.special_wide_radius - 10.0, 0))
	var sce := _make_sce(_spell(1, 1, 0.9))
	_full_meter(sce)

	sce._trigger_special()

	assert_array(_hd.damage_to(far)).has_size(1)
	assert_array(_sem.applied_to(far, GameEnums.BaseStatus.BLIND)).is_equal([AT.special_blind_duration])
	assert_array(far.pulls).has_size(1)
	assert_float(far.pulls[0].x).is_equal_approx(-AT.eclipse_pull_distance, 0.001)
	_teardown_sce(sce)


func test_stormgold_chain_hits_nearest_n_and_stuns() -> void:
	var hit: Array[MockEnemy] = []
	for i: int in range(AT.special_chain_targets + 1):
		hit.append(_enemy(Vector2(20.0 + 20.0 * i, 0)))
	var sce := _make_sce(_spell(2, 1, 1.15))
	_full_meter(sce)

	sce._trigger_special()

	for i: int in range(AT.special_chain_targets):
		assert_array(_hd.damage_to(hit[i])).has_size(1)
		assert_array(_sem.applied_to(hit[i], GameEnums.BaseStatus.STUN)).is_equal([AT.special_stun_duration])
	assert_array(_hd.damage_to(hit[AT.special_chain_targets])).is_empty()
	_teardown_sce(sce)


func test_deepfrost_glacier_hits_radius_and_freezes() -> void:
	var e := _enemy(Vector2(30, 0))
	var sce := _make_sce(_spell(3, 1, 0.8))
	_full_meter(sce)
	var dmg: float = sce.get_special_damage()

	sce._trigger_special()

	assert_array(_hd.damage_to(e)).is_equal([dmg])
	assert_array(_sem.applied_to(e, GameEnums.BaseStatus.FREEZE)).is_equal([AT.special_freeze_duration])
	_teardown_sce(sce)


func test_verdant_sanctuary_heals_and_regens() -> void:
	_enemy(Vector2(30, 0))
	var sce := _make_sce(_spell(4, 1, 0.7))
	_full_meter(sce)
	var dmg: float = sce.get_special_damage()

	sce._trigger_special()

	assert_array(_hd.heal_calls).is_equal([dmg * AT.special_heal_ratio])
	assert_array(_sem.applied_to(_fayde, GameEnums.BaseStatus.REGENERATE)).is_equal([AT.sanctuary_regen_duration])
	_teardown_sce(sce)


# ── Special: infusions and reactions ──────────────────────────────────────────

func test_deepfrost_infusion_scales_with_nonprimary_tier() -> void:
	var e := _enemy(Vector2(30, 0))
	var se := _spell(0, 1, 1.25)
	se.non_primary_modifiers = [_npm(3, 2)]
	var sce := _make_sce(se)
	_full_meter(sce)

	sce._trigger_special()

	assert_array(_sem.applied_to(e, GameEnums.BaseStatus.FREEZE)) \
		.is_equal([AT.infusion_freeze_duration * AT.infusion_tier2_mult])
	_teardown_sce(sce)


func test_stormgold_infusion_arcs_beyond_shape_and_stuns() -> void:
	var inside := _enemy(Vector2(30, 0))
	var beyond := _enemy(Vector2(AT.special_radius + 20.0, 0))
	var se := _spell(0, 1, 1.25)
	se.non_primary_modifiers = [_npm(2, 1)]
	var sce := _make_sce(se)
	_full_meter(sce)
	var dmg: float = sce.get_special_damage()

	sce._trigger_special()

	assert_array(_hd.damage_to(inside)).is_equal([dmg])
	assert_array(_hd.damage_to(beyond)).is_equal([dmg * 0.5])
	assert_array(_sem.applied_to(beyond, GameEnums.BaseStatus.STUN)).is_equal([AT.infusion_arc_stun_duration])
	_teardown_sce(sce)


func test_verdant_infusion_heals_flat() -> void:
	var se := _spell(0, 1, 1.25)
	se.non_primary_modifiers = [_npm(4, 1)]
	var sce := _make_sce(se)
	_full_meter(sce)

	sce._trigger_special()

	assert_array(_hd.heal_calls).is_equal([AT.infusion_heal])
	_teardown_sce(sce)


func test_primary_typed_nonprimary_entry_is_ignored() -> void:
	var e := _enemy(Vector2(30, 0))
	var se := _spell(3, 1, 0.8)
	se.non_primary_modifiers = [_npm(3, 2)]
	var sce := _make_sce(se)
	_full_meter(sce)

	sce._trigger_special()

	assert_array(_sem.applied_to(e, GameEnums.BaseStatus.FREEZE)).is_equal([AT.special_freeze_duration])
	_teardown_sce(sce)


func test_witchfire_rides_on_ashfire_special_burn() -> void:
	var e := _enemy(Vector2(30, 0))
	var sce := _make_sce(_spell(0, 1, 1.25, [WITCHFIRE]))
	_full_meter(sce)

	sce._trigger_special()

	assert_array(_sem.applied_to(e, GameEnums.BaseStatus.BLIND)).is_equal([WITCHFIRE.magnitude])
	_teardown_sce(sce)


func test_siphon_heals_from_special_on_blinded_enemy() -> void:
	var e := _enemy(Vector2(30, 0))
	_sem.give(e, GameEnums.BaseStatus.BLIND)
	var sce := _make_sce(_spell(0, 1, 1.25, [SIPHON]))
	_full_meter(sce)
	var dmg: float = sce.get_special_damage()

	sce._trigger_special()

	assert_array(_hd.heal_calls).is_equal([dmg * SIPHON.magnitude])
	_teardown_sce(sce)
