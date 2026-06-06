## combat_hud_test.gd — Unit tests for CombatHUD HP bar, dead state, and run reset.
##
## Coverage:
##   AC-HUD-01: HP bar value reaches target after drain duration elapses via _process
##   AC-HUD-02a: HP_BAR_DRAIN_DURATION constant == 0.15 (contract guard)
##   AC-HUD-03: hp_label updates immediately on damage_taken (same frame, no _process)
##   AC-HUD-07: Dead state — all H&D signals ignored after player_died
##   AC-HUD-08: Heal tint applied immediately; reverts to zone color after HEAL_TINT_DURATION
##   AC-HUD-09: HP_BAR_FILL_DURATION >= 0.15 (audio silence contract guard)
##   AC-HUD-20: run_started cancels in-flight animation and snaps HP to max
##   AC-HUD-21: run_started resets zone color and hides chain dots
##   AC-HUD-22: Mid-animation rapid hit starts new animation from current visual position
##
## Setup pattern:
##   - CombatHUD instantiated with CombatHUDScript.new() and add_child() — it connects
##     to Autoload signals in _ready(), which is fine since Autoloads are always present.
##   - set_process(false) enables manual time control via hud._process(delta).
##   - MockFayde (node in "player" group) simulates the player target.
##   - Teardown: remove_child() then free() (not queue_free() — headless exit 101 risk).
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const CombatHUDScript = preload("res://src/ui/combat_hud.gd")


# ── Inner classes ─────────────────────────────────────────────────────────────

## Minimal player stand-in — joins "player" group so H&D signal handlers route correctly.
class MockFayde extends Node:
	func _ready() -> void:
		add_to_group(&"player")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a CombatHUD instance in the scene tree with manual process control.
## Caller must call _teardown_hud() after each test.
func _make_hud() -> Node:
	var hud: Node = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)  # drive time manually via hud._process(delta)
	return hud


## Removes and frees a CombatHUD created by _make_hud().
func _teardown_hud(hud: Node) -> void:
	remove_child(hud)
	hud.free()


## Creates a MockFayde in the scene tree.
## Caller must call _teardown_fayde() after each test.
func _make_fayde() -> MockFayde:
	var fayde: MockFayde = MockFayde.new()
	add_child(fayde)
	return fayde


## Removes and frees a MockFayde created by _make_fayde().
func _teardown_fayde(fayde: MockFayde) -> void:
	remove_child(fayde)
	fayde.free()


# ── AC-HUD-01: HP bar drain animation completes after drain duration ──────────

## GIVEN CombatHUD in tree, hp_bar at 100, MockFayde in "player" group
## WHEN damage_taken(fayde, 20, 80) emits and _process(0.16) is called (> 0.15s)
## THEN hp_bar.value == 80.0
func test_hp_bar_drain_completes_after_drain_duration() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	HealthAndDamage.damage_taken.emit(fayde, 20, 80)
	hud._process(0.16)

	assert_float(hud.hp_bar.value).is_equal_approx(80.0, 0.1)

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-02a: HP_BAR_DRAIN_DURATION constant guard ─────────────────────────

## GIVEN CombatHUD loaded
## WHEN HP_BAR_DRAIN_DURATION constant is read
## THEN it equals exactly 0.15
func test_hp_bar_drain_duration_constant_equals_0_15() -> void:
	var hud: Node = _make_hud()

	assert_float(hud.HP_BAR_DRAIN_DURATION).is_equal(0.15)

	_teardown_hud(hud)


# ── AC-HUD-03: HP label updates immediately on damage_taken ──────────────────

## GIVEN CombatHUD in tree, hp_bar at 100, MockFayde in "player" group
## WHEN damage_taken(fayde, 20, 80) emits (NO _process call)
## THEN hp_label.text == "80 / 100"
func test_hp_label_updates_immediately_on_damage_taken() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	HealthAndDamage.damage_taken.emit(fayde, 20, 80)

	assert_str(hud.hp_label.text).is_equal("80 / 100")

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-07: Dead state ignores all subsequent HP signals ──────────────────

## GIVEN player_died fires (hp_bar.value snaps to 0)
## WHEN damage_taken, health_restored, and player_hp_zone_changed each fire
## THEN hp_bar.value stays 0 AND hp_bar.modulate is unchanged for all three
func test_dead_state_ignores_subsequent_hp_signals() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	HealthAndDamage.player_died.emit()
	assert_float(hud.hp_bar.value).is_equal_approx(0.0, 0.01)
	# Verify post-death modulate is the FULL zone color (no special death tint applied)
	assert_bool(hud.hp_bar.modulate == hud.HP_COLOR_FULL).is_true()

	var modulate_after_death: Color = hud.hp_bar.modulate

	# All three subsequent signals must be ignored
	HealthAndDamage.damage_taken.emit(fayde, 10, 0)
	HealthAndDamage.health_restored.emit(fayde, 6, 6)
	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.FULL)

	assert_float(hud.hp_bar.value).is_equal_approx(0.0, 0.01)
	assert_bool(hud.hp_bar.modulate == modulate_after_death).is_true()

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-08 (part 1): Heal tint applied immediately on health_restored ─────

