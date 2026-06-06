## wave_manager_integration_test.gd — Integration tests for full FP run lifecycle.
##
## Coverage:
##   AC-WES-14: Full FP run — preparation_started(0,1) → combat_started(false) → 10 × enemy_killed
##              → all_waves_cleared + boss_defeated emitted exactly once each; _wave_state=WAVE_COMPLETE
##   AC-WES-15: Player death mid-wave → WaveManager emits no completion signals;
##              subsequent preparation_started resets state to IDLE with zeroed counts
##
## Story: WaveManager Story 004 — Full FP Run Integration Test
## GDD:   design/gdd/wave-encounter-system.md (TR-WES-001, TR-WES-003, TR-WES-005)
## ADR:   ADR-0014 (H&D ↔ WaveManager Integration Contract)
## ADR:   ADR-0003 (Signal-Driven Architecture — real signal wiring verified end-to-end)
##
## Setup pattern:
##   - WaveManager added to tree via add_child(): triggers _ready(), connects to real Autoloads
##   - _wave_composition injected AFTER preparation_started fires (which rebuilds it with null catalog scenes)
##   - EnemyTestScene fixture used so spawn loop can instantiate without crashing on null PackedScene
##   - enemy_killed signals emitted with fake instance_ids (0-9): WaveManager's kill handler ignores
##     the instance_id param; EnemyInstance handlers return early (id != get_instance_id()), so no
##     enemy death animations or queue_free calls are triggered mid-test
##   - Teardown: remove_child() then free() — not queue_free() (headless GdUnit4 has no SceneTree
##     deletion queue; queue_free() would orphan nodes and cause exit 101)
##
## Framework: GdUnit4 v6.1.3 (extends GdUnitTestSuite) | Godot 4.6
extends GdUnitTestSuite

const WaveManagerScript = preload("res://src/systems/wave_manager.gd")
const _TEST_SCENE: PackedScene = preload(
	"res://tests/integration/wave-encounter-system/fixtures/EnemyTestScene.tscn"
)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_wm() -> WaveManager:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager
	add_child(wm)
	return wm


func _teardown_wm(wm: WaveManager) -> void:
	remove_child(wm)
	wm.free()


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


func _teardown_container(container: Node) -> void:
	remove_child(container)
	container.free()


## Builds the full FP composition (3 Drifter + 2 Charger + 5 Cluster) using the EnemyTestScene
## fixture. Mirrors _build_wave_composition() output with real scenes so the spawn loop runs.
func _make_fp_composition() -> Array[Dictionary]:
	var comp: Array[Dictionary] = []
	for _i: int in range(WaveManager.FP_DRIFTER_COUNT):
		comp.append({ "type_id": WaveManager.FP_DRIFTER_ID, "scene": _TEST_SCENE })
	for _i: int in range(WaveManager.FP_CHARGER_COUNT):
		comp.append({ "type_id": WaveManager.FP_CHARGER_ID, "scene": _TEST_SCENE })
	for _i: int in range(WaveManager.FP_CLUSTER_COUNT):
		comp.append({ "type_id": WaveManager.FP_CLUSTER_ID, "scene": _TEST_SCENE })
	return comp


# ── AC-WES-14: Full FP run — state transitions ────────────────────────────────

## GIVEN WaveManager connected to real Autoloads with 10 spawn markers
##       and FP composition injected with EnemyTestScene fixture
## WHEN full sequence fires: preparation_started(0,1) → combat_started(false) → 10 × enemy_killed
## THEN after preparation_started: _wave_state=IDLE
##      after combat_started: 10 child enemies, _enemies_alive=10, _enemies_total=10, _wave_state=WAVE_ACTIVE
##      after 10th kill: _enemies_alive=0, _wave_state=WAVE_COMPLETE
func test_full_fp_run_flow_transitions_through_all_states() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(10)
	wm.spawn_points_container = spawn_container

	# preparation_started resets state and rebuilds _wave_composition (with null catalog scenes).
	GameStateManager.preparation_started.emit(0, 1)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)

	# Inject real fixture scenes AFTER preparation_started rebuilds the composition.
	wm._wave_composition = _make_fp_composition()

	GameStateManager.combat_started.emit(false)
	assert_int(wm.get_child_count()).is_equal(10)
	assert_int(wm._enemies_alive).is_equal(10)
	assert_int(wm._enemies_total).is_equal(10)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)

	# Fake instance_ids (0-9): WaveManager ignores the id; EnemyInstance handlers return early.
	for i: int in range(10):
		HealthAndDamage.enemy_killed.emit(i, 0, GameEnums.DamageClass.NONE)

	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_COMPLETE)

	_teardown_container(spawn_container)
	_teardown_wm(wm)


