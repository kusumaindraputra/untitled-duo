## sem_stub_effects_test.gd — Unit tests for StatusEffectsManager stub effects:
## Blind, Stun, Chill, and Stagger (Story 003).
##
## Coverage:
##   AC-SE-22: BLIND creates instance + signals, no tick, expiry removes instance
##   AC-SE-22 edge: Blind re-apply resets duration; single instance kept
##   AC-SE-23: STUN calls apply_stun(duration) once at apply; no second call on expiry
##   AC-SE-24: CHILL suppressed when FREEZE is active; no instance, no signal, no speed call
##   AC-SE-25: CHILL applies apply_speed_modifier(0.85) when no FREEZE; instance created
##   AC-SE-26: CHILL expiry calls apply_speed_modifier(1.0); instance removed
##   AC-SE-27: STAGGER calls apply_stun(STAGGER_DURATION=0.3) once; expiry, no second call
##   Freeze-expiry Chill-awareness: when FREEZE expires with active CHILL, speed restores to 0.85
##   Sanity: CHILL_SLOW_PCT and STAGGER_DURATION constants have correct values
##
## Setup pattern:
##   - SEM added to tree (triggers _ready, mock preserved by null-guard)
##   - set_process(false) immediately after add_child to block engine auto-calls
##   - MockHD extends Node so Variant dispatch works via Node method table
##   - MockEnemy exposes apply_speed_modifier() and apply_stun() spies
##   - Manual _tick calls drive the accumulator exclusively
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
extends GdUnitTestSuite

const SEMScript = preload("res://src/systems/status_effects_manager.gd")


# ── Mock classes ──────────────────────────────────────────────────────────────

class MockHD extends Node:
	func apply_damage(_target, _damage, _element, _source) -> void:
		pass

	func apply_heal(_target, _amount: float) -> void:
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


## Drives sem._process(delta) [times] times manually.
func _tick(sem: Node, delta: float, times: int = 1) -> void:
	for _i: int in range(times):
		sem.call(&"_process", delta)


# ── AC-SE-22: BLIND creates instance + signals, no tick fires, expiry cleans up ─

func test_sem_blind_apply_creates_instance_emits_signal_no_tick_fires() -> void:
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
	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, st: GameEnums.BaseStatus) -> void:
		if st == GameEnums.BaseStatus.BLIND:
			expired_count[0] += 1
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.BLIND, 2.0, 0.0)

	# Instance registered correctly.
	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	var inst = sem._active_statuses[tid][0]
	assert_int(inst.status_type).is_equal(GameEnums.BaseStatus.BLIND)
	assert_float(inst.tick_interval).is_equal_approx(0.0, 0.0001)

	# status_applied emitted once.
	assert_int(applied_count[0]).is_equal(1)
	assert_int(applied_type[0]).is_equal(GameEnums.BaseStatus.BLIND)
	assert_float(applied_dur[0]).is_equal_approx(2.0, 0.001)

	# No speed modifier or stun call on apply.
	assert_int(enemy.speed_modifier_calls.size()).is_equal(0)
	assert_int(enemy.apply_stun_calls.size()).is_equal(0)

	# Advance to expiry — no tick damage calls should fire.
	_tick(sem, 2.01)

	# Instance removed and status_expired emitted once.
	assert_bool(sem._active_statuses.has(tid)).is_false()
	assert_int(expired_count[0]).is_equal(1)

	# Still no speed or stun calls from expiry.
	assert_int(enemy.speed_modifier_calls.size()).is_equal(0)
	assert_int(enemy.apply_stun_calls.size()).is_equal(0)


# ── AC-SE-22 edge: Blind re-apply resets duration; single instance ────────────

func test_sem_blind_reapply_resets_duration_keeps_single_instance() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t, _st, _d) -> void: applied_count[0] += 1)

	sem.apply_status(enemy, GameEnums.BaseStatus.BLIND, 2.0, 0.0)
	_tick(sem, 0.5)
	applied_count[0] = 0

	sem.apply_status(enemy, GameEnums.BaseStatus.BLIND, 2.0, 0.0)

	var tid: int = enemy.get_instance_id()
	assert_int(sem._active_statuses[tid].size()).is_equal(1)
	var inst = sem._active_statuses[tid][0]
	assert_float(inst.duration_remaining).is_equal_approx(2.0, 0.001)
	# status_applied emitted for the re-apply.
	assert_int(applied_count[0]).is_equal(1)


# ── AC-SE-23: STUN calls apply_stun(duration) once; no second call on expiry ──

