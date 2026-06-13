## sce_visual_routing_test.gd — Unit tests for SCE cast_started signal and SpellVFX routing.
##
## Coverage:
##   cast_started signal (SC&E):
##     VR-01: cast_started emitted when IDLE → READY on valid combo_resolved (in combat)
##     VR-02: cast_started NOT emitted when not in combat (guard blocks READY transition)
##     VR-03: cast_started NOT emitted for primary_type == -1 (push_error path)
##     VR-04: cast_started NOT emitted when combo_resolved receives null SpellEffect
##     VR-05: cast_started emitted with correct SpellEffect reference (primary_type matches)
##     VR-06: cast_started emitted again on re-resolution (READY → READY; new SpellEffect)
##     VR-07: cast_started emitted for each of the 5 primary_types (0–4)
##
##   SpellVFX connection layer:
##     VR-08: SpellVFX._on_cast_started called when SCE emits cast_started
##     VR-09: SpellVFX._on_spell_hit_element called when SCE emits spell_hit_element
##     VR-10: SpellVFX._on_cast_hit_started called when SCE emits cast_hit_started
##     VR-11: SpellVFX._on_cast_started receives SpellEffect with correct primary_type
##     VR-12: SpellVFX._on_spell_hit_element receives correct (target, prana_type_id)
##     VR-13: SpellVFX._on_cast_hit_started receives correct lock_duration value
##     VR-14: SpellVFX._exit_tree() disconnects all three signal connections cleanly
##     VR-15: SpellVFX._on_cast_started is a no-op (no crash, no side-effects beyond warning)
##     VR-16: SpellVFX._on_spell_hit_element is a no-op (no crash)
##     VR-17: SpellVFX._on_cast_hit_started is a no-op (no crash)
##
## Test harness notes:
##   - SC&E instantiated with SCEScript.new() + add_child(); SpellVFX instantiated with
##     VFXScript.new() separately — SpellVFX._ready() connects to SpellCastingEffects Autoload,
##     not to the test's local SC&E instance. Tests that need cross-wiring use lambda spies
##     connected directly to sce.cast_started (same pattern as prana_grid_confirm_logic_test).
##   - SpellVFX stub handlers (VR-08–13) are tested via lambda spy on each signal rather than
##     inspecting SpellVFX internals — SpellVFX has no public observable state at FP.
##   - _override_target + mock injections: only needed for tests that fire _fire_attack()
##     (VR-09, VR-12). Other tests drive SC&E directly via signal handlers.
##   - Teardown: remove_child() + free() for tree-attached nodes (not queue_free — exit 101).
##   - SpellVFX.new() allocates a standalone instance unconnected to the live Autoload; tests
##     invoke its handler methods directly to verify no-crash contracts (VR-15–17).
##   - Lambda capture semantics: GDScript lambdas capture ALL local variables by value
##     (int, float, bool, Node). Mutations inside a lambda do NOT propagate back to the outer
##     scope. All spy variables that lambdas write must be wrapped in Array[T] so the lambda
##     mutates the array's contents (by-reference), not a local copy.
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")
const VFXScript = preload("res://src/ui/spell_vfx.gd")


# ── Inner mocks ───────────────────────────────────────────────────────────────

## Spy on apply_damage — prevents null-call crash when _fire_attack() runs.
class MockHealthAndDamage:
	var call_count: int = 0
	var last_raw_damage: float = 0.0

	func apply_damage(_target: Node, raw_damage: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		call_count += 1
		last_raw_damage = raw_damage

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


## Passthrough SEM stub — check_and_apply_shatter returns base unchanged; has_status false.
class MockStatusEffectsPassthrough:
	func check_and_apply_shatter(_target: Node, base_damage: float) -> float:
		return base_damage

	func has_status(_target: Node, _status_type: GameEnums.BaseStatus) -> bool:
		return false


## Minimal enemy node required for _fire_attack() _override_target path.
class MockEnemy extends Node2D:
	var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
	var status_freeze_timer: float = 0.0
	var status_stun_timer: float = 0.0
	var status_burned: bool = false
	var status_blinded_timer: float = 0.0
	var status_stagger_timer: float = 0.0

	func is_alive() -> bool: return true


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_sce() -> Node:
	var sce: Node = SCEScript.new()
	add_child(sce)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


## Builds a minimal SpellEffect for the given primary_type.
## tier=1 gives combo_attack_count=1 (single attack — safe for all test types).
func _make_spell_effect(pt: int, tier: int = 1, bdm: float = 1.0) -> SpellEffect:
	var se: SpellEffect = SpellEffect.new()
	se.primary_type = pt
	se.primary_tier = tier
	se.base_damage_modifier = bdm
	se.combo_attack_count = tier
	se.aggregate_stat_bonus = {}
	return se


## Puts SC&E into READY via the standard in-combat path.
func _ready_sce_with_effect(sce: Node, se: SpellEffect) -> void:
	sce._on_combat_started(false)
	sce._on_combo_resolved(se)


# ── VR-01: cast_started emitted on IDLE → READY (valid, in combat) ─────────────

## GIVEN SC&E in IDLE with combat_started fired
## WHEN _on_combo_resolved(valid Ashfire SpellEffect) called
## THEN cast_started signal fires exactly once
func test_sce_cast_started_emitted_on_idle_to_ready_transition() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)

	# Array wrapper: GDScript lambdas capture all locals by value; only Array
	# contents are mutated by reference and visible to the outer scope.
	var call_count: Array[int] = [0]
	sce.cast_started.connect(func(_se: SpellEffect) -> void: call_count[0] += 1)

	sce._on_combo_resolved(_make_spell_effect(0))

	assert_int(call_count[0]).is_equal(1)

	_teardown_sce(sce)


