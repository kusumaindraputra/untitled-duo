## enemy_instance_skeleton_test.gd — Unit tests for EnemyInstance skeleton (Story EAI-001).
##
## Coverage (13 ACs):
##   AC-EAI-01:  process_mode == PROCESS_MODE_PAUSABLE
##   AC-EAI-02:  child Area2D named "HitArea" exists with a CollisionShape2D child;
##               root node also has a CollisionShape2D direct child
##   AC-EAI-03a: init(0, catalog) → _archetype == SEEKER, _base_damage == 8.0, _move_speed == 80.0
##   AC-EAI-03b: init(1, catalog) → _archetype == RUSHER, _base_damage == 20.0, _move_speed == 50.0
##   AC-EAI-03c: init(2, catalog) → _archetype == SWARMER, _base_damage == 4.0, _move_speed == 70.0
##   AC-EAI-04:  _combat_active = false → _physics_process sets velocity = Vector2.ZERO
##   AC-EAI-05:  _state == DEAD AND _combat_active = true → _physics_process still zeroes velocity
##   AC-EAI-06:  _on_combat_started() sets _combat_active = true
##   AC-EAI-18:  is_in_group("enemy") returns true
##   AC-EAI-19:  is_in_group("player") returns false
##   S3-13a:     is_alive() returns true when _state == CHASING (default / alive state)
##   S3-13b:     is_alive() returns false when _state == DEAD
##   S3-13c:     is_alive() returns true before init() — default _state is CHASING
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite)
extends GdUnitTestSuite

const EnemyInstanceScript = preload("res://src/gameplay/enemy_instance.gd")

# ── MockCatalog ───────────────────────────────────────────────────────────────

## Minimal in-memory catalog for test isolation — avoids Autoload file I/O and
## the EnemyCatalog initialization guard. Injected via init(id, catalog).
class MockCatalog:
	var _types: Dictionary = {}

	func add_type(et: EnemyType) -> void:
		_types[et.id] = et

	func get_type(id: int) -> EnemyType:
		if _types.has(id):
			return _types[id].duplicate_deep()
		return null


# ── Helpers ───────────────────────────────────────────────────────────────────

## Creates a fresh EnemyInstance. Not added to the scene tree unless the test
## requires _ready() to fire (groups, process_mode, signal connections).
func _make_enemy() -> EnemyInstance:
	return EnemyInstanceScript.new() as EnemyInstance


## Creates a fully populated MockCatalog with the three FP-scope enemy types:
##   ID 0 — Drifter (SEEKER,  8.0 dmg, 80.0 spd)
##   ID 1 — Charger (RUSHER, 20.0 dmg, 50.0 spd)
##   ID 2 — Cluster (SWARMER, 4.0 dmg, 70.0 spd)
func _make_catalog() -> MockCatalog:
	var catalog := MockCatalog.new()

	var drifter := EnemyType.new()
	drifter.id = 0
	drifter.name = "Drifter"
	drifter.archetype = GameEnums.EnemyArchetype.SEEKER
	drifter.base_damage = 8.0
	drifter.base_move_speed = 80.0
	drifter.base_hp = 30
	drifter.status = GameEnums.EnemyStatus.ACTIVE
	drifter.wave_threat_value = 1
	catalog.add_type(drifter)

	var charger := EnemyType.new()
	charger.id = 1
	charger.name = "Charger"
	charger.archetype = GameEnums.EnemyArchetype.RUSHER
	charger.base_damage = 20.0
	charger.base_move_speed = 50.0
	charger.base_hp = 35
	charger.status = GameEnums.EnemyStatus.ACTIVE
	charger.wave_threat_value = 2
	catalog.add_type(charger)

	var cluster := EnemyType.new()
	cluster.id = 2
	cluster.name = "Cluster"
	cluster.archetype = GameEnums.EnemyArchetype.SWARMER
	cluster.base_damage = 4.0
	cluster.base_move_speed = 70.0
	cluster.base_hp = 10
	cluster.status = GameEnums.EnemyStatus.ACTIVE
	cluster.wave_threat_value = 1
	catalog.add_type(cluster)

	return catalog


# ── AC-EAI-01: process_mode is PAUSABLE ──────────────────────────────────────

func test_enemy_instance_process_mode_is_pausable() -> void:
	var enemy: EnemyInstance = _make_enemy()
	add_child(enemy)

	assert_int(enemy.process_mode).is_equal(Node.PROCESS_MODE_PAUSABLE)

	remove_child(enemy)
	enemy.free()


# ── AC-EAI-02: HitArea child and root CollisionShape2D exist ─────────────────

func test_enemy_instance_hit_area_child_and_root_collision_shape_exist() -> void:
	var enemy: EnemyInstance = _make_enemy()
	add_child(enemy)

	# Root has a direct CollisionShape2D child
	var root_shape: CollisionShape2D = null
	for child: Node in enemy.get_children():
		if child is CollisionShape2D:
			root_shape = child as CollisionShape2D
			break
	assert_object(root_shape).is_not_null()

	# HitArea exists as a direct child and is an Area2D
	var hit_area: Node = enemy.get_node_or_null("HitArea")
	assert_object(hit_area).is_not_null()
	assert_bool(hit_area is Area2D).is_true()

	# HitArea has a CollisionShape2D child
	var hit_shape: CollisionShape2D = null
	for child: Node in hit_area.get_children():
		if child is CollisionShape2D:
			hit_shape = child as CollisionShape2D
			break
	assert_object(hit_shape).is_not_null()

	remove_child(enemy)
	enemy.free()


# ── AC-EAI-03a: init(0) caches Drifter / SEEKER stats ────────────────────────