func test_sem_stun_calls_apply_stun_once_at_apply_no_second_call_on_expiry() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, st: GameEnums.BaseStatus) -> void:
		if st == GameEnums.BaseStatus.STUN:
			expired_count[0] += 1
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.STUN, 0.8, 0.0)

	# apply_stun called exactly once with 0.8 at application time.
	assert_int(enemy.apply_stun_calls.size()).is_equal(1)
	assert_float(enemy.apply_stun_calls[0]).is_equal_approx(0.8, 0.001)

	# Instance registered; tick_interval is 0.0 (no tick logic).
	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	var inst = sem._active_statuses[tid][0]
	assert_float(inst.tick_interval).is_equal_approx(0.0, 0.0001)

	# Advance to expiry.
	_tick(sem, 0.81)

	# status_expired emitted once.
	assert_int(expired_count[0]).is_equal(1)
	# Instance removed.
	assert_bool(sem._active_statuses.has(tid)).is_false()
	# apply_stun call count unchanged — no second call on expiry.
	assert_int(enemy.apply_stun_calls.size()).is_equal(1)


# ── AC-SE-24: CHILL suppressed when FREEZE is active ─────────────────────────

func test_sem_chill_suppressed_when_freeze_active_no_instance_no_signal_no_speed_call() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	# Apply FREEZE first — this calls apply_speed_modifier(0.50).
	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0, 0.0)
	var speed_calls_after_freeze: int = enemy.speed_modifier_calls.size()

	var chill_applied_count: Array[int] = [0]
	sem.status_applied.connect(func(_t: Node, st: GameEnums.BaseStatus, _d: float) -> void:
		if st == GameEnums.BaseStatus.CHILL:
			chill_applied_count[0] += 1
	)

	# Try to apply CHILL while FREEZE is active.
	sem.apply_status(enemy, GameEnums.BaseStatus.CHILL, 2.0, 0.0)

	# No CHILL instance in registry.
	var tid: int = enemy.get_instance_id()
	var has_chill: bool = false
	for s in sem._active_statuses.get(tid, []):
		if s.status_type == GameEnums.BaseStatus.CHILL:
			has_chill = true
	assert_bool(has_chill).is_false()

	# No additional speed modifier call (Chill was suppressed).
	assert_int(enemy.speed_modifier_calls.size()).is_equal(speed_calls_after_freeze)

	# status_applied NOT emitted for CHILL.
	assert_int(chill_applied_count[0]).is_equal(0)


# ── AC-SE-25: CHILL applies speed modifier when no FREEZE active ──────────────

func test_sem_chill_applies_speed_modifier_085_when_no_freeze_active() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	var applied_type: Array[int] = [-1]
	var applied_dur: Array[float] = [0.0]
	sem.status_applied.connect(func(_t: Node, st: GameEnums.BaseStatus, d: float) -> void:
		applied_count[0] += 1
		applied_type[0] = st
		applied_dur[0] = d
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.CHILL, 2.0, 0.0)

	# Instance registered.
	var tid: int = enemy.get_instance_id()
	assert_bool(sem._active_statuses.has(tid)).is_true()
	var has_chill: bool = false
	for s in sem._active_statuses[tid]:
		if s.status_type == GameEnums.BaseStatus.CHILL:
			has_chill = true
	assert_bool(has_chill).is_true()

	# apply_speed_modifier called once with 0.85 (1.0 - CHILL_SLOW_PCT = 1.0 - 0.15).
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)
	assert_float(enemy.speed_modifier_calls[0]).is_equal_approx(0.85, 0.001)

	# status_applied emitted with correct args.
	assert_int(applied_count[0]).is_equal(1)
	assert_int(applied_type[0]).is_equal(GameEnums.BaseStatus.CHILL)
	assert_float(applied_dur[0]).is_equal_approx(2.0, 0.001)


# ── AC-SE-26: CHILL expiry calls apply_speed_modifier(1.0); instance removed ──

func test_sem_chill_expiry_restores_full_speed_and_removes_instance() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, st: GameEnums.BaseStatus) -> void:
		if st == GameEnums.BaseStatus.CHILL:
			expired_count[0] += 1
	)

	sem.apply_status(enemy, GameEnums.BaseStatus.CHILL, 0.1, 0.0)
	# After apply: speed_modifier_calls = [0.85]
	assert_int(enemy.speed_modifier_calls.size()).is_equal(1)

	_tick(sem, 0.11)

	# Instance removed.
	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()

	# status_expired emitted once.
	assert_int(expired_count[0]).is_equal(1)

	# apply_speed_modifier called a second time with 1.0 (restore).
	assert_int(enemy.speed_modifier_calls.size()).is_equal(2)
	assert_float(enemy.speed_modifier_calls[1]).is_equal_approx(1.0, 0.001)


