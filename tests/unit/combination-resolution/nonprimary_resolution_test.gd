## nonprimary_resolution_test.gd — Unit tests for CombinationResolution Story 003.
##
## Covers ACs: CR-07, CR-08, CR-09, CR-10, CR-11.
##
## CombinationResolution has no class_name (Autoload naming constraint), so it is
## loaded via load() rather than referenced as a global class name.
##
## PranaFragment, SpellEffect, and NonPrimaryModifier are Resources (RefCounted) —
## do NOT call .free() on them.
## CombinationResolution instances are created via script.new() and freed with
## node.free() (not queue_free()) since they are never added to the scene tree —
## avoids GdUnit4 orphan warnings and exit code 101.
##
## Prana type ID constants:
##   Ashfire   = 0
##   Voidblue  = 1
##   Stormgold = 2
##   Deepfrost = 3
##   Verdant   = 4
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


## Returns the NonPrimaryModifier entry for the given type_id, or null if absent.
func _find_modifier(modifiers: Array, type_id: int) -> NonPrimaryModifier:
	for mod in modifiers:
		if mod.type_id == type_id:
			return mod
	return null


# ── AC-CR-07: Non-centre fragment contributes to non-primary count ────────────

func test_noncentre_deepfrost_lv2_appears_in_modifiers_with_tier_1() -> void:
	# Arrange — slot 4 = Ashfire (0) lv.1 (primary); slot 0 = Deepfrost (3) lv.2;
	# rest null. Effective non-primary count for Deepfrost = 2. NP_TIER2_MIN = 3,
	# so count 2 → tier 1. Exactly one modifier entry expected.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)  # Ashfire — primary
	fragments[0] = _make_frag(3, 2)  # Deepfrost lv.2 — non-primary

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.non_primary_modifiers.size()).is_equal(1)
	var deepfrost_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(deepfrost_mod).is_not_null()
	assert_int(deepfrost_mod.tier).is_equal(1)

	cr.free()


func test_noncentre_deepfrost_lv2_effective_count_2_stays_tier_1() -> void:
	# Arrange — same setup as above. Effective count = 2 which is less than
	# NP_TIER2_MIN (3), confirming the tier 1 boundary is at count < 3.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)  # Ashfire — primary
	fragments[0] = _make_frag(3, 2)  # Deepfrost lv.2 — count = 2

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — count 2 must map to tier 1, not tier 2.
	var deepfrost_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(deepfrost_mod).is_not_null()
	assert_int(deepfrost_mod.tier).is_equal(1)

	cr.free()


# ── AC-CR-08: Absent non-primary type produces no entry ──────────────────────

func test_absent_deepfrost_produces_no_modifier_entry() -> void:
	# Arrange — Stormgold primary (slot 4 lv.1); no Deepfrost anywhere.
	# non_primary_modifiers must contain no entry for type_id 3.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(2, 1)  # Stormgold — primary

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	var deepfrost_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(deepfrost_mod).is_null()

	cr.free()


func test_no_nonprimary_fragments_gives_empty_modifiers_array() -> void:
	# Arrange — Stormgold primary (slot 4 lv.1); no other fragments at all.
	# non_primary_modifiers must be empty.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(2, 1)  # Stormgold — primary, no other slots filled

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.non_primary_modifiers.size()).is_equal(0)

	cr.free()


# ── AC-CR-09: Count 1 and count 2 both → tier 1 ──────────────────────────────

func test_deepfrost_count_1_gives_tier_1() -> void:
	# Arrange — Ashfire primary (slot 4 lv.1); one Deepfrost lv.1 in slot 0.
	# Effective non-primary count = 1 → tier 1.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)  # Ashfire — primary
	fragments[0] = _make_frag(3, 1)  # Deepfrost lv.1 — count = 1

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	var deepfrost_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(deepfrost_mod).is_not_null()
	assert_int(deepfrost_mod.tier).is_equal(1)

	cr.free()