func test_enemy_instance_init_drifter_caches_seeker_stats() -> void:
	var enemy: EnemyInstance = _make_enemy()
	var catalog: MockCatalog = _make_catalog()

	enemy.init(0, catalog)

	assert_int(enemy._archetype).is_equal(GameEnums.EnemyArchetype.SEEKER)
	assert_float(enemy._base_damage).is_equal(8.0)
	assert_float(enemy._move_speed).is_equal(80.0)
	enemy.free()


# ── AC-EAI-03b: init(1) caches Charger / RUSHER stats ────────────────────────

func test_enemy_instance_init_charger_caches_rusher_stats() -> void:
	var enemy: EnemyInstance = _make_enemy()
	var catalog: MockCatalog = _make_catalog()

	enemy.init(1, catalog)

	assert_int(enemy._archetype).is_equal(GameEnums.EnemyArchetype.RUSHER)
	assert_float(enemy._base_damage).is_equal(20.0)
	assert_float(enemy._move_speed).is_equal(50.0)
	enemy.free()


# ── AC-EAI-03c: init(2) caches Cluster / SWARMER stats ───────────────────────

func test_enemy_instance_init_cluster_caches_swarmer_stats() -> void:
	var enemy: EnemyInstance = _make_enemy()
	var catalog: MockCatalog = _make_catalog()

	enemy.init(2, catalog)

	assert_int(enemy._archetype).is_equal(GameEnums.EnemyArchetype.SWARMER)
	assert_float(enemy._base_damage).is_equal(4.0)
	assert_float(enemy._move_speed).is_equal(70.0)
	enemy.free()


# ── AC-EAI-04: combat inactive → _physics_process zeroes velocity ─────────────

func test_enemy_instance_physics_process_combat_inactive_holds_velocity_zero() -> void:
	var enemy: EnemyInstance = _make_enemy()
	enemy.velocity = Vector2(100.0, 0.0)
	# _combat_active is false by default

	enemy._physics_process(1.0 / 60.0)

	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	enemy.free()


# ── AC-EAI-05: DEAD state takes precedence over _combat_active ───────────────

func test_enemy_instance_physics_process_dead_state_takes_precedence_over_combat_active() -> void:
	var enemy: EnemyInstance = _make_enemy()
	enemy._combat_active = true
	enemy._state = EnemyInstance.EnemyState.DEAD
	enemy.velocity = Vector2(80.0, 0.0)

	enemy._physics_process(1.0 / 60.0)

	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	enemy.free()


# ── AC-EAI-06: _on_combat_started sets _combat_active = true ─────────────────
# AC-EAI-06 partial: velocity.length() > 0 assertion deferred to Story 002
# (skeleton _physics_process has no movement direction code yet).

func test_enemy_instance_combat_started_sets_combat_active_true() -> void:
	var enemy: EnemyInstance = _make_enemy()
	assert_bool(enemy._combat_active).is_false()

	enemy._on_combat_started(false)

	assert_bool(enemy._combat_active).is_true()
	# velocity > 0 deferred to Story 002 — skeleton has no movement direction code.
	# Confirm skeleton holds velocity at zero even with the gate open.
	enemy._physics_process(1.0 / 60.0)
	assert_vector(enemy.velocity).is_equal(Vector2.ZERO)
	enemy.free()


# ── init() invalid ID: defaults unchanged, push_error fired ──────────────────

func test_enemy_instance_init_invalid_id_leaves_defaults_unchanged() -> void:
	var enemy: EnemyInstance = _make_enemy()
	var catalog: MockCatalog = _make_catalog()  # IDs 0, 1, 2 only

	enemy.init(99, catalog)  # invalid ID — catalog.get_type returns null

	# Fields remain at constructor defaults — push_error fired but no crash
	assert_int(enemy._archetype).is_equal(GameEnums.EnemyArchetype.SEEKER)
	assert_float(enemy._base_damage).is_equal(0.0)
	assert_float(enemy._move_speed).is_equal(0.0)
	enemy.free()


# ── AC-EAI-18: ready adds to enemy group ─────────────────────────────────────

func test_enemy_instance_ready_adds_to_enemy_group() -> void:
	var enemy: EnemyInstance = _make_enemy()
	add_child(enemy)

	assert_bool(enemy.is_in_group(&"enemy")).is_true()

	remove_child(enemy)
	enemy.free()


# ── AC-EAI-19: ready does NOT add to player group ────────────────────────────

func test_enemy_instance_ready_not_in_player_group() -> void:
	var enemy: EnemyInstance = _make_enemy()
	add_child(enemy)

	assert_bool(enemy.is_in_group(&"player")).is_false()

	remove_child(enemy)
	enemy.free()


# ── S3-13: is_alive() contract ───────────────────────────────────────────────

func test_enemy_instance_is_alive_returns_true_when_chasing() -> void:
	var enemy: EnemyInstance = _make_enemy()
	enemy._state = EnemyInstance.EnemyState.CHASING

	assert_bool(enemy.is_alive()).is_true()

	enemy.free()


func test_enemy_instance_is_alive_returns_false_when_dead() -> void:
	var enemy: EnemyInstance = _make_enemy()
	enemy._state = EnemyInstance.EnemyState.DEAD

	assert_bool(enemy.is_alive()).is_false()

	enemy.free()


func test_enemy_instance_is_alive_returns_true_before_init() -> void:
	# Default _state is CHASING — is_alive() must return true without init() call.
	var enemy: EnemyInstance = _make_enemy()

	assert_bool(enemy.is_alive()).is_true()

	enemy.free()
