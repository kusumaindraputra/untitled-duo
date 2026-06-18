## payload_assembly_test.gd — Unit tests for CombinationResolution Story 004.
##
## Covers ACs: CR-13, CR-14 (distinct keys + additive stacking), CR-29.
## AC-CR-15 (adjacency STAT_BONUS contribution to aggregate) is deferred to
## Story 005 integration — that AC requires active_adjacency_effects wiring
## which is out of scope for Story 004.
##
## CombinationResolution has no class_name (Autoload naming constraint), so it is
## loaded via load() rather than referenced as a global class name.
##
## PranaFragment, SpellEffect, PranaType, and NonPrimaryModifier are Resources
## (RefCounted) — do NOT call .free() on them.
##
## Standalone CombinationResolution instances (not added to tree) are freed with
## node.free() (not queue_free()) — avoids GdUnit4 orphan warnings and exit code 101.
## For AC-CR-13 tests that need PranaCatalog access, cr is added as a child of the
## test suite (which IS in the scene tree), and freed with free() after removal.
##
## PranaCatalog injection strategy (AC-CR-13):
## PranaCatalog IS registered as Autoload #1 and available at /root/PranaCatalog in
## headless tests. before_each() mutates _types[0] and _types[4] to inject known
## test values; after_each() restores the originals.
##
## Prana type ID constants:
##   Ashfire   = 0
##   Voidblue  = 1
##   Stormgold = 2
##   Deepfrost = 3
##   Verdant   = 4
extends GdUnitTestSuite


# ── Catalog injection state ────────────────────────────────────────────────────

## Saved original values restored in after_each() to avoid test pollution.
var _orig_verdant_modifier: float
var _orig_verdant_status: int
var _orig_ashfire_modifier: float
var _orig_ashfire_status: int


func before_test() -> void:
	var catalog: Node = get_tree().root.get_node_or_null("PranaCatalog")
	if catalog == null or catalog._types.size() < 5:
		return
	# Save originals.
	_orig_verdant_modifier = catalog._types[4].base_damage_modifier
	_orig_verdant_status   = catalog._types[4].base_status
	_orig_ashfire_modifier = catalog._types[0].base_damage_modifier
	_orig_ashfire_status   = catalog._types[0].base_status
	# Inject known test values.
	catalog._types[4].base_damage_modifier = 0.70
	catalog._types[4].base_status          = GameEnums.BaseStatus.REGENERATE
	catalog._types[0].base_damage_modifier = 1.25
	catalog._types[0].base_status          = GameEnums.BaseStatus.BURN


func after_test() -> void:
	var catalog: Node = get_tree().root.get_node_or_null("PranaCatalog")
	if catalog == null or catalog._types.size() < 5:
		return
	catalog._types[4].base_damage_modifier = _orig_verdant_modifier
	catalog._types[4].base_status          = _orig_verdant_status
	catalog._types[0].base_damage_modifier = _orig_ashfire_modifier
	catalog._types[0].base_status          = _orig_ashfire_status


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a new PranaFragment with the given type_id, level, and optional stat_property.
func _make_frag(type_id: int, level: int, stats: Dictionary = {}) -> PranaFragment:
	var frag := PranaFragment.new()
	frag.type_id = type_id
	frag.level = level
	frag.stat_property = stats
	return frag


## Returns a 9-element Array of nulls (empty Prana grid).
func _make_grid() -> Array:
	var grid: Array = []
	grid.resize(9)
	return grid


## Loads and instantiates a standalone CombinationResolution for direct method testing.
## NOT added to the scene tree — use for catalog-independent tests; free with node.free().
func _make_cr() -> Node:
	var script := load("res://src/systems/combination_resolution.gd")
	return script.new()


## Loads, instantiates, and adds CombinationResolution to the test suite's scene tree.
## Use for catalog-dependent tests (AC-CR-13). Free with cr.free() after use.
func _make_cr_in_tree() -> Node:
	var script := load("res://src/systems/combination_resolution.gd")
	var cr: Node = script.new()
	add_child(cr)
	return cr


## Returns the NonPrimaryModifier entry for the given type_id, or null if absent.
func _find_modifier(modifiers: Array, type_id: int) -> NonPrimaryModifier:
	for mod in modifiers:
		if mod.type_id == type_id:
			return mod
	return null


# ── AC-CR-13: PranaCatalog fields populate SpellEffect ───────────────────────
#
# cr is added to the scene tree so get_node_or_null("/root/PranaCatalog") works.
# before_each() has injected known values into the Autoload's _types array.

