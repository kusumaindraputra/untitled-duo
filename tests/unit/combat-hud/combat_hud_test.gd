## combat_hud_test.gd — Unit tests for CombatHUD HP bar, dead state, run reset, and damage labels.
##
## Coverage:
##   AC-HUD-01: HP bar value reaches target after drain duration elapses via _process
##   AC-HUD-02a: HP_BAR_DRAIN_DURATION constant == 0.15 (contract guard)
##   AC-HUD-03: hp_label updates immediately on damage_taken (same frame, no _process)
##   AC-HUD-07: Dead state — all H&D signals ignored after player_died
##   AC-HUD-08: Heal tint applied immediately; reverts to zone color after HEAL_TINT_DURATION
##   AC-HUD-09: HP_BAR_FILL_DURATION >= 0.15 (audio silence contract guard)
##   AC-HUD-13: Damage label spawns on enemy hit with correct text
##   AC-HUD-14: Same-frame spell_hit_element → element color on label
##   AC-HUD-15: Wrong-target spell_hit_element does not color enemy_B's label
##   AC-HUD-16: No spell_hit_element → white label
##   AC-HUD-17: Fayde-received damage → grey label (#AAAAAA)
##   AC-HUD-18: 13th damage evicts oldest label before spawn; pool ≤ 12
##   AC-HUD-19: Below-cap damage → no eviction; count increments
##   AC-HUD-20: run_started cancels in-flight animation and snaps HP to max
##   AC-HUD-21: run_started resets zone color and hides chain dots
##   AC-HUD-22: Mid-animation rapid hit starts new animation from current visual position
##   AC-HUD-27: Chain dots positioned above Fayde in screen-space after chain_index_changed
##   AC-HUD-28: Chain dots track Fayde X position when she moves 64px right
##   AC-HUD-29: Chain dots clamped to viewport top when Fayde is near the top edge
##   AC-HUD-30: preparation_started stops chain dot position tracking
##   AC-HUD-31: health_restored with player target spawns "+N HP" label in HEAL_LABEL_COLOR
##   AC-HUD-32: health_restored with enemy target does NOT spawn a heal label
##
## Setup pattern:
##   - CombatHUD instantiated with CombatHUDScript.new() and add_child() — it connects
##     to Autoload signals in _ready(), which is fine since Autoloads are always present.
##   - set_process(false) enables manual time control via hud._process(delta).
##   - MockFayde (node in "player" group) simulates the player target.
##   - MockEnemy (plain Node, not in any group) simulates an enemy target.
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


## Minimal enemy stand-in — plain Node, not in any group.
## Not a Node2D, so world_pos defaults to Vector2.ZERO in _spawn_damage_label.
class MockEnemy extends Node:
	pass


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


## Creates a MockEnemy in the scene tree.
## Caller must call _teardown_enemy() after each test.
func _make_enemy() -> MockEnemy:
	var enemy: MockEnemy = MockEnemy.new()
	add_child(enemy)
	return enemy


## Removes and frees a MockEnemy created by _make_enemy().
func _teardown_enemy(enemy: MockEnemy) -> void:
	remove_child(enemy)
	enemy.free()


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


# ── AC-HUD-04: Zone CAREFUL → amber bar modulate and label color ──────────────

## GIVEN CombatHUD in tree; zone = FULL (default)
## WHEN player_hp_zone_changed(HPZone.CAREFUL) emits
## THEN hp_bar.modulate == Color("#FFA500") AND hp_label font_color == Color("#FFA500")
func test_zone_careful_applies_amber_color_to_bar_and_label() -> void:
	var hud: Node = _make_hud()

	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.CAREFUL)

	assert_bool(hud.hp_bar.modulate == Color("#FFA500")).is_true()
	assert_bool(hud.hp_label.get_theme_color(&"font_color") == Color("#FFA500")).is_true()

	_teardown_hud(hud)


# ── AC-HUD-05: Zone DESPERATE → red bar modulate and label color ──────────────