## GIVEN hp_bar.value = 60, FULL zone (warm white modulate)
## WHEN health_restored(fayde, 6, 66) emits (NO _process call)
## THEN hp_bar.modulate == HEAL_TINT_COLOR immediately
## AND  _hp_target == 66.0 (animation was started toward 66)
func test_health_restored_applies_heal_tint_immediately() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	hud.hp_bar.value = 60.0
	HealthAndDamage.health_restored.emit(fayde, 6, 66)

	assert_bool(hud.hp_bar.modulate == Color(0.6, 1.0, 0.6, 1.0)).is_true()
	assert_float(hud._hp_target).is_equal_approx(66.0, 0.01)

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-08 (part 2): Heal tint reverts after HEAL_TINT_DURATION ───────────

## GIVEN health_restored emitted (heal tint active, HP animation toward 66)
## WHEN _process(0.21) is called (> HP_BAR_FILL_DURATION == 0.20s AND > HEAL_TINT_DURATION == 0.20s)
## THEN hp_bar.modulate reverts to HP_COLOR_FULL AND hp_bar.value has reached 66
## Note: both the fill animation timer and the tint timer share the same 0.20s duration,
## so a single _process(0.21) advances both past expiry in the same frame.
func test_heal_tint_reverts_after_tint_duration() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	hud.hp_bar.value = 60.0
	HealthAndDamage.health_restored.emit(fayde, 6, 66)
	hud._process(0.21)

	assert_bool(hud.hp_bar.modulate == hud.HP_COLOR_FULL).is_true()
	assert_float(hud.hp_bar.value).is_equal_approx(66.0, 0.1)

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-09: HP_BAR_FILL_DURATION satisfies audio silence contract ──────────

## GIVEN CombatHUD loaded
## THEN HP_BAR_FILL_DURATION >= 0.15 (audio silence contract for sfx_fayde_heal)
func test_hp_bar_fill_duration_satisfies_audio_silence_contract() -> void:
	var hud: Node = _make_hud()

	assert_float(hud.HP_BAR_FILL_DURATION).is_greater_equal(0.15)

	_teardown_hud(hud)


# ── AC-HUD-20: run_started cancels animation and resets HP to max ─────────────

## GIVEN mid-drain animation active (bar animating toward 60)
## WHEN run_started emits mid-animation (after _process(0.07))
## THEN hp_bar.value == FAYDE_MAX_HP (100) immediately; no further animation toward 60
func test_run_started_cancels_animation_and_resets_to_max() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	HealthAndDamage.damage_taken.emit(fayde, 40, 60)
	hud._process(0.07)  # advance mid-animation; value should be between 60 and 100

	GameStateManager.run_started.emit()

	assert_float(hud.hp_bar.value).is_equal_approx(float(hud.FAYDE_MAX_HP), 0.01)

	# Reset RunManager _run_active so subsequent tests don't trigger push_error
	GameStateManager.run_ended.emit(false)

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-21: run_started hides chain dots and resets zone color ─────────────

## GIVEN chain_dots_container.visible=true; DESPERATE zone active (both modulate and _current_zone)
## WHEN run_started emits
## THEN chain_dots_container.visible == false; hp_bar.modulate == HP_COLOR_FULL
func test_run_started_hides_chain_dots_and_resets_zone() -> void:
	var hud: Node = _make_hud()

	hud.chain_dots_container.visible = true
	# Set both modulate AND _current_zone via signal so internal state matches visual state
	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.DESPERATE)

	GameStateManager.run_started.emit()

	assert_bool(hud.chain_dots_container.visible).is_false()
	assert_bool(hud.hp_bar.modulate == hud.HP_COLOR_FULL).is_true()

	# Reset RunManager _run_active so subsequent tests don't trigger push_error
	GameStateManager.run_ended.emit(false)

	_teardown_hud(hud)


# ── AC-HUD-22: Mid-animation rapid hit starts new animation from current value ─

## GIVEN bar at 100; drain animation started toward 60; _process(0.07) advances mid-animation
## WHEN second damage_taken(fayde, 10, 50) fires
## THEN _hp_start equals the visual mid-animation value (not original 100)
func test_mid_tween_rapid_hit_starts_from_current_value() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	HealthAndDamage.damage_taken.emit(fayde, 40, 60)
	hud._process(0.07)  # advance mid-animation; bar value is between 60 and 100

	var v_mid: float = hud.hp_bar.value

	HealthAndDamage.damage_taken.emit(fayde, 10, 50)

	# _hp_start must match v_mid (captured from hp_bar.value, not from 100)
	assert_float(hud._hp_start).is_equal_approx(v_mid, 0.01)

	_teardown_fayde(fayde)
	_teardown_hud(hud)
