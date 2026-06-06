## spell_casting_integration_test.gd — Integration tests for SC&E full FP cast flow.
##
## Coverage:
##   AC-WES-INT-01: Full cast flow — apply_damage fires; cast_hit_started emitted once with 0.20 lock
##   AC-WES-INT-02: Elemental affiliation 2× end-to-end — Ashfire vs FIRE enemy → 50.0 damage
##   AC-WES-INT-03: preparation_started resets SC&E — _state=IDLE, _current_spell_effect=null, _combo_index=0
##
## Setup pattern:
##   - SC&E added to tree via add_child(): triggers _ready(), connects to real Autoloads
##   - set_process(false) after add_child(): prevents auto-ticking; test controls timing manually
##   - Mocks injected via _health_and_damage / _status_effects / _override_target seams (after _ready)
##   - CombinationResolution emits combo_resolved automatically on combat_started; _on_combo_resolved
##     called again directly to ensure the test-controlled SpellEffect is cached
##   - Teardown: remove_child() then free() — not queue_free() (headless GdUnit4, exit 101 guard)
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SCEScript = preload("res://src/systems/spell_casting_effects.gd")


# ── Mock classes ──────────────────────────────────────────────────────────────

## Records apply_damage calls: call_count and last raw_damage delivered.
class MockHD:
	var call_count: int = 0
	var last_raw_damage: float = 0.0

	func apply_damage(_target: Node, raw_damage: float, _element: GameEnums.DamageClass, _source: GameEnums.DamageSource) -> void:
		call_count += 1
		last_raw_damage = raw_damage

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


## Pass-through SEM: shatter returns raw unchanged; has_status always false.
class MockSEM:
	func check_and_apply_shatter(_target: Node, raw: float) -> float:
		return raw

	func has_status(_target: Node, _status: GameEnums.BaseStatus) -> bool:
		return false


## Minimal enemy node exposing prana_affiliation and FP status stub fields.
class MockEnemy extends Node:
	var prana_affiliation: GameEnums.DamageClass = GameEnums.DamageClass.NONE
	var status_burned: bool = false
	var status_blinded_timer: float = 0.0
	var status_stun_timer: float = 0.0
	var status_freeze_timer: float = 0.0

	func is_alive() -> bool:
		return true

	func apply_speed_modifier(_m: float) -> void:
		pass

	func apply_stun(_d: float) -> void:
		pass


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_sce() -> Node:
	var sce: Node = SCEScript.new()
	add_child(sce)
	sce.set_process(false)
	return sce


func _teardown_sce(sce: Node) -> void:
	remove_child(sce)
	sce.free()


## Ashfire T1 SpellEffect: type=0 (FIRE), tier=1, base_damage_modifier=1.25, combo_count=1.
## Expected damage vs affine target: BASE(20) × mod(1.25) × tier_mod(1.00) × affinity(2.0) = 50.0
func _make_ashfire_t1() -> SpellEffect:
	var se: SpellEffect = SpellEffect.new()
	se.primary_type = 0  # GameEnums.DamageClass.FIRE
	se.primary_tier = 1
	se.base_damage_modifier = 1.25
	se.combo_attack_count = 1
	se.aggregate_stat_bonus = {}
	return se


## Emits the full phase signal sequence and caches the given SpellEffect in SC&E.
## CombinationResolution also fires combo_resolved on combat_started (Autoload stub);
## calling _on_combo_resolved directly afterwards ensures the test-controlled effect is active.
func _run_phase_sequence(sce: Node, spell_effect: SpellEffect) -> void:
	GameStateManager.preparation_started.emit(0, 1)
	GameStateManager.combat_started.emit(false)
	sce._on_combo_resolved(spell_effect)


# ── AC-WES-INT-01: Full cast flow ────────────────────────────────────────────