## GIVEN CombatHUD in tree; zone = CAREFUL
## WHEN player_hp_zone_changed(HPZone.DESPERATE) emits
## THEN hp_bar.modulate == Color("#FF3333") AND hp_label font_color == Color("#FF3333")
func test_zone_desperate_applies_red_color_to_bar_and_label() -> void:
	var hud: Node = _make_hud()

	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.CAREFUL)
	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.DESPERATE)

	assert_bool(hud.hp_bar.modulate == Color("#FF3333")).is_true()
	assert_bool(hud.hp_label.get_theme_color(&"font_color") == Color("#FF3333")).is_true()

	_teardown_hud(hud)


# ── AC-HUD-06: Zone FULL from DESPERATE → warm white bar, white label ─────────

## GIVEN zone = DESPERATE (red modulate)
## WHEN player_hp_zone_changed(HPZone.FULL) emits
## THEN hp_bar.modulate == Color("#F5F0E8") AND hp_label font_color == Color("#FFFFFF")
func test_zone_full_from_desperate_applies_warm_white_to_bar_and_white_to_label() -> void:
	var hud: Node = _make_hud()

	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.DESPERATE)
	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.FULL)

	assert_bool(hud.hp_bar.modulate == Color("#F5F0E8")).is_true()
	assert_bool(hud.hp_label.get_theme_color(&"font_color") == Color("#FFFFFF")).is_true()

	_teardown_hud(hud)


# ── AC-HUD-23: Heal tint reverts to DESPERATE zone color (not warm white) ─────

## GIVEN zone = DESPERATE (red modulate; _current_zone set internally)
## WHEN health_restored(fayde, 6, 26) emits (green tint applied) AND _process(0.21) expires tint
## THEN hp_bar.modulate == Color("#FF3333") (DESPERATE red — NOT warm white)
func test_heal_tint_reverts_to_desperate_zone_color_not_warm_white() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	# Set zone to DESPERATE so _current_zone is tracked internally
	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.DESPERATE)
	# Set bar value below max so health_restored routing doesn't no-op
	hud.hp_bar.value = 20.0
	# Emit heal — green tint applied, _tint_timer starts
	HealthAndDamage.health_restored.emit(fayde, 6, 26)
	# Advance past HEAL_TINT_DURATION (0.20s) — tint timer expires, _revert_zone_color() fires
	hud._process(0.21)

	assert_bool(hud.hp_bar.modulate == Color("#FF3333")).is_true()

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-25: Zone exit from DESPERATE stops pulse and resets scale ──────────

## GIVEN zone = DESPERATE (pulse is active; is_pulse_active() == true)
## WHEN player_hp_zone_changed(HPZone.CAREFUL) emits
## THEN is_pulse_active() == false AND hp_bar.scale == Vector2(1.0, 1.0)
func test_zone_exit_from_desperate_stops_pulse_and_resets_scale() -> void:
	var hud: Node = _make_hud()

	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.DESPERATE)
	# Pulse tween is valid immediately after creation (before any _process)
	assert_bool(hud.is_pulse_active()).is_true()

	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.CAREFUL)

	assert_bool(hud.is_pulse_active()).is_false()
	assert_bool(hud.hp_bar.scale == Vector2(1.0, 1.0)).is_true()

	_teardown_hud(hud)


# ── Dead-state guard prevents pulse on DESPERATE zone signal after death ────────

## GIVEN player_died fired (_dead == true; any prior pulse killed)
## WHEN player_hp_zone_changed(HPZone.DESPERATE) fires
## THEN is_pulse_active() == false (dead guard fires before _start_pulse)
func test_dead_state_prevents_pulse_on_desperate_zone() -> void:
	var hud: Node = _make_hud()

	HealthAndDamage.player_died.emit()
	HealthAndDamage.player_hp_zone_changed.emit(GameEnums.HPZone.DESPERATE)

	assert_bool(hud.is_pulse_active()).is_false()

	_teardown_hud(hud)


# ── AC-HUD-13: Damage label spawns on enemy hit with correct text ─────────────

