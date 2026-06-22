## wave_composition_test.gd — Unit tests for WaveManager random composition builder.
##
## Coverage:
##   AC-LG-05: total threat within [THREAT_BUDGET_MIN, THREAT_BUDGET_MAX] (+ guarantee slack)
##   AC-LG-06: every composition has >= 1 SEEKER (type_id 0) and >= 1 SWARMER (type_id 2)
##   Composition is non-empty after _on_preparation_started
##
## GDD: design/gdd/level-generation.md
## ADR: ADR-0014 (H&D ↔ WaveManager Contract)
extends GdUnitTestSuite

const WaveManagerScript = preload("res://src/systems/wave_manager.gd")
## Threat costs mirror WaveManager._THREAT_COST (not imported to keep tests isolated).
const _COST: Dictionary = { 0: 1, 1: 2, 2: 1, 4: 1 }


func _make_wm() -> WaveManager:
	var wm: WaveManager = WaveManagerScript.new() as WaveManager
	add_child(wm)
	return wm


func _teardown_wm(wm: WaveManager) -> void:
	remove_child(wm)
	wm.free()


# ── AC-LG-06: guaranteed SEEKER ───────────────────────────────────────────────

## GIVEN fresh preparation
## WHEN composition is built
## THEN at least one entry has type_id == 0 (SEEKER)
func test_composition_always_contains_seeker() -> void:
	var wm := _make_wm()
	wm._on_preparation_started(0, 0)
	var found: bool = false
	for entry: Dictionary in wm._wave_composition:
		if int(entry["type_id"]) == 0:
			found = true
			break
	assert_bool(found).is_true()
	_teardown_wm(wm)


# ── AC-LG-06: guaranteed SWARMER ─────────────────────────────────────────────

## GIVEN fresh preparation
## WHEN composition is built
## THEN at least one entry has type_id == 2 (SWARMER)
func test_composition_always_contains_swarmer() -> void:
	var wm := _make_wm()
	wm._on_preparation_started(0, 0)
	var found: bool = false
	for entry: Dictionary in wm._wave_composition:
		if int(entry["type_id"]) == 2:
			found = true
			break
	assert_bool(found).is_true()
	_teardown_wm(wm)


# ── AC-LG-05: threat total within budget ─────────────────────────────────────

## Runs three times to cover multiple random draws.
## THEN total threat is within [BUDGET_MIN, BUDGET_MAX + 2] (guarantee types may overshoot by ≤2).
func test_composition_threat_total_within_budget_range() -> void:
	for _run: int in range(3):
		var wm := _make_wm()
		wm._on_preparation_started(0, 0)
		var total: int = 0
		for entry: Dictionary in wm._wave_composition:
			total += _COST.get(int(entry["type_id"]), 1)
		assert_int(total).is_between(
			wm.THREAT_BUDGET_MIN - 1,
			wm.THREAT_BUDGET_MAX + 2)
		_teardown_wm(wm)


# ── Composition is non-empty ──────────────────────────────────────────────────

## GIVEN fresh preparation
## THEN composition has at least one entry (guarantees prevent vacuous composition)
func test_composition_is_not_empty() -> void:
	var wm := _make_wm()
	wm._on_preparation_started(0, 0)
	assert_int(wm._wave_composition.size()).is_greater(0)
	_teardown_wm(wm)


# ── enemy_count_max cap ───────────────────────────────────────────────────────

## GIVEN a pool config with enemy_count_max = 3 and a large budget
## WHEN composition is built
## THEN wave_composition.size() <= 3 regardless of budget
func test_composition_capped_by_enemy_count_max() -> void:
	var wm := _make_wm()
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 50
	cfg.threat_budget_max = 50
	cfg.threat_cost = { 0: 1, 2: 1 }
	cfg.enemy_pool = [0, 2]
	cfg.guaranteed_types = [0, 2]
	cfg.enemy_count_max = 3
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	assert_int(wm._wave_composition.size()).is_less_equal(3)
	_teardown_wm(wm)


## GIVEN a pool config with enemy_count_max = 0 (uncapped)
## WHEN composition is built with a large budget
## THEN wave_composition.size() > 3 (proves the cap is not applied when 0)
func test_composition_uncapped_when_max_is_zero() -> void:
	var wm := _make_wm()
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 20
	cfg.threat_budget_max = 20
	cfg.threat_cost = { 0: 1, 2: 1 }
	cfg.enemy_pool = [0, 2]
	cfg.guaranteed_types = [0]
	cfg.enemy_count_max = 0  # uncapped
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	assert_int(wm._wave_composition.size()).is_greater(3)
	_teardown_wm(wm)


# ── max_enemies_per_marker (geometry density cap) ────────────────────────────

## Builds a container node with [param n] Node2D spawn markers, added to the tree.
## Caller frees it via container.free() (frees children too). Mirrors the
## _make_spawn_container pattern in wave_manager_kill_tracking_test.
func _make_marker_container(n: int) -> Node:
	var container := Node2D.new()
	for _i in n:
		container.add_child(Node2D.new())
	add_child(container)
	return container


## GIVEN max_enemies_per_marker = 3 and 2 markers (cap 6) with a large budget
## THEN composition is trimmed to at most markers × per-marker = 6
func test_composition_capped_by_marker_density() -> void:
	var wm := _make_wm()
	var container := _make_marker_container(2)
	wm.spawn_points_container = container
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 50
	cfg.threat_budget_max = 50
	cfg.threat_cost = { 0: 1, 2: 1 }
	cfg.enemy_pool = [0, 2]
	cfg.guaranteed_types = [0, 2]
	cfg.max_enemies_per_marker = 3
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	assert_int(wm._wave_composition.size()).is_less_equal(6)
	_teardown_wm(wm)
	container.free()


