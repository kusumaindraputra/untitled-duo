## prana_catalog_test.gd — Unit tests for PranaCatalog Autoload (ADR-0008).
##
## Coverage:
##   AC-1:  get_type() returns a PranaType (non-null) for every valid ID in the catalog
##   AC-1e: String-property mutation on a returned copy is invisible to a subsequent call
##   AC-2:  Returned icon is non-null (ImageTexture stub satisfies non-null contract)
##   AC-3:  get_type() returns null + does not crash for out-of-bounds IDs (-1, count())
##   AC-4:  Property mutation on a returned copy is invisible to a subsequent get_type() call
##   AC-5:  get_all_types() returns exactly count() entries, all non-null
##   AC-6:  get_type() before _initialized=true returns null (initialization guard)
##   AC-6p: Two sequential get_type(0) calls return identical values for all 12 properties
##   AC-7:  _validate_all() on a well-formed catalog raises no crash
##   AC-7c: _validate_all() is non-blocking — corrupt entry logs error; catalog stays usable
##   AC-8:  get_all_types() copies are independent (mutating one does not affect another)
##
## Known gap — G4: push_error() assertions for AC-3/AC-5/AC-6 guard tests are not
##   implemented. GdUnit4 v6 has no push_error capture API. Null return + no-crash is the
##   observable contract verified here; push_error behavior is confirmed via manual run.
##
## Framework: GDUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/unit/prana-data/prana_catalog_test.gd --ignoreHeadlessMode
extends GdUnitTestSuite

