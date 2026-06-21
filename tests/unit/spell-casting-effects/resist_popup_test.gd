## resist_popup_test.gd — Unit tests for affiliation_resist_hit signal emission
## in SpellCastingEffects._fire_attack() Step 9.
##
## Coverage:
##   AC-RESIST-04: non-matching Prana vs affiliated enemy → affiliation_resist_hit emitted
##   AC-RESIST-05: matching Prana vs affiliated enemy → affiliation_resist_hit NOT emitted
##   AC-RESIST-06: any Prana vs NONE-affiliated enemy → affiliation_resist_hit NOT emitted
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


# ── AC-RESIST-04: non-matching prana vs affiliated enemy → signal emitted ──────

## GIVEN Ashfire T1 (FIRE=0); enemy affiliation = SHADOW (non-matching)
## WHEN _fire_attack(0) is called
## THEN affiliation_resist_hit is emitted exactly once
func test_sce_resist_signal_emitted_on_non_matching_prana() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1 (FIRE=0)
	var enemy := MockEnemy.new()
	enemy.prana_affiliation = GameEnums.DamageClass.SHADOW  # SHADOW ≠ FIRE → resist
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	# Array (reference type) — lambdas in GDScript 4 don't reliably update
	# outer local int variables (value type capture semantics). Array.append()
	# mutates the shared reference and is visible after _fire_attack() returns.
	var resist_calls: Array = []
	sce.affiliation_resist_hit.connect(func(_t: Node, _p: int) -> void: resist_calls.append(1))

	sce._fire_attack(0)

	assert_int(resist_calls.size()).is_equal(1)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-RESIST-05: matching prana vs affiliated enemy → signal NOT emitted ───────

## GIVEN Ashfire T1 (FIRE=0); enemy affiliation = FIRE (matching → bonus, not resist)
## WHEN _fire_attack(0) is called
## THEN affiliation_resist_hit is NOT emitted (affiliation_bonus_hit fires instead)
func test_sce_resist_signal_not_emitted_on_matching_prana() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1 (FIRE=0)
	var enemy := MockEnemy.new()
	enemy.prana_affiliation = GameEnums.DamageClass.FIRE  # FIRE = FIRE → bonus
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	var resist_calls: Array = []
	sce.affiliation_resist_hit.connect(func(_t: Node, _p: int) -> void: resist_calls.append(1))

	sce._fire_attack(0)

	assert_int(resist_calls.size()).is_equal(0)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)


# ── AC-RESIST-06: NONE-affiliated enemy → signal NOT emitted ────────────────────

## GIVEN Ashfire T1 (FIRE=0); enemy affiliation = NONE (no element — resistance bypassed)
## WHEN _fire_attack(0) is called
## THEN affiliation_resist_hit is NOT emitted
func test_sce_resist_signal_not_emitted_vs_none_affiliated() -> void:
	var hd := MockHealthAndDamage.new()
	var sce = _make_sce(hd)
	var se := _make_spell_effect(0, 1, 1.25)  # Ashfire T1 (FIRE=0)
	var enemy := MockEnemy.new()
	# enemy.prana_affiliation stays at NONE (default)
	add_child(enemy)
	_ready_sce(sce, se, enemy)
	sce._combo_index = 1

	var resist_calls: Array = []
	sce.affiliation_resist_hit.connect(func(_t: Node, _p: int) -> void: resist_calls.append(1))

	sce._fire_attack(0)

	assert_int(resist_calls.size()).is_equal(0)

	remove_child(enemy)
	enemy.free()
	_teardown_sce(sce)