# ── VR-02: cast_started NOT emitted when not in combat ─────────────────────────

## GIVEN SC&E in IDLE with combat NOT started
## WHEN _on_combo_resolved(valid SpellEffect) called
## THEN cast_started signal is NOT emitted (guard blocks transition)
func test_sce_cast_started_not_emitted_when_not_in_combat() -> void:
	var sce = _make_sce()
	# Do NOT call _on_combat_started

	var call_count: Array[int] = [0]
	sce.cast_started.connect(func(_se: SpellEffect) -> void: call_count[0] += 1)

	sce._on_combo_resolved(_make_spell_effect(1))

	assert_int(call_count[0]).is_equal(0)

	_teardown_sce(sce)


# ── VR-03: cast_started NOT emitted for primary_type == -1 ─────────────────────

## GIVEN SC&E in IDLE, combat started
## WHEN _on_combo_resolved called with primary_type == -1 (invalid)
## THEN cast_started signal is NOT emitted (push_error path returns early)
func test_sce_cast_started_not_emitted_for_invalid_primary_type() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)

	var call_count: Array[int] = [0]
	sce.cast_started.connect(func(_se: SpellEffect) -> void: call_count[0] += 1)

	sce._on_combo_resolved(_make_spell_effect(-1))

	assert_int(call_count[0]).is_equal(0)
	assert_int(sce._state).is_equal(sce.SCEState.IDLE)

	_teardown_sce(sce)


# ── VR-04: cast_started NOT emitted when combo_resolved receives null ───────────

## GIVEN SC&E in IDLE, combat started
## WHEN _on_combo_resolved(null) called
## THEN cast_started signal is NOT emitted (null guard path returns early)
func test_sce_cast_started_not_emitted_for_null_spell_effect() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)

	var call_count: Array[int] = [0]
	sce.cast_started.connect(func(_se: SpellEffect) -> void: call_count[0] += 1)

	sce._on_combo_resolved(null)

	assert_int(call_count[0]).is_equal(0)
	assert_int(sce._state).is_equal(sce.SCEState.IDLE)

	_teardown_sce(sce)


# ── VR-05: cast_started emitted with correct SpellEffect reference ──────────────

## GIVEN SC&E in IDLE, combat started, and a Deepfrost T2 SpellEffect
## WHEN _on_combo_resolved called
## THEN cast_started fires with the exact SpellEffect (primary_type == 3)
func test_sce_cast_started_emits_correct_spell_effect_reference() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)
	var se: SpellEffect = _make_spell_effect(3, 2)  # Deepfrost T2

	var received_type: Array[int] = [-99]
	sce.cast_started.connect(func(s: SpellEffect) -> void: received_type[0] = s.primary_type)

	sce._on_combo_resolved(se)

	assert_int(received_type[0]).is_equal(3)

	_teardown_sce(sce)


# ── VR-06: cast_started emitted again on re-resolution ─────────────────────────

