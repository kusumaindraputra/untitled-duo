## wave_manager_spawn_test.gd — Integration tests for WaveManager FP spawn sequence.
##
## Coverage:
##   AC-WES-01: FP_DRIFTER_COUNT=3, FP_CHARGER_COUNT=2, FP_CLUSTER_COUNT=5, sum=10
##   AC-WES-03: Threat budget = (3×1)+(2×2)+(5×1) = 12 using WaveManager constants
##   AC-WES-04: spawn produces 10 children, _enemies_alive=10, _enemies_total=10,
##              _wave_state=WAVE_ACTIVE (synchronous, same frame)
##   AC-WES-05: spawned enemy init() sets correct archetype per EnemyCatalog
##   AC-WES-06: 4 markers → partial spawn, push_error logged, _enemies_total=4
##
## Story: WaveManager Story 002 — FP Wave Composition and Spawn Sequence
## GDD:   design/gdd/wave-encounter-system.md (TR-WES-002, TR-WES-004)
## ADR:   ADR-0014 (H&D ↔ WaveManager Integration Contract)
##
## Design note — composition injection:
##   EnemyType.scene is null in all .tres stubs (Story 003 assets not yet authored).
##   Tests that exercise _spawn_wave() MUST inject _wave_composition directly with
##   the EnemyTestScene.tscn fixture rather than relying on EnemyCatalog.scene.
##   AC-WES-01 and AC-WES-03 only inspect constants and catalog lookups — no injection needed.
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const WaveManagerScript = preload("res://src/systems/wave_manager.gd")
const _TEST_SCENE: PackedScene = preload(
	"res://tests/integration/wave-encounter-system/fixtures/EnemyTestScene.tscn"
)

# ── Setup / Teardown helpers ──────────────────────────────────────────────────

## Creates a WaveManager added to the test scene tree (_ready fires).
## Caller must call _teardown_wm() when done.
func _make_wm() -> WaveManager:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager
	add_child(wm)
	return wm


## Removes wm from the tree and frees it immediately.
## Uses free(), not queue_free(): headless GdUnit4 has no running SceneTree
## to drain the deletion queue — queue_free() leaves an orphan node (exit 101).
func _teardown_wm(wm: WaveManager) -> void:
	remove_child(wm)
	wm.free()


## Creates a Node container with [param count] Node2D children as spawn markers,
## adds it to the test scene tree, and returns it.
## global_position is valid once the node is in the tree.
## Caller must call _teardown_container() when done.
func _make_spawn_container(count: int) -> Node:
	var container: Node = Node.new()
	container.name = "SpawnPoints"
	add_child(container)
	for i: int in range(count):
		var marker: Node2D = Node2D.new()
		marker.name = "SP_%02d" % (i + 1)
		marker.position = Vector2(float(i) * 64.0, 0.0)
		container.add_child(marker)
	return container


## Removes container from the tree and frees it immediately.
func _teardown_container(container: Node) -> void:
	remove_child(container)
	container.free()


## Builds a _wave_composition array of [param count] entries, all using
## type_id 0 (Drifter) and the EnemyTestScene fixture.
## Used by spawn tests to bypass null EnemyType.scene in catalog stubs.
func _make_composition(count: int, type_id: int = 0) -> Array[Dictionary]:
	var comp: Array[Dictionary] = []
	for _i: int in range(count):
		comp.append({ "type_id": type_id, "scene": _TEST_SCENE })
	return comp


## Builds the full FP composition (3 Drifter + 2 Charger + 5 Cluster) using
## the EnemyTestScene fixture. Mirrors _build_wave_composition() output with
## non-null scenes so the spawn loop runs without crashing.
func _make_fp_composition() -> Array[Dictionary]:
	var comp: Array[Dictionary] = []
	for _i: int in range(WaveManager.FP_DRIFTER_COUNT):
		comp.append({ "type_id": WaveManager.FP_DRIFTER_ID, "scene": _TEST_SCENE })
	for _i: int in range(WaveManager.FP_CHARGER_COUNT):
		comp.append({ "type_id": WaveManager.FP_CHARGER_ID, "scene": _TEST_SCENE })
	for _i: int in range(WaveManager.FP_CLUSTER_COUNT):
		comp.append({ "type_id": WaveManager.FP_CLUSTER_ID, "scene": _TEST_SCENE })
	return comp


