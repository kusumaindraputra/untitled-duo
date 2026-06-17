## archetype_behavior_test.gd — Unit tests for RUSHER and SWARMER archetype behaviours.
##
## Coverage:
##   AC-LG-07: RUSHER CHARGING velocity > APPROACH velocity
##   AC-LG-07: RUSHER TELEGRAPH velocity == 0
##   AC-LG-08: SWARMER targets orbit point (not Fayde directly); angle advances each frame
##   AC-LG-09: RUSHER does not execute SEEKER chase path (confirmed by speed difference)
##
## GDD: design/gdd/level-generation.md
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

const MOVE_SPEED: float = 80.0
const DELTA: float = 1.0 / 60.0


func _make_enemy(archetype: GameEnums.EnemyArchetype) -> EnemyInstance:
	var e := EnemyInstance.new()
	e._combat_active = true
	e._move_speed = MOVE_SPEED
	e._archetype = archetype
	add_child(e)
	return e


func _make_fayde_at(pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.global_position = pos
	add_child(n)
	return n


# ── AC-LG-07: RUSHER APPROACH is slower than SEEKER ──────────────────────────

## GIVEN Fayde is far away (outside CHARGE_RANGE → RUSHER stays in APPROACH)
## WHEN _physics_process is called
## THEN RUSHER approach speed < SEEKER chase speed
## NOTE: enemies placed 300 px apart on Y so no physics overlap between them.
func test_rusher_approach_speed_less_than_seeker_speed() -> void:
	var fayde_r := _make_fayde_at(Vector2(500.0, 0.0))
	auto_free(fayde_r)
	var rusher := _make_enemy(GameEnums.EnemyArchetype.RUSHER)
	auto_free(rusher)
	rusher.global_position = Vector2.ZERO
	rusher._fayde_ref = fayde_r
	rusher._physics_process(DELTA)
	var rusher_speed: float = rusher.velocity.length()

	# Seeker lives 300 px away on Y — outside SEPARATION_RADIUS, no overlap.
	var fayde_s := _make_fayde_at(Vector2(500.0, 300.0))
	auto_free(fayde_s)
	var seeker := _make_enemy(GameEnums.EnemyArchetype.SEEKER)
	auto_free(seeker)
	seeker.global_position = Vector2(0.0, 300.0)
	seeker._fayde_ref = fayde_s
	seeker._physics_process(DELTA)
	var seeker_speed: float = seeker.velocity.length()

	assert_float(rusher_speed).is_less(seeker_speed)


# ── AC-LG-07: RUSHER TELEGRAPH velocity == 0 ─────────────────────────────────

## GIVEN RUSHER is forced into TELEGRAPH phase with a long timer
## WHEN _physics_process is called
## THEN velocity is (approximately) zero
func test_rusher_telegraph_phase_velocity_is_zero() -> void:
	var rusher := _make_enemy(GameEnums.EnemyArchetype.RUSHER)
	auto_free(rusher)
	rusher.global_position = Vector2.ZERO
	rusher._fayde_ref = _make_fayde_at(Vector2(100.0, 0.0))
	auto_free(rusher._fayde_ref)
	rusher._rusher_phase = 1  # TELEGRAPH
	rusher._rusher_timer = 999.0  # won't expire this frame

	rusher._physics_process(DELTA)

	assert_float(rusher.velocity.length()).is_equal_approx(0.0, 0.5)


# ── AC-LG-07: RUSHER CHARGING speed >> APPROACH speed ────────────────────────

## GIVEN RUSHER APPROACH vs CHARGING under identical conditions
## WHEN _physics_process is called for each
## THEN CHARGING velocity magnitude > APPROACH velocity magnitude
func test_rusher_charging_speed_greater_than_approach_speed() -> void:
	var fayde := _make_fayde_at(Vector2(500.0, 0.0))
	auto_free(fayde)

	var rusher := _make_enemy(GameEnums.EnemyArchetype.RUSHER)
	auto_free(rusher)
	rusher.global_position = Vector2.ZERO
	rusher._fayde_ref = fayde
	rusher._physics_process(DELTA)
	var approach_speed: float = rusher.velocity.length()

	rusher._rusher_phase = 2  # CHARGING
	rusher._rusher_timer = 999.0
	rusher._rusher_charge_dir = Vector2.RIGHT
	rusher._physics_process(DELTA)
	var charge_speed: float = rusher.velocity.length()

	assert_float(charge_speed).is_greater(approach_speed)


# ── AC-LG-08: SWARMER targets orbit offset, not Fayde directly ───────────────

## GIVEN SWARMER at origin, Fayde at origin, orbit angle = 0
##       → orbit target = (SWARMER_ORBIT_RADIUS, 0)
## WHEN _physics_process is called
## THEN velocity.x > 0 (moving toward orbit target, not stationary like same-position SEEKER)
func test_swarmer_moves_toward_orbit_point_not_fayde() -> void:
	var swarmer := _make_enemy(GameEnums.EnemyArchetype.SWARMER)
	auto_free(swarmer)
	swarmer.global_position = Vector2.ZERO
	swarmer._fayde_ref = _make_fayde_at(Vector2.ZERO)
	auto_free(swarmer._fayde_ref)
	swarmer._swarmer_angle = 0.0  # orbit target = Fayde + (ORBIT_RADIUS, 0)

	swarmer._physics_process(DELTA)

	assert_float(swarmer.velocity.x).is_greater(0.0)


# ── AC-LG-08: SWARMER orbit angle advances each frame ────────────────────────

## GIVEN SWARMER with _swarmer_angle = 0
## WHEN _physics_process is called with DELTA
## THEN _swarmer_angle == SWARMER_ORBIT_SPEED * DELTA
func test_swarmer_orbit_angle_advances_per_frame() -> void:
	var swarmer := _make_enemy(GameEnums.EnemyArchetype.SWARMER)
	auto_free(swarmer)
	swarmer.global_position = Vector2.ZERO
	swarmer._fayde_ref = _make_fayde_at(Vector2.ZERO)
	auto_free(swarmer._fayde_ref)
	swarmer._swarmer_angle = 0.0

	swarmer._physics_process(DELTA)

	var expected: float = EnemyInstance.SWARMER_ORBIT_SPEED * DELTA
	assert_float(swarmer._swarmer_angle).is_equal_approx(expected, 0.001)


# ── Preparation reset: RUSHER phase resets to APPROACH ───────────────────────

## GIVEN RUSHER in mid-charge (phase 2)
## WHEN _on_preparation_started fires
## THEN _rusher_phase == 0 and _rusher_timer == 0
func test_rusher_resets_to_approach_on_preparation_started() -> void:
	var rusher := _make_enemy(GameEnums.EnemyArchetype.RUSHER)
	auto_free(rusher)
	rusher._rusher_phase = 2
	rusher._rusher_timer = 0.3

	rusher._on_preparation_started()

	assert_int(rusher._rusher_phase).is_equal(0)
	assert_float(rusher._rusher_timer).is_equal(0.0)