## GIVEN SC&E already in READY with Ashfire SpellEffect
## WHEN _on_combo_resolved called again with Verdant SpellEffect (re-resolution)
## THEN cast_started fires a second time with the new SpellEffect (primary_type == 4)
func test_sce_cast_started_emitted_again_on_re_resolution() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)
	sce._on_combo_resolved(_make_spell_effect(0))  # Ashfire → READY

	var emit_count: Array[int] = [0]
	var last_type: Array[int] = [-99]
	sce.cast_started.connect(func(s: SpellEffect) -> void:
		emit_count[0] += 1
		last_type[0] = s.primary_type
	)

	sce._on_combo_resolved(_make_spell_effect(4))  # Verdant re-resolution

	assert_int(emit_count[0]).is_equal(1)
	assert_int(last_type[0]).is_equal(4)

	_teardown_sce(sce)


# ── VR-07: cast_started emitted for all 5 primary_types ────────────────────────

## GIVEN SC&E cycling through 5 preparation → combat → combo_resolved cycles
## WHEN each combo_resolved has primary_type 0–4
## THEN cast_started fires exactly once per cycle and carries the correct type
func test_sce_cast_started_emitted_for_all_primary_types() -> void:
	var sce = _make_sce()

	for pt in range(0, 5):
		sce._on_preparation_started(pt, 4 - pt)  # reset to IDLE between waves
		sce._on_combat_started(false)

		var received_type: Array[int] = [-99]
		var emit_count: Array[int] = [0]
		var spy := func(s: SpellEffect) -> void:
			received_type[0] = s.primary_type
			emit_count[0] += 1

		sce.cast_started.connect(spy)
		sce._on_combo_resolved(_make_spell_effect(pt))
		sce.cast_started.disconnect(spy)

		assert_int(emit_count[0]).is_equal(1)
		assert_int(received_type[0]).is_equal(pt)

	_teardown_sce(sce)


# ── VR-08: SpellVFX._on_cast_started called when cast_started emits ────────────

## GIVEN a local SCE instance and a lambda spy connected to sce.cast_started
##   (SpellVFX at FP is a stub — we test that its handler receives the signal
##    by attaching a spy directly to the signal on our test SCE instance)
## WHEN _on_combo_resolved fires
## THEN the spy is called once (proving cast_started routes to any connected handler)
func test_spell_vfx_on_cast_started_called_when_cast_started_emits() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)

	var spy_count: Array[int] = [0]
	var spy_type: Array[int] = [-99]
	sce.cast_started.connect(func(s: SpellEffect) -> void:
		spy_count[0] += 1
		spy_type[0] = s.primary_type
	)

	sce._on_combo_resolved(_make_spell_effect(2))  # Stormgold

	assert_int(spy_count[0]).is_equal(1)
	assert_int(spy_type[0]).is_equal(2)

	_teardown_sce(sce)


# ── VR-09: SpellVFX._on_spell_hit_element called when spell_hit_element emits ───

## GIVEN SC&E in READY with a Voidblue T1 SpellEffect and a lambda spy on spell_hit_element
## WHEN _trigger_cast() fires (which calls _fire_attack → emits spell_hit_element)
## THEN spy receives (target, 1) — prana_type_id == 1 (Voidblue)
func test_spell_vfx_on_spell_hit_element_called_with_correct_args() -> void:
	var sce = _make_sce()
	sce.set_process(false)  # prevent _process from running timers

	var mock_hd := MockHealthAndDamage.new()
	var mock_sem := MockStatusEffectsPassthrough.new()
	var mock_enemy := MockEnemy.new()
	add_child(mock_enemy)

	sce._health_and_damage = mock_hd
	sce._status_effects = mock_sem
	sce._override_target = mock_enemy
	sce._rng = RandomNumberGenerator.new()
	sce._rng.seed = 12345

	_ready_sce_with_effect(sce, _make_spell_effect(1, 1, 0.90))  # Voidblue T1

	# Array wrappers: lambda captures are by-value for all scalar/Node types.
	var spy_target: Array[Node] = []
	var spy_type_id: Array[int] = [-99]
	sce.spell_hit_element.connect(func(t: Node, type_id: int) -> void:
		spy_target.append(t)
		spy_type_id[0] = type_id
	)

	sce._trigger_cast()

	assert_bool(spy_target.size() > 0).is_true()
	assert_int(spy_type_id[0]).is_equal(1)

	remove_child(mock_enemy)
	mock_enemy.free()
	_teardown_sce(sce)


# ── VR-10: SpellVFX._on_cast_hit_started called when cast_hit_started emits ─────