# PranaCatalog has no class_name — Godot 4 rejects class_name matching the Autoload
# node name. Use preload() to instantiate fresh instances in tests.
const PranaCatalogScript = preload("res://src/data/prana_catalog.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh PranaCatalog node with [param types] pre-loaded into its
## internal `_types` array and `_initialized` already set to true.
##
## This helper bypasses `_ready()` to avoid file I/O and Autoload order
## dependencies, keeping every test fast and deterministic.
func _make_catalog_with(types: Array[PranaType]) -> Node:
	var catalog: Node = PranaCatalogScript.new()
	catalog._types = types
	catalog._initialized = true
	auto_free(catalog)
	return catalog


## Creates a minimal PranaType with the given [param id] and non-null asset fields.
##
## icon: 1×1 ImageTexture — same strategy as PranaCatalog._make_stub().
## audio_signature: empty AudioStreamWAV — satisfies non-null audio check.
func _make_prana_type(id: int) -> PranaType:
	var pt := PranaType.new()
	pt.id = id
	pt.name = "TestPrana_%d" % id
	pt.element = "test"
	pt.semantic_identity = "Test entry for unit tests"
	pt.base_damage_modifier = 1.0
	var img: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	pt.icon = ImageTexture.create_from_image(img)
	pt.audio_signature = AudioStreamWAV.new()
	return pt


# ── AC-1: get_type() returns a valid PranaType for every in-bounds ID ─────────

func test_prana_catalog_get_type_returns_non_null_for_valid_id() -> void:
	# Arrange
	var types: Array[PranaType] = [_make_prana_type(0), _make_prana_type(1)]
	var catalog: Node = _make_catalog_with(types)

	# Act / Assert — both valid IDs must return non-null PranaType instances
	assert_object(catalog.get_type(0)).is_not_null()
	assert_object(catalog.get_type(1)).is_not_null()


func test_prana_catalog_get_type_returns_correct_id_field() -> void:
	# Arrange
	var types: Array[PranaType] = [_make_prana_type(0), _make_prana_type(1)]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var result: PranaType = catalog.get_type(1)

	# Assert — the returned copy carries the correct id value
	assert_int(result.id).is_equal(1)


# ── AC-6p: Two sequential get_type(0) calls return identical values for all 12 properties

func test_prana_catalog_get_type_returns_consistent_properties_across_calls() -> void:
	# Arrange
	var types: Array[PranaType] = [_make_prana_type(0)]
	var catalog: Node = _make_catalog_with(types)

	# Act — two sequential calls must produce copies with identical property values
	var a: PranaType = catalog.get_type(0)
	var b: PranaType = catalog.get_type(0)

	# Assert — all 12 exported PranaType properties are consistent between calls
	assert_int(a.id).is_equal(b.id)
	assert_str(a.name).is_equal(b.name)
	assert_str(a.element).is_equal(b.element)
	assert_str(a.semantic_identity).is_equal(b.semantic_identity)
	assert_bool(a.color == b.color).is_true()
	assert_object(a.icon).is_not_null()
	assert_object(b.icon).is_not_null()
	assert_object(a.audio_signature).is_not_null()
	assert_object(b.audio_signature).is_not_null()
	assert_int(a.cast_animation).is_equal(b.cast_animation)
	assert_int(a.damage_class).is_equal(b.damage_class)
	assert_int(a.base_status).is_equal(b.base_status)
	assert_float(a.base_damage_modifier).is_equal(b.base_damage_modifier)


# ── AC-2: Returned icon is non-null ───────────────────────────────────────────

func test_prana_catalog_get_type_icon_is_not_null() -> void:
	# Arrange — icon is set via _make_prana_type() (ImageTexture stub)
	var types: Array[PranaType] = [_make_prana_type(0)]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var result: PranaType = catalog.get_type(0)

	# Assert
	assert_object(result.icon).is_not_null()


# ── AC-3: get_type() returns null for out-of-bounds IDs ──────────────────────

func test_prana_catalog_get_type_returns_null_for_negative_id() -> void:
	# Arrange
	var types: Array[PranaType] = [_make_prana_type(0)]
	var catalog: Node = _make_catalog_with(types)

	# Act — push_error() is expected to fire (not assertable via GdUnit4 v6)
	var result: PranaType = catalog.get_type(-1)

	# Assert — must return null, must not crash
	assert_object(result).is_null()


func test_prana_catalog_get_type_returns_null_for_id_equal_to_count() -> void:
	# Arrange — catalog has 1 entry; valid ID is 0; ID 1 is out of bounds
	var types: Array[PranaType] = [_make_prana_type(0)]
	var catalog: Node = _make_catalog_with(types)

	# Act — push_error() is expected to fire (not assertable via GdUnit4 v6)
	var result: PranaType = catalog.get_type(catalog.count())

	# Assert
	assert_object(result).is_null()


# ── AC-4: Mutation of returned copy is invisible to the catalog ───────────────

func test_prana_catalog_get_type_mutation_invisible_to_subsequent_call() -> void:
	# Arrange
	var types: Array[PranaType] = [_make_prana_type(0)]
	var catalog: Node = _make_catalog_with(types)
	# Record the original modifier value so we have a baseline to compare against
	var original_modifier: float = catalog.get_type(0).base_damage_modifier

	# Act — mutate the returned copy
	var copy_a: PranaType = catalog.get_type(0)
	copy_a.base_damage_modifier = 999.0

	# Assert — a second call must return the unmodified original value
	var copy_b: PranaType = catalog.get_type(0)
	assert_float(copy_b.base_damage_modifier).is_equal(original_modifier)


func test_prana_catalog_get_type_icon_reassignment_invisible_to_catalog() -> void:
	# Arrange — AC-PD-04c: reassigning a reference-type field on copy_a must not
	# affect copy_b returned by a subsequent get_type() call.
	# Note: duplicate_deep() creates new sub-Resource instances (it deep-copies
	# Resources), so copy_b.icon != original_icon by design. The test verifies
	# isolation at the property-assignment level: copy_b must not carry copy_a's stub.
	var types: Array[PranaType] = [_make_prana_type(0)]
	var catalog: Node = _make_catalog_with(types)

	# Act — Caller A replaces icon with a red stub
	var copy_a: PranaType = catalog.get_type(0)
	var replacement_img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	replacement_img.fill(Color.RED)
	var stub_icon: ImageTexture = ImageTexture.create_from_image(replacement_img)
	copy_a.icon = stub_icon

	# Assert — Caller B gets a fresh copy; its icon is NOT the stub assigned by Caller A
	var copy_b: PranaType = catalog.get_type(0)
	assert_bool(is_same(copy_b.icon, stub_icon)).is_false()
	# Sanity: copy_b still has a non-null icon (catalog entry is intact)
	assert_object(copy_b.icon).is_not_null()


# ── AC-1e: String-property mutation invisible to subsequent call ──────────────

func test_prana_catalog_get_type_name_mutation_invisible_to_subsequent_call() -> void:
	# Arrange — AC-1 edge case: verify String-property isolation (non-primitive)
	var types: Array[PranaType] = [_make_prana_type(0)]
	var catalog: Node = _make_catalog_with(types)
	var original_name: String = catalog.get_type(0).name

	# Act — mutate the name field on the returned copy
	var copy_a: PranaType = catalog.get_type(0)
	copy_a.name = "MUTATED"

	# Assert — a second call returns the unmodified original name
	var copy_b: PranaType = catalog.get_type(0)
	assert_str(copy_b.name).is_equal(original_name)


# ── AC-5: get_all_types() returns the correct count and non-null entries ───────

func test_prana_catalog_get_all_types_returns_correct_count() -> void:
	# Arrange
	var types: Array[PranaType] = [
		_make_prana_type(0),
		_make_prana_type(1),
		_make_prana_type(2),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var all_types: Array[PranaType] = catalog.get_all_types()

	# Assert
	assert_int(all_types.size()).is_equal(3)


func test_prana_catalog_get_all_types_all_entries_non_null() -> void:
	# Arrange
	var types: Array[PranaType] = [_make_prana_type(0), _make_prana_type(1)]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var all_types: Array[PranaType] = catalog.get_all_types()

	# Assert — every element must be a non-null PranaType
	for entry: PranaType in all_types:
		assert_object(entry).is_not_null()


# ── AC-6: Initialization guard — get_type() before _ready() returns null ─────

func test_prana_catalog_get_type_before_initialized_returns_null() -> void:
	# Arrange — create catalog but leave _initialized at its default (false).
	# Untyped var: required to set _types directly before _initialized is set.
	var catalog = PranaCatalogScript.new()
	auto_free(catalog)
	var types: Array[PranaType] = [_make_prana_type(0)]
	catalog._types = types
	# _initialized deliberately NOT set to true

	# Act — push_error() is expected to fire (not assertable via GdUnit4 v6)
	var result: PranaType = catalog.get_type(0)

	# Assert — must return null without crashing
	assert_object(result).is_null()


func test_prana_catalog_get_all_types_before_initialized_returns_empty_array() -> void:
	# Arrange
	# Untyped var: required to set _types directly before _initialized is set.
	var catalog = PranaCatalogScript.new()
	auto_free(catalog)
	var types: Array[PranaType] = [_make_prana_type(0)]
	catalog._types = types
	# _initialized deliberately NOT set to true

	# Act — push_error() is expected to fire (not assertable via GdUnit4 v6)
	var result: Array[PranaType] = catalog.get_all_types()

	# Assert
	assert_int(result.size()).is_equal(0)


# ── AC-7: _validate_all() on a well-formed catalog does not crash ─────────────

func test_prana_catalog_validate_all_does_not_crash_on_valid_catalog() -> void:
	# Arrange — all types have valid fields; no push_error expected
	var types: Array[PranaType] = [
		_make_prana_type(0),
		_make_prana_type(1),
		_make_prana_type(2),
		_make_prana_type(3),
		_make_prana_type(4),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act — must not crash
	catalog._validate_all()

	# Assert — reaching this line means no exception was thrown
	assert_bool(true).is_true()


# ── AC-7c: _validate_all() is non-blocking — corrupt entry does not halt validation

func test_prana_catalog_validate_all_continues_past_corrupt_modifier() -> void:
	# Arrange — type 0 has base_damage_modifier = 0.0 (triggers push_error for type 0).
	# Per ADR-0008, validation is non-blocking: the error is logged but validation
	# continues for types 1 and 2, and the catalog remains usable afterward.
	var corrupt: PranaType = _make_prana_type(0)
	corrupt.base_damage_modifier = 0.0
	var types: Array[PranaType] = [corrupt, _make_prana_type(1), _make_prana_type(2)]
	var catalog: Node = _make_catalog_with(types)

	# Act — push_error fires for type 0; must not crash or halt
	catalog._validate_all()

	# Assert — catalog still usable; count unchanged; valid types still accessible
	assert_int(catalog.count()).is_equal(3)
	var t1: PranaType = catalog.get_type(1)
	assert_object(t1).is_not_null()
	assert_float(t1.base_damage_modifier).is_equal(1.0)


# ── AC-8: get_all_types() copies are independent of each other ────────────────

func test_prana_catalog_get_all_types_copies_are_independent() -> void:
	# Arrange
	var types: Array[PranaType] = [_make_prana_type(0), _make_prana_type(1)]
	var catalog: Node = _make_catalog_with(types)

	# Act — get two separate snapshots and mutate the first
	var snapshot_a: Array[PranaType] = catalog.get_all_types()
	snapshot_a[0].base_damage_modifier = 42.0

	var snapshot_b: Array[PranaType] = catalog.get_all_types()

	# Assert — snapshot_b is unaffected by the mutation in snapshot_a
	assert_float(snapshot_b[0].base_damage_modifier).is_not_equal(42.0)
