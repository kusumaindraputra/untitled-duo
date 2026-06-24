## reaction_resolution_test.gd — Unit tests for the Prana Reaction & Cascade layer (ADR-0016).
##
## Covers ACs: CR-30 through CR-44 (Rule 16 / Formula 9 reactions; Rule 17 / Formula 10 cascade).
##
## The recognition layer is a pure function of the fragment array — no SceneTree, no RNG, no
## timers. Tests use standalone _make_cr() instances (loaded via load(), since
## CombinationResolution has no class_name) and free them with cr.free() — never queue_free()
## — to avoid GdUnit4 orphan warnings (exit code 101).
##
## The Reaction Matrix loads lazily from res://assets/data/reactions/*.tres on the first
## recognition call, so a standalone (not-in-tree) instance arms reactions without _ready().
##
## ReactionDef is a class_name Resource (RefCounted) — do NOT call .free() on it.
## CascadeEffect is class_name RefCounted — do NOT call .free() on it.
##
## Prana type ID constants:
##   Ashfire = 0, Voidblue = 1, Stormgold = 2, Deepfrost = 3, Verdant = 4
##
## ReactionKind constants (GameEnums.ReactionKind):
##   THERMAL_SHOCK=0, DETONATE=1, WITCHFIRE=2, WILDFIRE=3, SHORT_CIRCUIT=4,
##   WHITEOUT=5, SIPHON=6, SUPERCONDUCT=7, SURGE=8, PERMAFROST=9
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

## Loads and instantiates a standalone CombinationResolution for direct method testing.
## NOT added to the scene tree — free with node.free() after each test.
func _make_cr() -> Node:
	var script := load("res://src/systems/combination_resolution.gd")
	return script.new()


## Returns a new PranaFragment with the given type_id and level.
func _make_frag(type_id: int, level: int = 1) -> PranaFragment:
	var frag := PranaFragment.new()
	frag.type_id = type_id
	frag.level = level
	return frag


## Returns a 9-element Array of nulls (empty Prana grid).
func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(9)
	return grid


## Collects the effect_kind of every reaction in an active_reactions array.
func _kinds(reactions: Array) -> Array:
	var kinds: Array = []
	for rdef: ReactionDef in reactions:
		kinds.append(rdef.effect_kind)
	return kinds


## True when active_reactions holds at least one entry with the given effect_kind.
func _has_kind(reactions: Array, kind: int) -> bool:
	return _kinds(reactions).has(kind)


# ── AC-CR-30: Reaction arms on cardinal adjacency of two different types ───────

func test_reaction_arms_on_cardinal_adjacency_of_two_different_types() -> void:
	# Arrange — slot 4 Deepfrost (primary), slot 1 Ashfire ABOVE it.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(3)  # Deepfrost
	fragments[1] = _make_frag(0)  # Ashfire (ABOVE slot 4)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — exactly one Thermal Shock (pair 0,3).
	assert_int(effect.active_reactions.size()).is_equal(1)
	assert_bool(_has_kind(effect.active_reactions, GameEnums.ReactionKind.THERMAL_SHOCK)).is_true()

	cr.free()


# ── AC-CR-31: Diagonal-only adjacency does NOT arm a reaction ─────────────────

func test_diagonal_only_adjacency_does_not_arm_a_reaction() -> void:
	# Arrange — slot 0 is diagonal to slot 4, not cardinal.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(3)  # Deepfrost
	fragments[0] = _make_frag(0)  # Ashfire (diagonal to slot 4)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.active_reactions.size()).is_equal(0)

	cr.free()


# ── AC-CR-32: Same-type cardinal adjacency arms no reaction ───────────────────

func test_same_type_cardinal_adjacency_arms_no_reaction() -> void:
	# Arrange — two Ashfire neighbors.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0)  # Ashfire
	fragments[1] = _make_frag(0)  # Ashfire (ABOVE)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.active_reactions.size()).is_equal(0)

	cr.free()


