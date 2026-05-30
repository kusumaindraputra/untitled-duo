## enemy_type_schema_test.gd — Unit tests for EnemyType resource schema (Story 001).
##
## Coverage:
##   AC-1: EnemyStatus enum exists with correct values (ACTIVE=0, VS_SCOPE=1, INACTIVE=2)
##   AC-2: EnemyType can be instantiated
##   AC-3: prana_affiliation defaults to DamageClass.NONE (= -1), not FIRE (0)
##   AC-4: Nullable fields (drop_prana_type, drop_rate, wave_threat_value) default to null
##   AC-5: scene field is PackedScene typed and defaults to null
##   AC-6: Typed enum fields accept correct enum values on assign/read-back
##
## Framework: GDUnit4 v6
## Run: godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd
##      -a res://tests/unit/enemy-data/enemy_type_schema_test.gd --ignoreHeadlessMode
extends GdUnitTestSuite


# ── AC-1: EnemyStatus enum values ────────────────────────────────────────────

func test_enemy_type_schema_enemy_status_active_is_zero() -> void:
	assert_int(GameEnums.EnemyStatus.ACTIVE).is_equal(0)


func test_enemy_type_schema_enemy_status_vs_scope_is_one() -> void:
	assert_int(GameEnums.EnemyStatus.VS_SCOPE).is_equal(1)


func test_enemy_type_schema_enemy_status_inactive_is_two() -> void:
	assert_int(GameEnums.EnemyStatus.INACTIVE).is_equal(2)


func test_enemy_type_schema_enemy_status_values_are_distinct() -> void:
	assert_bool(
		GameEnums.EnemyStatus.ACTIVE != GameEnums.EnemyStatus.VS_SCOPE and
		GameEnums.EnemyStatus.VS_SCOPE != GameEnums.EnemyStatus.INACTIVE
	).is_true()


# ── AC-2: EnemyType instantiation ────────────────────────────────────────────

func test_enemy_type_schema_can_be_instantiated() -> void:
	var enemy := EnemyType.new()
	assert_object(enemy).is_not_null()


func test_enemy_type_schema_is_resource() -> void:
	var enemy := EnemyType.new()
	assert_bool(enemy is Resource).is_true()


# ── AC-3: prana_affiliation defaults to DamageClass.NONE = -1 ────────────────

func test_enemy_type_schema_prana_affiliation_default_is_none() -> void:
	var enemy := EnemyType.new()
	assert_int(enemy.prana_affiliation).is_equal(GameEnums.DamageClass.NONE)


func test_enemy_type_schema_prana_affiliation_default_is_minus_one() -> void:
	# Explicit int check — NONE must be -1 per TR-ED-004, not 0 (FIRE)
	var enemy := EnemyType.new()
	assert_int(enemy.prana_affiliation).is_equal(-1)


# ── AC-4: Nullable fields default to null ────────────────────────────────────

func test_enemy_type_schema_drop_prana_type_default_is_null() -> void:
	var enemy := EnemyType.new()
	assert_object(enemy.drop_prana_type).is_null()


func test_enemy_type_schema_drop_rate_default_is_null() -> void:
	var enemy := EnemyType.new()
	assert_object(enemy.drop_rate).is_null()


func test_enemy_type_schema_wave_threat_value_default_is_null() -> void:
	var enemy := EnemyType.new()
	assert_object(enemy.wave_threat_value).is_null()


# ── AC-5: scene field ─────────────────────────────────────────────────────────

func test_enemy_type_schema_scene_default_is_null() -> void:
	var enemy := EnemyType.new()
	assert_object(enemy.scene).is_null()


# ── AC-6: Enum fields accept and read back correct values ────────────────────

func test_enemy_type_schema_archetype_accepts_boss_value() -> void:
	var enemy := EnemyType.new()
	enemy.archetype = GameEnums.EnemyArchetype.BOSS
	assert_int(enemy.archetype).is_equal(GameEnums.EnemyArchetype.BOSS)


func test_enemy_type_schema_status_accepts_vs_scope_value() -> void:
	var enemy := EnemyType.new()
	enemy.status = GameEnums.EnemyStatus.VS_SCOPE
	assert_int(enemy.status).is_equal(GameEnums.EnemyStatus.VS_SCOPE)


func test_enemy_type_schema_prana_affiliation_accepts_fire_value() -> void:
	var enemy := EnemyType.new()
	enemy.prana_affiliation = GameEnums.DamageClass.FIRE
	assert_int(enemy.prana_affiliation).is_equal(GameEnums.DamageClass.FIRE)


func test_enemy_type_schema_status_default_is_active() -> void:
	var enemy := EnemyType.new()
	assert_int(enemy.status).is_equal(GameEnums.EnemyStatus.ACTIVE)
