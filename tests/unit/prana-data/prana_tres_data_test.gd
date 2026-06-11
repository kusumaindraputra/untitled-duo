## prana_tres_data_test.gd — Data integrity tests for the five PranaType .tres files.
##
## Coverage (Story 004 / AC-2 through AC-6):
##   AC-2:  Names roundtrip — PranaCatalog.get_type(N).name for N = 0–4
##   AC-3:  Damage modifier values (0→1.25, 1→0.90, 2→1.15, 3→0.80, 4→0.70)
##   AC-4:  damage_class enum matches GDD catalog table
##   AC-5:  base_status enum matches GDD catalog table
##   AC-6:  Color values — verified via Color.is_equal_approx(), never ==
##
## .tres files do not require a separate `--import` step (text resources are loaded
## directly by the resource loader). If any test fails with "catalog not loaded",
## check that res://assets/data/prana_types/ contains all five .tres files.
##
## Framework: GDUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/unit/prana-data/prana_tres_data_test.gd --ignoreHeadlessMode
extends GdUnitTestSuite

const PranaCatalogScript = preload("res://src/data/prana_catalog.gd")

const _FIRST_TRES: String = "res://assets/data/prana_types/prana_fire.tres"


# ── Helper ────────────────────────────────────────────────────────────────────

## Creates a PranaCatalog loaded from the actual .tres files on disk.
## Fails the calling test with a descriptive message if files are not found.
func _load_catalog_from_disk() -> Node:
	var catalog: Node = PranaCatalogScript.new()
	catalog._load_types()
	catalog._initialized = true
	auto_free(catalog)
	return catalog


func _assert_catalog_loaded(catalog: Node, test_label: String) -> bool:
	if catalog == null or catalog.count() == 0:
		assert_bool(false).override_failure_message(
			test_label + ": catalog empty — check that res://assets/data/prana_types/ "
			+ "contains the five PranaType .tres files authored in Story 004."
		).is_true()
		return false
	return true


# ── Prerequisite guard ────────────────────────────────────────────────────────

func test_prana_tres_files_exist_on_disk() -> void:
	assert_bool(ResourceLoader.exists(_FIRST_TRES)).override_failure_message(
		"prana_fire.tres not found at res://assets/data/prana_types/. "
		+ "Verify the five .tres files were authored (Story 004 AC-Prerequisite)."
	).is_true()


func test_prana_catalog_loads_five_types_from_tres_files() -> void:
	var catalog: Node = _load_catalog_from_disk()
	assert_int(catalog.count()).override_failure_message(
		"Expected 5 PranaTypes from .tres files but got %d. "
		% catalog.count()
		+ "Check that all five files exist in res://assets/data/prana_types/."
	).is_equal(5)


# ── AC-2: Name roundtrip ──────────────────────────────────────────────────────

func test_prana_tres_name_id0_is_ashfire() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-2 name id0"):
		return
	assert_str(catalog.get_type(0).name).is_equal("Ashfire")


func test_prana_tres_name_id1_is_voidblue() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-2 name id1"):
		return
	assert_str(catalog.get_type(1).name).is_equal("Voidblue")


func test_prana_tres_name_id2_is_stormgold() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-2 name id2"):
		return
	assert_str(catalog.get_type(2).name).is_equal("Stormgold")


func test_prana_tres_name_id3_is_deepfrost() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-2 name id3"):
		return
	assert_str(catalog.get_type(3).name).is_equal("Deepfrost")


func test_prana_tres_name_id4_is_verdant() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-2 name id4"):
		return
	assert_str(catalog.get_type(4).name).is_equal("Verdant")


# ── AC-3: base_damage_modifier values ────────────────────────────────────────

func test_prana_tres_modifier_ashfire_is_1_25() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-3 modifier id0"):
		return
	assert_float(catalog.get_type(0).base_damage_modifier).is_equal_approx(1.25, 0.001)


func test_prana_tres_modifier_voidblue_is_0_90() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-3 modifier id1"):
		return
	assert_float(catalog.get_type(1).base_damage_modifier).is_equal_approx(0.90, 0.001)


func test_prana_tres_modifier_stormgold_is_1_15() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-3 modifier id2"):
		return
	assert_float(catalog.get_type(2).base_damage_modifier).is_equal_approx(1.15, 0.001)