# ── AC-CR-33: Duplicate reacting pair dedups to a single reaction ─────────────

func test_duplicate_reacting_pair_dedups_to_single_reaction() -> void:
	# Arrange — Deepfrost core; Ashfire ABOVE (slot 1) and RIGHT (slot 5):
	# the Deepfrost–Ashfire pair is cardinally adjacent at two seams.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(3)  # Deepfrost
	fragments[1] = _make_frag(0)  # Ashfire (ABOVE)
	fragments[5] = _make_frag(0)  # Ashfire (RIGHT)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — exactly one Thermal Shock entry (dedup, Rule 16c). Note |M|==1 → no cascade.
	assert_int(effect.active_reactions.size()).is_equal(1)
	assert_bool(_has_kind(effect.active_reactions, GameEnums.ReactionKind.THERMAL_SHOCK)).is_true()
	assert_object(effect.active_cascade).is_null()

	cr.free()


# ── AC-CR-34: Multiple distinct reactions arm simultaneously, ordered ─────────

func test_multiple_distinct_reactions_arm_in_ascending_pair_order() -> void:
	# Arrange — Deepfrost core (3); Ashfire ABOVE (0, slot 1); Verdant LEFT (4, slot 3).
	# Pairs: (0,3) Thermal Shock and (3,4) Permafrost. Ashfire and Verdant are NOT
	# adjacent → no Wildfire. |M|==2 here, BUT the two distinct neighbors are Ashfire and
	# Verdant → cascade would fire and consume both core pairwise reactions. To isolate the
	# pure reaction-ordering AC, both reacting types share Deepfrost as the common pair
	# member while the cascade is avoided by giving the core only ONE non-core neighbor type.
	#
	# AC-CR-34 as written keeps the cascade OUT of scope (it lists exactly two reactions and
	# no cascade), so we reproduce its arrangement and assert on the post-merge result: with
	# Ashfire + Verdant as the two distinct core neighbors, the cascade consumes both, leaving
	# zero core reactions. The non-cascade reaction-ordering guarantee is therefore validated
	# via compute_reactions on a pre-merge equivalent below.
	var cr := _make_cr()

	# Pre-merge ordering check (Formula 9 sort): use the raw reaction scan directly.
	var fragments := _make_grid()
	fragments[4] = _make_frag(3)  # Deepfrost
	fragments[1] = _make_frag(0)  # Ashfire (ABOVE)
	fragments[3] = _make_frag(4)  # Verdant (LEFT)

	var raw: Array = cr._compute_reactions_raw(fragments)

	# Assert — exactly two, ascending by (type_a, type_b): Thermal Shock (0,3) then Permafrost (3,4).
	assert_int(raw.size()).is_equal(2)
	assert_array(_kinds(raw)).is_equal(
		[GameEnums.ReactionKind.THERMAL_SHOCK, GameEnums.ReactionKind.PERMAFROST]
	)
	assert_bool(_has_kind(raw, GameEnums.ReactionKind.WILDFIRE)).is_false()

	cr.free()


# ── AC-CR-35: All-same-type arrangement arms no reactions, no error ───────────

func test_all_same_type_arrangement_arms_no_reactions() -> void:
	# Arrange — all 9 slots Ashfire.
	var cr := _make_cr()
	var fragments := _make_grid()
	for i: int in range(9):
		fragments[i] = _make_frag(0)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — no reactions, no cascade, no error (test completes cleanly).
	assert_int(effect.active_reactions.size()).is_equal(0)
	assert_object(effect.active_cascade).is_null()

	cr.free()


# ── AC-CR-36: compute_reactions is stateless and pure (preview parity) ────────

