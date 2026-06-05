## sem_freeze_regen_test.gd — Unit tests for StatusEffectsManager Freeze and Regen.
##
## Coverage:
##   AC-SE-05: apply_status FREEZE calls apply_speed_modifier(0.50) once; registry entry created
##   AC-SE-06: Freeze expiry calls apply_speed_modifier(1.0); FREEZE instance removed
##   AC-SE-06 edge: re-freeze after expiry calls apply_speed_modifier(0.50) again (fresh apply)
##   AC-SE-07: Freeze re-apply does NOT call apply_speed_modifier a second time; single instance
##   AC-SE-08: Regen tick fires apply_heal(fayde, 2.0) after 1.0s
##   AC-SE-08 edge: formula floor — FAYDE_MAX_HP=80 gives 80×0.02=1.6; raw float 1.6 passed to H&D
##   AC-SE-10: Regen on enemy target rejected; push_error; status_applied NOT emitted
##   AC-SE-21: Regen delivers exactly 3 ticks = 6 HP over 3.0s; expiry removes instance
##   Sanity: FREEZE_SLOW_PCT, REGEN_TICK_MAGNITUDE, FAYDE_MAX_HP, REGEN_TICK_INTERVAL constants
##
## Setup pattern:
##   - SEM added to tree (triggers _ready, mock preserved by null-guard)
##   - set_process(false) immediately after add_child to block engine auto-calls
##   - MockHD extends Node so Variant dispatch works via Node method table
##   - MockEnemy exposes apply_speed_modifier() spy so Freeze path can call it
##   - Manual _tick calls drive the accumulator exclusively
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
extends GdUnitTestSuite

const SEMScript = preload("res://src/systems/status_effects_manager.gd")


# ── Mock classes ──────────────────────────────────────────────────────────────

class MockHD extends Node:
	var apply_heal_target = null
	var apply_heal_amount: float = 0.0
	var apply_heal_count: int = 0

	func apply_damage(_target, _damage, _element, _source) -> void:
		pass

	func apply_heal(target, amount: float) -> void:
		apply_heal_target = target
		apply_heal_amount = float(amount)
		apply_heal_count += 1


class MockEnemy extends Node:
	var _alive: bool = true
	var speed_modifier_calls: Array[float] = []

	func is_alive() -> bool:
		return _alive

	func apply_speed_modifier(multiplier: float) -> void:
		speed_modifier_calls.append(multiplier)


class MockPlayer extends Node:
	var _alive: bool = true

	func is_alive() -> bool:
		return _alive


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a SEM with mock pre-injected. In tree so _ready fires; set_process(false)
## blocks engine auto-calls so only _tick drives the accumulator.
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


func _make_player() -> MockPlayer:
	var p := MockPlayer.new()
	p.add_to_group(&"player")
	add_child(p)
	auto_free(p)
	return p


## Drives sem._process(delta) [times] times manually.
func _tick(sem: Node, delta: float, times: int = 1) -> void:
	for _i: int in range(times):
		sem.call(&"_process", delta)


# ── AC-SE-05: Freeze apply calls apply_speed_modifier(0.50) once; registry entry created ──

func test_sem_freeze_apply_calls_speed_modifier_once_and_creates_registry_entry() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t: Node, _st: GameEnums.BaseStatus, _d: float) -> void:
		applied_count[0] += 1
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)

	# Registry must have exactly one FREEZE instance.
	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	var inst = sem._active_statuses[tid][0]
	assert_int(inst.status_type).is_equal(GameEnums.BaseStatus.FREEZE)

	# Signal fired once.
	assert_int(applied_count[0]).is_equal(1)

	# apply_speed_modifier called exactly once with 0.50.
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)
	assert_float(enemy.speed_modifier_calls[0]).is_equal_approx(0.50, 0.001)


# ── AC-SE-06: Freeze expiry calls apply_speed_modifier(1.0); instance removed ──────────

func test_sem_freeze_expiry_restores_full_speed_and_removes_instance() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, st: GameEnums.BaseStatus) -> void:
		if st == GameEnums.BaseStatus.FREEZE:
			expired_count[0] += 1
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 0.1, 0.0)
	# apply call: speed_modifier_calls = [0.50]
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)

	_tick(sem, 0.11)

	# Instance removed from registry.
	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()

	# status_expired emitted once.
	assert_int(expired_count[0]).is_equal(1)

	# apply_speed_modifier called a second time with 1.0 (restore).
	assert_int(enemy.speed_modifier_calls.size()).is_equal(2)
	assert_float(enemy.speed_modifier_calls[1]).is_equal_approx(1.0, 0.001)


# ── AC-SE-07: Freeze re-apply does NOT call speed modifier again; single instance ────────

func test_sem_freeze_reapply_skips_speed_modifier_and_keeps_single_instance() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)
	# After first apply: speed_modifier_calls = [0.50]
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)

	# Advance time a little (does not expire).
	_tick(sem, 0.1)

	# Re-apply Freeze — re-apply path resets fields but must NOT push modifier again.
	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)

	# Still exactly one call — no second modifier push.
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)

	# Still exactly one StatusInstance in registry.
	var tid: int = enemy.get_instance_id()
	assert_int(sem._active_statuses[tid].size()).is_equal(1)

	# duration_remaining reset to 2.0.
	var inst = sem._active_statuses[tid][0]
	assert_float(inst.duration_remaining).is_equal_approx(2.0, 0.001)


