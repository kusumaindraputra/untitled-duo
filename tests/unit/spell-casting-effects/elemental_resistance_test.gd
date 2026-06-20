## elemental_resistance_test.gd — Unit tests for elemental resistance (0.5×)
## added to Step 9 of spell_casting_effects.gd.
##
## Coverage:
##   AC-RESIST-01: Non-matching Prana vs affiliated enemy → raw × 0.5
##   AC-RESIST-02: Any Prana vs NONE-affiliated enemy → raw × 1.0 (no resistance)
##
## Framework: GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")


class MockHealthAndDamage:
	var call_count: int = 0
	var last_raw_damage: float = 0.0

	func apply_damage(_target: Node, raw_damage: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		call_count += 1
		last_raw_damage = raw_damage

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


class MockStatusEffectsPassthrough:
	func apply_status(_target: Node, _status_type: GameEnums.BaseStatus, _duration: float, _spell_base_damage: float = 0.0) -> void:
		pass

	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage

	func has_status(_target: Node, _status_type: GameEnums.BaseStatus) -> bool:
		return false


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


func _make_sce(mock_hd: MockHealthAndDamage = null) -> Node:
	var sce: Node = SCEScript.new()
	sce._health_and_damage = mock_hd if mock_hd != null else MockHealthAndDamage.new()
	sce._status_effects = MockStatusEffectsPassthrough.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	sce._rng = rng
	add_child(sce)
	sce.set_process(false)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


func _make_spell_effect(pt: int, tier: int, bdm: float) -> SpellEffect:
	var se: SpellEffect = SpellEffect.new()
	se.primary_type = pt
	se.primary_tier = tier
	se.base_damage_modifier = bdm
	se.combo_attack_count = tier
	se.aggregate_stat_bonus = {}
	return se


func _ready_sce(sce: Node, se: SpellEffect, target: MockEnemy) -> void:
	sce._on_combat_started(false)
	sce._on_combo_resolved(se)
	sce._override_target = target


# ── AC-RESIST-01: Non-matching Prana vs affiliated enemy → 0.5× ──────────────

## GIVEN Ashfire T1 SpellEffect (bdm=1.25); enemy affiliation = SHADOW (no match)
## WHEN _fire_attack(0) called
## THEN apply_damage called with raw ≈ 25.0 × 0.5 = 12.5
func test_sce_non_matching_prana_vs_affiliated_enemy_halves_damage() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1 (FIRE = 0)
	var enemy := MockEnemy.new()
	enemy.prana_affiliation = GameEnums.DamageClass.SHADOW  # Not FIRE — resistance applies
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# raw = 20 × 1.25 × 1.00 = 25.0; after 0.5× resistance: 12.5
	assert_float(hd.last_raw_damage).is_equal_approx(12.5, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-RESIST-02: Any Prana vs NONE-affiliated enemy → 1.0× (no resistance) ──

## GIVEN Ashfire T1 SpellEffect (bdm=1.25); enemy affiliation = NONE (no element)
## WHEN _fire_attack(0) called
## THEN apply_damage called with raw ≈ 25.0 (× 1.0 — NONE-affiliated enemies ignore resistance)
func test_sce_any_prana_vs_none_affiliated_enemy_no_resistance() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1
	var enemy := MockEnemy.new()
	# prana_affiliation stays at NONE (default) — no affiliation, no resistance
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	sce._fire_attack(0)

	# raw = 20 × 1.25 × 1.00 = 25.0 — no resistance multiplier for NONE-affiliated
	assert_float(hd.last_raw_damage).is_equal_approx(25.0, 0.01)
	assert_int(hd.call_count).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)