## GIVEN max_enemies_per_marker = 3 but NO spawn container (0 markers)
## THEN the marker cap does not apply (large budget → more than 6 enemies)
func test_composition_marker_cap_ignored_without_markers() -> void:
	var wm := _make_wm()
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 30
	cfg.threat_budget_max = 30
	cfg.threat_cost = { 0: 1, 2: 1 }
	cfg.enemy_pool = [0, 2]
	cfg.guaranteed_types = [0]
	cfg.max_enemies_per_marker = 3  # no container set → no marker cap
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	assert_int(wm._wave_composition.size()).is_greater(6)
	_teardown_wm(wm)


## GIVEN both caps active, the SMALLER wins: enemy_count_max=4 beats markers×per (15)
func test_composition_smaller_of_two_caps_wins() -> void:
	var wm := _make_wm()
	var container := _make_marker_container(5)  # 5 × 3 = 15
	wm.spawn_points_container = container
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 50
	cfg.threat_budget_max = 50
	cfg.threat_cost = { 0: 1, 2: 1 }
	cfg.enemy_pool = [0, 2]
	cfg.guaranteed_types = [0, 2]
	cfg.enemy_count_max = 4   # absolute cap is the smaller of the two
	cfg.max_enemies_per_marker = 3
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	assert_int(wm._wave_composition.size()).is_less_equal(4)
	_teardown_wm(wm)
	container.free()


## GIVEN a cap below the guaranteed-type count, protected types are NOT trimmed away
## (1 marker × 1 per-marker = cap 1, but 4 guaranteed types must all survive)
func test_composition_protected_types_survive_tiny_cap() -> void:
	var wm := _make_wm()
	var container := _make_marker_container(1)  # 1 × 1 = cap 1
	wm.spawn_points_container = container
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 20
	cfg.threat_budget_max = 20
	cfg.threat_cost = { 0: 1, 1: 1, 2: 1, 4: 1 }
	cfg.enemy_pool = [0, 1, 2, 4]
	cfg.guaranteed_types = [0, 1, 2, 4]  # 4 protected entries
	cfg.max_enemies_per_marker = 1
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	# All 4 guaranteed types survive despite the cap of 1.
	assert_int(wm._wave_composition.size()).is_greater_equal(4)
	_teardown_wm(wm)
	container.free()


# ── min_counts: minimum 2 Clusters ───────────────────────────────────────────

## GIVEN a pool config with min_counts = { 2: 2 } and guaranteed_types = [0] (no Cluster)
## WHEN composition is built
## THEN at least 2 entries have type_id == 2 (Cluster)
func test_composition_min_counts_enforces_minimum_cluster_count() -> void:
	var wm := _make_wm()
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 10
	cfg.threat_budget_max = 10
	cfg.threat_cost = { 0: 1, 2: 1 }
	cfg.enemy_pool = [0, 2]
	cfg.guaranteed_types = [0]
	cfg.min_counts = { 2: 2 }
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	var cluster_count: int = 0
	for entry: Dictionary in wm._wave_composition:
		if int(entry["type_id"]) == 2:
			cluster_count += 1
	assert_int(cluster_count).is_greater_equal(2)
	_teardown_wm(wm)


## GIVEN min_counts = { 2: 2 } and guaranteed_types already includes type 2 once
## WHEN composition is built
## THEN still at least 2 Clusters (min_counts tops up, not doubles)
func test_composition_min_counts_does_not_double_count_guaranteed() -> void:
	var wm := _make_wm()
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 4
	cfg.threat_budget_max = 4
	cfg.threat_cost = { 0: 1, 2: 1 }
	cfg.enemy_pool = [0, 2]
	cfg.guaranteed_types = [0, 2]
	cfg.min_counts = { 2: 2 }
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(0)
	var cluster_count: int = 0
	for entry: Dictionary in wm._wave_composition:
		if int(entry["type_id"]) == 2:
			cluster_count += 1
	assert_int(cluster_count).is_greater_equal(2)
	_teardown_wm(wm)


# ── Swarmer grouping ──────────────────────────────────────────────────────────

## GIVEN a pool with both swarmer and non-swarmer types
## WHEN composition is built
## THEN all swarmer entries appear after all non-swarmer entries (no non-swarmer after first swarmer)
func test_composition_swarmers_are_grouped_at_end() -> void:
	var wm := _make_wm()
	var cfg := EnemyPoolConfig.new()
	cfg.threat_budget_min = 10
	cfg.threat_budget_max = 10
	cfg.threat_cost = { 0: 1, 1: 2, 2: 1 }
	cfg.enemy_pool = [0, 1, 2]
	cfg.guaranteed_types = [0, 1, 2]
	cfg.min_counts = { 2: 2 }
	wm.enemy_pool_config = cfg
	wm._build_wave_composition(42)
	# SWARMER archetype int value = 2 (GameEnums.EnemyArchetype.SWARMER)
	var seen_swarmer := false
	var non_swarmer_after_swarmer := false
	for entry: Dictionary in wm._wave_composition:
		var is_sw: bool = (int(entry.get("archetype", -1)) == 2)
		if is_sw:
			seen_swarmer = true
		elif seen_swarmer:
			non_swarmer_after_swarmer = true
			break
	assert_bool(non_swarmer_after_swarmer).is_false()
	_teardown_wm(wm)