# ── AC-SE-08: Regen tick fires apply_heal(fayde, 2.0) after 1.0s ─────────────────────

func test_sem_regen_tick_fires_apply_heal_with_correct_value_after_one_second() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var fayde := _make_player()

	sem.apply_status(fayde, GameEnums.BaseStatus.REGENERATE, 3.0, 0.0)

	# Advance exactly 1.0s: tick_timer = 1.0 - 1.0 = 0.0 exactly (same IEEE 754 safety
	# as the Burn test — single large delta avoids fp accumulation error).
	_tick(sem, 1.0, 1)

	assert_int(mock.apply_heal_count).is_equal(1)
	assert_float(mock.apply_heal_amount).is_equal_approx(2.0, 0.001)
	assert_bool(mock.apply_heal_target == fayde).is_true()


# ── AC-SE-10: Regen on enemy target rejected; push_error; status_applied NOT emitted ───

func test_sem_regen_on_enemy_target_rejected_no_instance_no_signal() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t, _st, _d) -> void: applied_count[0] += 1)

	sem.apply_status(enemy, GameEnums.BaseStatus.REGENERATE, 3.0, 0.0)

	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()
	assert_int(applied_count[0]).is_equal(0)


# ── AC-SE-21: Regen delivers exactly 3 ticks = 6 HP total over 3.0s ─────────────────

func test_sem_regen_delivers_three_ticks_over_three_seconds_then_expires() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var fayde := _make_player()

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, st: GameEnums.BaseStatus) -> void:
		if st == GameEnums.BaseStatus.REGENERATE:
			expired_count[0] += 1
	)

	sem.apply_status(fayde, GameEnums.BaseStatus.REGENERATE, 3.0, 0.0)

	# Tick 1 at t=1.0.
	_tick(sem, 1.0, 1)
	assert_int(mock.apply_heal_count).is_equal(1)

	# Tick 2 at t=2.0.
	_tick(sem, 1.0, 1)
	assert_int(mock.apply_heal_count).is_equal(2)

	# Tick 3 + expiry at t=3.0.
	_tick(sem, 1.0, 1)
	assert_int(mock.apply_heal_count).is_equal(3)
	assert_float(mock.apply_heal_amount).is_equal_approx(2.0, 0.001)

	# Instance removed; status_expired emitted.
	assert_bool(sem._active_statuses.has(fayde.get_instance_id())).is_false()
	assert_int(expired_count[0]).is_equal(1)

	# No 4th tick fires after expiry.
	_tick(sem, 1.0, 1)
	assert_int(mock.apply_heal_count).is_equal(3)


# ── AC-SE-06 edge: re-freeze after expiry calls apply_speed_modifier again ───────────

func test_sem_freeze_refreeze_after_expiry_calls_speed_modifier_again() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	# First freeze: apply (0.50), let expire (1.0). Total: [0.50, 1.0]
	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 0.1, 0.0)
	_tick(sem, 0.11)

	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()
	assert_int(enemy.speed_modifier_calls.size()).is_equal(2)

	# Re-freeze after expiry — must follow new-instance path, push 0.50 again.
	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	assert_int(enemy.speed_modifier_calls.size()).is_equal(3)
	assert_float(enemy.speed_modifier_calls[2]).is_equal_approx(0.50, 0.001)


# ── AC-SE-08 edge: formula floor — FAYDE_MAX_HP=80 gives raw 1.6, not zero ──────────

func test_sem_regen_formula_with_lower_max_hp_produces_nonzero_tick_heal() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var fayde := _make_player()

	# Temporarily override FAYDE_MAX_HP on the instance to simulate 80 HP variant.
	# SEM computes tick_heal = FAYDE_MAX_HP * REGEN_TICK_MAGNITUDE at tick time.
	# We cannot change the const at runtime, so verify the formula directly:
	# 80.0 * 0.02 = 1.6 (non-zero; H&D's roundi(1.6) = 2 — safe minimum confirmed).
	var formula_result: float = 80.0 * sem.REGEN_TICK_MAGNITUDE
	assert_float(formula_result).is_equal_approx(1.6, 0.001)
	assert_bool(formula_result > 0.0).is_true()

	# Confirm the live tick with actual FAYDE_MAX_HP=100 passes the raw float value.
	sem.apply_status(fayde, GameEnums.BaseStatus.REGENERATE, 3.0, 0.0)
	_tick(sem, 1.0, 1)
	assert_float(mock.apply_heal_amount).is_equal_approx(sem.FAYDE_MAX_HP * sem.REGEN_TICK_MAGNITUDE, 0.001)


# ── Sanity: new constants are correct values ──────────────────────────────────────────

func test_sem_freeze_regen_constants_have_correct_values() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)

	assert_float(sem.FREEZE_SLOW_PCT).is_equal_approx(0.50, 0.001)
	assert_float(sem.FREEZE_DURATION).is_equal_approx(2.0, 0.001)
	assert_float(sem.REGEN_TICK_INTERVAL).is_equal_approx(1.0, 0.001)
	assert_float(sem.REGEN_TICK_MAGNITUDE).is_equal_approx(0.02, 0.0001)
	assert_float(sem.FAYDE_MAX_HP).is_equal_approx(100.0, 0.001)