## GIVEN CombatHUD in tree; MockEnemy not in "player" group
## WHEN damage_taken(enemy, 25, 10) emits
## THEN one Label in _active_damage_labels; text == "25"
func test_damage_label_spawns_on_enemy_hit_with_correct_text() -> void:
	var hud: Node = _make_hud()
	var enemy: MockEnemy = _make_enemy()

	HealthAndDamage.damage_taken.emit(enemy, 25, 10)

	assert_int(hud._active_damage_labels.size()).is_equal(1)
	assert_str(hud._active_damage_labels[0].text).is_equal("25")

	_teardown_enemy(enemy)
	_teardown_hud(hud)


# ── AC-HUD-14: Same-frame spell_hit_element gives label element color ─────────

## GIVEN spell_hit_element(enemy, 2) emitted (Stormgold, prana_type_id=2)
## WHEN damage_taken(enemy, 23, 12) emits in the same frame (no await between)
## THEN label font_color == Color("#FFCC00") (Stormgold: prana_lightning.tres Color(1,0.8,0,1))
func test_damage_label_uses_element_color_when_spell_hit_element_precedes_damage() -> void:
	var hud: Node = _make_hud()
	var enemy: MockEnemy = _make_enemy()

	SpellCastingEffects.spell_hit_element.emit(enemy, 2)
	HealthAndDamage.damage_taken.emit(enemy, 23, 12)

	assert_int(hud._active_damage_labels.size()).is_equal(1)
	var label_color: Color = hud._active_damage_labels[0].get_theme_color(&"font_color")
	assert_bool(label_color == Color("#FFCC00")).is_true()

	_teardown_enemy(enemy)
	_teardown_hud(hud)


# ── AC-HUD-15: Wrong-target element signal leaves enemy_B label white ─────────

## GIVEN spell_hit_element(enemy_A, 2) emitted
## WHEN damage_taken(enemy_B, 16, 10) emits (B ≠ A)
## THEN label for enemy_B font_color == Color("#FFFFFF") (element signal for A not applied to B)
func test_damage_label_color_not_applied_for_wrong_target() -> void:
	var hud: Node = _make_hud()
	var enemy_a: MockEnemy = _make_enemy()
	var enemy_b: MockEnemy = _make_enemy()

	SpellCastingEffects.spell_hit_element.emit(enemy_a, 2)
	HealthAndDamage.damage_taken.emit(enemy_b, 16, 10)

	assert_int(hud._active_damage_labels.size()).is_equal(1)
	var label_color: Color = hud._active_damage_labels[0].get_theme_color(&"font_color")
	assert_bool(label_color == Color("#FFFFFF")).is_true()

	_teardown_enemy(enemy_a)
	_teardown_enemy(enemy_b)
	_teardown_hud(hud)


# ── AC-HUD-16: No element signal → white label ────────────────────────────────

## GIVEN no spell_hit_element emitted for mock enemy
## WHEN damage_taken(enemy, 16, 10) emits
## THEN label font_color == Color("#FFFFFF")
func test_damage_label_defaults_to_white_without_element_signal() -> void:
	var hud: Node = _make_hud()
	var enemy: MockEnemy = _make_enemy()

	HealthAndDamage.damage_taken.emit(enemy, 16, 10)

	assert_int(hud._active_damage_labels.size()).is_equal(1)
	var label_color: Color = hud._active_damage_labels[0].get_theme_color(&"font_color")
	assert_bool(label_color == Color("#FFFFFF")).is_true()

	_teardown_enemy(enemy)
	_teardown_hud(hud)


# ── AC-HUD-17: Fayde-received damage → grey label ────────────────────────────

## GIVEN MockFayde in "player" group
## WHEN damage_taken(fayde, 20, 80) emits
## THEN label font_color == Color("#AAAAAA")
func test_damage_label_is_grey_for_fayde_hit() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	HealthAndDamage.damage_taken.emit(fayde, 20, 80)

	assert_int(hud._active_damage_labels.size()).is_equal(1)
	var label_color: Color = hud._active_damage_labels[0].get_theme_color(&"font_color")
	assert_bool(label_color == Color("#AAAAAA")).is_true()

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-18: 13th damage evicts oldest before spawn; pool count ≤ 12 ────────

