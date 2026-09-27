## hud_readout_boss_bar_test.gd — Boss bar phase notches, ghost chunk and flash (ADR-0045).
##
## Coverage:
##   HR-01: thresholds keep distinct ratios inside (0, 1), highest first
##   HR-02: a hit leaves a ghost that holds, then drains to the live HP
##   HR-03: a heal moves the ghost up with the fill; max_value resets both
##   HR-04: the phase flash fades linearly and ends
##   HR-05: CombatHUD reads the boss's thresholds on spawn and flashes on phase up
##   HR-06: EnemyInstance reports one threshold per pattern layer
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

const TUNING: HudReadoutTuning = preload("res://assets/data/hud_readout_tuning.tres")
const CombatHUDScript = preload("res://src/ui/combat_hud.gd")


class _MockCatalog:
	var types: Dictionary = {}

	func get_type(id: int) -> EnemyType:
		return types.get(id, null)


class _StubBoss extends Node:
	signal phase_changed(phase: int)

	func get_max_hp() -> int:
		return 400

	func get_phase_thresholds() -> PackedFloat32Array:
		return PackedFloat32Array([1.0, 0.66, 0.33, 0.66])

	func get_display_name() -> String:
		return "VaultSentinel"


# ── HR-01 ─────────────────────────────────────────────────────────────────────

func test_thresholds_are_distinct_inner_and_sorted() -> void:
	var t: PackedFloat32Array = BossHealthBar.clean_thresholds(
		PackedFloat32Array([1.0, 0.33, 0.66, 0.66, 0.0, 0.5]))

	assert_int(t.size()).is_equal(3)
	assert_float(t[0]).is_equal_approx(0.66, 0.0001)
	assert_float(t[1]).is_equal_approx(0.5, 0.0001)
	assert_float(t[2]).is_equal_approx(0.33, 0.0001)


# ── HR-02 ─────────────────────────────────────────────────────────────────────

func test_ghost_holds_then_drains_to_live_hp() -> void:
	var bar := BossHealthBar.new()
	bar.max_value = 100.0
	bar.value = 60.0

	assert_float(bar.get_ghost()).is_equal(100.0)
	bar.tick(TUNING.boss_ghost_hold_sec * 0.5)
	assert_float(bar.get_ghost()).is_equal(100.0)
	bar.tick(TUNING.boss_ghost_hold_sec)  # hold over; this tick only clears it
	bar.tick(0.1)
	var expected: float = 100.0 - TUNING.boss_ghost_drain_per_sec * 100.0 * 0.1
	assert_float(bar.get_ghost()).is_equal_approx(expected, 0.001)
	for i: int in 60:
		bar.tick(0.1)
	assert_float(bar.get_ghost()).is_equal(60.0)
	bar.free()


func test_ghost_step_never_undershoots_current() -> void:
	var g: Vector2 = BossHealthBar.ghost_step(50.0, 40.0, 0.0, 10.0, 1.0, 100.0)

	assert_float(g.x).is_equal(40.0)


# ── HR-03 ─────────────────────────────────────────────────────────────────────

func test_heal_and_max_reset_move_ghost() -> void:
	var bar := BossHealthBar.new()
	bar.max_value = 100.0
	bar.value = 30.0
	bar.value = 90.0

	assert_float(bar.get_ghost()).is_equal(100.0)  # the earlier chunk is still draining
	bar.max_value = 500.0
	assert_float(bar.value).is_equal(500.0)
	assert_float(bar.get_ghost()).is_equal(500.0)
	bar.free()


# ── HR-04 ─────────────────────────────────────────────────────────────────────

func test_phase_flash_fades_and_ends() -> void:
	assert_float(BossHealthBar.flash_alpha(0.5, 0.5, 0.8)).is_equal_approx(0.8, 0.0001)
	assert_float(BossHealthBar.flash_alpha(0.25, 0.5, 0.8)).is_equal_approx(0.4, 0.0001)
	assert_float(BossHealthBar.flash_alpha(0.0, 0.5, 0.8)).is_equal(0.0)
	var bar := BossHealthBar.new()
	bar.flash_phase()
	assert_bool(bar.is_flashing()).is_true()
	bar.tick(TUNING.boss_phase_flash_sec + 0.01)
	assert_bool(bar.is_flashing()).is_false()
	bar.free()


# ── HR-05 ─────────────────────────────────────────────────────────────────────

func test_hud_reads_thresholds_and_flashes_on_phase() -> void:
	var hud: CombatHUD = CombatHUDScript.new()
	add_child(hud)
	hud.set_process(false)
	var boss := _StubBoss.new()
	add_child(boss)

	hud._on_boss_spawned(boss)
	var bar: BossHealthBar = hud._boss_bar
	assert_bool(bar.visible).is_true()
	assert_float(bar.max_value).is_equal(400.0)
	assert_int(bar.get_thresholds().size()).is_equal(2)
	boss.phase_changed.emit(1)
	assert_bool(bar.is_flashing()).is_true()

	hud._hide_boss_ui()
	remove_child(boss)
	boss.free()
	remove_child(hud)
	hud.free()


# ── HR-06 ─────────────────────────────────────────────────────────────────────

func test_enemy_reports_layer_thresholds() -> void:
	var et := EnemyType.new()
	et.id = 1
	et.base_hp = 100
	et.archetype = GameEnums.EnemyArchetype.BOSS
	for t: float in [1.0, 0.5]:
		var p := BulletPattern.new()
		p.hp_threshold = t
		et.pattern_layers.append(p)
	var cat := _MockCatalog.new()
	cat.types[et.id] = et
	var enemy := EnemyInstance.new()
	enemy.init(et.id, cat)

	var got: PackedFloat32Array = enemy.get_phase_thresholds()
	assert_int(got.size()).is_equal(2)
	assert_float(got[1]).is_equal_approx(0.5, 0.0001)
	enemy.free()
