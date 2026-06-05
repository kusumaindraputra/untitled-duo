## Unit tests for StatusEffectsManager Story 005: has_status(), check_and_apply_shatter(),
## and Burn Contagion via _on_enemy_killed().
## Covers AC-SE-13, AC-SE-14, AC-SE-15, AC-SE-16, AC-SE-17, AC-SE-18.
extends GdUnitTestSuite


# ── Inner mocks ───────────────────────────────────────────────────────────────

class MockHealthAndDamage:
	func apply_damage(_target: Node, _amount: float, _dc: int, _ds: int) -> void: pass
	func apply_heal(_target: Node, _amount: float) -> void: pass


class MockEnemy extends Node2D:
	var _alive: bool = true
	func is_alive() -> bool: return _alive
	func apply_speed_modifier(_mult: float) -> void: pass
	func apply_stun(_duration: float) -> void: pass


# ── Fixtures ──────────────────────────────────────────────────────────────────

var _sem: Node
var _mock_hd: MockHealthAndDamage
var _shatter_count: int = 0
var _contagion_count: int = 0
var _contagion_last_target: Node = null
var _contagion_last_pos: Vector2 = Vector2.ZERO


func before_test() -> void:
	_shatter_count = 0
	_contagion_count = 0
	_contagion_last_target = null
	_contagion_last_pos = Vector2.ZERO
	_mock_hd = MockHealthAndDamage.new()
	_sem = preload("res://src/systems/status_effects_manager.gd").new()
	_sem._health_and_damage = _mock_hd
	add_child(_sem)
	_sem.set_process(false)
	_sem.shatter_triggered.connect(_on_shatter)
	_sem.burn_contagion_triggered.connect(_on_contagion)


func after_test() -> void:
	_sem.queue_free()


func _on_shatter(_target: Node) -> void:
	_shatter_count += 1


func _on_contagion(pos: Vector2, target: Node) -> void:
	_contagion_count += 1
	_contagion_last_target = target
	_contagion_last_pos = pos


## Creates a MockEnemy in the scene tree and "enemy" group at [param pos].
func _make_enemy(pos: Vector2, alive: bool = true) -> MockEnemy:
	var e := MockEnemy.new()
	e._alive = alive
	e.global_position = pos
	e.add_to_group(&"enemy")
	add_child(e)
	return e


# ── has_status() ──────────────────────────────────────────────────────────────

func test_has_status_true_when_active() -> void:
	var enemy := _make_enemy(Vector2.ZERO)
	_sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0)
	assert_bool(_sem.has_status(enemy, GameEnums.BaseStatus.FREEZE)).is_true()
	enemy.queue_free()


func test_has_status_false_when_not_applied() -> void:
	var enemy := _make_enemy(Vector2.ZERO)
	assert_bool(_sem.has_status(enemy, GameEnums.BaseStatus.FREEZE)).is_false()
	enemy.queue_free()


func test_has_status_false_for_wrong_type() -> void:
	var enemy := _make_enemy(Vector2.ZERO)
	_sem.apply_status(enemy, GameEnums.BaseStatus.BURN, 2.0, 10.0)
	assert_bool(_sem.has_status(enemy, GameEnums.BaseStatus.FREEZE)).is_false()
	enemy.queue_free()


# ── AC-SE-16 — Shatter: 1.25× for frozen target, signal emitted ───────────────

func test_shatter_frozen_target_multiplies_damage() -> void:
	var enemy := _make_enemy(Vector2.ZERO)
	_sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0)

	var result: float = _sem.check_and_apply_shatter(enemy, 16.0)

	assert_float(result).is_equal(20.0)
	assert_int(_shatter_count).is_equal(1)
	assert_bool(_sem.has_status(enemy, GameEnums.BaseStatus.FREEZE)).is_true()
	enemy.queue_free()


func test_shatter_zero_damage_returns_zero() -> void:  # AC-SE-16 edge: 0 × 1.25 = 0
	var enemy := _make_enemy(Vector2.ZERO)
	_sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0)

	var result: float = _sem.check_and_apply_shatter(enemy, 0.0)
	assert_float(result).is_equal(0.0)
	enemy.queue_free()


# ── AC-SE-17 — Shatter: unchanged value when not frozen ───────────────────────

func test_shatter_unfrozen_target_unchanged() -> void:
	var enemy := _make_enemy(Vector2.ZERO)

	var result: float = _sem.check_and_apply_shatter(enemy, 16.0)

	assert_float(result).is_equal(16.0)
	assert_int(_shatter_count).is_equal(0)
	enemy.queue_free()


func test_shatter_chill_only_does_not_trigger() -> void:  # AC-SE-17 edge: Chill ≠ Freeze
	var enemy := _make_enemy(Vector2.ZERO)
	_sem.apply_status(enemy, GameEnums.BaseStatus.CHILL, 2.0)

	var result: float = _sem.check_and_apply_shatter(enemy, 16.0)

	assert_float(result).is_equal(16.0)
	assert_int(_shatter_count).is_equal(0)
	enemy.queue_free()