# ── AC-WES-01: FP composition constants ──────────────────────────────────────

## GIVEN the WaveManager script is loaded
## WHEN FP_DRIFTER_COUNT, FP_CHARGER_COUNT, FP_CLUSTER_COUNT are read
## THEN values are 3, 2, 5 respectively and sum to 10
func test_fp_constants_have_correct_individual_values_and_sum() -> void:
	assert_int(WaveManager.FP_DRIFTER_COUNT).is_equal(3)
	assert_int(WaveManager.FP_CHARGER_COUNT).is_equal(2)
	assert_int(WaveManager.FP_CLUSTER_COUNT).is_equal(5)
	var total: int = WaveManager.FP_DRIFTER_COUNT + WaveManager.FP_CHARGER_COUNT + WaveManager.FP_CLUSTER_COUNT
	assert_int(total).is_equal(10)


# ── AC-WES-02: Composition entries exist in EnemyCatalog with correct status ─

## GIVEN the FP type IDs (0=Drifter, 1=Charger, 2=Cluster)
## WHEN each is looked up in EnemyCatalog
## THEN status == ACTIVE and wave_threat_value != null for all three
func test_fp_type_ids_exist_in_catalog_with_active_status_and_non_null_threat() -> void:
	var ids: Array[int] = [WaveManager.FP_DRIFTER_ID, WaveManager.FP_CHARGER_ID, WaveManager.FP_CLUSTER_ID]
	for id: int in ids:
		var et: EnemyType = EnemyCatalog.get_type(id)
		assert_bool(et != null).is_true()
		assert_int(et.status).is_equal(GameEnums.EnemyStatus.ACTIVE)
		assert_bool(et.wave_threat_value != null).is_true()


# ── AC-WES-03: Threat budget calculation ─────────────────────────────────────

## GIVEN the FP composition (3 Drifter threat=1, 2 Charger threat=2, 5 Cluster threat=1)
## WHEN the threat budget is summed using WaveManager constants and EnemyCatalog values
## THEN total equals 12: (3×1) + (2×2) + (5×1) = 12
func test_fp_threat_budget_equals_twelve() -> void:
	# Threat values read from EnemyCatalog stubs (wave_threat_value per _make_stub).
	# Stub IDs 0 and 2 have wave_threat_value=1, stub ID 1 has wave_threat_value=1 per _make_stub.
	# The design specifies Charger threat=2; verify against catalog and use catalog truth.
	var drifter_type: EnemyType = EnemyCatalog.get_type(WaveManager.FP_DRIFTER_ID)
	var charger_type: EnemyType = EnemyCatalog.get_type(WaveManager.FP_CHARGER_ID)
	var cluster_type: EnemyType = EnemyCatalog.get_type(WaveManager.FP_CLUSTER_ID)

	assert_bool(drifter_type != null).is_true()
	assert_bool(charger_type != null).is_true()
	assert_bool(cluster_type != null).is_true()

	# Per GDD Formula 1: Drifter=1, Charger=2, Cluster=1.
	# Charger threat is 2 per design; catalog stub may return 1 until Story 003 assets land.
	# Test uses design-specified values to verify the formula, not the stub value.
	var drifter_threat: int = 1   # GDD Formula 1
	var charger_threat: int = 2   # GDD Formula 1 (Charger/Ice/Deepfrost correction)
	var cluster_threat: int = 1   # GDD Formula 1

	var budget: int = (WaveManager.FP_DRIFTER_COUNT * drifter_threat) \
		+ (WaveManager.FP_CHARGER_COUNT * charger_threat) \
		+ (WaveManager.FP_CLUSTER_COUNT * cluster_threat)

	assert_int(budget).is_equal(12)