func test_compute_reactions_is_stateless_and_pure() -> void:
	# Arrange — one cardinal cross-type pair (Deepfrost core, Ashfire ABOVE).
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(3)
	fragments[1] = _make_frag(0)

	# Act — call twice with no intervening state change.
	var first: Array = cr.compute_reactions(fragments)
	var second: Array = cr.compute_reactions(fragments)

	# Assert — identical result (same ids, same order): preview/combat parity.
	assert_int(first.size()).is_equal(1)
	assert_int(second.size()).is_equal(1)
	assert_array(_kinds(first)).is_equal(_kinds(second))
	assert_object(first[0]).is_same(second[0])  # same shared matrix instance

	cr.free()


# ── AC-CR-37: Reaction involving the centre (primary) type is not excluded ────

func test_centre_type_participates_in_reactions() -> void:
	# Arrange — Stormgold core (2, primary); Voidblue RIGHT (1, slot 5). |M|==1 → no cascade.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(2)  # Stormgold
	fragments[5] = _make_frag(1)  # Voidblue (RIGHT)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — Short Circuit present (the centre slot reacts), no cascade.
	assert_bool(_has_kind(effect.active_reactions, GameEnums.ReactionKind.SHORT_CIRCUIT)).is_true()
	assert_object(effect.active_cascade).is_null()

	cr.free()


# ── AC-CR-38: Cascade fires at >=2 distinct core-neighbor types; lead = core ──

func test_cascade_fires_at_two_distinct_neighbors_lead_is_core() -> void:
	# Arrange — Ashfire core (0); Voidblue ABOVE (1), Stormgold RIGHT (2).
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0)  # Ashfire core
	fragments[1] = _make_frag(1)  # Voidblue (ABOVE)
	fragments[5] = _make_frag(2)  # Stormgold (RIGHT)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_object(effect.active_cascade).is_not_null()
	assert_int(effect.active_cascade.lead_type).is_equal(0)
	assert_array(effect.active_cascade.modifiers).is_equal([1, 2])

	cr.free()


# ── AC-CR-39: Exactly one distinct core neighbor → no Cascade, reaction survives ─

func test_single_core_neighbor_no_cascade_core_reaction_survives() -> void:
	# Arrange — Stormgold core (2); Voidblue RIGHT (1) only. |M|==1.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(2)  # Stormgold
	fragments[5] = _make_frag(1)  # Voidblue

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — no cascade; the core Short Circuit pairwise reaction is intact.
	assert_object(effect.active_cascade).is_null()
	assert_bool(_has_kind(effect.active_reactions, GameEnums.ReactionKind.SHORT_CIRCUIT)).is_true()

	cr.free()


# ── AC-CR-40: Same three types, different core → different Cascade lead ───────

func test_core_sensitivity_same_types_different_lead() -> void:
	var cr := _make_cr()

	# (a) Ashfire core (0); Voidblue ABOVE (1), Stormgold RIGHT (2).
	var grid_a := _make_grid()
	grid_a[4] = _make_frag(0)
	grid_a[1] = _make_frag(1)
	grid_a[5] = _make_frag(2)
	var effect_a: SpellEffect = cr._resolve(grid_a)

	# (b) Stormgold core (2); Voidblue ABOVE (1), Ashfire RIGHT (0).
	var grid_b := _make_grid()
	grid_b[4] = _make_frag(2)
	grid_b[1] = _make_frag(1)
	grid_b[5] = _make_frag(0)
	var effect_b: SpellEffect = cr._resolve(grid_b)

	# Assert — same three types, different lead and modifier set.
	assert_int(effect_a.active_cascade.lead_type).is_equal(0)
	assert_array(effect_a.active_cascade.modifiers).is_equal([1, 2])
	assert_int(effect_b.active_cascade.lead_type).is_equal(2)
	assert_array(effect_b.active_cascade.modifiers).is_equal([0, 1])

	cr.free()


# ── AC-CR-41: Cascade consumes core↔neighbor pairwise but not ring↔ring ───────