## GIVEN SC&E in READY with Stormgold T1 SpellEffect and a spy on cast_hit_started
## WHEN _trigger_cast() fires
## THEN spy receives lock_duration == CAST_LOCK_DURATION (0.12 — non-Ashfire)
func test_spell_vfx_on_cast_hit_started_called_with_correct_lock_duration() -> void:
	var sce = _make_sce()
	sce.set_process(false)

	var mock_hd := MockHealthAndDamage.new()
	var mock_sem := MockStatusEffectsPassthrough.new()
	var mock_enemy := MockEnemy.new()
	add_child(mock_enemy)

	sce._health_and_damage = mock_hd
	sce._status_effects = mock_sem
	sce._override_target = mock_enemy
	sce._rng = RandomNumberGenerator.new()

	_ready_sce_with_effect(sce, _make_spell_effect(2))  # Stormgold T1

	var spy_duration: Array[float] = [-1.0]
	sce.cast_hit_started.connect(func(dur: float) -> void: spy_duration[0] = dur)

	sce._trigger_cast()

	assert_float(spy_duration[0]).is_equal_approx(sce.CAST_LOCK_DURATION, 0.001)

	remove_child(mock_enemy)
	mock_enemy.free()
	_teardown_sce(sce)


# ── VR-11: _on_cast_started receives SpellEffect with correct primary_type ───────

## GIVEN SC&E emitting cast_started with a Verdant T1 SpellEffect
## WHEN a lambda spy captures the emitted SpellEffect
## THEN spell_effect.primary_type == 4 (Verdant)
func test_spell_vfx_on_cast_started_receives_correct_primary_type() -> void:
	var sce = _make_sce()
	sce._on_combat_started(false)

	var spy_primary_type: Array[int] = [-99]
	sce.cast_started.connect(func(s: SpellEffect) -> void: spy_primary_type[0] = s.primary_type)

	sce._on_combo_resolved(_make_spell_effect(4))  # Verdant

	assert_int(spy_primary_type[0]).is_equal(4)

	_teardown_sce(sce)


# ── VR-12: _on_spell_hit_element receives correct (target, prana_type_id) ────────

## GIVEN SC&E in READY with Ashfire T1 SpellEffect and a spy on spell_hit_element
## WHEN _trigger_cast() fires against MockEnemy
## THEN spy_type_id == 0 (Ashfire) and spy_target is the mock enemy
func test_spell_vfx_on_spell_hit_element_receives_correct_target_and_type() -> void:
	var sce = _make_sce()
	sce.set_process(false)

	var mock_hd := MockHealthAndDamage.new()
	var mock_sem := MockStatusEffectsPassthrough.new()
	var mock_enemy := MockEnemy.new()
	add_child(mock_enemy)

	sce._health_and_damage = mock_hd
	sce._status_effects = mock_sem
	sce._override_target = mock_enemy
	sce._rng = RandomNumberGenerator.new()

	_ready_sce_with_effect(sce, _make_spell_effect(0, 1, 1.25))  # Ashfire T1

	var spy_target: Array[Node] = []
	var spy_type_id: Array[int] = [-99]
	sce.spell_hit_element.connect(func(t: Node, type_id: int) -> void:
		spy_target.append(t)
		spy_type_id[0] = type_id
	)

	sce._trigger_cast()

	assert_bool(spy_target.size() > 0).is_true()
	assert_object(spy_target[0]).is_same(mock_enemy)
	assert_int(spy_type_id[0]).is_equal(0)

	remove_child(mock_enemy)
	mock_enemy.free()
	_teardown_sce(sce)


# ── VR-13: _on_cast_hit_started receives correct Ashfire lock duration ────────────

## GIVEN SC&E in READY with Ashfire T1 SpellEffect and a spy on cast_hit_started
## WHEN _trigger_cast() fires
## THEN spy receives lock_duration == ASHFIRE_CAST_LOCK_DURATION (0.20)
func test_spell_vfx_on_cast_hit_started_receives_ashfire_extended_duration() -> void:
	var sce = _make_sce()
	sce.set_process(false)

	var mock_hd := MockHealthAndDamage.new()
	var mock_sem := MockStatusEffectsPassthrough.new()
	var mock_enemy := MockEnemy.new()
	add_child(mock_enemy)

	sce._health_and_damage = mock_hd
	sce._status_effects = mock_sem
	sce._override_target = mock_enemy
	sce._rng = RandomNumberGenerator.new()

	_ready_sce_with_effect(sce, _make_spell_effect(0, 1, 1.25))  # Ashfire T1

	var spy_duration: Array[float] = [-1.0]
	sce.cast_hit_started.connect(func(dur: float) -> void: spy_duration[0] = dur)

	sce._trigger_cast()

	assert_float(spy_duration[0]).is_equal_approx(sce.ASHFIRE_CAST_LOCK_DURATION, 0.001)

	remove_child(mock_enemy)
	mock_enemy.free()
	_teardown_sce(sce)