# ── AC-SE-27: STAGGER calls apply_stun(0.3) once; no second call on expiry ────

func test_sem_stagger_calls_apply_stun_with_fixed_duration_no_second_call_on_expiry() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	var applied_count: Array[int] = [0]
	var applied_dur: Array[float] = [0.0]
	sem.status_applied.connect(func(_t: Node, st: GameEnums.BaseStatus, d: float) -> void:
		if st == GameEnums.BaseStatus.STAGGER:
			applied_count[0] += 1
			applied_dur[0] = d
	)
	var expired_count: Array[int] = [0]
	sem.status_expired.connect(func(_t: Node, st: GameEnums.BaseStatus) -> void:
		if st == GameEnums.BaseStatus.STAGGER:
			expired_count[0] += 1
	)

	# Pass a non-0.3 duration to confirm STAGGER_DURATION overrides the parameter.
	sem.apply_status(enemy, GameEnums.BaseStatus.STAGGER, 1.0, 0.0)

	# apply_stun called with fixed STAGGER_DURATION (0.3), not the passed duration (1.0).
	assert_int(enemy.apply_stun_calls.size()).is_equal(1)
	assert_float(enemy.apply_stun_calls[0]).is_equal_approx(0.3, 0.001)

	# status_applied emitted with STAGGER_DURATION (0.3), not caller-supplied 1.0 (AC-SE-27).
	assert_int(applied_count[0]).is_equal(1)
	assert_float(applied_dur[0]).is_equal_approx(0.3, 0.001)

	# Instance duration_remaining is 0.3 — advances past 0.3s, not 1.0s.
	_tick(sem, 0.31)

	# status_expired emitted; instance removed.
	assert_int(expired_count[0]).is_equal(1)
	assert_bool(sem._active_statuses.has(enemy.get_instance_id())).is_false()

	# apply_stun call count unchanged — no second call on expiry.
	assert_int(enemy.apply_stun_calls.size()).is_equal(1)


# ── Freeze-expiry Chill-awareness: restores to 0.85 if Chill is still active ──

func test_sem_freeze_expiry_restores_chill_speed_when_chill_still_active() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)
	var enemy := _make_enemy()

	# Apply Chill first (no FREEZE active), then immediately FREEZE.
	# CHILL applies 0.85. FREEZE then applies 0.50 over Chill (Freeze wins).
	sem.apply_status(enemy, GameEnums.BaseStatus.CHILL, 5.0, 0.0)
	sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 0.1, 0.0)

	# speed_modifier_calls: [0.85, 0.50]
	assert_int(enemy.speed_modifier_calls.size()).is_equal(2)
	assert_float(enemy.speed_modifier_calls[0]).is_equal_approx(0.85, 0.001)
	assert_float(enemy.speed_modifier_calls[1]).is_equal_approx(0.50, 0.001)

	# Advance so Freeze expires (0.11 s) but Chill (5.0 s) is still active.
	_tick(sem, 0.11)

	# Freeze expired; Chill still in registry.
	var tid: int = enemy.get_instance_id()
	var freeze_present: bool = false
	var chill_present: bool = false
	for s in sem._active_statuses.get(tid, []):
		if s.status_type == GameEnums.BaseStatus.FREEZE:
			freeze_present = true
		if s.status_type == GameEnums.BaseStatus.CHILL:
			chill_present = true
	assert_bool(freeze_present).is_false()
	assert_bool(chill_present).is_true()

	# Freeze expiry should restore to Chill speed (0.85), not full speed (1.0).
	assert_int(enemy.speed_modifier_calls.size()).is_equal(3)
	assert_float(enemy.speed_modifier_calls[2]).is_equal_approx(0.85, 0.001)


# ── Sanity: CHILL_SLOW_PCT and STAGGER_DURATION constants ─────────────────────

func test_sem_stub_effects_constants_have_correct_values() -> void:
	var mock := MockHD.new()
	add_child(mock)
	auto_free(mock)
	var sem: Node = _make_sem(mock)

	assert_float(sem.CHILL_SLOW_PCT).is_equal_approx(0.15, 0.0001)
	assert_float(sem.STAGGER_DURATION).is_equal_approx(0.3, 0.001)