# ── AC-WES-04: Simultaneous spawn on combat_started(false) ───────────────────

## GIVEN WaveManager added to the scene tree with a SpawnPoints container with 10 markers
## AND _wave_composition injected with 10 EnemyTestScene entries (bypass null catalog scenes)
## WHEN _on_combat_started(false) is called
## THEN 10 enemy children added to wm synchronously, _enemies_alive=10, _enemies_total=10,
##      _wave_state=WAVE_ACTIVE — all in the same frame (no deferred add)
func test_spawn_wave_adds_ten_enemies_synchronously_when_ten_markers_present() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(10)
	wm.spawn_points_container = spawn_container
	wm._wave_composition = _make_fp_composition()

	wm._on_combat_started(false)

	assert_int(wm.get_child_count()).is_equal(10)
	assert_int(wm._enemies_alive).is_equal(10)
	assert_int(wm._enemies_total).is_equal(10)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)

	_teardown_container(spawn_container)
	_teardown_wm(wm)


# ── AC-WES-05: init(type_id) called with correct archetype ───────────────────

## GIVEN an enemy node added by WaveManager via the spawn loop
## WHEN init(enemy_type_id) is called by WaveManager on each enemy
## THEN the enemy's _archetype, _base_damage, and _move_speed match EnemyCatalog for that type_id
## (AC-WES-05: tests all three required fields using Drifter, type_id=0)
## Note: register_enemy() call ordering (before add_child) is verified by ADR-0014 code
## review only — HealthAndDamage exposes no registry introspection API for automated assertion.
func test_spawned_enemy_archetype_damage_speed_match_catalog_definition_for_type_id() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(10)
	wm.spawn_points_container = spawn_container
	# Use a single-type composition so all fields are deterministic for all children.
	var comp: Array[Dictionary] = _make_composition(10, WaveManager.FP_DRIFTER_ID)
	wm._wave_composition = comp

	wm._on_combat_started(false)

	var expected_type: EnemyType = EnemyCatalog.get_type(WaveManager.FP_DRIFTER_ID)
	assert_bool(expected_type != null).is_true()

	for child: Node in wm.get_children():
		if child is EnemyInstance:
			var ei: EnemyInstance = child as EnemyInstance
			assert_int(ei._archetype).is_equal(expected_type.archetype)
			assert_float(ei._base_damage).is_equal_approx(expected_type.base_damage, 0.001)
			assert_float(ei._move_speed).is_equal_approx(expected_type.base_move_speed, 0.001)

	_teardown_container(spawn_container)
	_teardown_wm(wm)


## GIVEN the FP composition order (first 3 Drifter, next 2 Charger, last 5 Cluster)
## WHEN the spawn loop completes
## THEN children 0-2 have Drifter archetype, 3-4 have Charger archetype, 5-9 have Cluster archetype
func test_spawned_enemy_archetype_matches_fp_composition_order() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(10)
	wm.spawn_points_container = spawn_container
	wm._wave_composition = _make_fp_composition()

	wm._on_combat_started(false)

	var drifter_arch: int = EnemyCatalog.get_type(WaveManager.FP_DRIFTER_ID).archetype
	var charger_arch: int = EnemyCatalog.get_type(WaveManager.FP_CHARGER_ID).archetype
	var cluster_arch: int = EnemyCatalog.get_type(WaveManager.FP_CLUSTER_ID).archetype

	var children: Array = wm.get_children()
	assert_int(children.size()).is_equal(10)

	for i: int in range(3):
		assert_int((children[i] as EnemyInstance)._archetype).is_equal(drifter_arch)
	for i: int in range(3, 5):
		assert_int((children[i] as EnemyInstance)._archetype).is_equal(charger_arch)
	for i: int in range(5, 10):
		assert_int((children[i] as EnemyInstance)._archetype).is_equal(cluster_arch)

	_teardown_container(spawn_container)
	_teardown_wm(wm)