## GIVEN 12 Labels pre-added to hud._active_damage_labels as hud children
## WHEN damage_taken(enemy, 5, 5) emits (spawns 13th)
## THEN oldest label was freed; _active_damage_labels.size() == 12; new label text == "5"
func test_damage_label_evicts_oldest_when_pool_at_cap() -> void:
	var hud: Node = _make_hud()
	var enemy: MockEnemy = _make_enemy()

	# Pre-populate pool at cap; labels are hud children so they free with hud in teardown
	var first_label: Label = null
	for i: int in range(12):
		var fake := Label.new()
		fake.text = "fake_%d" % i
		hud.add_child(fake)
		hud._active_damage_labels.append(fake)
		if i == 0:
			first_label = fake

	HealthAndDamage.damage_taken.emit(enemy, 5, 5)

	assert_bool(is_instance_valid(first_label)).is_false()
	assert_int(hud._active_damage_labels.size()).is_equal(12)
	assert_str(hud._active_damage_labels[-1].text).is_equal("5")

	_teardown_enemy(enemy)
	_teardown_hud(hud)


# ── AC-HUD-19: Below-cap damage → no eviction; count increments ──────────────

## GIVEN 5 Labels pre-added to hud._active_damage_labels as hud children
## WHEN damage_taken(enemy, 8, 8) emits
## THEN no label evicted; _active_damage_labels.size() == 6
func test_damage_label_no_eviction_when_below_pool_cap() -> void:
	var hud: Node = _make_hud()
	var enemy: MockEnemy = _make_enemy()

	for i: int in range(5):
		var fake := Label.new()
		hud.add_child(fake)
		hud._active_damage_labels.append(fake)

	HealthAndDamage.damage_taken.emit(enemy, 8, 8)

	assert_int(hud._active_damage_labels.size()).is_equal(6)

	_teardown_enemy(enemy)
	_teardown_hud(hud)


# ── AC-HUD-10: Chain dots appear with Prana color on chain_index_changed ────

## GIVEN combo_resolved emitted with primary_type=2 (Stormgold)
## WHEN chain_index_changed(0, 2) fires
## THEN chain_dots_container visible; 2 dots; dot[0].color == Stormgold; dot[1].color == grey
func test_chain_dots_appear_with_prana_color_on_chain_index_changed() -> void:
	var hud: Node = _make_hud()

	var effect := SpellEffect.new()
	effect.primary_type = 2
	CombinationResolution.combo_resolved.emit(effect)
	SpellCastingEffects.chain_index_changed.emit(0, 2)

	assert_bool(hud.chain_dots_container.visible).is_true()
	assert_int(hud.chain_dots_container.get_child_count()).is_equal(2)
	var dot0: ColorRect = hud.chain_dots_container.get_child(0)
	var dot1: ColorRect = hud.chain_dots_container.get_child(1)
	assert_bool(dot0.color == PranaCatalog.get_type(2).color).is_true()
	assert_bool(dot1.color == Color("#888888")).is_true()

	_teardown_hud(hud)


# ── AC-HUD-11: Second chain_index_changed advances the active dot ─────────────

## GIVEN combo_resolved with primary_type=0 (Ashfire); chain_index_changed(0, 2) already fired
## WHEN chain_index_changed(1, 2) fires
## THEN dot[1].color == Ashfire color; dot[0].color == grey
func test_chain_dots_advance_active_dot_on_second_chain_index_changed() -> void:
	var hud: Node = _make_hud()

	var effect := SpellEffect.new()
	effect.primary_type = 0
	CombinationResolution.combo_resolved.emit(effect)
	SpellCastingEffects.chain_index_changed.emit(0, 2)
	SpellCastingEffects.chain_index_changed.emit(1, 2)

	assert_int(hud.chain_dots_container.get_child_count()).is_equal(2)
	var dot0: ColorRect = hud.chain_dots_container.get_child(0)
	var dot1: ColorRect = hud.chain_dots_container.get_child(1)
	# dot1 is the active dot (index 1): full prana color + animation
	assert_bool(dot1.color == PranaCatalog.get_type(0).color).is_true()
	# dot0 is the completed dot (index 0): dimmed prana color (50% alpha trail marker)
	var ashfire_color: Color = PranaCatalog.get_type(0).color
	assert_bool(dot0.color.r == ashfire_color.r).is_true()
	assert_bool(dot0.color.g == ashfire_color.g).is_true()
	assert_bool(dot0.color.b == ashfire_color.b).is_true()
	assert_bool(dot0.color.a < 1.0).is_true()  # dimmed

	_teardown_hud(hud)


