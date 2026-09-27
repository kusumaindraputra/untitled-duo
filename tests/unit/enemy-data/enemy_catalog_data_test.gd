## enemy_catalog_data_test.gd — Data-integrity tests for the REAL EnemyCatalog.
##
## Unlike enemy_catalog_test.gd (which uses synthetic fixtures to test the catalog's
## API behavior), this suite loads the actual .tres assets via _ready() and asserts
## the shipped data matches the Enemy Data GDD + entity registry. It exists to catch
## design-vs-data drift: if someone rebalances a .tres without updating the GDD/registry
## (the exact gap found 2026-06-21), these assertions fail and force propagation.
##
## Source of truth: design/gdd/enemy-data.md "MVP Enemy Catalog" table +
##                  design/registry/entities.yaml (enemies section).
##
## Framework: GDUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/unit/enemy-data/enemy_catalog_data_test.gd --ignoreHeadlessMode
extends GdUnitTestSuite

const EnemyCatalogScript = preload("res://src/data/enemy_catalog.gd")

# Enemy IDs (stable — never reassigned).
const ID_DRIFTER: int = 0
const ID_CHARGER: int = 1
const ID_CLUSTER: int = 2
const ID_WARPED_WARDEN: int = 3
const ID_RIFTER: int = 4
const ID_VAULT_SENTINEL: int = 5
const ID_SPINNER: int = 6
const ID_SNIPER: int = 7
const ID_MORTAR: int = 8
const ID_WEAVER: int = 9
const ID_SPLITTER: int = 10
const ID_PULSAR: int = 12
const ID_WISP: int = 13
const ID_LANCER: int = 14
const ACTIVE_IDS: Array[int] = [0, 1, 2, 4, 6, 7, 8, 9, 10, 12, 13, 14]


# ── Helpers ───────────────────────────────────────────────────────────────────

## Loads the real catalog from .tres by invoking _ready() directly. The node is never
## added to the scene tree, so it is torn down with free() per the headless test rule.
func _load_real_catalog() -> Node:
	var catalog: Node = EnemyCatalogScript.new()
	catalog._ready()  # _load_catalog() (real .tres) + _validate_all() + _initialized = true
	return catalog


func _ids_of(types: Array) -> Array[int]:
	var ids: Array[int] = []
	for et: EnemyType in types:
		ids.append(et.id)
	ids.sort()
	return ids


# ── Catalog composition ───────────────────────────────────────────────────────

## AC-ED-01 / AC-ED-02: 12 active + 3 vs_scope bosses = 15 total entries (ADR-0018
## roster, the ADR-0026 final boss and the ADR-0053 floor enemies).
func test_real_catalog_has_fifteen_entries() -> void:
	var catalog: Node = _load_real_catalog()

	assert_int(catalog.count()).is_equal(15)

	catalog.free()


## AC-ED-01: active entries are the four FP enemies plus the ADR-0018 roster.
func test_real_catalog_active_ids_exclude_bosses() -> void:
	var catalog: Node = _load_real_catalog()

	var active_ids: Array[int] = _ids_of(catalog.get_active_types())

	assert_array(active_ids).contains_exactly(ACTIVE_IDS)

	catalog.free()


## AC-ED-02: boss entries ship at vs_scope (not ACTIVE).
func test_real_catalog_bosses_are_vs_scope() -> void:
	var catalog: Node = _load_real_catalog()

	assert_int(catalog.get_type(ID_WARPED_WARDEN).status).is_equal(GameEnums.EnemyStatus.VS_SCOPE)
	assert_int(catalog.get_type(ID_VAULT_SENTINEL).status).is_equal(GameEnums.EnemyStatus.VS_SCOPE)

	catalog.free()


## AC-ED-16: spawnable set excludes bosses (status guard + null threat).
func test_real_catalog_spawnable_excludes_bosses() -> void:
	var catalog: Node = _load_real_catalog()

	var spawnable_ids: Array[int] = _ids_of(catalog.get_spawnable_types())

	assert_array(spawnable_ids).contains_exactly(ACTIVE_IDS)

	catalog.free()


## AC-ED-09 / AC-ED-10: boss threat/drop fields are strictly null.
func test_real_catalog_boss_nullable_fields_are_null() -> void:
	var catalog: Node = _load_real_catalog()

	for boss_id: int in [ID_WARPED_WARDEN, ID_VAULT_SENTINEL]:
		var boss: EnemyType = catalog.get_type(boss_id)
		assert_object(boss.wave_threat_value).is_null()
		assert_object(boss.drop_prana_type).is_null()
		assert_object(boss.drop_rate).is_null()

	catalog.free()


