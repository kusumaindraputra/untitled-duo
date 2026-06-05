## sem_skeleton_burn_test.gd — Unit tests for StatusEffectsManager skeleton + Burn DoT.
##
## Coverage:
##   AC-SE-01: apply_status BURN creates StatusInstance and emits status_applied
##   AC-SE-02: Burn tick fires correct raw damage value (1.6) after 0.5s of _process
##   AC-SE-02 edge: zero spell_base_damage → apply_damage(0.0); no negative DoT
##   AC-SE-02 edge: negative spell_base_damage clamped to 0.0 by maxf guard
##   AC-SE-03: Burn expiry removes instance and emits status_expired; no further ticks
##   AC-SE-03 edge: tick fires before expiry when both occur in the same _process call
##   AC-SE-04: Re-apply Burn resets duration, spell_base_damage, tick_timer; exactly 1 instance
##   AC-SE-09: Player target rejected with push_error; status_applied NOT emitted
##   AC-SE-11: Dead target rejected silently; status_applied NOT emitted
##   AC-SE-20: Zero duration rejected with push_error; no StatusInstance created
##
## Setup pattern:
##   - SEM added to tree (triggers _ready, mock preserved by null-guard)
##   - set_process(false) immediately after add_child to block engine auto-calls
##   - MockHD extends Node so Variant dispatch works via Node method table
##   - MockHD also added to tree to ensure refcounts and dispatch work correctly
##   - Manual _tick calls drive the accumulator exclusively
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
extends GdUnitTestSuite

const SEMScript = preload("res://src/systems/status_effects_manager.gd")


# ── Mock classes ──────────────────────────────────────────────────────────────

class MockHD extends Node:
	var last_target = null
	var last_damage: float = 0.0
	var last_element: int = -1
	var last_source: int = -1
	var call_count: int = 0

	func apply_damage(target, damage, element, source) -> void:
		last_target = target
		last_damage = float(damage)
		last_element = int(element)
		last_source = int(source)
		call_count += 1


class MockEnemy extends Node:
	var _alive: bool = true
	func is_alive() -> bool: return _alive


class MockPlayer extends Node:
	var _alive: bool = true
	func is_alive() -> bool: return _alive


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


# ── AC-SE-01: apply_status BURN creates registry entry and emits status_applied ──

func test_sem_apply_burn_creates_registry_entry_and_emits_signal() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	var applied_type: Array[int] = [-1]
	var applied_dur: Array[float] = [0.0]
	sem.status_applied.connect(func(t: Node, st: GameEnums.BaseStatus, d: float) -> void:
		applied_count[0] += 1
		applied_type[0] = st
		applied_dur[0] = d
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	var inst = sem._active_statuses[tid][0]
	assert_float(inst.duration_remaining).is_equal_approx(2.0, 0.001)
	assert_float(inst.spell_base_damage).is_equal(20.0)
	assert_int(inst.status_type).is_equal(GameEnums.BaseStatus.BURN)
	assert_int(applied_count[0]).is_equal(1)
	assert_int(applied_type[0]).is_equal(GameEnums.BaseStatus.BURN)
	assert_float(applied_dur[0]).is_equal(2.0)


# ── AC-SE-02: Burn tick fires correct raw damage (1.6) after 0.5s ─────────────

func test_sem_burn_tick_fires_correct_damage_value_at_half_second() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)

	# delta = BURN_TICK_INTERVAL (0.5) exactly: tick_timer (0.5) - delta (0.5) = 0.0 exactly.
	# 5 × 0.1 would leave tick_timer ≈ 2.8e-17 (positive) due to IEEE 754 rounding.
	_tick(sem, 0.5, 1)

	assert_int(mock.call_count).is_equal(1)
	assert_float(mock.last_damage).is_equal_approx(1.6, 0.001)
	assert_int(mock.last_element).is_equal(GameEnums.DamageClass.NONE)
	assert_int(mock.last_source).is_equal(GameEnums.DamageSource.DOT)
	assert_bool(mock.last_target == enemy).is_true()


# ── AC-SE-03: Burn expiry removes instance and emits status_expired ────────────