## GIVEN SC&E connected to real Autoloads; MockHD, MockSEM, MockEnemy(FIRE) injected
## WHEN preparation_started → combat_started → _on_combo_resolved(Ashfire T1) → _trigger_cast()
## THEN MockHD.call_count == 1; cast_hit_started emitted once with lock_duration == 0.20
func test_full_cast_flow_apply_damage_and_cast_hit_started_fire() -> void:
	var sce: Node = _make_sce()
	var mock_hd := MockHD.new()
	var mock_sem := MockSEM.new()
	var mock_enemy := MockEnemy.new()
	mock_enemy.prana_affiliation = GameEnums.DamageClass.FIRE

	sce._health_and_damage = mock_hd
	sce._status_effects = mock_sem
	sce._override_target = mock_enemy

	var hit_count: Array[int] = [0]
	var hit_lock: Array[float] = [0.0]
	sce.cast_hit_started.connect(func(lock_dur: float) -> void:
		hit_count[0] += 1
		hit_lock[0] = lock_dur
	)

	_run_phase_sequence(sce, _make_ashfire_t1())
	sce._trigger_cast()

	assert_int(mock_hd.call_count).is_equal(1)
	assert_int(hit_count[0]).is_equal(1)
	assert_float(hit_lock[0]).is_equal_approx(0.20, 0.001)

	mock_enemy.free()  # Node — must free manually; MockHD/MockSEM are RefCounted (auto-freed)
	_teardown_sce(sce)


# ── AC-WES-INT-02: Elemental affiliation 2× end-to-end ───────────────────────

## GIVEN MockEnemy(FIRE); Ashfire T1 SpellEffect (base_damage_modifier=1.25)
## WHEN full phase sequence → _trigger_cast()
## THEN apply_damage called once; raw_damage ≈ 50.0 (BASE=20 × 1.25 × 1.00 × 2.0); tolerance ±0.01
func test_elemental_affiliation_doubles_damage_ashfire_vs_fire_enemy() -> void:
	var sce: Node = _make_sce()
	var mock_hd := MockHD.new()
	var mock_sem := MockSEM.new()
	var mock_enemy := MockEnemy.new()
	mock_enemy.prana_affiliation = GameEnums.DamageClass.FIRE

	sce._health_and_damage = mock_hd
	sce._status_effects = mock_sem
	sce._override_target = mock_enemy

	_run_phase_sequence(sce, _make_ashfire_t1())
	sce._trigger_cast()

	assert_int(mock_hd.call_count).is_equal(1)
	assert_float(mock_hd.last_raw_damage).is_equal_approx(50.0, 0.01)

	mock_enemy.free()
	_teardown_sce(sce)


# ── AC-WES-INT-03: preparation_started resets SC&E ───────────────────────────

## GIVEN SC&E in CAST_LOCKED state (_combo_index=1, SpellEffect cached) after a completed cast
## WHEN GameStateManager.preparation_started emits
## THEN _state == IDLE; _current_spell_effect == null; _combo_index == 0
func test_preparation_started_resets_sce_state_after_completed_cast() -> void:
	var sce: Node = _make_sce()
	var mock_hd := MockHD.new()
	var mock_sem := MockSEM.new()
	var mock_enemy := MockEnemy.new()
	mock_enemy.prana_affiliation = GameEnums.DamageClass.FIRE

	sce._health_and_damage = mock_hd
	sce._status_effects = mock_sem
	sce._override_target = mock_enemy

	# Execute full cast sequence to reach CAST_LOCKED state
	_run_phase_sequence(sce, _make_ashfire_t1())
	sce._trigger_cast()

	assert_int(sce._state).is_equal(sce.SCEState.CAST_LOCKED)
	assert_int(sce._combo_index).is_equal(1)
	assert_bool(sce._current_spell_effect != null).is_true()

	# Wave reset — SC&E should return to IDLE
	GameStateManager.preparation_started.emit(0, 1)

	assert_int(sce._state).is_equal(sce.SCEState.IDLE)
	assert_bool(sce._current_spell_effect == null).is_true()
	assert_int(sce._combo_index).is_equal(0)

	mock_enemy.free()
	_teardown_sce(sce)