# ── Stats match the Enemy Data GDD table (2026-06-20 rebalance values) ─────────

## base_hp / base_damage per enemy. These mirror the GDD "MVP Enemy Catalog" table
## exactly — a .tres edit that diverges from the GDD breaks this test on purpose.
func test_real_catalog_base_stats_match_gdd() -> void:
	var catalog: Node = _load_real_catalog()

	# id -> [base_hp, base_damage]
	var expected: Dictionary = {
		ID_DRIFTER: [50, 14.0],
		ID_CHARGER: [90, 30.0],
		ID_CLUSTER: [30, 10.0],
		ID_RIFTER: [32, 12.0],
		ID_WARPED_WARDEN: [1800, 25.0],
		ID_VAULT_SENTINEL: [600, 25.0],
		ID_SPINNER: [44, 10.0],
		ID_SNIPER: [28, 14.0],
		ID_MORTAR: [40, 14.0],
		ID_WEAVER: [30, 9.0],
		ID_SPLITTER: [40, 12.0],
		ID_PULSAR: [45, 10.0],
		ID_WISP: [34, 10.0],
		ID_LANCER: [70, 14.0],
	}

	for id: int in expected:
		var et: EnemyType = catalog.get_type(id)
		var want: Array = expected[id]
		assert_int(et.base_hp).is_equal(want[0])
		assert_float(et.base_damage).is_equal_approx(want[1], 0.001)

	catalog.free()


## Names, archetypes, and affiliations match the GDD. Rifter must be SHOOTER with
## Verdant affiliation (sole Verdant dropper); bosses are NONE affiliation.
func test_real_catalog_identity_fields_match_gdd() -> void:
	var catalog: Node = _load_real_catalog()

	var drifter: EnemyType = catalog.get_type(ID_DRIFTER)
	assert_str(drifter.name).is_equal("Drifter")
	assert_int(drifter.archetype).is_equal(GameEnums.EnemyArchetype.SEEKER)
	assert_int(drifter.prana_affiliation).is_equal(GameEnums.DamageClass.SHADOW)

	var charger: EnemyType = catalog.get_type(ID_CHARGER)
	assert_str(charger.name).is_equal("Charger")
	assert_int(charger.archetype).is_equal(GameEnums.EnemyArchetype.RUSHER)
	assert_int(charger.prana_affiliation).is_equal(GameEnums.DamageClass.ICE)

	var cluster: EnemyType = catalog.get_type(ID_CLUSTER)
	assert_str(cluster.name).is_equal("Cluster")
	assert_int(cluster.archetype).is_equal(GameEnums.EnemyArchetype.SWARMER)
	assert_int(cluster.prana_affiliation).is_equal(GameEnums.DamageClass.LIGHTNING)

	var rifter: EnemyType = catalog.get_type(ID_RIFTER)
	assert_str(rifter.name).is_equal("Rifter")
	assert_int(rifter.archetype).is_equal(GameEnums.EnemyArchetype.SHOOTER)
	assert_int(rifter.prana_affiliation).is_equal(GameEnums.DamageClass.NATURE)
	assert_int(rifter.drop_prana_type).is_equal(GameEnums.DamageClass.NATURE)  # Verdant ID 4

	for boss_id: int in [ID_WARPED_WARDEN, ID_VAULT_SENTINEL]:
		assert_int(catalog.get_type(boss_id).archetype).is_equal(GameEnums.EnemyArchetype.BOSS)
		assert_int(catalog.get_type(boss_id).prana_affiliation).is_equal(GameEnums.DamageClass.NONE)

	catalog.free()


## AC-ED-14: sprite sizes match the art bible values in the GDD.
func test_real_catalog_sprite_sizes_match_gdd() -> void:
	var catalog: Node = _load_real_catalog()

	assert_vector(catalog.get_type(ID_DRIFTER).sprite_size).is_equal(Vector2i(16, 16))
	assert_vector(catalog.get_type(ID_CHARGER).sprite_size).is_equal(Vector2i(12, 20))
	assert_vector(catalog.get_type(ID_CLUSTER).sprite_size).is_equal(Vector2i(24, 24))
	assert_vector(catalog.get_type(ID_RIFTER).sprite_size).is_equal(Vector2i(14, 14))
	assert_vector(catalog.get_type(ID_WARPED_WARDEN).sprite_size).is_equal(Vector2i(96, 96))
	assert_vector(catalog.get_type(ID_VAULT_SENTINEL).sprite_size).is_equal(Vector2i(96, 96))

	catalog.free()