func test_prana_tres_modifier_deepfrost_is_0_80() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-3 modifier id3"):
		return
	assert_float(catalog.get_type(3).base_damage_modifier).is_equal_approx(0.80, 0.001)


func test_prana_tres_modifier_verdant_is_0_70() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-3 modifier id4"):
		return
	assert_float(catalog.get_type(4).base_damage_modifier).is_equal_approx(0.70, 0.001)


# ── AC-4: damage_class enum values ────────────────────────────────────────────

func test_prana_tres_damage_class_ashfire_is_fire() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-4 damage_class id0"):
		return
	assert_int(catalog.get_type(0).damage_class).is_equal(GameEnums.DamageClass.FIRE)


func test_prana_tres_damage_class_voidblue_is_shadow() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-4 damage_class id1"):
		return
	assert_int(catalog.get_type(1).damage_class).is_equal(GameEnums.DamageClass.SHADOW)


func test_prana_tres_damage_class_stormgold_is_lightning() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-4 damage_class id2"):
		return
	assert_int(catalog.get_type(2).damage_class).is_equal(GameEnums.DamageClass.LIGHTNING)


func test_prana_tres_damage_class_deepfrost_is_ice() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-4 damage_class id3"):
		return
	assert_int(catalog.get_type(3).damage_class).is_equal(GameEnums.DamageClass.ICE)


func test_prana_tres_damage_class_verdant_is_nature() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-4 damage_class id4"):
		return
	assert_int(catalog.get_type(4).damage_class).is_equal(GameEnums.DamageClass.NATURE)


# ── AC-5: base_status enum values ─────────────────────────────────────────────

func test_prana_tres_base_status_ashfire_is_burn() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-5 base_status id0"):
		return
	assert_int(catalog.get_type(0).base_status).is_equal(GameEnums.BaseStatus.BURN)


func test_prana_tres_base_status_voidblue_is_blind() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-5 base_status id1"):
		return
	assert_int(catalog.get_type(1).base_status).is_equal(GameEnums.BaseStatus.BLIND)


func test_prana_tres_base_status_stormgold_is_stun() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-5 base_status id2"):
		return
	assert_int(catalog.get_type(2).base_status).is_equal(GameEnums.BaseStatus.STUN)


func test_prana_tres_base_status_deepfrost_is_freeze() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-5 base_status id3"):
		return
	assert_int(catalog.get_type(3).base_status).is_equal(GameEnums.BaseStatus.FREEZE)


func test_prana_tres_base_status_verdant_is_regenerate() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-5 base_status id4"):
		return
	assert_int(catalog.get_type(4).base_status).is_equal(GameEnums.BaseStatus.REGENERATE)


# ── AC-6: Color values ────────────────────────────────────────────────────────
# Always use Color.is_equal_approx() — float components do not round-trip exactly.

func test_prana_tres_color_ashfire_matches_gdd() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-6 color id0"):
		return
	assert_bool(catalog.get_type(0).color.is_equal_approx(Color("#F24C1D"))).is_true()


func test_prana_tres_color_voidblue_matches_gdd() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-6 color id1"):
		return
	assert_bool(catalog.get_type(1).color.is_equal_approx(Color("#4A5EF5"))).is_true()


func test_prana_tres_color_stormgold_matches_gdd() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-6 color id2"):
		return
	assert_bool(catalog.get_type(2).color.is_equal_approx(Color("#FFCC00"))).is_true()


func test_prana_tres_color_deepfrost_matches_gdd() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-6 color id3"):
		return
	assert_bool(catalog.get_type(3).color.is_equal_approx(Color("#3DD9F0"))).is_true()


func test_prana_tres_color_verdant_matches_gdd() -> void:
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-6 color id4"):
		return
	assert_bool(catalog.get_type(4).color.is_equal_approx(Color("#1AC953"))).is_true()


# ── AC-1 (startup validation): _validate_all() produces no crash ──────────────

func test_prana_tres_validate_all_does_not_crash() -> void:
	# _validate_all() logs via push_error() — not assertable in GdUnit4 v6 (known gap G4).
	# Reaching this line without a crash is the observable contract.
	var catalog: Node = _load_catalog_from_disk()
	if not _assert_catalog_loaded(catalog, "AC-1 validate_all"):
		return
	catalog._validate_all()
	assert_bool(true).is_true()
