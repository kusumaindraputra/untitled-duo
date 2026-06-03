## death_sequencing_test.gd — Unit tests for EnemyInstance death sequencing (Story 004, EAI).
## Covers: AC-EAI-15 (simultaneous state changes on kill), AC-EAI-16 (death animation starts),
##         AC-EAI-17 (queue_free deferred after animation), AC-EAI-28 (instance ID guard),
##         AC-EAI-29 (fallback timer when no animation)
##
## Story Type: Integration (tests cross _on_enemy_killed signal handler + physics timer + queue_free)
## GdUnit4 v6.1.3 | Godot 4.6.2
extends GdUnitTestSuite

const DELTA: float = 1.0 / 60.0

## Frames to tick a 0.7s fallback timer to expiry at 60fps.
## DELTA = 1/60. 42 × (1/60) ≈ 0.6999... < 0.7, so tick 43 causes expiry.
## 43 ticks to fire queue_free(); process_frame delivers the deferred free.
const FRAMES_TO_DIE: int = 43


## Creates a combat-active EnemyInstance in the scene tree.
## add_child() is required: death handler uses $HitArea and $AnimationPlayer.
func _make_enemy() -> EnemyInstance:
	var e := EnemyInstance.new()
	e._combat_active = true
	add_child(e)
	return e


## Adds a "death" AnimationLibrary to the enemy's AnimationPlayer.
## Animation length 0.5s — long enough that it won't complete during state assertions.
func _add_death_animation(enemy: EnemyInstance) -> void:
	var lib := AnimationLibrary.new()
	var anim := Animation.new()
	anim.length = 0.5
	lib.add_animation(&"death", anim)
	(enemy.get_node("AnimationPlayer") as AnimationPlayer).add_animation_library(&"", lib)


# ── AC-EAI-15 — Simultaneous state changes on kill ───────────────────────────

## GIVEN enemy alive with contact timer running,
## WHEN _on_enemy_killed fires with matching instance_id,
## THEN all four state changes occur in the same call: DEAD, velocity=0, timer=0, monitoring=false.
func test_death_simultaneous_state_changes_on_kill() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	enemy._contact_timer = 0.15
	enemy._fayde_in_contact = true
	(enemy.get_node("HitArea") as Area2D).monitoring = true

	enemy._on_enemy_killed(enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_int(enemy._state).is_equal(EnemyInstance.EnemyState.DEAD)
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	assert_float(enemy._contact_timer).is_equal(0.0)
	assert_bool((enemy.get_node("HitArea") as Area2D).monitoring).is_false()


# ── AC-EAI-28 — Instance ID guard protects other enemies ─────────────────────

## GIVEN two enemies A and B in CHASING state,
## WHEN enemy_killed fires with B's instance_id on A's handler,
## THEN A's state is unchanged.
func test_death_instance_id_guard_protects_other_enemies() -> void:
	var enemy_a := _make_enemy()
	auto_free(enemy_a)
	var enemy_b := _make_enemy()
	auto_free(enemy_b)
	enemy_a.velocity = Vector2(80.0, 0.0)

	enemy_a._on_enemy_killed(enemy_b.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_int(enemy_a._state).is_equal(EnemyInstance.EnemyState.CHASING)
	assert_float(enemy_a.velocity.x).is_equal_approx(80.0, 0.01)
	assert_bool((enemy_a.get_node("AnimationPlayer") as AnimationPlayer).is_playing()).is_false()


# ── AC-EAI-16 — Death animation starts when available ────────────────────────

## GIVEN enemy has an AnimationPlayer with a "death" animation,
## WHEN _on_enemy_killed fires with matching instance_id,
## THEN AnimationPlayer is playing "death".
func test_death_starts_animation_when_available() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	_add_death_animation(enemy)

	enemy._on_enemy_killed(enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	var ap := enemy.get_node("AnimationPlayer") as AnimationPlayer
	assert_bool(ap.is_playing()).is_true()
	assert_str(ap.get_current_animation()).is_equal("death")


# ── AC-EAI-17 — queue_free is deferred after animation_finished ──────────────

## GIVEN enemy in the scene tree,
## WHEN _on_death_animation_finished fires,
## THEN node is still valid immediately after (deferred free),
## and invalid after the next process frame.
func test_death_queue_free_deferred_after_animation_finished() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)  # safety net — no-op if queue_free() already ran

	enemy._on_death_animation_finished(&"death")

	assert_bool(is_instance_valid(enemy)).is_true()

	await get_tree().process_frame
	assert_bool(is_instance_valid(enemy)).is_false()


# ── AC-EAI-29 — Fallback timer frees enemy when no animation ─────────────────

## GIVEN enemy AnimationPlayer has no "death" animation,
## WHEN _on_enemy_killed fires,
## THEN fallback timer is armed and enemy is freed after BASE_DEATH_DURATION.
func test_death_fallback_timer_frees_enemy_without_animation() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)  # safety net — no-op if queue_free() already ran

	enemy._on_enemy_killed(enemy.get_instance_id(), 0, GameEnums.DamageClass.NONE)

	assert_bool(enemy._death_fallback_active).is_true()
	assert_float(enemy._death_fallback_timer).is_equal_approx(EnemyInstance.BASE_DEATH_DURATION, 0.001)

	for _i: int in FRAMES_TO_DIE:
		enemy._physics_process(DELTA)

	await get_tree().process_frame
	assert_bool(is_instance_valid(enemy)).is_false()


# ── DEAD-state guard — double kill is a no-op ────────────────────────────────

## GIVEN enemy already in DEAD state,
## WHEN _on_enemy_killed fires again with the same matching instance_id,
## THEN the second call is a no-op: no second animation_finished connection added.
func test_death_double_kill_signal_is_no_op() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	_add_death_animation(enemy)
	var own_id: int = enemy.get_instance_id()

	enemy._on_enemy_killed(own_id, 0, GameEnums.DamageClass.NONE)
	# Enemy is now DEAD and animation is playing.
	assert_int(enemy._state).is_equal(EnemyInstance.EnemyState.DEAD)
	var ap := enemy.get_node("AnimationPlayer") as AnimationPlayer

	# Second kill signal — must be a no-op.
	enemy._on_enemy_killed(own_id, 0, GameEnums.DamageClass.NONE)

	# Only one CONNECT_ONE_SHOT connection was added; signal count stays at 1.
	assert_int(ap.animation_finished.get_connections().size()).is_equal(1)