func test_verdant_primary_base_damage_modifier_reads_from_catalog() -> void:
	# Arrange — before_each injected base_damage_modifier = 0.70 for Verdant (4).
	var cr := _make_cr_in_tree()
	var fragments := _make_grid()
	fragments[4] = _make_frag(4, 1)  # Verdant — primary

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_float(effect.base_damage_modifier).is_equal(0.70)

	cr.free()


func test_verdant_primary_base_status_reads_from_catalog() -> void:
	# Arrange — before_each injected base_status = REGENERATE for Verdant (4).
	var cr := _make_cr_in_tree()
	var fragments := _make_grid()
	fragments[4] = _make_frag(4, 1)  # Verdant — primary

	# Act
	var effect: SpellEffect = cr._resolve(fragments)

	# Assert
	assert_int(effect.primary_base_status).is_equal(GameEnums.BaseStatus.REGENERATE)

	cr.free()


# ── AC-CR-14: Stat aggregation sums all fragment stat_properties ─────────────

func test_aggregate_stat_bonus_sums_distinct_keys_from_three_fragments() -> void:
	# Arrange — slot 4 = Ashfire {ASH_DMG: 5}, slot 0 = Deepfrost {FROST_DMG: 3},
	# slot 2 = Verdant {VER_HEAL_FLAT: 2}; rest null.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1, {&"ASH_DMG": 5.0})
	fragments[0] = _make_frag(3, 1, {&"FROST_DMG": 3.0})
	fragments[2] = _make_frag(4, 1, {&"VER_HEAL_FLAT": 2.0})

	# Act
	var bonus: Dictionary = cr._aggregate_stat_bonus(fragments)

	# Assert — three distinct keys, exact values, no extra keys.
	assert_int(bonus.size()).is_equal(3)
	assert_float(bonus[&"ASH_DMG"]).is_equal(5.0)
	assert_float(bonus[&"FROST_DMG"]).is_equal(3.0)
	assert_float(bonus[&"VER_HEAL_FLAT"]).is_equal(2.0)

	cr.free()


func test_aggregate_stat_bonus_null_slots_are_skipped() -> void:
	# Arrange — only slot 4 has a stat; all other slots null.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1, {&"ASH_DMG": 7.0})

	# Act
	var bonus: Dictionary = cr._aggregate_stat_bonus(fragments)

	# Assert — exactly one key; nulls contributed nothing.
	assert_int(bonus.size()).is_equal(1)
	assert_float(bonus[&"ASH_DMG"]).is_equal(7.0)

	cr.free()


func test_aggregate_stat_bonus_empty_grid_gives_empty_dict() -> void:
	# Arrange — all nine slots null.
	var cr := _make_cr()
	var fragments := _make_grid()

	# Act
	var bonus: Dictionary = cr._aggregate_stat_bonus(fragments)

	# Assert
	assert_int(bonus.size()).is_equal(0)

	cr.free()


# ── AC-CR-14 additive stacking: same key across two fragments ────────────────

func test_aggregate_stat_bonus_same_key_is_additive_not_overwrite() -> void:
	# Arrange — slot 4 = Ashfire {ASH_DMG: 5}, slot 0 = Ashfire {ASH_DMG: 3}.
	# Expected: ASH_DMG = 5 + 3 = 8 (additive). Dictionary.merge() would overwrite
	# to 3 — this test guards against that pattern.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1, {&"ASH_DMG": 5.0})
	fragments[0] = _make_frag(0, 1, {&"ASH_DMG": 3.0})

	# Act
	var bonus: Dictionary = cr._aggregate_stat_bonus(fragments)

	# Assert
	assert_float(bonus[&"ASH_DMG"]).is_equal(8.0)

	cr.free()


func test_aggregate_stat_bonus_three_fragments_same_key_accumulates() -> void:
	# Arrange — slots 0, 1, 2 each contribute {FROST_DMG: 2.0}.
	# Expected: FROST_DMG = 2 + 2 + 2 = 6.0.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(3, 1, {})
	fragments[0] = _make_frag(3, 1, {&"FROST_DMG": 2.0})
	fragments[1] = _make_frag(3, 1, {&"FROST_DMG": 2.0})
	fragments[2] = _make_frag(3, 1, {&"FROST_DMG": 2.0})

	# Act
	var bonus: Dictionary = cr._aggregate_stat_bonus(fragments)

	# Assert
	assert_float(bonus[&"FROST_DMG"]).is_equal(6.0)

	cr.free()


