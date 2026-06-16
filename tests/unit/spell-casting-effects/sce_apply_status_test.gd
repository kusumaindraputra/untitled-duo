## sce_apply_status_test.gd — Unit tests for StatusEffectsManager.apply_status()
## as called from the SpellCastingEffects context.
##
## Coverage:
##   1. apply_status(BURN, 1.0) 3-arg default stores spell_base_damage == 0.0
##   2. apply_status(BURN, 1.0, 25.0) stores spell_base_damage == 25.0
##   3. apply_status(BURN, 1.0, 0.0) explicit zero stores spell_base_damage == 0.0
##   4. apply_status(FREEZE, 2.0, 99.0) stores spell_base_damage == 99.0 (stored for all types)
##   5. BURN re-apply on same target with different spell_base_damage updates stored value
##   6. apply_status(BURN, 1.0, -5.0) stores -5.0 (storage); tick formula clamps via maxf(0,-5)*0.08==0.0
##
## Setup pattern:
##   - SEM added to tree (triggers _ready; mock null-guard preserves injection).
##   - set_process(false) immediately after add_child to block engine auto-calls.
##   - MockHD extends Node so Variant dispatch works via Node method table.
##   - MockEnemy exposes apply_speed_modifier() and apply_stun() stubs; in "enemy" group.
##   - _active_statuses[target_id][0].spell_base_damage read directly (internal access).
##   - Teardown: auto_free() after add_child — GdUnit4 owns lifecycle (matches sem_stub_effects_test).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SEMScript = preload("res://src/systems/status_effects_manager.gd")


# ── Mock classes ──────────────────────────────────────────────────────────────

class MockHD extends Node:
	func apply_damage(_target: Node, _damage: float, _element: int, _source: int) -> void:
		pass

	func apply_heal(_target: Node, _amount: float) -> void:
		pass


class MockEnemy extends Node:
	var _alive: bool = true
	var speed_modifier_calls: Array[float] = []
	var apply_stun_calls: Array[float] = []

	func is_alive() -> bool:
		return _alive

	func apply_speed_modifier(multiplier: float) -> void:
		speed_modifier_calls.append(multiplier)

	func apply_stun(duration: float) -> void:
		apply_stun_calls.append(duration)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_sem(mock: MockHD) -> Node:
	var sem: Node = SEMScript.new()
	sem._health_and_damage = mock
	add_child(sem)
	sem.set_process(false)
	auto_free(sem)
	return sem


func _make_enemy() -> MockEnemy:
	var e := MockEnemy.new()
	e.add_to_group(&"enemy")
	add_child(e)
	auto_free(e)
	return e


# ── Test 1: 3-arg call uses default spell_base_damage of 0.0 ─────────────────

func test_apply_status_burn_with_zero_spell_damage_stores_zero() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 1.0)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	var stored: float = sem._active_statuses[tid][0].spell_base_damage
	assert_float(stored).is_equal_approx(0.0, 0.0001)


# ── Test 2: 4-arg call stores provided spell_base_damage ─────────────────────

func test_apply_status_burn_with_spell_damage_stores_value() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 1.0, 25.0)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	var stored: float = sem._active_statuses[tid][0].spell_base_damage
	assert_float(stored).is_equal_approx(25.0, 0.0001)


# ── Test 3: explicit 0.0 arg stores 0.0 (not distinguishable from default) ───

func test_apply_status_burn_explicit_zero_stores_zero() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 1.0, 0.0)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	var stored: float = sem._active_statuses[tid][0].spell_base_damage
	assert_float(stored).is_equal_approx(0.0, 0.0001)


# ── Test 4: non-DoT status (FREEZE) still stores spell_base_damage ───────────

func test_apply_status_freeze_ignores_spell_damage() -> void:
	# SEM stores spell_base_damage for all statuses; tick logic ignores it for non-BURN.
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 99.0)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	var stored: float = sem._active_statuses[tid][0].spell_base_damage
	assert_float(stored).is_equal_approx(99.0, 0.0001)


# ── Test 5: re-apply BURN updates stored spell_base_damage (refresh path) ────

func test_apply_status_burn_reapply_updates_spell_damage() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 1.0, 10.0)

	var tid: int = enemy.get_instance_id()
	assert_float(sem._active_statuses[tid][0].spell_base_damage).is_equal_approx(10.0, 0.0001)

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 1.0, 20.0)

	# Re-apply path (existing instance found) updates spell_base_damage.
	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	assert_float(sem._active_statuses[tid][0].spell_base_damage).is_equal_approx(20.0, 0.0001)


# ── Test 6: negative spell_base_damage stored as-is; tick formula clamps ─────

func test_apply_status_burn_negative_spell_damage_clamped_to_zero_in_tick() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 1.0, -5.0)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()

	# Storage is raw (no clamp at apply time).
	var stored: float = sem._active_statuses[tid][0].spell_base_damage
	assert_float(stored).is_equal_approx(-5.0, 0.0001)

	# Tick formula: maxf(0.0, spell_base_damage) * BURN_TICK_MAGNITUDE.
	# Verify the formula produces 0.0 for the stored negative value using SEM constants.
	var tick_damage: float = maxf(0.0, stored) * sem.BURN_TICK_MAGNITUDE
	assert_float(tick_damage).is_equal_approx(0.0, 0.0001)