func test_cascade_consumes_core_pairwise_keeps_ring_pairwise() -> void:
	# Arrange — Deepfrost core (3); Ashfire ABOVE (0, slot 1), Verdant RIGHT (4, slot 5)
	# → cascade fires (modifiers [0,4]), consuming Thermal Shock (0,3) and Permafrost (3,4).
	# Additionally slot 0 = Ashfire (0) and slot 3 = Voidblue (1) form a ring↔ring
	# Ashfire–Voidblue cardinal pair (slot 0 ABOVE slot 3) → Witchfire survives.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(3)  # Deepfrost core
	fragments[1] = _make_frag(0)  # Ashfire (ABOVE core)
	fragments[5] = _make_frag(4)  # Verdant (RIGHT of core)
	fragments[0] = _make_frag(0)  # Ashfire (ring)
	fragments[3] = _make_frag(1)  # Voidblue (ring, BELOW slot 0)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — cascade present; core pairwise consumed; ring Witchfire survives.
	assert_object(effect.active_cascade).is_not_null()
	assert_bool(_has_kind(effect.active_reactions, GameEnums.ReactionKind.THERMAL_SHOCK)).is_false()
	assert_bool(_has_kind(effect.active_reactions, GameEnums.ReactionKind.PERMAFROST)).is_false()
	assert_bool(_has_kind(effect.active_reactions, GameEnums.ReactionKind.WITCHFIRE)).is_true()

	cr.free()


# ── AC-CR-42: Duplicate neighbor type → one modifier but counts toward tier ───

func test_duplicate_neighbor_type_dedups_to_one_modifier() -> void:
	# Arrange — Ashfire core (0); Voidblue ABOVE (1, slot 1) and BELOW (1, slot 7);
	# Stormgold RIGHT (2, slot 5).
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0)  # Ashfire core
	fragments[1] = _make_frag(1)  # Voidblue (ABOVE)
	fragments[7] = _make_frag(1)  # Voidblue (BELOW)
	fragments[5] = _make_frag(2)  # Stormgold (RIGHT)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — Voidblue appears once as a modifier; its non-primary count is still 2.
	assert_array(effect.active_cascade.modifiers).is_equal([1, 2])
	assert_int(cr._compute_nonprimary_count(fragments, 1, 0)).is_equal(2)

	cr.free()


# ── AC-CR-43: Four distinct core neighbors → four modifiers; cascade_mult cap ─

func test_four_distinct_neighbors_four_modifiers_mult_respects_cap() -> void:
	# Arrange — Ashfire core (0); cardinal neighbors Voidblue/Stormgold/Deepfrost/Verdant.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0)  # Ashfire core
	fragments[1] = _make_frag(1)  # Voidblue (ABOVE)
	fragments[3] = _make_frag(2)  # Stormgold (LEFT)
	fragments[5] = _make_frag(3)  # Deepfrost (RIGHT)
	fragments[7] = _make_frag(4)  # Verdant (BELOW)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — four modifiers; cascade_mult = min(1.0 + 4×0.10, 1.6) = 1.40.
	assert_array(effect.active_cascade.modifiers).is_equal([1, 2, 3, 4])
	assert_float(effect.active_cascade.cascade_mult).is_equal_approx(1.40, 0.0001)

	cr.free()


# ── AC-CR-44: Corner slots do not feed the Cascade ────────────────────────────

func test_corner_slots_do_not_feed_the_cascade() -> void:
	# Arrange — Ashfire core (0); four distinct corner types; all cardinal neighbors null.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0)  # Ashfire core
	fragments[0] = _make_frag(1)  # Voidblue (corner)
	fragments[2] = _make_frag(2)  # Stormgold (corner)
	fragments[6] = _make_frag(3)  # Deepfrost (corner)
	fragments[8] = _make_frag(4)  # Verdant (corner)

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert — corners are diagonal to the core; no cascade.
	assert_object(effect.active_cascade).is_null()

	cr.free()
