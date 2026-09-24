## sce_reaction_application_test.gd — Unit tests for SC&E applying Prana Reactions and
## the Cascade burst in combat (ADR-0016 application; GDD Formulas 9–10).
##
## Coverage:
##   - Baseline: no armed reaction leaves the plain hit unchanged
##   - Thermal Shock: first hit per target per chain boosted; never stacks with Shatter
##   - Siphon: damage to a Blinded enemy heals Fayde magnitude × damage
##   - Detonate: first kill of the chain bursts nearby enemies once
##   - Witchfire / Wildfire: Burn also Blinds / spreads once within range
##   - Short Circuit: first Stun of the chain also stuns the nearest other enemy
##   - Superconduct: hit on a Frozen primary arcs to the nearest un-hit enemy
##   - Surge: longer combo window; heals only on a landed hit
##   - Permafrost: regen multiplier only while an enemy is Frozen; SEM applies it
##   - Cascade: Ashfire nova with Blind + arc facets; Verdant bloom heals Fayde
##
## Harness (same as damage_formula_test): SC&E added via add_child() then
## set_process(false); _health_and_damage / _status_effects / _get_enemies /
## _fayde_ref / _override_target injected. Reactions come from the real .tres files
## so expectations follow ReactionDef.magnitude, not duplicated numbers.
## Teardown: remove_child() + free() (not queue_free — headless exit 101).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")
const SEMScript = preload("res://src/systems/status_effects_manager.gd")
const TUNING: ReactionTuning = preload("res://assets/data/reaction_tuning.tres")

const THERMAL_SHOCK: ReactionDef = preload("res://assets/data/reactions/react_thermal_shock.tres")
const DETONATE: ReactionDef = preload("res://assets/data/reactions/react_detonate.tres")
const WITCHFIRE: ReactionDef = preload("res://assets/data/reactions/react_witchfire.tres")
const WILDFIRE: ReactionDef = preload("res://assets/data/reactions/react_wildfire.tres")
const SHORT_CIRCUIT: ReactionDef = preload("res://assets/data/reactions/react_short_circuit.tres")
const SIPHON: ReactionDef = preload("res://assets/data/reactions/react_siphon.tres")
const SUPERCONDUCT: ReactionDef = preload("res://assets/data/reactions/react_superconduct.tres")
const SURGE: ReactionDef = preload("res://assets/data/reactions/react_surge.tres")
const PERMAFROST: ReactionDef = preload("res://assets/data/reactions/react_permafrost.tres")


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


## An enemy at [param pos]; registered with the SC&E enemy list.
func _enemy(pos: Vector2) -> MockEnemy:
	var e := MockEnemy.new()
	e.position = pos
	add_child(e)
	_enemies.append(e)
	return e


## SC&E in READY with [param se] cached, reactions armed, and [param target] as the
## attack target (null = the attack misses).
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


func _cascade(lead: int, mods: Array[int], mult: float) -> CascadeEffect:
	var c := CascadeEffect.new()
	c.lead_type = lead
	c.modifiers = mods
	c.cascade_mult = mult
	return c


# ── Baseline ──────────────────────────────────────────────────────────────────

func test_no_reactions_plain_hit_only() -> void:
	var target := _enemy(Vector2.ZERO)
	var sce := _make_sce(_spell(0, 1, 1.25), target)

	sce._trigger_cast()

	assert_array(_hd.damage_to(target)).is_equal([25.0])
	assert_int(_hd.damage_calls.size()).is_equal(1)
	assert_array(_hd.heal_calls).is_empty()
	_teardown_sce(sce)


# ── Thermal Shock ─────────────────────────────────────────────────────────────