func test_sem_burn_expiry_removes_instance_and_emits_expired_signal() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var expired_count: Array[int] = [0]
	var expired_type: Array[int] = [-1]
	sem.status_expired.connect(func(_t: Node, st: GameEnums.BaseStatus) -> void:
		expired_count[0] += 1
		expired_type[0] = st
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 0.1, 20.0)
	_tick(sem, 0.11)

	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_false()
	assert_int(expired_count[0]).is_equal(1)
	assert_int(expired_type[0]).is_equal(GameEnums.BaseStatus.BURN)

	var calls_before: int = mock.call_count
	_tick(sem, 0.1)
	assert_int(mock.call_count).is_equal(calls_before)


# ── AC-SE-04: Re-apply Burn resets duration, damage, tick_timer; single instance ─

func test_sem_burn_reapply_resets_duration_and_damage_keeps_single_instance() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t, _st, _d) -> void: applied_count[0] += 1)

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)
	var tid: int = enemy.get_instance_id()
	_tick(sem, 0.1, 2)

	applied_count[0] = 0
	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 30.0)

	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	var inst = sem._active_statuses[tid][0]
	assert_float(inst.duration_remaining).is_equal_approx(2.0, 0.001)
	assert_float(inst.spell_base_damage).is_equal(30.0)
	assert_float(inst.tick_timer).is_equal(0.0)
	assert_int(applied_count[0]).is_equal(1)


# ── AC-SE-09: Player target rejected ─────────────────────────────────────────

func test_sem_burn_on_player_target_creates_no_instance_and_no_signal() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var player := _make_player()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t, _st, _d) -> void: applied_count[0] += 1)

	sem.apply_status(player, GameEnums.BaseStatus.BURN, 2.0, 20.0)

	assert_bool(sem._active_statuses.has(player.get_instance_id())).is_false()
	assert_int(applied_count[0]).is_equal(0)


# ── AC-SE-11: Dead target rejected ───────────────────────────────────────────

func test_sem_apply_on_dead_target_creates_no_instance_and_no_signal() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()
	enemy._alive = false

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t, _st, _d) -> void: applied_count[0] += 1)

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)

	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()
	assert_int(applied_count[0]).is_equal(0)


# ── AC-SE-20: Zero duration rejected ─────────────────────────────────────────

func test_sem_zero_duration_creates_no_instance_and_no_signal() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t, _st, _d) -> void: applied_count[0] += 1)

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 0.0, 20.0)

	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()
	assert_int(applied_count[0]).is_equal(0)


# ── AC-SE-20 (edge): Negative duration also rejected ─────────────────────────

func test_sem_negative_duration_creates_no_instance() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t, _st, _d) -> void: applied_count[0] += 1)

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, -1.0, 20.0)

	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()
	assert_int(applied_count[0]).is_equal(0)


# ── AC-SE-02 edge: zero spell_base_damage → tick fires with 0.0, maxf guard verified ──

func test_sem_burn_zero_spell_base_damage_tick_applies_zero_not_negative() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 0.0)
	_tick(sem, 0.5, 1)

	assert_int(mock.call_count).is_equal(1)
	assert_float(mock.last_damage).is_equal_approx(0.0, 0.001)


# ── AC-SE-02 edge: negative spell_base_damage clamped to 0.0 by maxf ─────────

func test_sem_burn_negative_spell_base_damage_clamped_to_zero() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, -10.0)
	_tick(sem, 0.5, 1)

	assert_int(mock.call_count).is_equal(1)
	assert_float(mock.last_damage).is_equal_approx(0.0, 0.001)


# ── AC-SE-03 edge: tick fires before expiry when both occur in same _process call ──

func test_sem_burn_tick_fires_before_expiry_on_same_process_call() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, _st: GameEnums.BaseStatus) -> void:
		expired_count[0] += 1
	)

	# duration = BURN_TICK_INTERVAL: tick fires at 0.5s, expiry also at 0.5s — same frame.
	# _process checks tick before duration, so tick must fire before the instance is removed.
	sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 0.5, 20.0)
	_tick(sem, 0.5, 1)

	assert_int(mock.call_count).is_equal(1)
	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()
	assert_int(expired_count[0]).is_equal(1)


# ── Sanity: constants and fresh state ────────────────────────────────────────

func test_sem_burn_tick_magnitude_constant_is_008() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	assert_float(sem.BURN_TICK_MAGNITUDE).is_equal(0.08)


func test_sem_active_statuses_empty_on_init() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	assert_bool(sem._active_statuses.is_empty()).is_true()
