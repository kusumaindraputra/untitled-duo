## data_model_test.gd — Schema tests for CR data model Resources (Story CR-001).
##
## Coverage (4 schema ACs):
##   CR-001a: PranaFragment default field values
##   CR-001b: NonPrimaryModifier default field values
##   CR-001c: SpellEffect new fields (primary_base_status, non_primary_modifiers, active_adjacency_effects)
##   CR-001d: AdjacencyEffect / NeighborCondition defaults
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
## All classes are Resources (RefCounted) — do NOT call .free().
extends GdUnitTestSuite


# ── CR-001a: PranaFragment defaults ──────────────────────────────────────────

func test_prana_fragment_type_id_defaults_to_invalid() -> void:
	var frag := PranaFragment.new()
	assert_int(frag.type_id).is_equal(-1)


func test_prana_fragment_level_defaults_to_one() -> void:
	var frag := PranaFragment.new()
	assert_int(frag.level).is_equal(1)


func test_prana_fragment_stat_property_defaults_to_empty_dict() -> void:
	var frag := PranaFragment.new()
	assert_int(frag.stat_property.size()).is_equal(0)


func test_prana_fragment_adjacency_effects_defaults_to_empty_array() -> void:
	var frag := PranaFragment.new()
	assert_int(frag.adjacency_effects.size()).is_equal(0)


# ── CR-001b: NonPrimaryModifier defaults ─────────────────────────────────────

func test_non_primary_modifier_type_id_defaults_to_invalid() -> void:
	var mod := NonPrimaryModifier.new()
	assert_int(mod.type_id).is_equal(-1)


func test_non_primary_modifier_heal_amplifier_defaults_to_one() -> void:
	var mod := NonPrimaryModifier.new()
	assert_float(mod.heal_amplifier).is_equal(1.0)


func test_non_primary_modifier_final_attack_stun_defaults_to_false() -> void:
	var mod := NonPrimaryModifier.new()
	assert_bool(mod.final_attack_stun).is_false()


func test_non_primary_modifier_numeric_fields_default_to_zero() -> void:
	var mod := NonPrimaryModifier.new()
	assert_float(mod.burn_bonus).is_equal(0.0)
	assert_float(mod.window_extension).is_equal(0.0)
	assert_float(mod.freeze_duration).is_equal(0.0)
	assert_float(mod.chill_slow_pct).is_equal(0.0)


# ── CR-001c: SpellEffect new field defaults ───────────────────────────────────

func test_spell_effect_primary_base_status_defaults_to_invalid() -> void:
	var se := SpellEffect.new()
	assert_int(se.primary_base_status).is_equal(-1)


func test_spell_effect_non_primary_modifiers_defaults_to_empty_array() -> void:
	var se := SpellEffect.new()
	assert_int(se.non_primary_modifiers.size()).is_equal(0)


func test_spell_effect_active_adjacency_effects_defaults_to_empty_array() -> void:
	var se := SpellEffect.new()
	assert_int(se.active_adjacency_effects.size()).is_equal(0)


func test_spell_effect_existing_fields_unchanged_by_extensions() -> void:
	# Guard: new fields must not disturb pre-existing SpellEffect fields.
	var se := SpellEffect.new()
	assert_int(se.primary_type).is_equal(-1)
	assert_int(se.primary_tier).is_equal(1)
	assert_float(se.base_damage_modifier).is_equal(1.0)
	assert_int(se.combo_attack_count).is_equal(1)
	assert_int(se.aggregate_stat_bonus.size()).is_equal(0)


# ── CR-001d: AdjacencyEffect and NeighborCondition defaults ──────────────────

func test_adjacency_effect_empty_required_neighbors_is_valid() -> void:
	# Empty = vacuously satisfied (GDD Rule 8 — ADJ_DOUBLE_HIT pattern).
	var adj := AdjacencyEffect.new()
	assert_int(adj.required_neighbors.size()).is_equal(0)
	assert_str(str(adj.effect_id)).is_equal("")


func test_neighbor_condition_direction_defaults_to_above() -> void:
	var cond := NeighborCondition.new()
	assert_int(cond.direction).is_equal(NeighborCondition.Direction.ABOVE)


func test_neighbor_condition_required_type_id_defaults_to_wildcard() -> void:
	var cond := NeighborCondition.new()
	assert_int(cond.required_type_id).is_equal(-1)
