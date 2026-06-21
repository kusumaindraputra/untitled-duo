## prana_type_schema_test.gd — Unit tests for PranaType resource schema (Story 002).
##
## Coverage:
##   AC-1: All 12 required properties accessible with correct defaults on PranaType.new()
##   AC-2: Forbidden shape properties absent (targeting_shape, cast_shape, spell_shape)
##   AC-3: Forbidden resonance properties absent (resonance, resonance_weight)
##   AC-4: .tres roundtrip preserves base_damage_modifier
##
## Framework: GDUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/unit/prana-data/prana_type_schema_test.gd --ignoreHeadlessMode
extends GdUnitTestSuite


const _ROUNDTRIP_PATH: String = "user://test_prana_type_roundtrip.tres"


func after_test() -> void:
	if FileAccess.file_exists(_ROUNDTRIP_PATH):
		DirAccess.remove_absolute(_ROUNDTRIP_PATH)


# ── AC-1: All 12 properties with correct defaults ─────────────────────────────

func test_prana_type_schema_id_default_is_zero() -> void:
	var prana := PranaType.new()
	assert_int(prana.id).is_equal(0)


func test_prana_type_schema_name_default_is_empty_string() -> void:
	var prana := PranaType.new()
	assert_str(prana.name).is_equal("")


func test_prana_type_schema_element_default_is_empty_string() -> void:
	var prana := PranaType.new()
	assert_str(prana.element).is_equal("")


func test_prana_type_schema_semantic_identity_default_is_empty_string() -> void:
	var prana := PranaType.new()
	assert_str(prana.semantic_identity).is_equal("")


func test_prana_type_schema_color_default_is_white() -> void:
	# Color serializes as float components in .tres — use is_equal_approx, never ==.
	var prana := PranaType.new()
	assert_bool(prana.color.is_equal_approx(Color.WHITE)).is_true()


func test_prana_type_schema_icon_default_is_null() -> void:
	# Null until .tres is authored in Story 004 — expected default per AC-PD-03.
	var prana := PranaType.new()
	assert_object(prana.icon).is_null()


func test_prana_type_schema_audio_signature_default_is_null() -> void:
	# Null until .tres is authored in Story 004 — expected default per AC-PD-03.
	var prana := PranaType.new()
	assert_object(prana.audio_signature).is_null()


func test_prana_type_schema_cast_animation_default_is_cast_thrust() -> void:
	var prana := PranaType.new()
	assert_int(prana.cast_animation).is_equal(GameEnums.CastAnimation.CAST_THRUST)


func test_prana_type_schema_damage_class_default_is_fire() -> void:
	var prana := PranaType.new()
	assert_int(prana.damage_class).is_equal(GameEnums.DamageClass.FIRE)


func test_prana_type_schema_base_status_default_is_burn() -> void:
	var prana := PranaType.new()
	assert_int(prana.base_status).is_equal(GameEnums.BaseStatus.BURN)


func test_prana_type_schema_base_damage_modifier_default_is_one() -> void:
	var prana := PranaType.new()
	assert_float(prana.base_damage_modifier).is_equal(1.0)


# ── AC-2: No targeting shape properties (AC-PD-06) ───────────────────────────

func test_prana_type_schema_has_no_targeting_shape_property() -> void:
	var prana := PranaType.new()
	assert_bool("targeting_shape" in prana).is_false()


func test_prana_type_schema_has_no_cast_shape_property() -> void:
	var prana := PranaType.new()
	assert_bool("cast_shape" in prana).is_false()


func test_prana_type_schema_has_no_spell_shape_property() -> void:
	var prana := PranaType.new()
	assert_bool("spell_shape" in prana).is_false()


# ── AC-3: No resonance properties (AC-PD-07) ─────────────────────────────────

func test_prana_type_schema_has_no_resonance_property() -> void:
	var prana := PranaType.new()
	assert_bool("resonance" in prana).is_false()


func test_prana_type_schema_has_no_resonance_weight_property() -> void:
	var prana := PranaType.new()
	assert_bool("resonance_weight" in prana).is_false()


# ── AC-4: .tres roundtrip preserves base_damage_modifier ─────────────────────

func test_prana_type_schema_tres_roundtrip_preserves_base_damage_modifier() -> void:
	# Confirms @export var serialization works end-to-end.
	# Failures here indicate a .tres save/load regression (see Story 002 AC-4).
	var original := PranaType.new()
	original.base_damage_modifier = 1.25

	var save_error: Error = ResourceSaver.save(original, _ROUNDTRIP_PATH)
	assert_int(save_error).is_equal(OK)

	var loaded: PranaType = ResourceLoader.load(_ROUNDTRIP_PATH) as PranaType
	assert_object(loaded).is_not_null()
	assert_float(loaded.base_damage_modifier).is_equal(1.25)