func test_thermal_shock_boosts_first_hit_per_target_per_chain_only() -> void:
	var target := _enemy(Vector2.ZERO)
	# Voidblue T2: hits of 20×0.9×1.0 = 18 and 20×0.9×1.1 = 19.8.
	var sce := _make_sce(_spell(1, 2, 0.9, [THERMAL_SHOCK]), target)

	sce._trigger_cast()
	sce._trigger_cast()

	var hits: Array[float] = _hd.damage_to(target)
	assert_float(hits[0]).is_equal_approx(18.0 * (1.0 + THERMAL_SHOCK.magnitude), 0.001)
	assert_float(hits[1]).is_equal_approx(19.8, 0.001)
	_teardown_sce(sce)


func test_thermal_shock_does_not_stack_with_shatter() -> void:
	var target := _enemy(Vector2.ZERO)
	_sem.shatter_mult = 1.0 + THERMAL_SHOCK.magnitude  # frozen target at default knobs
	var sce := _make_sce(_spell(1, 1, 0.9, [THERMAL_SHOCK]), target)

	sce._trigger_cast()

	assert_float(_hd.damage_to(target)[0]).is_equal_approx(18.0 * _sem.shatter_mult, 0.001)
	_teardown_sce(sce)


# ── Siphon ────────────────────────────────────────────────────────────────────

func test_siphon_heals_from_damage_to_blinded_enemy() -> void:
	var target := _enemy(Vector2.ZERO)
	_sem.give(target, GameEnums.BaseStatus.BLIND)
	var sce := _make_sce(_spell(1, 1, 0.9, [SIPHON]), target)

	sce._trigger_cast()

	assert_array(_hd.heal_calls).has_size(1)
	assert_float(_hd.heal_calls[0]).is_equal_approx(18.0 * SIPHON.magnitude, 0.001)
	_teardown_sce(sce)


func test_siphon_ignores_unblinded_enemy() -> void:
	var target := _enemy(Vector2.ZERO)
	var sce := _make_sce(_spell(1, 1, 0.9, [SIPHON]), target)

	sce._trigger_cast()

	assert_array(_hd.heal_calls).is_empty()
	_teardown_sce(sce)


# ── Detonate ──────────────────────────────────────────────────────────────────

func test_detonate_bursts_nearby_enemies_on_first_kill_only() -> void:
	var target := _enemy(Vector2.ZERO)
	target.dies_on_hit = true
	var near := _enemy(Vector2(TUNING.detonate_radius - 10.0, 0.0))
	var far := _enemy(Vector2(TUNING.detonate_radius + 50.0, 0.0))
	var sce := _make_sce(_spell(0, 2, 1.25, [DETONATE]), target)

	sce._trigger_cast()
	var burst: float = SCEScript.BASE_SPELL_DAMAGE * DETONATE.magnitude
	assert_array(_hd.damage_to(near)).is_equal([burst])
	assert_array(_hd.damage_to(far)).is_empty()

	# Second kill in the same chain: no second burst.
	var second := _enemy(Vector2(-5.0, 0.0))
	second.dies_on_hit = true
	sce._override_target = second
	sce._trigger_cast()
	assert_array(_hd.damage_to(near)).has_size(1)
	_teardown_sce(sce)


# ── Witchfire / Wildfire ──────────────────────────────────────────────────────

func test_witchfire_burn_also_blinds() -> void:
	var target := _enemy(Vector2.ZERO)
	var sce := _make_sce(_spell(0, 1, 1.25, [WITCHFIRE]), target)

	sce._trigger_cast()

	assert_array(_sem.applied_to(target, GameEnums.BaseStatus.BURN)).has_size(1)
	assert_array(_sem.applied_to(target, GameEnums.BaseStatus.BLIND)).is_equal([WITCHFIRE.magnitude])
	_teardown_sce(sce)