# ── AC-HUD-12: preparation_started hides chain dots ──────────────────────────

## GIVEN chain dots are visible (combo_resolved + chain_index_changed fired)
## WHEN preparation_started fires
## THEN chain_dots_container.visible == false
func test_preparation_started_hides_chain_dots() -> void:
	var hud: Node = _make_hud()

	var effect := SpellEffect.new()
	effect.primary_type = 0
	CombinationResolution.combo_resolved.emit(effect)
	SpellCastingEffects.chain_index_changed.emit(0, 2)
	assert_bool(hud.chain_dots_container.visible).is_true()

	GameStateManager.preparation_started.emit(0, 1)

	assert_bool(hud.chain_dots_container.visible).is_false()

	_teardown_hud(hud)


# ── AC-HUD-27: Chain dots appear above Fayde in screen-space after chain_index_changed ──

## GIVEN CombatHUD in tree; fayde_node at (200, 200); combo_resolved(type=0) + chain_index_changed(0,2) fired
## WHEN one _process frame elapses
## THEN chain_dots_container.position.y < fayde screen-Y (dots above Fayde)
func test_chain_dots_positioned_above_fayde_in_screen_space() -> void:
	var hud: Node = _make_hud()
	var fayde := Node2D.new()
	add_child(fayde)
	fayde.global_position = Vector2(200.0, 200.0)
	hud.fayde_node = fayde

	var effect := SpellEffect.new()
	effect.primary_type = 0
	CombinationResolution.combo_resolved.emit(effect)
	SpellCastingEffects.chain_index_changed.emit(0, 2)
	hud._process(0.016)

	var canvas_xform: Transform2D = hud.get_viewport().get_canvas_transform()
	var fayde_screen_y: float = (canvas_xform * fayde.global_position).y
	# Verify dots are offset above Fayde by at least DOT_OFFSET_ABOVE_PLAYER (not just any upward shift).
	assert_float(hud.chain_dots_container.position.y).is_less_equal(fayde_screen_y - hud.DOT_OFFSET_ABOVE_PLAYER)

	remove_child(fayde)
	fayde.free()
	_teardown_hud(hud)


# ── AC-HUD-28: Chain dots track Fayde position when she moves ─────────────────

## GIVEN dots visible; fayde_node at (200, 200); one frame processed
## WHEN fayde_node.global_position set to (264, 200); one more _process frame
## THEN chain_dots_container.position.x has shifted ~64px (tracks Fayde in X)
func test_chain_dots_track_fayde_position_when_she_moves() -> void:
	var hud: Node = _make_hud()
	var fayde := Node2D.new()
	add_child(fayde)
	fayde.global_position = Vector2(200.0, 200.0)
	hud.fayde_node = fayde

	var effect := SpellEffect.new()
	effect.primary_type = 0
	CombinationResolution.combo_resolved.emit(effect)
	SpellCastingEffects.chain_index_changed.emit(0, 2)
	hud._process(0.016)
	var x_before: float = hud.chain_dots_container.position.x

	fayde.global_position = Vector2(264.0, 200.0)
	hud._process(0.016)
	var x_after: float = hud.chain_dots_container.position.x

	var delta_x: float = x_after - x_before
	# HBoxContainer layout size may stabilize between frames (±8px centering shift),
	# so allow ±10px tolerance around the expected 64px movement.
	assert_float(absf(delta_x - 64.0)).is_less(10.0)

	remove_child(fayde)
	fayde.free()
	_teardown_hud(hud)