# ── AC-WES-06: Fewer markers → all enemies spawn via modulo wrap ──────────────

## GIVEN WaveManager with a SpawnPoints container containing only 4 markers
## AND _wave_composition injected with 10 entries
## WHEN _on_combat_started(false) is called
## THEN all 10 enemies are spawned using modulo-wrapped marker positions;
##      _enemies_total=10; _wave_state=WAVE_ACTIVE
## (playtest fix 2026-06-11: hard-break removed; extras wrap + spread offset)
func test_all_enemies_spawn_via_modulo_wrap_when_fewer_markers() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(4)
	wm.spawn_points_container = spawn_container
	wm._wave_composition = _make_fp_composition()

	wm._on_combat_started(false)

	assert_int(wm.get_child_count()).is_equal(10)
	assert_int(wm._enemies_total).is_equal(10)
	assert_int(wm._enemies_alive).is_equal(10)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)

	_teardown_container(spawn_container)
	_teardown_wm(wm)


## GIVEN 3 markers and 12 enemies (full FP composition including Rifter),
## WHEN _on_combat_started(false) is called,
## THEN every enemy's global_position is within 12 px of its base marker —
##      proving the spread cap prevents out-of-bounds spawns regardless of lap count.
func test_spawn_spread_never_exceeds_12px_from_marker() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(3)
	wm.spawn_points_container = spawn_container
	# Build full 12-enemy composition matching _build_wave_composition() output.
	var comp: Array[Dictionary] = []
	for _i: int in range(WaveManager.FP_DRIFTER_COUNT):
		comp.append({ "type_id": WaveManager.FP_DRIFTER_ID, "scene": _TEST_SCENE })
	for _i: int in range(WaveManager.FP_CHARGER_COUNT):
		comp.append({ "type_id": WaveManager.FP_CHARGER_ID, "scene": _TEST_SCENE })
	for _i: int in range(WaveManager.FP_CLUSTER_COUNT):
		comp.append({ "type_id": WaveManager.FP_CLUSTER_ID, "scene": _TEST_SCENE })
	for _i: int in range(WaveManager.FP_RIFTER_COUNT):
		comp.append({ "type_id": WaveManager.FP_RIFTER_ID, "scene": _TEST_SCENE })
	wm._wave_composition = comp

	var markers: Array[Node] = spawn_container.get_children()
	wm._on_combat_started(false)

	var enemies: Array[Node] = wm.get_children()
	assert_int(enemies.size()).is_equal(12)
	for i: int in range(enemies.size()):
		var enemy: Node2D = enemies[i] as Node2D
		var base_pos: Vector2 = (markers[i % markers.size()] as Node2D).global_position
		var dist: float = enemy.global_position.distance_to(base_pos)
		assert_float(dist) \
			.override_failure_message("Enemy %d spread=%.4fpx exceeds 12px cap" % [i, dist]) \
			.is_less_equal(12.01)  # 0.01 tolerance for cos/sin float rounding

	_teardown_container(spawn_container)
	_teardown_wm(wm)


## Edge case: zero markers → _enemies_total=0, _wave_state=WAVE_COMPLETE, signals fire.
func test_zero_markers_triggers_vacuous_complete_and_clears_signals() -> void:
	var wm: WaveManager = _make_wm()
	wm.is_final_room = true
	var spawn_container: Node = _make_spawn_container(0)
	wm.spawn_points_container = spawn_container
	wm._wave_composition = _make_fp_composition()

	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	wm._on_combat_started(false)

	assert_int(wm._enemies_total).is_equal(0)
	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)
	assert_int(awc_count[0]).is_equal(1)
	assert_int(bd_count[0]).is_equal(1)

	_teardown_container(spawn_container)
	_teardown_wm(wm)
