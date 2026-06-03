## contact_attack_test.gd — Unit tests for EnemyInstance contact attack (Story 003, EAI).
## Covers: AC-EAI-10 (initial hit + DEAD/inactive edge cases), AC-EAI-11 (repeat timer),
##         AC-EAI-12 (timer disarm), AC-EAI-13 (constant value), AC-EAI-14 (ratio constraint)
##
## NOTE: signal monitoring on Autoload nodes (HealthAndDamage) causes GdUnit4 to add them
## to its auto-cleanup list and free() them between tests, breaking subsequent tests.
## Instead, damage verification uses _fayde_current_hp delta — simpler and Autoload-safe.
##
## GdUnit4 v6.1.3 | Godot 4.6.2
extends GdUnitTestSuite

const BASE_DAMAGE: float = 8.0
const DELTA: float = 1.0 / 60.0

## Frames needed to tick a 0.3s timer to expiry at 60fps.
## ceil(0.3 × 60) = 18; +1 safety margin for float rounding (18 × 1/60 ≈ 0.2999... > 0).
const FRAMES_TO_EXPIRE: int = 19


## Reset H&D Fayde state before each test to isolate i-frame, HP, and zone side-effects.
func before_test() -> void:
	HealthAndDamage.force_end_iframe_window()
	HealthAndDamage._fayde_current_hp = HealthAndDamage.FAYDE_MAX_HP
	HealthAndDamage._fayde_dead = false
	HealthAndDamage._current_zone = GameEnums.HPZone.FULL


## Creates a combat-active EnemyInstance with non-zero base_damage.
## Non-zero base_damage is required: H&D only decrements HP when final_damage > 0.
func _make_enemy() -> EnemyInstance:
	var e := EnemyInstance.new()
	e._base_damage = BASE_DAMAGE
	e._combat_active = true
	add_child(e)
	return e


## Creates a Node2D in the "player" group — satisfies H&D's is_in_group("player") guard.
func _make_fayde() -> Node2D:
	var n := Node2D.new()
	n.add_to_group(&"player")
	add_child(n)
	return n


# ── AC-EAI-10 — body_entered fires immediate damage ──────────────────────────

## GIVEN enemy alive in CHASING state with combat active,
## WHEN _on_hitarea_body_entered fires with a player-group node,
## THEN Fayde HP decreases by BASE_DAMAGE, _fayde_in_contact armed, timer set.
func test_contact_body_entered_immediate_damage_applied() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	var hp_before: int = HealthAndDamage._fayde_current_hp

	enemy._on_hitarea_body_entered(fayde)

	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp_before - int(BASE_DAMAGE))
	assert_bool(enemy._fayde_in_contact).is_true()
	assert_float(enemy._contact_timer).is_equal_approx(EnemyInstance.ENEMY_MIN_CONTACT_INTERVAL, 0.001)


## GIVEN enemy in DEAD state,
## WHEN body_entered fires,
## THEN Fayde HP unchanged (no damage).
func test_contact_body_entered_dead_state_no_damage() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	enemy._state = EnemyInstance.EnemyState.DEAD
	var hp_before: int = HealthAndDamage._fayde_current_hp

	enemy._on_hitarea_body_entered(fayde)

	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp_before)


## GIVEN enemy with _combat_active = false,
## WHEN body_entered fires,
## THEN Fayde HP unchanged (no damage).
func test_contact_body_entered_combat_inactive_no_damage() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	enemy._combat_active = false
	var hp_before: int = HealthAndDamage._fayde_current_hp

	enemy._on_hitarea_body_entered(fayde)

	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp_before)


# ── AC-EAI-11 — timer expiry fires repeat damage ─────────────────────────────

## GIVEN _fayde_in_contact = true and _contact_timer armed at ENEMY_MIN_CONTACT_INTERVAL,
## WHEN FRAMES_TO_EXPIRE physics frames are ticked,
## THEN Fayde HP decreases by BASE_DAMAGE (one repeat hit) and timer re-armed.
func test_contact_timer_expiry_fires_repeat_damage() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	enemy._fayde_in_contact = true
	enemy._contact_timer = EnemyInstance.ENEMY_MIN_CONTACT_INTERVAL
	enemy._fayde_ref = fayde
	var hp_before: int = HealthAndDamage._fayde_current_hp

	for _i: int in FRAMES_TO_EXPIRE:
		enemy._physics_process(DELTA)

	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp_before - int(BASE_DAMAGE))
	assert_float(enemy._contact_timer).is_greater(0.0)


