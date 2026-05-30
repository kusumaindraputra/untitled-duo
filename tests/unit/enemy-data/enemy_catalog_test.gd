## enemy_catalog_test.gd — Unit tests for EnemyCatalog Autoload (Story 002).
##
## Coverage:
##   AC-1:  get_type() returns a deep copy — name mutation invisible to subsequent call (AC-ED-08)
##   AC-2:  Two sequential get_type() calls return identical field values (AC-ED-07)
##   AC-3:  get_type(99) returns null; get_type(-1) returns null (AC-ED-11)
##   AC-4:  get_active_types() excludes VS_SCOPE entries (AC-ED-12)
##   AC-5:  get_active_types() excludes INACTIVE entries (AC-ED-13)
##   AC-6:  get_spawnable_types() excludes null wave_threat_value entries (AC-ED-16)
##   AC-7:  Single get_type() call exposes all required fields (AC-ED-15)
##   AC-8:  Initialization guard — get_type() before _ready() returns null
##   AC-9:  _validate_all() does not crash on a well-formed catalog
##   AC-10: _validate_all() is non-blocking — corrupt entry logs error; catalog stays usable
##
## Known gap — G4: push_error() assertions for guard tests are not implementable.
##   GdUnit4 v6 has no push_error capture API. Null return + no-crash is the observable
##   contract verified here; push_error behavior is confirmed via manual run.
##
## Framework: GDUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/unit/enemy-data/enemy_catalog_test.gd --ignoreHeadlessMode
extends GdUnitTestSuite