func test_deepfrost_count_2_two_lv1_fragments_gives_tier_1() -> void:
	# Arrange — Ashfire primary (slot 4 lv.1); two Deepfrost lv.1 fragments in
	# non-centre slots 0 and 1. Effective count = 1 + 1 = 2 → tier 1.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)  # Ashfire — primary
	fragments[0] = _make_frag(3, 1)  # Deepfrost lv.1
	fragments[1] = _make_frag(3, 1)  # Deepfrost lv.1 — total count = 2

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	var deepfrost_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(deepfrost_mod).is_not_null()
	assert_int(deepfrost_mod.tier).is_equal(1)

	cr.free()


# ── AC-CR-10: T1/T2 seam at count 3 (NP_TIER2_MIN) ──────────────────────────

func test_deepfrost_count_2_stays_below_tier_2_seam() -> void:
	# Arrange — Ashfire primary (slot 4 lv.1); one Deepfrost lv.2 in slot 0.
	# Effective count = 2, which is one below NP_TIER2_MIN (3) → tier 1.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)  # Ashfire — primary
	fragments[0] = _make_frag(3, 2)  # Deepfrost lv.2 — count = 2

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — count 2 must NOT reach tier 2.
	var deepfrost_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(deepfrost_mod).is_not_null()
	assert_int(deepfrost_mod.tier).is_equal(1)

	cr.free()


func test_deepfrost_count_3_reaches_tier_2_seam() -> void:
	# Arrange — Ashfire primary (slot 4 lv.1); one Deepfrost lv.3 in slot 0.
	# Effective count = 3 which equals NP_TIER2_MIN → tier 2.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)  # Ashfire — primary
	fragments[0] = _make_frag(3, 3)  # Deepfrost lv.3 — count = 3

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — count 3 must reach tier 2.
	var deepfrost_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(deepfrost_mod).is_not_null()
	assert_int(deepfrost_mod.tier).is_equal(2)

	cr.free()


# ── AC-CR-11: Three non-primaries active simultaneously ──────────────────────

func test_three_nonprimary_types_all_active_gives_size_3() -> void:
	# Arrange — Stormgold primary (slot 4 lv.1);
	#   Ashfire lv.1 in slot 0 + lv.1 in slot 1 → count = 2 → tier 1
	#   Deepfrost lv.1 in slot 2 → count = 1 → tier 1
	#   Verdant lv.1 in slot 3 → count = 1 → tier 1
	# All three non-primary types qualify; non_primary_modifiers.size() == 3.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(2, 1)  # Stormgold — primary
	fragments[0] = _make_frag(0, 1)  # Ashfire lv.1
	fragments[1] = _make_frag(0, 1)  # Ashfire lv.1 — Ashfire count = 2 → tier 1
	fragments[2] = _make_frag(3, 1)  # Deepfrost lv.1 — count = 1 → tier 1
	fragments[3] = _make_frag(4, 1)  # Verdant lv.1 — count = 1 → tier 1

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.non_primary_modifiers.size()).is_equal(3)

	cr.free()


func test_primary_type_never_appears_in_nonprimary_modifiers() -> void:
	# Arrange — same multi-type grid as above. Stormgold is the primary type (2);
	# it must not appear in non_primary_modifiers regardless of how many Stormgold
	# fragments are in non-centre slots (here: none, but the primary guard must hold).
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(2, 1)  # Stormgold — primary
	fragments[0] = _make_frag(0, 1)  # Ashfire lv.1
	fragments[1] = _make_frag(0, 1)  # Ashfire lv.1
	fragments[2] = _make_frag(3, 1)  # Deepfrost lv.1
	fragments[3] = _make_frag(4, 1)  # Verdant lv.1

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — no Stormgold (type_id 2) entry in non_primary_modifiers.
	var stormgold_mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 2)
	assert_object(stormgold_mod).is_null()

	cr.free()
