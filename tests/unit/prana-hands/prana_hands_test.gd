## prana_hands_test.gd — the grid's two hands (ADR-0057, combination-resolution.md Rule 18).
##
## Ayden's hand (left column) adds damage, Faith's hand (right column) lengthens the core
## status, and equal non-zero hands touch and multiply both bonuses. Expected values come
## from assets/data/hands_tuning.tres so the tests follow the knobs.
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")
const CRScript = preload("res://src/systems/combination_resolution.gd")
const T: HandsTuning = preload("res://assets/data/hands_tuning.tres")
const COPY: UICopy = preload("res://assets/data/ui_copy.tres")


class MockHealthAndDamage:
	var amounts: Array[float] = []

	func apply_damage(_target: Node, amount: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		amounts.append(amount)

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


class MockStatusEffects:
	var durations: Array[float] = []

	func apply_status(_target: Node, _status: GameEnums.BaseStatus, duration: float, _base: float = 0.0) -> void:
		durations.append(duration)

	func has_status(_target: Node, _status: GameEnums.BaseStatus) -> bool:
		return false

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage


class MockEnemy extends Node2D:
	func is_alive() -> bool: return true
	func apply_speed_modifier(_mult: float) -> void: pass
	func apply_stun(_duration: float) -> void: pass
	func apply_knockback(_direction: Vector2, _distance: float) -> void: pass


func _grid(filled: Array[int]) -> Array:
	var g: Array = []
	g.resize(9)
	for i: int in filled:
		g[i] = 1
	return g


func _frag(type_id: int) -> PranaFragment:
	var f := PranaFragment.new()
	f.type_id = type_id
	return f


# ── Pure rules ───────────────────────────────────────────────────────────────

func test_default_hands_are_the_left_and_right_columns() -> void:
	assert_array(Array(T.ayden_slots)).contains_exactly([0, 3, 6])
	assert_array(Array(T.faith_slots)).contains_exactly([2, 5, 8])


func test_empty_hands_change_nothing() -> void:
	var h: Dictionary = PranaHands.read(_grid([4, 1, 7]))
	assert_int(h["ayden"]).is_equal(0)
	assert_int(h["faith"]).is_equal(0)
	assert_bool(h["touch"]).is_false()
	assert_float(h["power_mult"]).is_equal(1.0)
	assert_float(h["control_mult"]).is_equal(1.0)


func test_ayden_hand_adds_power_per_prana() -> void:
	var h: Dictionary = PranaHands.read(_grid([4, 0, 3]))
	assert_int(h["ayden"]).is_equal(2)
	assert_float(h["power_mult"]).is_equal_approx(1.0 + 2.0 * T.power_per_prana, 0.0001)
	assert_float(h["control_mult"]).is_equal(1.0)


func test_faith_hand_adds_control_per_prana() -> void:
	var h: Dictionary = PranaHands.read(_grid([4, 8]))
	assert_int(h["faith"]).is_equal(1)
	assert_float(h["control_mult"]).is_equal_approx(1.0 + T.control_per_prana, 0.0001)
	assert_float(h["power_mult"]).is_equal(1.0)


func test_equal_hands_touch_and_multiply_both_bonuses() -> void:
	var h: Dictionary = PranaHands.read(_grid([4, 0, 3, 2, 5]))
	assert_bool(h["touch"]).is_true()
	assert_float(h["power_mult"]).is_equal_approx(1.0 + 2.0 * T.power_per_prana * T.touch_mult, 0.0001)
	assert_float(h["control_mult"]).is_equal_approx(1.0 + 2.0 * T.control_per_prana * T.touch_mult, 0.0001)


func test_uneven_hands_do_not_touch() -> void:
	assert_bool(PranaHands.touching(2, 1)).is_false()
	assert_bool(PranaHands.touching(0, 0)).is_false()
	assert_bool(PranaHands.touching(3, 3)).is_true()


# ── Resolution and preview ───────────────────────────────────────────────────

func test_resolve_puts_the_hands_on_the_spell_effect() -> void:
	var cr: Node = CRScript.new()
	var frags: Array = []
	frags.resize(9)
	frags[4] = _frag(0)
	frags[0] = _frag(3)
	frags[2] = _frag(1)
	var se: SpellEffect = cr._resolve(frags)
	assert_bool(se.hands_touching).is_true()
	assert_float(se.hand_power_mult).is_equal_approx(1.0 + T.power_per_prana * T.touch_mult, 0.0001)
	assert_float(se.hand_control_mult).is_equal_approx(1.0 + T.control_per_prana * T.touch_mult, 0.0001)
	cr.free()


func test_preview_build_reports_the_hands() -> void:
	var summary: Dictionary = CombinationResolution.preview_build(_grid([4, 6]))
	assert_int(summary["hands"]["ayden"]).is_equal(1)


func test_preview_line_names_each_active_hand() -> void:
	var line: String = SpellPreview.hands_line(PranaHands.read(_grid([4, 0, 2])), COPY)
	assert_str(line).contains("Ayden").contains("Faith")
	assert_str(SpellPreview.hands_line(PranaHands.read(_grid([4])), COPY)).is_empty()


# ── Combat ───────────────────────────────────────────────────────────────────

func _cast_once(power: float, control: float) -> Array:
	var hd := MockHealthAndDamage.new()
	var sem := MockStatusEffects.new()
	var fayde := Node2D.new()
	add_child(fayde)
	var target := MockEnemy.new()
	target.position = Vector2(10, 0)
	add_child(target)
	var sce: Node = SCEScript.new()
	sce._health_and_damage = hd
	sce._status_effects = sem
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	sce._rng = rng
	add_child(sce)
	sce.set_process(false)
	sce._fayde_ref = fayde
	var enemies: Array[Node] = [target]
	sce._get_enemies = func() -> Array[Node]: return enemies
	sce._on_combat_started(false)
	var se := SpellEffect.new()
	se.primary_type = 1  # Voidblue: Blind, no crit roll
	se.primary_tier = 1
	se.combo_attack_count = 1
	se.base_damage_modifier = 0.9
	se.hand_power_mult = power
	se.hand_control_mult = control
	sce._on_combo_resolved(se)
	sce._override_target = target
	sce._trigger_cast()
	var out: Array = [hd.amounts[0], sem.durations[0]]
	for n: Node in [sce, target, fayde]:
		remove_child(n)
		n.free()
	return out


func test_ayden_hand_scales_hit_damage_and_faith_hand_scales_status() -> void:
	var plain: Array = _cast_once(1.0, 1.0)
	var held: Array = _cast_once(1.2, 1.5)
	assert_float(held[0]).is_equal_approx(plain[0] * 1.2, 0.001)
	assert_float(held[1]).is_equal_approx(plain[1] * 1.5, 0.001)
