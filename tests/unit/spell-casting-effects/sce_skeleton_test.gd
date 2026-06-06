## sce_skeleton_test.gd — Unit tests for SpellCastingEffects skeleton and state machine.
##
## Coverage:
##   AC-SC-01: IDLE → READY on _on_combo_resolved with valid primary_type while in combat
##   AC-SC-06: preparation_started resets _state=IDLE, _combo_index=0, _current_spell_effect=null
##   AC-SC-24: _on_combo_resolved with primary_type == -1 stays IDLE, push_error called
##   ADR-0009: get_stat_bonus returns 0.0 when cache null; returns cached value when set
##
## Setup pattern:
##   - SC&E instantiated with SCEScript.new() — returned as Node (no class_name).
##   - Untyped local vars used when accessing private fields (_state, _combo_index, etc.)
##     because GDScript can't cast to an unnamed type; duck-typing resolves at runtime.
##   - Signal handler methods called directly (_on_preparation_started, _on_combat_started,
##     _on_combo_resolved) — avoids cross-Autoload signal contamination in unit tests.
##   - DO NOT use monitor_signals() on Autoloads — GdUnit4 frees the Autoload between tests.
##   - Teardown: remove_child() then free() (not queue_free() — headless GdUnit4, exit 101).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_sce() -> Node:
	var sce: Node = SCEScript.new()
	add_child(sce)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


func _make_spell_effect(pt: int, tier: int = 1, bdm: float = 1.25) -> SpellEffect:
	var se: SpellEffect = SpellEffect.new()
	se.primary_type = pt
	se.primary_tier = tier
	se.base_damage_modifier = bdm
	se.combo_attack_count = tier
	se.aggregate_stat_bonus = {}
	return se


# ── AC-SC-01: IDLE → READY on valid combo_resolved while in combat ────────────

## GIVEN SC&E in IDLE, combat_started fired
## WHEN _on_combo_resolved(valid SpellEffect) called
## THEN _state == READY and _combo_index == 0
func test_sce_idle_to_ready_on_combo_resolved_with_valid_primary_type() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)

	sce._on_combo_resolved(_make_spell_effect(0))  # Ashfire

	assert_int(sce._state).is_equal(sce.SCEState.READY)
	assert_int(sce._combo_index).is_equal(0)

	_teardown_sce(sce)


## GIVEN SC&E in IDLE, combat NOT started
## WHEN _on_combo_resolved(valid SpellEffect) called
## THEN _state remains IDLE (guard: _in_combat must be true)
func test_sce_remains_idle_on_combo_resolved_when_not_in_combat() -> void:
	var sce = _make_sce()
	# Do NOT call _on_combat_started

	sce._on_combo_resolved(_make_spell_effect(0))

	assert_int(sce._state).is_equal(sce.SCEState.IDLE)

	_teardown_sce(sce)


## GIVEN SC&E in READY (previous wave), preparation_started fires
## WHEN _on_combo_resolved called with valid primary_type and combat_started
## THEN _state == READY, _combo_index == 0, _current_spell_effect is the new effect
func test_sce_idle_to_ready_with_verdant_primary_type() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)
	var se: SpellEffect = _make_spell_effect(4)  # Verdant

	sce._on_combo_resolved(se)

	assert_int(sce._state).is_equal(sce.SCEState.READY)
	assert_bool(sce._current_spell_effect != null).is_true()
	assert_int(sce._current_spell_effect.primary_type).is_equal(4)

	_teardown_sce(sce)


# ── AC-SC-06: preparation_started resets all state ───────────────────────────

## GIVEN SC&E in CHAINING state with _combo_index=1 and a non-null SpellEffect
## WHEN _on_preparation_started() called
## THEN _state == IDLE, _combo_index == 0, _current_spell_effect == null
func test_sce_preparation_started_resets_state_to_idle() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)
	sce._on_combo_resolved(_make_spell_effect(0))
	sce._state = sce.SCEState.CHAINING
	sce._combo_index = 1

	sce._on_preparation_started(0, 1)

	assert_int(sce._state).is_equal(sce.SCEState.IDLE)
	assert_int(sce._combo_index).is_equal(0)
	assert_bool(sce._current_spell_effect == null).is_true()

	_teardown_sce(sce)


## GIVEN SC&E in CAST_LOCKED with _in_combat=true
## WHEN preparation_started fires
## THEN _in_combat == false (reset so next combo_resolved won't prematurely ready)
func test_sce_preparation_started_clears_in_combat_flag() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)
	sce._on_combo_resolved(_make_spell_effect(2))  # Stormgold
	sce._state = sce.SCEState.CAST_LOCKED

	sce._on_preparation_started(1, 0)

	assert_bool(sce._in_combat).is_false()
	assert_int(sce._state).is_equal(sce.SCEState.IDLE)

	_teardown_sce(sce)


# ── AC-SC-24: combo_resolved with primary_type == -1 stays IDLE ──────────────

## GIVEN SC&E in IDLE, in combat
## WHEN _on_combo_resolved called with primary_type == -1
## THEN _state remains IDLE (push_error called — not assertable directly; state is observable contract)
func test_sce_combo_resolved_with_invalid_primary_type_stays_idle() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)
	var invalid_se: SpellEffect = _make_spell_effect(-1)

	sce._on_combo_resolved(invalid_se)

	assert_int(sce._state).is_equal(sce.SCEState.IDLE)
	assert_bool(sce._current_spell_effect == null).is_true()

	_teardown_sce(sce)


# ── ADR-0009: get_stat_bonus() stat broker ────────────────────────────────────

## GIVEN SC&E with _current_spell_effect == null (no wave active)
## WHEN get_stat_bonus(&"ASH_DMG") called
## THEN returns 0.0
func test_sce_get_stat_bonus_returns_zero_when_no_spell_effect_cached() -> void:
	var sce = _make_sce()
	# Do not set _current_spell_effect — it is null by default

	var result: float = sce.get_stat_bonus(&"ASH_DMG")

	assert_float(result).is_equal_approx(0.0, 0.001)

	_teardown_sce(sce)


## GIVEN SC&E with a cached SpellEffect containing aggregate_stat_bonus = {"ASH_DMG": 5.0}
## WHEN get_stat_bonus(&"ASH_DMG") called
## THEN returns 5.0
func test_sce_get_stat_bonus_returns_value_from_cached_spell_effect() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)
	var se: SpellEffect = _make_spell_effect(0)
	se.aggregate_stat_bonus = {&"ASH_DMG": 5.0, &"FROST_DMG": 3.0}
	sce._on_combo_resolved(se)

	assert_float(sce.get_stat_bonus(&"ASH_DMG")).is_equal_approx(5.0, 0.001)
	assert_float(sce.get_stat_bonus(&"FROST_DMG")).is_equal_approx(3.0, 0.001)
	assert_float(sce.get_stat_bonus(&"NONEXISTENT")).is_equal_approx(0.0, 0.001)

	_teardown_sce(sce)
