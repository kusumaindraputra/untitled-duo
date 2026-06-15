## enemy_instance_integration_test.gd — Integration tests for EnemyInstance (Story 005, EAI).
##
## Covers: AC-EAI-24 (full contact sequence), AC-EAI-25 (phase transition clears contact state),
##         AC-EAI-26 (kill during overlap stops damage), TR-EAI-007 (status API stubs)
##
## Note: all three stubs (apply_speed_modifier, apply_stun, is_alive) were already
## implemented in Story 001 — this story provides integration-level test coverage.
##
## Note: monitor_signals(HealthAndDamage) causes GdUnit4 to free the Autoload between
## tests. Use HP-delta tracking for damage verification and force_end_iframe_window()
## between steps to avoid i-frame interference.
##
## GdUnit4 v6.1.3 | Godot 4.6.2
extends GdUnitTestSuite

const BASE_DAMAGE: float = 8.0
const DELTA: float = 1.0 / 60.0

## Frames to tick the 0.3s contact timer to expiry at 60fps (verified in Story 003).
## ceil(0.3 × 60) + 1 safety margin = 18 + 1 = 19.
const CONTACT_FRAMES: int = 19


## Reset H&D Fayde state before each test to isolate i-frame and HP side-effects.
func before_test() -> void:
	HealthAndDamage.force_end_iframe_window()
	HealthAndDamage._fayde_current_hp = HealthAndDamage.FAYDE_MAX_HP
	HealthAndDamage._fayde_dead = false
	HealthAndDamage._current_zone = GameEnums.HPZone.FULL


func _make_enemy() -> EnemyInstance:
	var e := EnemyInstance.new()
	e._base_damage = BASE_DAMAGE
	e._combat_active = true
	add_child(e)
	return e


func _make_fayde() -> Node2D:
	var n := Node2D.new()
	n.add_to_group(&"player")
	add_child(n)
	return n


## Adds a 2s "death" animation so _on_enemy_killed takes the animation path
## rather than arming the fallback timer (which would queue_free the enemy mid-test).
func _add_death_animation(enemy: EnemyInstance) -> void:
	var lib := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 2.0
	lib.add_animation(&"death", anim)
	(enemy.get_node("AnimationPlayer") as AnimationPlayer).add_animation_library(&"", lib)


# ── AC-EAI-24 — Full contact sequence (4 steps) ──────────────────────────────

## GIVEN alive enemy in COMBAT_PHASE,
## WHEN full contact sequence runs (enter → timer fires → exit → no more hits),
## THEN HP reflects exactly 2 hits and no more.
func test_enemy_instance_contact_full_sequence_applies_initial_and_repeat_damage() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	enemy._fayde_ref = fayde
	var hp0: int = HealthAndDamage._fayde_current_hp

	# Step 1: body_entered fires immediate damage.
	enemy._on_hitarea_body_entered(fayde)
	var hp1: int = HealthAndDamage._fayde_current_hp
	assert_int(hp1).is_equal(hp0 - int(BASE_DAMAGE))

	# Step 2: contact timer fires repeat damage (clear i-frames first so hit lands).
	HealthAndDamage.force_end_iframe_window()
	for _i: int in CONTACT_FRAMES:
		enemy._physics_process(DELTA)
	var hp2: int = HealthAndDamage._fayde_current_hp
	assert_int(hp2).is_equal(hp1 - int(BASE_DAMAGE))

	# Step 3: body_exited disarms timer.
	enemy._on_hitarea_body_exited(fayde)
	assert_float(enemy._contact_timer).is_equal(0.0)
	assert_bool(enemy._fayde_in_contact).is_false()

	# Step 4: no third hit after exit (clear residual i-frames from Step 2).
	HealthAndDamage.force_end_iframe_window()
	for _i: int in CONTACT_FRAMES:
		enemy._physics_process(DELTA)
	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp2)


# ── AC-EAI-25 — Phase transition clears contact state ────────────────────────

## GIVEN Fayde overlapping with timer mid-interval,
## WHEN preparation_started fires then combat_started fires,
## THEN no damage during PREP and a fresh body_entered fires exactly one hit.
func test_enemy_instance_contact_phase_transition_clears_state_and_rearms() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	enemy._fayde_in_contact = true
	enemy._contact_timer = 0.15
	enemy._fayde_ref = fayde
	var hp0: int = HealthAndDamage._fayde_current_hp

	# Step 1: preparation_started zeros contact state.
	enemy._on_preparation_started()
	assert_float(enemy._contact_timer).is_equal(0.0)
	assert_bool(enemy._fayde_in_contact).is_false()
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)

	# Step 2: 10 frames in PREP — no damage (_combat_active = false).
	for _i: int in 10:
		enemy._physics_process(DELTA)
	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp0)

	# Step 3: combat_started re-opens gate.
	enemy._on_combat_started()
	assert_bool(enemy._combat_active).is_true()

	# Step 4: fresh body_entered fires damage exactly once (no leaked timer state).
	enemy._on_hitarea_body_entered(fayde)
	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp0 - int(BASE_DAMAGE))
	assert_float(enemy._contact_timer).is_equal_approx(EnemyInstance.ENEMY_MIN_CONTACT_INTERVAL, 0.001)


# ── AC-EAI-26 — Kill during overlap stops further damage ─────────────────────

## GIVEN Fayde overlapping and timer running,
## WHEN enemy_killed fires for this enemy,
## THEN HitArea.monitoring is false and no further damage occurs.
func test_enemy_instance_kill_during_contact_overlap_stops_all_damage() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	# Add death animation so fallback timer is not armed (enemy stays alive for assertions).
	_add_death_animation(enemy)
	enemy._fayde_in_contact = true
	enemy._contact_timer = 0.15
	enemy._fayde_ref = fayde
	var hp0: int = HealthAndDamage._fayde_current_hp

	# Kill the enemy.
	enemy._on_enemy_killed(enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_bool((enemy.get_node("HitArea") as Area2D).monitoring).is_false()

	# Drive frames — DEAD state prevents any contact damage.
	HealthAndDamage.force_end_iframe_window()
	for _i: int in CONTACT_FRAMES:
		enemy._physics_process(DELTA)
	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp0)


# ── TR-EAI-007 — Status effects API stubs ────────────────────────────────────

## is_alive() returns true when CHASING, false when DEAD.
## apply_speed_modifier() and apply_stun() exist and do not crash (FP stubs).
func test_enemy_instance_status_api_stubs_and_is_alive_reflect_dead_state() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)

	# is_alive() when CHASING (default).
	assert_bool(enemy.is_alive()).is_true()

	# is_alive() when DEAD.
	enemy._state = EnemyInstance.EnemyState.DEAD
	assert_bool(enemy.is_alive()).is_false()

	# Stubs do not crash and do not change state.
	enemy._state = EnemyInstance.EnemyState.CHASING
	enemy.apply_speed_modifier(0.5)
	assert_bool(enemy.is_alive()).is_true()
	enemy.apply_stun(0.8)
	assert_bool(enemy.is_alive()).is_true()