# ── AC-SE-18 — Non-consuming Shatter: both hits fire, Freeze remains ──────────

func test_shatter_fires_twice_freeze_not_consumed() -> void:
	var enemy := _make_enemy(Vector2.ZERO)
	_sem.apply_status(enemy, GameEnums.BaseStatus.FREEZE, 2.0)

	var r1: float = _sem.check_and_apply_shatter(enemy, 16.0)
	var r2: float = _sem.check_and_apply_shatter(enemy, 16.0)

	assert_float(r1).is_equal(20.0)
	assert_float(r2).is_equal(20.0)
	assert_int(_shatter_count).is_equal(2)
	assert_bool(_sem.has_status(enemy, GameEnums.BaseStatus.FREEZE)).is_true()
	enemy.queue_free()


# ── AC-SE-13 — Burn Contagion: transfers to nearest alive enemy within 200px ──

func test_contagion_transfers_to_nearest_alive_in_range() -> void:
	var dying_enemy := _make_enemy(Vector2(0, 0), true)
	var target_enemy := _make_enemy(Vector2(150, 0), true)

	_sem.apply_status(dying_enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)
	dying_enemy._alive = false  # mark as dying after apply_status validates it

	_sem._on_enemy_killed(dying_enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_bool(_sem.has_status(target_enemy, GameEnums.BaseStatus.BURN)).is_true()
	assert_int(_contagion_count).is_equal(1)
	assert_bool(_contagion_last_target == target_enemy).is_true()
	assert_bool(_contagion_last_pos == Vector2(0, 0)).is_true()
	dying_enemy.queue_free()
	target_enemy.queue_free()


func test_contagion_reapplies_if_target_already_burning() -> void:  # AC-SE-13 edge
	var dying_enemy := _make_enemy(Vector2(0, 0), true)
	var target_enemy := _make_enemy(Vector2(100, 0), true)

	_sem.apply_status(dying_enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)
	_sem.apply_status(target_enemy, GameEnums.BaseStatus.BURN, 0.5, 5.0)
	dying_enemy._alive = false

	_sem._on_enemy_killed(dying_enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_bool(_sem.has_status(target_enemy, GameEnums.BaseStatus.BURN)).is_true()
	assert_int(_contagion_count).is_equal(1)
	# Verify the contagion re-applied with dying enemy's original spell_base_damage (20.0), not 5.0.
	var burn_instances: Array = _sem._active_statuses.get(target_enemy.get_instance_id(), [])
	var reapplied_base: float = 0.0
	for inst in burn_instances:
		if inst.status_type == GameEnums.BaseStatus.BURN:
			reapplied_base = inst.spell_base_damage
			break
	assert_float(reapplied_base).is_equal(20.0)
	dying_enemy.queue_free()
	target_enemy.queue_free()


# ── AC-SE-14 — Burn Contagion: no fire when no alive enemy in range ────────────

func test_contagion_no_fire_when_no_alive_enemy_nearby() -> void:
	# Only the dying enemy exists; it is not alive so the scan skips it.
	var dying_enemy := _make_enemy(Vector2(0, 0), true)

	_sem.apply_status(dying_enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)
	dying_enemy._alive = false

	_sem._on_enemy_killed(dying_enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_int(_contagion_count).is_equal(0)
	dying_enemy.queue_free()


# ── AC-SE-15 — Burn Contagion: boundary 201px = no transfer ───────────────────

func test_contagion_no_fire_at_201px() -> void:
	var dying_enemy := _make_enemy(Vector2(0, 0), true)
	var far_enemy := _make_enemy(Vector2(201, 0), true)

	_sem.apply_status(dying_enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)
	dying_enemy._alive = false

	_sem._on_enemy_killed(dying_enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_int(_contagion_count).is_equal(0)
	assert_bool(_sem.has_status(far_enemy, GameEnums.BaseStatus.BURN)).is_false()
	dying_enemy.queue_free()
	far_enemy.queue_free()


func test_contagion_fires_at_200px_inclusive() -> void:  # AC-SE-15 edge: <= is inclusive
	var dying_enemy := _make_enemy(Vector2(0, 0), true)
	var edge_enemy := _make_enemy(Vector2(200, 0), true)

	_sem.apply_status(dying_enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)
	dying_enemy._alive = false

	_sem._on_enemy_killed(dying_enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_int(_contagion_count).is_equal(1)
	assert_bool(_sem.has_status(edge_enemy, GameEnums.BaseStatus.BURN)).is_true()
	dying_enemy.queue_free()
	edge_enemy.queue_free()


func test_contagion_no_crash_when_enemy_group_empty() -> void:  # AC-SE-14 edge: empty array
	# Enemy is in group during apply_status, then removed — scan returns empty array.
	var dying_enemy := _make_enemy(Vector2(0, 0), true)
	_sem.apply_status(dying_enemy, GameEnums.BaseStatus.BURN, 2.0, 20.0)
	dying_enemy.remove_from_group(&"enemy")
	dying_enemy._alive = false

	_sem._on_enemy_killed(dying_enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_int(_contagion_count).is_equal(0)
	dying_enemy.queue_free()