# ── AC-WES-14: Full FP run — completion signal counts ────────────────────────

## GIVEN WaveManager with real Autoloads; full FP sequence via real signals
## WHEN preparation_started → combat_started(false) → 10 × enemy_killed
## THEN all_waves_cleared emitted exactly 1 time; boss_defeated emitted exactly 1 time
func test_full_fp_run_completion_signals_emitted_exactly_once_each() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(10)
	wm.spawn_points_container = spawn_container

	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	GameStateManager.preparation_started.emit(0, 1)
	wm._wave_composition = _make_fp_composition()
	GameStateManager.combat_started.emit(false)

	for i: int in range(10):
		HealthAndDamage.enemy_killed.emit(i, 0, GameEnums.DamageClass.NONE)

	assert_int(awc_count[0]).is_equal(1)
	assert_int(bd_count[0]).is_equal(1)

	_teardown_container(spawn_container)
	_teardown_wm(wm)


# ── AC-WES-14 (edge case): signal emission order ──────────────────────────────

## GIVEN WaveManager with real Autoloads; full FP sequence
## WHEN preparation_started → combat_started(false) → 10 × enemy_killed
## THEN all_waves_cleared fires BEFORE boss_defeated (synchronous, same frame — ADR-0014)
func test_full_fp_run_all_waves_cleared_fires_before_boss_defeated() -> void:
	var wm: WaveManager = _make_wm()
	var spawn_container: Node = _make_spawn_container(10)
	wm.spawn_points_container = spawn_container

	var emission_order: Array[String] = []
	wm.all_waves_cleared.connect(func() -> void: emission_order.append("all_waves_cleared"))
	wm.boss_defeated.connect(func() -> void: emission_order.append("boss_defeated"))

	GameStateManager.preparation_started.emit(0, 1)
	wm._wave_composition = _make_fp_composition()
	GameStateManager.combat_started.emit(false)

	for i: int in range(10):
		HealthAndDamage.enemy_killed.emit(i, 0, GameEnums.DamageClass.NONE)

	assert_int(emission_order.size()).is_equal(2)
	assert_str(emission_order[0]).is_equal("all_waves_cleared")
	assert_str(emission_order[1]).is_equal("boss_defeated")

	_teardown_container(spawn_container)
	_teardown_wm(wm)


# ── AC-WES-15: Player death mid-wave — no completion signals ──────────────────

## GIVEN WaveManager in WAVE_ACTIVE state with _enemies_alive=5
## WHEN HealthAndDamage.player_died fires (WaveManager does not connect to this signal)
## THEN _wave_state remains WAVE_ACTIVE; all_waves_cleared and boss_defeated NOT emitted
func test_player_died_mid_wave_does_not_change_wave_state_or_emit_completion_signals() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 5
	wm._enemies_total = 5

	var awc_count: Array[int] = [0]
	var bd_count: Array[int] = [0]
	wm.all_waves_cleared.connect(func() -> void: awc_count[0] += 1)
	wm.boss_defeated.connect(func() -> void: bd_count[0] += 1)

	# WaveManager does not connect to player_died — this emit is a no-op for WaveManager.
	HealthAndDamage.player_died.emit()

	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)
	assert_int(awc_count[0]).is_equal(0)
	assert_int(bd_count[0]).is_equal(0)

	_teardown_wm(wm)


# ── AC-WES-15: State reset after player death ─────────────────────────────────

## GIVEN WaveManager in WAVE_ACTIVE state after a simulated player death (state not reset)
## WHEN preparation_started fires on the subsequent run
## THEN _enemies_alive=0, _enemies_total=0, _wave_state=IDLE (full reset — ADR-0014 Wave Reset Contract)
func test_preparation_started_after_player_death_resets_wave_state_completely() -> void:
	var wm: WaveManager = _make_wm()
	wm._wave_state = WaveManager.WaveState.WAVE_ACTIVE
	wm._enemies_alive = 5
	wm._enemies_total = 5

	# Simulate player death — WaveManager ignores this signal; state stays WAVE_ACTIVE.
	HealthAndDamage.player_died.emit()
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.WAVE_ACTIVE)

	# Next run begins — preparation_started must fully reset WaveManager state.
	GameStateManager.preparation_started.emit(0, 1)

	assert_int(wm._enemies_alive).is_equal(0)
	assert_int(wm._enemies_total).is_equal(0)
	assert_int(wm._wave_state).is_equal(WaveManager.WaveState.IDLE)

	_teardown_wm(wm)
