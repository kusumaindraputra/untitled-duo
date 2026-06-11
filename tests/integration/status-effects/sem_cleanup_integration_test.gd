## sem_cleanup_integration_test.gd — Integration tests for StatusEffectsManager
## kill-cleanup and wave-clear paths (Story 004).
##
## Coverage:
##   AC-SE-11: enemy_killed removes all statuses for that enemy; no status_expired emitted
##   AC-SE-12: enemy_killed restores speed modifier to 1.0 when FREEZE was active
##   AC-SE-13: enemy_killed with CHILL active restores speed to 1.0
##   AC-SE-14: preparation_started clears all statuses across all enemies; no status_expired emitted
##   AC-SE-15: preparation_started with no active statuses does not error
##   AC-SE-16: enemy_killed for an enemy with no active statuses does not error
##   AC-SE-17: after wave-clear, a subsequent apply_status on the same target succeeds
##
## Setup pattern mirrors the established unit-test approach:
##   - SEM added to tree (triggers _ready, mock pre-injection bypasses the null-guard)
##   - set_process(false) blocks engine auto-ticks so tests control timing entirely
##   - MockHD extends Node — Variant dispatch works via Node method table
##   - MockEnemy / MockFayde expose spy arrays for call-count assertions
##   - Signals are wired with inline lambdas; counters held in single-element typed arrays
##     so they are captured by reference inside the closure
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const SEMScript = preload("res://src/systems/status_effects_manager.gd")


# ── Mock classes ──────────────────────────────────────────────────────────────

class MockHD extends Node:
	var damage_calls: Array[float] = []

	func apply_damage(_target: Variant, damage: float, _element: Variant, _source: Variant) -> void:
		damage_calls.append(damage)

	func apply_heal(_target: Variant, _amount: float) -> void:
		pass


class MockEnemy extends Node2D:
	var _alive: bool = true
	var speed_modifier_calls: Array[float] = []
	var stun_calls: Array[float] = []

	func is_alive() -> bool:
		return _alive

	func apply_speed_modifier(multiplier: float) -> void:
		speed_modifier_calls.append(multiplier)

	func apply_stun(duration: float) -> void:
		stun_calls.append(duration)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a SEM with mock pre-injected. Added to tree so _ready fires;
## set_process(false) immediately blocks auto-ticks.
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


# ── AC-SE-11: enemy_killed removes all statuses; status_expired NOT emitted ──

func test_sem_enemy_killed_removes_all_statuses_without_expired_signal() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 50.0)
	sem.apply_status(enemy, GameEnums.BaseStatus.CHILL, 2.0, 0.0)

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, _st: GameEnums.BaseStatus) -> void:
		expired_count[0] += 1
	)

	# Act — simulate HealthAndDamage.enemy_killed signal
	var instance_id: int = enemy.get_instance_id()
	sem.call(&"_on_enemy_killed", instance_id, 0, GameEnums.DamageClass.NONE)

	# Assert — registry entry gone, no expired signal emitted
	assert_bool(sem._active_statuses.has(instance_id)).is_false()
	assert_int(expired_count[0]).is_equal(0)


# ── AC-SE-12: enemy_killed with FREEZE active restores speed to 1.0 ──────────

func test_sem_enemy_killed_with_freeze_restores_full_speed() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)
	# apply_status calls apply_speed_modifier(0.50) — clear the spy so we only track cleanup
	enemy.speed_modifier_calls.clear()

	# Act
	sem.call(&"_on_enemy_killed", enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	# Assert — cleanup path must restore speed to 1.0 exactly once
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)
	assert_float(enemy.speed_modifier_calls[0]).is_equal_approx(1.0, 0.001)


# ── AC-SE-13: enemy_killed with CHILL active restores speed to 1.0 ────────────

func test_sem_enemy_killed_with_chill_restores_full_speed() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.CHILL, 2.0, 0.0)
	enemy.speed_modifier_calls.clear()

	# Act
	sem.call(&"_on_enemy_killed", enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	# Assert
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)
	assert_float(enemy.speed_modifier_calls[0]).is_equal_approx(1.0, 0.001)


# ── AC-SE-14: preparation_started clears all enemies; no status_expired emitted ──