# ── AC-HUD-29: Chain dots clamped to viewport top when Fayde is near top edge ─

## GIVEN fayde_node at (320, 8) — near top of screen; DOT_OFFSET_ABOVE_PLAYER = 48
## WHEN chain_index_changed(0, 1) fires and one _process frame elapses
## THEN chain_dots_container.global_position.y >= 0.0 (not off-screen)
func test_chain_dots_clamped_when_fayde_near_top_edge() -> void:
	var hud: Node = _make_hud()
	var fayde := Node2D.new()
	add_child(fayde)
	fayde.global_position = Vector2(320.0, 8.0)
	hud.fayde_node = fayde

	var effect := SpellEffect.new()
	effect.primary_type = 0
	CombinationResolution.combo_resolved.emit(effect)
	SpellCastingEffects.chain_index_changed.emit(0, 1)
	hud._process(0.016)

	assert_float(hud.chain_dots_container.global_position.y).is_greater_equal(0.0)

	remove_child(fayde)
	fayde.free()
	_teardown_hud(hud)


# ── AC-HUD-30: preparation_started stops chain dot position tracking ──────────

## GIVEN dots visible and tracking fayde_node at (200, 200)
## WHEN preparation_started fires; fayde_node moves to (400, 200); one _process frame
## THEN chain_dots_container.visible == false AND position.x unchanged
func test_preparation_started_stops_chain_dot_position_tracking() -> void:
	var hud: Node = _make_hud()
	var fayde := Node2D.new()
	add_child(fayde)
	fayde.global_position = Vector2(200.0, 200.0)
	hud.fayde_node = fayde

	var effect := SpellEffect.new()
	effect.primary_type = 0
	CombinationResolution.combo_resolved.emit(effect)
	SpellCastingEffects.chain_index_changed.emit(0, 2)
	hud._process(0.016)

	GameStateManager.preparation_started.emit(0, 1)
	assert_bool(hud.chain_dots_container.visible).is_false()
	var x_locked: float = hud.chain_dots_container.position.x

	fayde.global_position = Vector2(400.0, 200.0)
	hud._process(0.016)

	assert_float(hud.chain_dots_container.position.x).is_equal(x_locked)

	remove_child(fayde)
	fayde.free()
	_teardown_hud(hud)


# ── AC-HUD-31: health_restored on player spawns "+N HP" label ─────────────────

## GIVEN CombatHUD in tree; MockFayde in "player" group
## WHEN health_restored(fayde, 15, 90) emits
## THEN a child label with text "+15 HP" and font_color == HEAL_LABEL_COLOR is present
func test_health_restored_player_spawns_heal_label_green_text() -> void:
	var hud: Node = _make_hud()
	var fayde: MockFayde = _make_fayde()

	HealthAndDamage.health_restored.emit(fayde, 15, 90)

	# Find label with "+15 HP" text among hud children
	var found: bool = false
	for child: Node in hud.get_children():
		if child is Label and (child as Label).text == "+15 HP":
			found = true
			var color: Color = (child as Label).get_theme_color(&"font_color")
			assert_bool(color.is_equal_approx(hud.HEAL_LABEL_COLOR)).is_true()
			break
	assert_bool(found).is_true()

	_teardown_fayde(fayde)
	_teardown_hud(hud)


# ── AC-HUD-32: health_restored on enemy does NOT spawn heal label ─────────────

## GIVEN CombatHUD in tree; MockEnemy (not in "player" group)
## WHEN health_restored(enemy, 15, 50) emits
## THEN no "+15 HP" label is spawned
func test_health_restored_enemy_target_no_heal_label() -> void:
	var hud: Node = _make_hud()
	var enemy: MockEnemy = _make_enemy()

	var label_count_before: int = hud.get_child_count()
	HealthAndDamage.health_restored.emit(enemy, 15, 50)
	assert_int(hud.get_child_count()).is_equal(label_count_before)

	_teardown_enemy(enemy)
	_teardown_hud(hud)
