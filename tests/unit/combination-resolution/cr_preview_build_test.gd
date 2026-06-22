## cr_preview_build_test.gd — Unit tests for CombinationResolution.preview_build()
## (Stage 3 build readout). preview_build is a pure summary used by the Preparation
## Phase readout; it must reuse the same tier thresholds as _resolve().
##
## Coverage:
##   AC-PV-01: no core (slot 4 null) → primary_type -1, tier 0
##   AC-PV-02: core only → primary tier 1, count 1
##   AC-PV-03: 3 of the primary type → tier 2 (PRIMARY_T1_MAX boundary)
##   AC-PV-04: 6 of the primary type → tier 3 (PRIMARY_T2_MAX boundary)
##   AC-PV-05: non-primary type with 1–2 copies → active at tier 1
##   AC-PV-06: non-primary type with 3 copies → tier 2 (NP_TIER2_MIN)
##   AC-PV-07: a non-primary type with zero copies is omitted from the list
##
## CombinationResolution has no class_name (Autoload constraint); loaded via load().
## preview_build is pure (no state, no signals), so one shared .new() instance is
## reused across tests and freed in after() (free(), not queue_free — no SceneTree).
##
## Framework: GdUnit4 | Godot 4.6
extends GdUnitTestSuite

var _cr: Node = null


func before() -> void:
	_cr = load("res://src/systems/combination_resolution.gd").new()


func after() -> void:
	if is_instance_valid(_cr):
		_cr.free()


## Returns a 9-element type_id array of nulls.
func _grid() -> Array:
	var g: Array = []
	g.resize(9)
	return g


# ── AC-PV-01: no core ────────────────────────────────────────────────────────

func test_preview_build_no_core_returns_invalid_primary() -> void:
	var b: Dictionary = _cr.preview_build(_grid())

	assert_int(b["primary_type"]).is_equal(-1)
	assert_int(b["primary_tier"]).is_equal(0)
	assert_array(b["nonprimary"]).is_empty()


# ── AC-PV-02: core only → tier 1 ─────────────────────────────────────────────

func test_preview_build_core_only_is_tier_one() -> void:
	var g: Array = _grid()
	g[4] = 0  # Ashfire core

	var b: Dictionary = _cr.preview_build(g)

	assert_int(b["primary_type"]).is_equal(0)
	assert_int(b["primary_count"]).is_equal(1)
	assert_int(b["primary_tier"]).is_equal(1)


# ── AC-PV-03: 3 primary → tier 2 ─────────────────────────────────────────────

func test_preview_build_three_primary_is_tier_two() -> void:
	var g: Array = _grid()
	g[4] = 2  # core Stormgold
	g[1] = 2
	g[3] = 2

	var b: Dictionary = _cr.preview_build(g)

	assert_int(b["primary_count"]).is_equal(3)
	assert_int(b["primary_tier"]).is_equal(2)


# ── AC-PV-04: 6 primary → tier 3 ─────────────────────────────────────────────

func test_preview_build_six_primary_is_tier_three() -> void:
	var g: Array = _grid()
	for i in [4, 0, 1, 2, 3, 5]:
		g[i] = 1  # Voidblue ×6 (incl. core)

	var b: Dictionary = _cr.preview_build(g)

	assert_int(b["primary_count"]).is_equal(6)
	assert_int(b["primary_tier"]).is_equal(3)


# ── AC-PV-05: non-primary tier 1 ─────────────────────────────────────────────

func test_preview_build_nonprimary_one_copy_is_tier_one() -> void:
	var g: Array = _grid()
	g[4] = 0  # Ashfire core
	g[1] = 3  # one Deepfrost (non-primary)

	var b: Dictionary = _cr.preview_build(g)

	var nps: Array = b["nonprimary"]
	assert_int(nps.size()).is_equal(1)
	assert_int(nps[0]["type"]).is_equal(3)
	assert_int(nps[0]["tier"]).is_equal(1)


# ── AC-PV-06: non-primary tier 2 ─────────────────────────────────────────────

func test_preview_build_nonprimary_three_copies_is_tier_two() -> void:
	var g: Array = _grid()
	g[4] = 0  # Ashfire core
	g[1] = 4
	g[2] = 4
	g[3] = 4  # three Verdant (non-primary)

	var b: Dictionary = _cr.preview_build(g)

	var nps: Array = b["nonprimary"]
	assert_int(nps.size()).is_equal(1)
	assert_int(nps[0]["type"]).is_equal(4)
	assert_int(nps[0]["tier"]).is_equal(2)


# ── AC-PV-07: inactive non-primary types are omitted ─────────────────────────

func test_preview_build_omits_types_with_no_copies() -> void:
	var g: Array = _grid()
	g[4] = 0  # Ashfire core, no other types placed

	var b: Dictionary = _cr.preview_build(g)

	assert_array(b["nonprimary"]).is_empty()