func test_wildfire_spreads_burn_to_nearest_enemy_in_range_once() -> void:
	var target := _enemy(Vector2.ZERO)
	var near := _enemy(Vector2(WILDFIRE.magnitude - 20.0, 0.0))
	var farther := _enemy(Vector2(WILDFIRE.magnitude - 5.0, 0.0))
	var sce := _make_sce(_spell(0, 1, 1.25, [WILDFIRE]), target)

	sce._trigger_cast()

	assert_array(_sem.applied_to(near, GameEnums.BaseStatus.BURN)).is_equal([TUNING.wildfire_burn_duration])
	assert_array(_sem.applied_to(farther, GameEnums.BaseStatus.BURN)).is_empty()
	_teardown_sce(sce)


func test_wildfire_out_of_range_does_not_spread() -> void:
	var target := _enemy(Vector2.ZERO)
	var far := _enemy(Vector2(WILDFIRE.magnitude + 10.0, 0.0))
	var sce := _make_sce(_spell(0, 1, 1.25, [WILDFIRE]), target)

	sce._trigger_cast()

	assert_array(_sem.applied_to(far, GameEnums.BaseStatus.BURN)).is_empty()
	_teardown_sce(sce)


# ── Short Circuit ─────────────────────────────────────────────────────────────

func test_short_circuit_stuns_nearest_second_enemy_once_per_chain() -> void:
	var target := _enemy(Vector2.ZERO)
	var other := _enemy(Vector2(60.0, 0.0))
	var sce := _make_sce(_spell(2, 2, 1.15, [SHORT_CIRCUIT]), target)

	sce._trigger_cast()
	sce._trigger_cast()

	assert_array(_sem.applied_to(other, GameEnums.BaseStatus.STUN)).is_equal([SHORT_CIRCUIT.magnitude])
	_teardown_sce(sce)


# ── Superconduct ──────────────────────────────────────────────────────────────

func test_superconduct_arcs_from_frozen_primary() -> void:
	var target := _enemy(Vector2.ZERO)
	_sem.give(target, GameEnums.BaseStatus.FREEZE)
	var other := _enemy(Vector2(80.0, 0.0))
	var sce := _make_sce(_spell(2, 1, 1.15, [SUPERCONDUCT]), target)

	sce._trigger_cast()

	var step4: float = SCEScript.BASE_SPELL_DAMAGE * 1.15
	assert_array(_hd.damage_to(other)).has_size(1)
	assert_float(_hd.damage_to(other)[0]).is_equal_approx(step4 * SUPERCONDUCT.magnitude, 0.001)
	_teardown_sce(sce)


func test_superconduct_needs_frozen_or_chilled_primary() -> void:
	var target := _enemy(Vector2.ZERO)
	var other := _enemy(Vector2(80.0, 0.0))
	var sce := _make_sce(_spell(2, 1, 1.15, [SUPERCONDUCT]), target)

	sce._trigger_cast()

	assert_array(_hd.damage_to(other)).is_empty()
	_teardown_sce(sce)


# ── Surge ─────────────────────────────────────────────────────────────────────

func test_surge_extends_window_and_heals_on_hit() -> void:
	var target := _enemy(Vector2.ZERO)
	var sce := _make_sce(_spell(2, 2, 1.15, [SURGE]), target)

	sce._trigger_cast()

	assert_float(sce._combo_window_timer).is_equal_approx(
		SCEScript.COMBO_CONTINUATION_WINDOW + SURGE.magnitude, 0.001)
	assert_array(_hd.heal_calls).is_equal([TUNING.surge_heal])
	_teardown_sce(sce)


func test_surge_does_not_heal_on_miss() -> void:
	var sce := _make_sce(_spell(2, 2, 1.15, [SURGE]), null)

	sce._trigger_cast()

	assert_array(_hd.heal_calls).is_empty()
	_teardown_sce(sce)


# ── Permafrost ────────────────────────────────────────────────────────────────

func test_permafrost_amplifies_regen_only_while_an_enemy_is_frozen() -> void:
	var enemy := _enemy(Vector2.ZERO)
	var sce := _make_sce(_spell(3, 1, 0.8, [PERMAFROST]))

	assert_float(sce.get_regen_multiplier()).is_equal(1.0)
	_sem.give(enemy, GameEnums.BaseStatus.FREEZE)
	assert_float(sce.get_regen_multiplier()).is_equal(PERMAFROST.magnitude)
	_teardown_sce(sce)


