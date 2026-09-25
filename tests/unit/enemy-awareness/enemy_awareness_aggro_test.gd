## enemy_awareness_aggro_test.gd — Unit tests for enemy dormant / alert behaviour (ADR-0024).
##
## Coverage:
##   Dormant enemy holds still while Fayde is outside the aggro area
##   Fayde entering the aggro area wakes the enemy (and it starts chasing)
##   Distance is measured on the iso floor (y stretched by iso_y_scale)
##   Taking damage wakes a dormant enemy
##   An alert wakes dormant allies inside alert_link_radius only
##   max_dormant_sec wakes the enemy on its own; bosses never go dormant
##   The shipped tuning keeps the aggro area inside the combat view
##
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite

const MOVE_SPEED: float = 80.0
const DELTA: float = 1.0 / 60.0


func _make_tuning() -> EnemyAwarenessTuning:
	var t := EnemyAwarenessTuning.new()
	t.enabled = true
	t.aggro_radius = 200.0
	t.alert_link_radius = 120.0
	t.iso_y_scale = 2.0
	t.max_dormant_sec = 5.0
	t.alert_mark_sec = 0.0  # no mark node in unit tests
	return t


func _make_enemy(pos: Vector2, tuning: EnemyAwarenessTuning,
		archetype: GameEnums.EnemyArchetype = GameEnums.EnemyArchetype.SEEKER) -> EnemyInstance:
	var e := EnemyInstance.new()
	e._awareness = tuning
	e._combat_active = true
	e._move_speed = MOVE_SPEED
	e._archetype = archetype
	add_child(e)
	e.global_position = pos
	return e


func _make_fayde_at(pos: Vector2) -> Node2D:
	var n := Node2D.new()
	add_child(n)
	n.global_position = pos
	return n


func test_awareness_dormant_enemy_outside_radius_stays_still() -> void:
	var t := _make_tuning()
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	var fayde := auto_free(_make_fayde_at(Vector2(t.aggro_radius + 50.0, 0.0))) as Node2D
	enemy._fayde_ref = fayde
	enemy.enter_dormant()

	enemy._physics_process(DELTA)

	assert_bool(enemy.is_dormant()).is_true()
	assert_float(enemy.velocity.length()).is_equal(0.0)


func test_awareness_fayde_inside_radius_wakes_and_chases() -> void:
	var t := _make_tuning()
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	var fayde := auto_free(_make_fayde_at(Vector2(t.aggro_radius - 10.0, 0.0))) as Node2D
	enemy._fayde_ref = fayde
	enemy.enter_dormant()

	enemy._physics_process(DELTA)

	assert_bool(enemy.is_dormant()).is_false()
	assert_float(enemy.velocity.x).is_greater(0.0)


func test_awareness_vertical_distance_counts_double_on_iso_floor() -> void:
	var t := _make_tuning()
	# 0.75 × radius straight down on screen = 1.5 × radius on the floor → still dormant.
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	var fayde := auto_free(_make_fayde_at(Vector2(0.0, t.aggro_radius * 0.75))) as Node2D
	enemy._fayde_ref = fayde
	enemy.enter_dormant()

	enemy._physics_process(DELTA)

	assert_bool(enemy.is_dormant()).is_true()
	assert_float(EnemyInstance.iso_distance(Vector2.ZERO, Vector2(30.0, 40.0), 2.0)) \
		.is_equal_approx(Vector2(30.0, 80.0).length(), 0.001)


func test_awareness_taking_damage_wakes_dormant_enemy() -> void:
	var t := _make_tuning()
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	enemy._max_hp = 10
	enemy.enter_dormant()

	enemy._on_damage_taken_hp_bar(enemy, 3, 7)

	assert_bool(enemy.is_dormant()).is_false()


func test_awareness_damage_to_other_enemy_does_not_wake() -> void:
	var t := _make_tuning()
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	var other := auto_free(Node.new()) as Node
	enemy.enter_dormant()

	enemy._on_damage_taken_hp_bar(other, 3, 7)

	assert_bool(enemy.is_dormant()).is_true()


func test_awareness_alert_chains_only_within_link_radius() -> void:
	var t := _make_tuning()
	var a := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	var near := auto_free(_make_enemy(Vector2(t.alert_link_radius - 10.0, 0.0), t)) as EnemyInstance
	var far := auto_free(_make_enemy(Vector2(t.alert_link_radius + 60.0, 0.0), t)) as EnemyInstance
	for e: EnemyInstance in [a, near, far]:
		e.enter_dormant()

	a.alert()

	assert_bool(a.is_dormant()).is_false()
	assert_bool(near.is_dormant()).is_false()
	assert_bool(far.is_dormant()).is_true()


func test_awareness_alert_emits_signal_once() -> void:
	var t := _make_tuning()
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	var hits: Array[int] = [0]
	enemy.alerted.connect(func() -> void: hits[0] += 1)
	enemy.enter_dormant()

	enemy.alert()
	enemy.alert()

	assert_int(hits[0]).is_equal(1)


func test_awareness_max_dormant_sec_wakes_enemy() -> void:
	var t := _make_tuning()
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance
	var fayde := auto_free(_make_fayde_at(Vector2(t.aggro_radius * 4.0, 0.0))) as Node2D
	enemy._fayde_ref = fayde
	enemy.enter_dormant()

	enemy._physics_process(t.max_dormant_sec - 0.1)
	assert_bool(enemy.is_dormant()).is_true()
	enemy._physics_process(0.2)

	assert_bool(enemy.is_dormant()).is_false()


func test_awareness_boss_never_goes_dormant() -> void:
	var t := _make_tuning()
	var boss := auto_free(_make_enemy(Vector2.ZERO, t, GameEnums.EnemyArchetype.BOSS)) as EnemyInstance

	boss.enter_dormant()

	assert_bool(boss.is_dormant()).is_false()


func test_awareness_disabled_tuning_keeps_enemy_awake() -> void:
	var t := _make_tuning()
	t.enabled = false
	var enemy := auto_free(_make_enemy(Vector2.ZERO, t)) as EnemyInstance

	enemy.enter_dormant()

	assert_bool(enemy.is_dormant()).is_false()


func test_awareness_default_spawn_is_awake() -> void:
	var enemy := auto_free(_make_enemy(Vector2.ZERO, _make_tuning())) as EnemyInstance

	assert_bool(enemy.is_dormant()).is_false()


## The shipped aggro ellipse must fit inside the combat view, so a dormant enemy is
## always on screen before it wakes and starts shooting.
func test_awareness_shipped_aggro_area_fits_combat_view() -> void:
	var aware: EnemyAwarenessTuning = EnemyInstance.AWARENESS_TUNING
	var cam: CameraTuning = PlayerController.CAMERA_TUNING
	var half_view: Vector2 = CameraTuning.visible_area(cam.combat_zoom) * 0.5

	assert_float(aware.aggro_radius).is_less(half_view.x)
	assert_float(aware.aggro_radius / aware.iso_y_scale).is_less(half_view.y)