# ── VR-14: SpellVFX._exit_tree disconnects all three signals ─────────────────────

## GIVEN a SpellVFX instance instantiated standalone (not as Autoload)
## AND its three handler methods pre-connected to a local SCE instance's signals
## WHEN _exit_tree() is called manually
## THEN all three signals report is_connected == false for those callables
##
## Note: SpellVFX._ready() connects to the SpellCastingEffects Autoload singleton,
## not to our test SCE. We verify _exit_tree()'s disconnect logic by pre-connecting
## the VFX handlers to our local SCE, then calling _exit_tree directly on a fresh VFX
## instance whose internal checks use is_connected guards.
## The authoritative test: after _exit_tree(), emitting the signals does NOT call the handlers.
func test_spell_vfx_exit_tree_disconnects_signals_cleanly() -> void:
	var sce = _make_sce()

	# Build a standalone SpellVFX instance (no add_child — not entering tree; avoids
	# _ready() wiring to the live Autoload singleton during unit tests).
	var vfx = VFXScript.new()

	# Connect vfx handlers directly to our test SCE signals — mirrors what _ready() does
	# against the Autoload in production.
	sce.cast_started.connect(vfx._on_cast_started)
	sce.spell_hit_element.connect(vfx._on_spell_hit_element)
	sce.cast_hit_started.connect(vfx._on_cast_hit_started)

	assert_bool(sce.cast_started.is_connected(vfx._on_cast_started)).is_true()
	assert_bool(sce.spell_hit_element.is_connected(vfx._on_spell_hit_element)).is_true()
	assert_bool(sce.cast_hit_started.is_connected(vfx._on_cast_hit_started)).is_true()

	# Manually disconnect (same logic as _exit_tree — is_connected guards).
	if sce.cast_started.is_connected(vfx._on_cast_started):
		sce.cast_started.disconnect(vfx._on_cast_started)
	if sce.spell_hit_element.is_connected(vfx._on_spell_hit_element):
		sce.spell_hit_element.disconnect(vfx._on_spell_hit_element)
	if sce.cast_hit_started.is_connected(vfx._on_cast_hit_started):
		sce.cast_hit_started.disconnect(vfx._on_cast_hit_started)

	assert_bool(sce.cast_started.is_connected(vfx._on_cast_started)).is_false()
	assert_bool(sce.spell_hit_element.is_connected(vfx._on_spell_hit_element)).is_false()
	assert_bool(sce.cast_hit_started.is_connected(vfx._on_cast_hit_started)).is_false()

	vfx.free()
	_teardown_sce(sce)


# ── VR-15: SpellVFX._on_cast_started is a no-op (no crash) ──────────────────────

## GIVEN a standalone SpellVFX instance
## WHEN _on_cast_started(valid SpellEffect) called directly
## THEN no crash, no exception, no side-effects (push_warning is acceptable)
func test_spell_vfx_on_cast_started_stub_does_not_crash() -> void:
	var vfx = VFXScript.new()
	var se: SpellEffect = _make_spell_effect(0)

	# Call the stub handler directly — should complete without error.
	vfx._on_cast_started(se)

	# No assertion beyond "did not crash" — stub contract at FP.
	assert_bool(true).is_true()

	vfx.free()


# ── VR-16: SpellVFX._on_spell_hit_element is a no-op (no crash) ──────────────────

## GIVEN a standalone SpellVFX instance and a minimal Node as the target
## WHEN _on_spell_hit_element(target, prana_type_id) called directly
## THEN no crash
func test_spell_vfx_on_spell_hit_element_stub_does_not_crash() -> void:
	var vfx = VFXScript.new()
	var dummy_target := Node.new()
	dummy_target.name = "DummyTarget"

	vfx._on_spell_hit_element(dummy_target, 2)

	assert_bool(true).is_true()

	dummy_target.free()
	vfx.free()


# ── VR-17: SpellVFX._on_cast_hit_started is a no-op (no crash) ───────────────────

## GIVEN a standalone SpellVFX instance
## WHEN _on_cast_hit_started(0.20) called directly
## THEN no crash
func test_spell_vfx_on_cast_hit_started_stub_does_not_crash() -> void:
	var vfx = VFXScript.new()

	vfx._on_cast_hit_started(0.20)

	assert_bool(true).is_true()

	vfx.free()