func test_sem_preparation_started_clears_all_enemies_without_expired_signal() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy_a := _make_enemy()
	var enemy_b := _make_enemy()

	sem.apply_status(enemy_a, GameEnums.BaseStatus.BURN, 2.0, 30.0)
	sem.apply_status(enemy_a, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)
	sem.apply_status(enemy_b, GameEnums.BaseStatus.CHILL, 2.0, 0.0)

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, _st: GameEnums.BaseStatus) -> void:
		expired_count[0] += 1
	)

	# Act
	sem.call(&"_on_preparation_started", 1, 2)

	# Assert — all registry entries gone, no expired signal
	assert_bool(sem._active_statuses.is_empty()).is_true()
	assert_int(expired_count[0]).is_equal(0)


# ── AC-SE-14 (speed restore): wave-clear restores speed for frozen/chilled enemies ──

func test_sem_preparation_started_restores_speed_for_frozen_enemy() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)
	enemy.speed_modifier_calls.clear()

	# Act
	sem.call(&"_on_preparation_started", 0, 3)

	# Assert
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)
	assert_float(enemy.speed_modifier_calls[0]).is_equal_approx(1.0, 0.001)


# ── AC-SE-15: preparation_started with empty registry does not error ──────────

func test_sem_preparation_started_with_no_active_statuses_does_not_error() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)

	# Act — must complete without error; assert registry stays empty
	sem.call(&"_on_preparation_started", 0, 1)

	assert_bool(sem._active_statuses.is_empty()).is_true()


# ── AC-SE-16: enemy_killed for enemy with no statuses does not error ──────────

func test_sem_enemy_killed_for_enemy_with_no_statuses_does_not_error() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	# Act — enemy was never registered; must complete silently
	sem.call(&"_on_enemy_killed", enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_bool(sem._active_statuses.is_empty()).is_true()


# ── AC-SE-17: apply_status succeeds on same target after wave-clear ───────────

func test_sem_apply_status_succeeds_on_same_target_after_wave_clear() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 40.0)
	sem.call(&"_on_preparation_started", 0, 1)
	assert_bool(sem._active_statuses.is_empty()).is_true()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t: Node, _st: GameEnums.BaseStatus, _d: float) -> void:
		applied_count[0] += 1
	)

	# Act — re-apply after clear
	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 40.0)

	# Assert — new instance created, signal fired
	var target_id: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(target_id)).is_true()
	assert_int(sem._active_statuses[target_id].size()).is_equal(1)
	assert_int(applied_count[0]).is_equal(1)


# ── AC-SE-12: BURN + FREEZE combo — kill removes both, restores speed, no signal ──

func test_sem_enemy_killed_with_burn_and_freeze_removes_both_and_restores_speed() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 50.0)
	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)
	# Clear spy so we only count cleanup calls, not the apply_status speed call
	enemy.speed_modifier_calls.clear()

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, _st: GameEnums.BaseStatus) -> void:
		expired_count[0] += 1
	)

	# Act
	sem.call(&"_on_enemy_killed", enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	# Assert — registry gone, speed restored exactly once to 1.0, no expired signal
	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()
	assert_int(expired_count[0]).is_equal(0)
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)
	assert_float(enemy.speed_modifier_calls[0]).is_equal_approx(1.0, 0.001)


# ── AC-SE-12: no tick fires for enemy after kill cleanup ─────────────────────

func test_sem_enemy_killed_stops_burn_ticks() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 50.0)

	# Act — kill cleanup, then clear the damage spy and drive _process past tick interval
	sem.call(&"_on_enemy_killed", enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)
	mock.damage_calls.clear()
	sem.call(&"_process", 1.0)  # 1.0s > BURN_TICK_INTERVAL (0.5s) — would tick if active

	# Assert — no damage calls after cleanup
	assert_int(mock.damage_calls.size()).is_equal(0)


# ── AC-SE-19: no tick fires for enemies after wave-clear ─────────────────────

func test_sem_preparation_started_stops_burn_ticks() -> void:
	# Arrange
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 50.0)

	# Act — wave clear, then clear the damage spy and drive _process past tick interval
	sem.call(&"_on_preparation_started", 0, 1)
	mock.damage_calls.clear()
	sem.call(&"_process", 1.0)  # 1.0s > BURN_TICK_INTERVAL (0.5s) — would tick if active

	# Assert — no damage calls after wave-clear
	assert_int(mock.damage_calls.size()).is_equal(0)