# EnemyCatalog has no class_name — Godot 4 rejects class_name matching the Autoload
# node name. Use preload() to instantiate fresh instances in tests.
const EnemyCatalogScript = preload("res://src/data/enemy_catalog.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh EnemyCatalog node with [param types] pre-loaded into its
## internal `_types` dictionary and `_initialized` already set to true.
##
## This helper bypasses `_ready()` to avoid file I/O and Autoload order
## dependencies, keeping every test fast and deterministic.
func _make_catalog_with(types: Array[EnemyType]) -> Node:
	var catalog: Node = EnemyCatalogScript.new()
	for entry: EnemyType in types:
		catalog._types[entry.id] = entry
	catalog._initialized = true
	return catalog


## Creates a minimal EnemyType with the given [param id], fully populated with
## valid non-default values. wave_threat_value is set to 1 (non-null) by default.
func _make_enemy_type(id: int, status: GameEnums.EnemyStatus = GameEnums.EnemyStatus.ACTIVE) -> EnemyType:
	var et := EnemyType.new()
	et.id = id
	et.name = "TestEnemy_%d" % id
	et.archetype = GameEnums.EnemyArchetype.SEEKER
	et.prana_affiliation = GameEnums.DamageClass.NONE
	et.base_hp = 10
	et.base_damage = 1.0
	et.base_move_speed = 60.0
	et.status = status
	et.wave_threat_value = 1
	return et


## Creates a minimal EnemyType with null wave_threat_value (boss-style entry).
func _make_enemy_type_no_threat(id: int) -> EnemyType:
	var et: EnemyType = _make_enemy_type(id, GameEnums.EnemyStatus.VS_SCOPE)
	et.wave_threat_value = null
	return et


## Creates a VS_SCOPE EnemyType with a non-null wave_threat_value.
## Used to independently verify the ACTIVE status guard in get_spawnable_types().
func _make_enemy_type_vs_scope_with_threat(id: int) -> EnemyType:
	return _make_enemy_type(id, GameEnums.EnemyStatus.VS_SCOPE)


# ── AC-1: get_type() returns a deep copy — mutation invisible to catalog ───────

func test_enemy_catalog_get_type_name_mutation_invisible_to_subsequent_call() -> void:
	# Arrange
	var types: Array[EnemyType] = [_make_enemy_type(0)]
	var catalog: Node = _make_catalog_with(types)
	var original_name: String = catalog.get_type(0).name

	# Act — mutate the name on the returned copy
	var copy_a: EnemyType = catalog.get_type(0)
	copy_a.name = "MUTATED"

	# Assert — a second call must return the unmodified original name (AC-ED-08)
	var copy_b: EnemyType = catalog.get_type(0)
	assert_str(copy_b.name).is_equal(original_name)


func test_enemy_catalog_get_type_numeric_mutation_invisible_to_subsequent_call() -> void:
	# Arrange
	var types: Array[EnemyType] = [_make_enemy_type(0)]
	var catalog: Node = _make_catalog_with(types)
	var original_hp: int = catalog.get_type(0).base_hp

	# Act — mutate a numeric field on the returned copy
	var copy_a: EnemyType = catalog.get_type(0)
	copy_a.base_hp = 9999

	# Assert — a second call returns the unmodified original value
	var copy_b: EnemyType = catalog.get_type(0)
	assert_int(copy_b.base_hp).is_equal(original_hp)


# ── AC-2: Two sequential get_type() calls return identical field values ────────

func test_enemy_catalog_get_type_returns_consistent_id_across_calls() -> void:
	# Arrange
	var types: Array[EnemyType] = [_make_enemy_type(0)]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var a: EnemyType = catalog.get_type(0)
	var b: EnemyType = catalog.get_type(0)

	# Assert — all required fields are consistent between calls (AC-ED-07)
	assert_int(a.id).is_equal(b.id)
	assert_str(a.name).is_equal(b.name)
	assert_int(a.archetype).is_equal(b.archetype)
	assert_int(a.prana_affiliation).is_equal(b.prana_affiliation)
	assert_int(a.base_hp).is_equal(b.base_hp)
	assert_float(a.base_damage).is_equal(b.base_damage)
	assert_float(a.base_move_speed).is_equal(b.base_move_speed)
	assert_int(a.status).is_equal(b.status)


# ── AC-3: get_type() returns null for non-existent IDs ───────────────────────

func test_enemy_catalog_get_type_returns_null_for_unknown_id() -> void:
	# Arrange
	var types: Array[EnemyType] = [
		_make_enemy_type(0), _make_enemy_type(1), _make_enemy_type(2), _make_enemy_type(3),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act — push_error() is expected to fire (not assertable via GdUnit4 v6)
	var result: EnemyType = catalog.get_type(99)

	# Assert — must return null (strict null — not a default EnemyType) (AC-ED-11)
	assert_object(result).is_null()


func test_enemy_catalog_get_type_returns_null_for_negative_id() -> void:
	# Arrange
	var types: Array[EnemyType] = [_make_enemy_type(0)]
	var catalog: Node = _make_catalog_with(types)

	# Act — push_error() is expected to fire (not assertable via GdUnit4 v6)
	var result: EnemyType = catalog.get_type(-1)

	# Assert — must return null, must not crash
	assert_object(result).is_null()


# ── AC-4: get_active_types() excludes VS_SCOPE entries ────────────────────────

func test_enemy_catalog_get_active_types_excludes_vs_scope() -> void:
	# Arrange — IDs 0, 1, 2 are ACTIVE; ID 3 is VS_SCOPE
	var types: Array[EnemyType] = [
		_make_enemy_type(0),
		_make_enemy_type(1),
		_make_enemy_type(2),
		_make_enemy_type_no_threat(3),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var active: Array[EnemyType] = catalog.get_active_types()

	# Assert — result must contain exactly IDs 0, 1, 2 (AC-ED-12)
	assert_int(active.size()).is_equal(3)
	var active_ids: Array[int] = []
	for entry: EnemyType in active:
		active_ids.append(entry.id)
	assert_bool(active_ids.has(0)).is_true()
	assert_bool(active_ids.has(1)).is_true()
	assert_bool(active_ids.has(2)).is_true()
	assert_bool(active_ids.has(3)).is_false()


# ── AC-5: get_active_types() excludes INACTIVE entries ────────────────────────

func test_enemy_catalog_get_active_types_excludes_inactive() -> void:
	# Arrange — ID 0 is ACTIVE; ID 1 is INACTIVE
	var inactive_entry: EnemyType = _make_enemy_type(1, GameEnums.EnemyStatus.INACTIVE)
	inactive_entry.wave_threat_value = null
	var types: Array[EnemyType] = [
		_make_enemy_type(0),
		inactive_entry,
	]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var active: Array[EnemyType] = catalog.get_active_types()

	# Assert — INACTIVE entry (ID 1) must not appear in the result (AC-ED-13)
	assert_int(active.size()).is_equal(1)
	assert_int(active[0].id).is_equal(0)


# ── AC-6: get_spawnable_types() excludes null wave_threat_value entries ───────

func test_enemy_catalog_get_spawnable_types_excludes_null_threat() -> void:
	# Arrange — IDs 0, 1, 2 are ACTIVE with threat values; ID 3 is VS_SCOPE with null threat
	var types: Array[EnemyType] = [
		_make_enemy_type(0),
		_make_enemy_type(1),
		_make_enemy_type(2),
		_make_enemy_type_no_threat(3),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var spawnable: Array[EnemyType] = catalog.get_spawnable_types()

	# Assert — result must contain IDs 0, 1, 2 only; ID 3 absent (AC-ED-16)
	assert_int(spawnable.size()).is_equal(3)
	var spawnable_ids: Array[int] = []
	for entry: EnemyType in spawnable:
		spawnable_ids.append(entry.id)
	assert_bool(spawnable_ids.has(0)).is_true()
	assert_bool(spawnable_ids.has(1)).is_true()
	assert_bool(spawnable_ids.has(2)).is_true()
	assert_bool(spawnable_ids.has(3)).is_false()


func test_enemy_catalog_get_spawnable_types_count_is_three() -> void:
	# Arrange — same as above; edge case: count must be exactly 3
	var types: Array[EnemyType] = [
		_make_enemy_type(0),
		_make_enemy_type(1),
		_make_enemy_type(2),
		_make_enemy_type_no_threat(3),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var spawnable: Array[EnemyType] = catalog.get_spawnable_types()

	# Assert
	assert_int(spawnable.size()).is_equal(3)


func test_enemy_catalog_get_spawnable_types_excludes_vs_scope_with_non_null_threat() -> void:
	# Arrange — VS_SCOPE entry with non-null wave_threat_value verifies the ACTIVE
	# status guard works independently of the null-threat guard (AC-6 gap coverage).
	var types: Array[EnemyType] = [
		_make_enemy_type(0),
		_make_enemy_type(1),
		_make_enemy_type(2),
		_make_enemy_type_vs_scope_with_threat(3),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act
	var spawnable: Array[EnemyType] = catalog.get_spawnable_types()

	# Assert — VS_SCOPE entry with non-null threat must be excluded by the ACTIVE guard
	assert_int(spawnable.size()).is_equal(3)
	var spawnable_ids: Array[int] = []
	for entry: EnemyType in spawnable:
		spawnable_ids.append(entry.id)
	assert_bool(spawnable_ids.has(3)).is_false()


# ── AC-7: Single get_type() call exposes all required fields ──────────────────

func test_enemy_catalog_get_type_returns_all_required_fields_in_one_call() -> void:
	# Arrange — fully populated EnemyType for ID 0
	var et: EnemyType = EnemyType.new()
	et.id = 0
	et.name = "Drifter"
	et.archetype = GameEnums.EnemyArchetype.SEEKER
	et.prana_affiliation = GameEnums.DamageClass.NONE
	et.base_hp = 30
	et.base_damage = 5.0
	et.base_move_speed = 80.0
	et.status = GameEnums.EnemyStatus.ACTIVE
	et.wave_threat_value = 1
	var types: Array[EnemyType] = [et]
	var catalog: Node = _make_catalog_with(types)

	# Act — single call must expose all required fields (AC-ED-15)
	var result: EnemyType = catalog.get_type(0)

	# Assert — all 13 fields accessible from a single get_type() call (AC-ED-15)
	assert_int(result.id).is_equal(0)
	assert_str(result.name).is_equal("Drifter")
	assert_int(result.archetype).is_equal(GameEnums.EnemyArchetype.SEEKER)
	assert_int(result.base_hp).is_equal(30)
	assert_float(result.base_damage).is_equal(5.0)
	assert_float(result.base_move_speed).is_equal(80.0)
	# Remaining 7 fields — typed enums, sentinel, Variant, Vector2i, nullable Object
	assert_int(result.prana_affiliation).is_equal(GameEnums.DamageClass.NONE)
	assert_int(result.status).is_equal(GameEnums.EnemyStatus.ACTIVE)
	assert_bool(result.wave_threat_value == 1).is_true()
	assert_bool(result.sprite_size == Vector2i(16, 16)).is_true()
	assert_bool(result.drop_prana_type == null).is_true()
	assert_bool(result.drop_rate == null).is_true()
	assert_object(result.scene).is_null()


# ── AC-8: Initialization guard — get_type() before _ready() returns null ─────

func test_enemy_catalog_get_type_before_initialized_returns_null() -> void:
	# Arrange — create catalog but leave _initialized at its default (false).
	# Untyped var: required to set _types directly before _initialized is set.
	var catalog = EnemyCatalogScript.new()
	catalog._types[0] = _make_enemy_type(0)
	# _initialized deliberately NOT set to true

	# Act — push_error() is expected to fire (not assertable via GdUnit4 v6)
	var result: EnemyType = catalog.get_type(0)

	# Assert — must return null without crashing
	assert_object(result).is_null()


func test_enemy_catalog_get_active_types_before_initialized_returns_empty_array() -> void:
	# Arrange
	var catalog = EnemyCatalogScript.new()
	catalog._types[0] = _make_enemy_type(0)
	# _initialized deliberately NOT set to true

	# Act
	var result: Array[EnemyType] = catalog.get_active_types()

	# Assert
	assert_int(result.size()).is_equal(0)


func test_enemy_catalog_get_spawnable_types_before_initialized_returns_empty_array() -> void:
	# Arrange
	var catalog = EnemyCatalogScript.new()
	catalog._types[0] = _make_enemy_type(0)
	# _initialized deliberately NOT set to true

	# Act
	var result: Array[EnemyType] = catalog.get_spawnable_types()

	# Assert
	assert_int(result.size()).is_equal(0)


# ── AC-9: _validate_all() does not crash on a well-formed catalog ─────────────

func test_enemy_catalog_validate_all_does_not_crash_on_valid_catalog() -> void:
	# Arrange — all four entries are fully valid; no push_error expected
	var types: Array[EnemyType] = [
		_make_enemy_type(0),
		_make_enemy_type(1),
		_make_enemy_type(2),
		_make_enemy_type_no_threat(3),
	]
	var catalog: Node = _make_catalog_with(types)

	# Act — must not crash
	catalog._validate_all()

	# Assert — reaching this line means no exception was thrown; catalog still usable
	assert_int(catalog.count()).is_equal(4)


# ── AC-10: _validate_all() is non-blocking — corrupt entry does not halt ──────

func test_enemy_catalog_validate_all_continues_past_corrupt_entry() -> void:
	# Arrange — entry 0 has empty name (triggers push_error for entry 0).
	# Per ADR-0008, validation is non-blocking: error is logged but continues
	# for entries 1 and 2, and the catalog remains usable afterward.
	var corrupt: EnemyType = _make_enemy_type(0)
	corrupt.name = ""
	var types: Array[EnemyType] = [corrupt, _make_enemy_type(1), _make_enemy_type(2)]
	var catalog: Node = _make_catalog_with(types)

	# Act — push_error fires for entry 0; must not crash or halt
	catalog._validate_all()

	# Assert — catalog still usable; count unchanged; valid entries still accessible
	assert_int(catalog.count()).is_equal(3)
	var t1: EnemyType = catalog.get_type(1)
	assert_object(t1).is_not_null()
	assert_str(t1.name).is_equal("TestEnemy_1")


func test_enemy_catalog_validate_all_continues_past_negative_id() -> void:
	# Arrange — entry with id = -1 triggers push_error; entry 1 is valid
	var bad_id_entry: EnemyType = _make_enemy_type(0)
	bad_id_entry.id = -1
	var types: Array[EnemyType] = [bad_id_entry, _make_enemy_type(1)]
	var catalog: Node = _make_catalog_with(types)

	# Act — push_error fires for the negative-id entry; must not crash
	catalog._validate_all()

	# Assert — catalog still usable; valid entry 1 is still accessible
	var t1: EnemyType = catalog.get_type(1)
	assert_object(t1).is_not_null()
	assert_int(t1.id).is_equal(1)
