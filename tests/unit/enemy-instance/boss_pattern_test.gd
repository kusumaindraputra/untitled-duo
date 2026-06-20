## boss_pattern_test.gd — Unit tests for distance-driven boss attack selection (T06).
##
## Coverage:
##   AC-EI-BOSS-01: dist < SLAM threshold (normal) → selects SLAM (0)
##   AC-EI-BOSS-02: dist > CHARGE threshold (normal) → selects CHARGE (1)
##   AC-EI-BOSS-03: dist in middle range (normal) → selects SALVO (2)
##   AC-EI-BOSS-04: dist < reduced SLAM threshold (enraged) → selects SLAM (0)
##   AC-EI-BOSS-05: dist > reduced CHARGE threshold (enraged) → selects CHARGE (1)
##   AC-EI-BOSS-06: dist in middle range (enraged) → selects SALVO (2)
##   AC-EI-BOSS-07: dist exactly at SLAM boundary → SLAM (< is exclusive)
##   AC-EI-BOSS-08: dist exactly at CHARGE boundary → SALVO (> is exclusive)
##
## GDD: design/gdd/ (Boss AI, T06 sprint-10-tasks.md)
## GdUnit4 v6.1.3 | Godot 4.6
extends GdUnitTestSuite


## Creates a minimal EnemyInstance with BOSS archetype, never added to scene tree.
## Caller must free() after use.
func _make_boss() -> EnemyInstance:
	var e := EnemyInstance.new()
	e._archetype = GameEnums.EnemyArchetype.BOSS
	e._max_hp = 250
	e._current_hp = 250
	return e


# ── AC-EI-BOSS-01: Normal, close range → SLAM ────────────────────────────────

## GIVEN dist = 50 (below BOSS_SELECT_SLAM_DIST 80), not enraged
## WHEN _select_boss_attack is called
## THEN returns 0 (SLAM)
func test_select_boss_attack_close_normal_returns_slam() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(50.0, false)
	boss.free()
	assert_int(result).is_equal(0)


# ── AC-EI-BOSS-02: Normal, far range → CHARGE ────────────────────────────────

## GIVEN dist = 200 (above BOSS_SELECT_CHARGE_DIST 150), not enraged
## WHEN _select_boss_attack is called
## THEN returns 1 (CHARGE)
func test_select_boss_attack_far_normal_returns_charge() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(200.0, false)
	boss.free()
	assert_int(result).is_equal(1)


# ── AC-EI-BOSS-03: Normal, middle range → SALVO ──────────────────────────────

## GIVEN dist = 110 (between 80 and 150), not enraged
## WHEN _select_boss_attack is called
## THEN returns 2 (SALVO)
func test_select_boss_attack_middle_normal_returns_salvo() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(110.0, false)
	boss.free()
	assert_int(result).is_equal(2)


# ── AC-EI-BOSS-04: Enraged, close range → SLAM ───────────────────────────────

## GIVEN dist = 55 (below enraged SLAM threshold 60 = 80 - 20), enraged
## WHEN _select_boss_attack is called
## THEN returns 0 (SLAM)
func test_select_boss_attack_close_enraged_returns_slam() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(55.0, true)
	boss.free()
	assert_int(result).is_equal(0)


# ── AC-EI-BOSS-05: Enraged, far range → CHARGE ───────────────────────────────

## GIVEN dist = 140 (above enraged CHARGE threshold 130 = 150 - 20), enraged
## WHEN _select_boss_attack is called
## THEN returns 1 (CHARGE)
func test_select_boss_attack_far_enraged_returns_charge() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(140.0, true)
	boss.free()
	assert_int(result).is_equal(1)


# ── AC-EI-BOSS-06: Enraged, middle range → SALVO ─────────────────────────────

## GIVEN dist = 90 (between enraged thresholds 60 and 130), enraged
## WHEN _select_boss_attack is called
## THEN returns 2 (SALVO)
func test_select_boss_attack_middle_enraged_returns_salvo() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(90.0, true)
	boss.free()
	assert_int(result).is_equal(2)


# ── AC-EI-BOSS-07: Exact SLAM boundary (exclusive) ───────────────────────────

## GIVEN dist = exactly BOSS_SELECT_SLAM_DIST (80), not enraged
## WHEN _select_boss_attack is called
## THEN returns 2 (SALVO) — boundary is exclusive (< not <=)
func test_select_boss_attack_exactly_slam_boundary_returns_salvo() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(EnemyInstance.BOSS_SELECT_SLAM_DIST, false)
	boss.free()
	assert_int(result).is_equal(2)


# ── AC-EI-BOSS-08: Exact CHARGE boundary (exclusive) ─────────────────────────

## GIVEN dist = exactly BOSS_SELECT_CHARGE_DIST (150), not enraged
## WHEN _select_boss_attack is called
## THEN returns 2 (SALVO) — boundary is exclusive (> not >=)
func test_select_boss_attack_exactly_charge_boundary_returns_salvo() -> void:
	var boss := _make_boss()
	var result: int = boss._select_boss_attack(EnemyInstance.BOSS_SELECT_CHARGE_DIST, false)
	boss.free()
	assert_int(result).is_equal(2)