func test_sem_regen_tick_uses_injected_multiplier() -> void:
	var hd := MockHealthAndDamage.new()
	var sem: Node = SEMScript.new()
	sem._health_and_damage = hd
	add_child(sem)
	sem.set_process(false)
	sem._regen_multiplier = func() -> float: return PERMAFROST.magnitude
	var player := MockEnemy.new()  # has is_alive(); group decides scope
	player.add_to_group(&"player")
	add_child(player)

	sem.apply_status(player, GameEnums.BaseStatus.REGENERATE, 3.0)
	sem.call(&"_process", 1.0)

	var base_tick: float = SEMScript.FAYDE_MAX_HP * SEMScript.REGEN_TICK_MAGNITUDE
	assert_array(hd.heal_calls).has_size(1)
	assert_float(hd.heal_calls[0]).is_equal_approx(base_tick * PERMAFROST.magnitude, 0.001)
	remove_child(player)
	player.free()
	remove_child(sem)
	sem.free()


# ── Cascade ───────────────────────────────────────────────────────────────────

func test_ashfire_cascade_nova_blinds_and_arcs() -> void:
	var target := _enemy(Vector2.ZERO)
	var in_nova := _enemy(Vector2(TUNING.aoe_radius - 10.0, 0.0))
	var arc_only := _enemy(Vector2(TUNING.aoe_radius + 40.0, 0.0))
	var se := _spell(0, 1, 1.25)
	se.active_cascade = _cascade(0, [1, 2], 1.2)
	var sce := _make_sce(se, target)
	var bursts: Array = []
	sce.cascade_burst.connect(func(lead: int, _pos: Vector2, radius: float) -> void:
		bursts.append([lead, radius]))

	sce._trigger_cast()

	var burst: float = roundf(SCEScript.BASE_SPELL_DAMAGE * 1.25 * 1.2)
	assert_array(_hd.damage_to(target)).is_equal([25.0, burst])
	assert_array(_hd.damage_to(in_nova)).is_equal([burst])
	assert_array(_hd.damage_to(arc_only)).is_equal([burst])
	assert_array(_sem.applied_to(in_nova, GameEnums.BaseStatus.BLIND)).is_equal([TUNING.blind_duration])
	assert_array(bursts).is_equal([[0, TUNING.aoe_radius]])
	_teardown_sce(sce)


func test_cascade_fires_only_on_final_chain_attack() -> void:
	var target := _enemy(Vector2.ZERO)
	var se := _spell(0, 2, 1.25)
	se.active_cascade = _cascade(0, [1, 3], 1.2)
	var sce := _make_sce(se, target)
	var bursts: Array[int] = []
	sce.cascade_burst.connect(func(lead: int, _pos: Vector2, _r: float) -> void: bursts.append(lead))

	sce._trigger_cast()
	assert_array(bursts).is_empty()
	sce._trigger_cast()
	assert_array(bursts).is_equal([0])
	_teardown_sce(sce)


func test_verdant_cascade_bloom_heals_without_damage() -> void:
	var target := _enemy(Vector2.ZERO)
	var se := _spell(4, 1, 0.7)
	se.active_cascade = _cascade(4, [0, 3], 1.2)
	var sce := _make_sce(se, target)

	sce._trigger_cast()

	var burst: float = roundf(SCEScript.BASE_SPELL_DAMAGE * 0.7 * 1.2)
	assert_array(_hd.damage_to(target)).has_size(1)  # the primary hit only
	assert_array(_hd.heal_calls).is_equal([burst * TUNING.lifesteal])
	assert_array(_sem.applied_to(target, GameEnums.BaseStatus.FREEZE)).is_equal([TUNING.freeze_duration])
	_teardown_sce(sce)
