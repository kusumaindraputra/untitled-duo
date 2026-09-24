## pickup_orb_test.gd — PickupOrb magnet, collect and drop table (ADR-0019).
##
## Orbs are created with .new() and never enter the tree; step() is driven directly.
extends GdUnitTestSuite

const T: PaceTuning = preload("res://assets/data/pace_tuning.tres")
const DT: float = 1.0 / 60.0


func _orb(pos: Vector2) -> PickupOrb:
	var orb := PickupOrb.new()
	orb.position = pos
	return orb


## Steps past the pop phase so the magnet can engage.
func _skip_pop(orb: PickupOrb, target: Vector2) -> void:
	for _i: int in ceili(PickupOrb.POP_SEC / DT) + 1:
		orb.step(DT, target)


func test_orb_idles_outside_magnet_radius() -> void:
	var orb := _orb(Vector2(T.orb_magnet_radius + 50.0, 0.0))
	_skip_pop(orb, Vector2.ZERO)
	assert_bool(orb.is_magnetized()).is_false()
	assert_float(orb.position.x).is_equal(T.orb_magnet_radius + 50.0)
	orb.free()


func test_orb_flies_to_player_inside_magnet_radius_and_collects() -> void:
	var orb := _orb(Vector2(T.orb_magnet_radius - 5.0, 0.0))
	_skip_pop(orb, Vector2.ZERO)
	var collected: bool = false
	for _i: int in 120:
		if orb.step(DT, Vector2.ZERO):
			collected = true
			break
	assert_bool(collected).is_true()
	orb.free()


func test_orb_collects_only_once() -> void:
	var orb := _orb(Vector2(40.0, 0.0))
	_skip_pop(orb, Vector2.ZERO)
	var hits: int = 0
	for _i: int in 10:
		if orb.step(DT, Vector2.ZERO):
			hits += 1
	assert_int(hits).is_equal(1)
	orb.free()


func test_orb_magnetize_pulls_from_anywhere() -> void:
	var orb := _orb(Vector2(1000.0, 0.0))
	orb.magnetize()
	_skip_pop(orb, Vector2.ZERO)
	assert_float(orb.position.x).is_less(1000.0)
	orb.free()


func test_orb_stays_idle_without_target() -> void:
	var orb := _orb(Vector2(5.0, 0.0))
	_skip_pop(orb, Vector2.ZERO)
	assert_bool(orb.step(DT, Vector2.ZERO, false)).is_false()
	orb.free()


func test_orb_drops_normal_kill() -> void:
	var t := PaceTuning.new()
	t.hp_orb_chance = 0.2
	t.meter_orbs_per_kill = 1
	assert_dict(PaceDirector.orb_drops(false, 0.5, t)).is_equal({ "hp": 0, "meter": 1 })
	assert_dict(PaceDirector.orb_drops(false, 0.1, t)).is_equal({ "hp": 1, "meter": 1 })


func test_orb_drops_elite_always_has_hp_and_double_meter() -> void:
	var t := PaceTuning.new()
	t.hp_orb_chance = 0.0
	t.meter_orbs_per_kill = 2
	t.elite_always_drops_hp = true
	assert_dict(PaceDirector.orb_drops(true, 0.99, t)).is_equal({ "hp": 1, "meter": 4 })
