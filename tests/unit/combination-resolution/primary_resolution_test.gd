## primary_resolution_test.gd — Unit tests for CombinationResolution Story 002.
##
## Covers ACs: CR-01, CR-02, CR-03, CR-04, CR-05, CR-06, CR-12.
##
## CombinationResolution has no class_name (Autoload naming constraint), so it is
## loaded via load() rather than referenced as a global class name.
##
## PranaFragment and SpellEffect are Resources (RefCounted) — do NOT call .free().
## CombinationResolution is a plain Node instantiated via .new() for testing —
## do NOT call .free() (RefCounted chain; no SceneTree orphan risk for plain objects,
## but we leave teardown to GC since it is a Node subclass and we never add it to
## the tree — see test-standards.md for the queue_free vs free distinction; here
## we simply let the reference drop).
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a new PranaFragment with the given type_id and level.
func _make_frag(type_id: int, level: int) -> PranaFragment:
	var frag := PranaFragment.new()
	frag.type_id = type_id
	frag.level = level
	return frag


## Returns a 9-element Array of nulls (empty Prana grid).
func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(9)
	return grid


## Loads and instantiates a CombinationResolution instance for direct method testing.
func _make_cr() -> Node:
	var script := load("res://src/systems/combination_resolution.gd")
	return script.new()


# ── AC-CR-01: Centre slot determines primary_type ────────────────────────────

func test_primary_type_is_centre_slot_type() -> void:
	# Arrange — slot 4 = Deepfrost (3) lv.1; slots 0 and 2 = Ashfire (0) lv.1; rest null.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(3, 1)  # Deepfrost at centre
	fragments[0] = _make_frag(0, 1)  # Ashfire — must NOT override centre
	fragments[2] = _make_frag(0, 1)  # Ashfire — must NOT override centre

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.primary_type).is_equal(3)

	cr.free()


# ── AC-CR-02: Effective count sums fragment levels ────────────────────────────

func test_effective_count_sums_fragment_levels() -> void:
	# Arrange — slot 4 = Ashfire lv.2, slot 0 = Ashfire lv.1, slot 7 = Ashfire lv.3.
	# Effective count = 2 + 1 + 3 = 6 → tier 3.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 2)
	fragments[0] = _make_frag(0, 1)
	fragments[7] = _make_frag(0, 3)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.primary_tier).is_equal(3)

	cr.free()


# ── AC-CR-03: Non-centre same-type contributes to primary, not non_primary ───

func test_same_type_non_centre_goes_to_primary_not_non_primary() -> void:
	# Arrange — slot 4 = Ashfire lv.1, slot 0 = Ashfire lv.1.
	# Effective count = 2 → tier 1. No Ashfire entry in non_primary_modifiers.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)
	fragments[0] = _make_frag(0, 1)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.primary_tier).is_equal(1)
	assert_int(effect.non_primary_modifiers.size()).is_equal(0)

	cr.free()


# ── AC-CR-04: T1/T2 seam — count 2 → tier 1 ─────────────────────────────────

func test_t1_t2_seam_count_2_gives_tier_1() -> void:
	var cr := _make_cr()

	assert_int(cr._compute_primary_tier(2)).is_equal(1)

	cr.free()


# ── AC-CR-04: T1/T2 seam — count 3 → tier 2 ─────────────────────────────────

func test_t1_t2_seam_count_3_gives_tier_2() -> void:
	var cr := _make_cr()

	assert_int(cr._compute_primary_tier(3)).is_equal(2)

	cr.free()


# ── AC-CR-05: T2/T3 seam — count 5 → tier 2 ─────────────────────────────────

func test_t2_t3_seam_count_5_gives_tier_2() -> void:
	var cr := _make_cr()

	assert_int(cr._compute_primary_tier(5)).is_equal(2)

	cr.free()


# ── AC-CR-05: T2/T3 seam — count 6 → tier 3 ─────────────────────────────────

func test_t2_t3_seam_count_6_gives_tier_3() -> void:
	var cr := _make_cr()

	assert_int(cr._compute_primary_tier(6)).is_equal(3)

	cr.free()


# ── AC-CR-06: High-level fragments (count 10) → tier 3, no error ─────────────

func test_high_level_fragments_give_tier_3() -> void:
	# Arrange — slot 4 = Ashfire lv.5, slot 0 = Ashfire lv.5. Effective count = 10.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 5)
	fragments[0] = _make_frag(0, 5)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.primary_tier).is_equal(3)

	cr.free()


# ── AC-CR-12: All-same-type grid → tier 3, non_primary_modifiers empty ───────

func test_all_same_type_gives_tier_3_no_non_primary() -> void:
	# Arrange — 9 × Ashfire lv.1. Effective count = 9 → tier 3.
	var cr := _make_cr()
	var fragments := _make_grid()
	for i: int in range(9):
		fragments[i] = _make_frag(0, 1)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.primary_tier).is_equal(3)
	assert_int(effect.non_primary_modifiers.size()).is_equal(0)

	cr.free()


# ── combo_attack_count mirrors primary_tier ───────────────────────────────────

func test_combo_attack_count_equals_primary_tier() -> void:
	# Arrange — slot 4 = Ashfire lv.2, slot 0 = Ashfire lv.1, slot 7 = Ashfire lv.3.
	# Effective count = 6 → tier 3 → combo_attack_count == 3.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 2)
	fragments[0] = _make_frag(0, 1)
	fragments[7] = _make_frag(0, 3)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.combo_attack_count).is_equal(effect.primary_tier)

	cr.free()