# ── Non-primary modifier field-filling tests (GDD Formula 6) ─────────────────

func test_fill_nonprimary_deepfrost_tier_1_sets_chill_slow_only() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 3
	mod.tier = 1

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.chill_slow_pct).is_equal(0.15)
	assert_float(mod.freeze_duration).is_equal(0.0)

	cr.free()


func test_fill_nonprimary_deepfrost_tier_2_sets_chill_and_freeze() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 3
	mod.tier = 2

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.chill_slow_pct).is_equal(0.15)
	assert_float(mod.freeze_duration).is_equal(1.0)

	cr.free()


func test_fill_nonprimary_stormgold_tier_1_sets_window_no_stun() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 2
	mod.tier = 1

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.window_extension).is_equal(0.3)
	assert_bool(mod.final_attack_stun).is_false()

	cr.free()


func test_fill_nonprimary_stormgold_tier_2_sets_window_and_stun() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 2
	mod.tier = 2

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.window_extension).is_equal(0.3)
	assert_bool(mod.final_attack_stun).is_true()

	cr.free()


func test_fill_nonprimary_ashfire_tier_1_burn_bonus_unchanged() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 0
	mod.tier = 1

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.burn_bonus).is_equal(0.0)

	cr.free()


func test_fill_nonprimary_ashfire_tier_2_sets_burn_bonus() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 0
	mod.tier = 2

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.burn_bonus).is_equal(0.15)

	cr.free()


func test_fill_nonprimary_verdant_tier_1_heal_amplifier_unchanged() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 4
	mod.tier = 1

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.heal_amplifier).is_equal(1.0)

	cr.free()


func test_fill_nonprimary_verdant_tier_2_sets_heal_amplifier() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 4
	mod.tier = 2

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.heal_amplifier).is_equal(1.25)

	cr.free()


func test_fill_nonprimary_voidblue_leaves_all_fields_at_defaults() -> void:
	var cr := _make_cr()
	var mod := NonPrimaryModifier.new()
	mod.type_id = 1
	mod.tier = 1

	cr._fill_nonprimary_modifier_fields(mod)

	assert_float(mod.burn_bonus).is_equal(0.0)
	assert_float(mod.window_extension).is_equal(0.0)
	assert_bool(mod.final_attack_stun).is_false()
	assert_float(mod.heal_amplifier).is_equal(1.0)
	assert_float(mod.freeze_duration).is_equal(0.0)
	assert_float(mod.chill_slow_pct).is_equal(0.0)

	cr.free()


# ── AC-CR-29: primary_base_status is always populated alongside non_primary_modifiers

func test_nonprimary_deepfrost_modifier_filled_in_full_resolve_pipeline() -> void:
	# Verify that _resolve() calls _fill_nonprimary_modifier_fields after building
	# non_primary_modifiers. Deepfrost tier 1 must have chill_slow_pct = 0.15.
	# (Catalog fields are covered by the dedicated AC-CR-13 tests.)
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1)  # Ashfire — primary
	fragments[0] = _make_frag(3, 1)  # Deepfrost lv.1 — non-primary tier 1

	var effect: SpellEffect = cr._resolve(fragments)

	assert_int(effect.non_primary_modifiers.size()).is_equal(1)
	var mod: NonPrimaryModifier = _find_modifier(effect.non_primary_modifiers, 3)
	assert_object(mod).is_not_null()
	assert_int(mod.tier).is_equal(1)
	assert_float(mod.chill_slow_pct).is_equal(0.15)

	cr.free()


func test_aggregate_stat_bonus_present_on_resolved_spell_effect() -> void:
	# Verify _resolve() calls _aggregate_stat_bonus and assigns the result.
	var cr := _make_cr()
	var fragments := _make_grid()
	fragments[4] = _make_frag(0, 1, {&"ASH_DMG": 4.0})
	fragments[0] = _make_frag(3, 1, {&"FROST_DMG": 2.0})

	var effect: SpellEffect = cr._resolve(fragments)

	assert_int(effect.aggregate_stat_bonus.size()).is_equal(2)
	assert_float(effect.aggregate_stat_bonus[&"ASH_DMG"]).is_equal(4.0)
	assert_float(effect.aggregate_stat_bonus[&"FROST_DMG"]).is_equal(2.0)

	cr.free()