# ── AC-EAI-12 — body_exited stops timer and prevents further damage ───────────

## GIVEN timer mid-interval and Fayde in contact,
## WHEN body_exited fires and 30 more physics frames are ticked,
## THEN _contact_timer == 0, _fayde_in_contact = false, Fayde HP unchanged.
func test_contact_body_exited_stops_timer_no_further_damage() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	enemy._fayde_in_contact = true
	enemy._contact_timer = 0.15
	enemy._fayde_ref = fayde

	enemy._on_hitarea_body_exited(fayde)

	assert_float(enemy._contact_timer).is_equal(0.0)
	assert_bool(enemy._fayde_in_contact).is_false()

	var hp_before: int = HealthAndDamage._fayde_current_hp
	for _i: int in 30:
		enemy._physics_process(DELTA)
	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp_before)


# ── AC-EAI-13 — ENEMY_MIN_CONTACT_INTERVAL == 0.3 ────────────────────────────

## The class constant must equal exactly 0.3 seconds.
func test_enemy_min_contact_interval_equals_0_3() -> void:
	assert_float(EnemyInstance.ENEMY_MIN_CONTACT_INTERVAL).is_equal_approx(0.3, 0.001)


# ── AC-EAI-14 — i-frame ratio constraint ─────────────────────────────────────

## ENEMY_MIN_CONTACT_INTERVAL >= 0.3 AND FAYDE_IFRAME_DURATION / interval >= 1.0
## ensures one full H&D i-frame fits between consecutive contact hits (TR-EAI-003).
func test_contact_interval_iframe_ratio_satisfies_hd_guarantee() -> void:
	assert_float(EnemyInstance.ENEMY_MIN_CONTACT_INTERVAL).is_greater_equal(0.3)
	var ratio: float = (
		HealthAndDamage.FAYDE_IFRAME_DURATION / EnemyInstance.ENEMY_MIN_CONTACT_INTERVAL
	)
	assert_float(ratio).is_greater_equal(1.0)


# ── AC-EAI-10 edge — duplicate body_entered guard ────────────────────────────

## Calling body_entered twice without an intervening body_exited must apply
## damage exactly once (duplicate signal guard via _fayde_in_contact check).
func test_contact_body_entered_double_fire_applies_damage_once() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var fayde := _make_fayde()
	auto_free(fayde)
	var hp_before: int = HealthAndDamage._fayde_current_hp

	enemy._on_hitarea_body_entered(fayde)
	enemy._on_hitarea_body_entered(fayde)  # second signal — must be no-op

	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp_before - int(BASE_DAMAGE))


# ── AC-EAI-10 edge — non-player body guards ──────────────────────────────────

## body_entered with a node NOT in the "player" group must not apply damage
## and must not set _fayde_in_contact.
func test_contact_body_entered_non_player_body_no_damage() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var non_player := Node2D.new()
	add_child(non_player)
	auto_free(non_player)
	var hp_before: int = HealthAndDamage._fayde_current_hp

	enemy._on_hitarea_body_entered(non_player)

	assert_int(HealthAndDamage._fayde_current_hp).is_equal(hp_before)
	assert_bool(enemy._fayde_in_contact).is_false()


## body_exited with a node NOT in the "player" group must not change contact state.
func test_contact_body_exited_non_player_body_no_state_change() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	var non_player := Node2D.new()
	add_child(non_player)
	auto_free(non_player)
	enemy._fayde_in_contact = true
	enemy._contact_timer = 0.15

	enemy._on_hitarea_body_exited(non_player)

	assert_bool(enemy._fayde_in_contact).is_true()
	assert_float(enemy._contact_timer).is_equal(0.15)


# ── _on_preparation_started resets contact state ─────────────────────────────

## preparation_started must clear both _fayde_in_contact and _contact_timer
## so stale overlap state from the previous wave does not bleed into the next.
func test_contact_preparation_started_resets_contact_state() -> void:
	var enemy := _make_enemy()
	auto_free(enemy)
	enemy._fayde_in_contact = true
	enemy._contact_timer = 0.15

	enemy._on_preparation_started()

	assert_bool(enemy._fayde_in_contact).is_false()
	assert_float(enemy._contact_timer).is_equal(0.0)
	assert_bool(enemy._combat_active).is_false()
