## wave_manager.gd — WaveManager scene node. Owns the wave encounter lifecycle.
##
## Implements: design/gdd/wave-encounter-system.md
## Story: WaveManager Story 001 — Skeleton, Signals, and Phase Gating
## Story: WaveManager Story 002 — FP Wave Composition and Spawn Sequence
## Story: WaveManager Story 003 — Kill Tracking and Wave Completion Signals
## ADR: ADR-0003 (Signal-Driven Architecture), ADR-0014 (H&D ↔ WaveManager Contract)
##
## Responsibilities (Story 001 — skeleton):
##   - Declare wave state enum and initial field values
##   - Declare the three output signals: wave_cleared, all_waves_cleared, boss_defeated
##   - Connect to GameStateManager.preparation_started and .combat_started in _ready()
##   - Connect to HealthAndDamage.enemy_killed in _ready()
##   - Implement phase-gating: combat_started(is_boss:true) guard, preparation_started reset
##   - Disconnect from all Autoload signals in _exit_tree() (ADR-0003 Rule 4)
##
## Responsibilities (Story 002 — FP composition and spawn):
##   - Declare FP composition constants (TR-WES-002)
##   - Build _wave_composition in _on_preparation_started() from EnemyCatalog
##   - Implement _get_spawn_markers() via @export spawn_points_container
##   - Implement _spawn_wave() body: strict ADR-0014 spawn order
##
## Responsibilities (Story 003 — kill tracking):
##   - Implement _on_enemy_killed() body: WAVE_ACTIVE guard → decrement → completion check
##   - Emit all_waves_cleared and boss_defeated when _enemies_alive <= 0 (TR-WES-003, TR-WES-005)
##
## Architecture notes:
##   - WaveManager is a scene node (NOT an Autoload). It lives inside the arena scene
##     and is freed when the run ends.
##   - WaveManager is the sole authoritative emitter of wave_cleared, all_waves_cleared,
##     and boss_defeated. No other system may emit these signals. (TR-WES-001)
##   - Kill tracking uses HealthAndDamage.enemy_killed exclusively — WaveManager never
##     reads HealthAndDamage._enemy_registry directly. (ADR-0014)
##   - Spawn order (ADR-0014): instantiate() → register_enemy() → add_child()
##     → set global_position → init(type_id). register_enemy() MUST precede add_child()
##     so the H&D HP pool is live before EnemyInstance._ready() fires.
class_name WaveManager
extends Node

# ── State enum ────────────────────────────────────────────────────────────────

enum WaveState {
	IDLE        = 0,  ## No active wave. Initial state; reset to on preparation_started.
	WAVE_ACTIVE = 1,  ## Enemies are alive; kill tracking is in progress.
	WAVE_COMPLETE = 2 ## All enemies have been killed; wave completion signals have fired.
}

# ── Composition Constants (design/gdd/level-generation.md) ───────────────────
## Deprecated: prefer enemy_pool_config resource (LD-03).
## Kept for backward compat — tests reference THREAT_BUDGET_MIN/MAX directly.
const THREAT_BUDGET_MIN: int = 10
const THREAT_BUDGET_MAX: int = 18
const _THREAT_COST: Dictionary = { 0: 1, 1: 2, 2: 1, 4: 1 }
const _ENEMY_POOL: Array[int] = [0, 1, 2, 4]
const _GUARANTEED_TYPES: Array[int] = [0, 2]

## FP spawn type IDs — match EnemyCatalog stub indices (pre-Story-003 assets).
const FP_DRIFTER_ID: int = 0
const FP_CHARGER_ID: int = 1
const FP_CLUSTER_ID: int = 2
const FP_RIFTER_ID: int = 4

## FP per-type spawn counts: Drifter×3 + Charger×2 + Cluster×5 + Rifter×2 = 12 enemies.
## Threat budget: (3×1)+(2×2)+(5×1)+(2×1) = 14 — within THREAT_BUDGET_MAX=18.
const FP_DRIFTER_COUNT: int = 3
const FP_CHARGER_COUNT: int = 2
const FP_CLUSTER_COUNT: int = 5
const FP_RIFTER_COUNT: int = 2

# ── Exports ───────────────────────────────────────────────────────────────────

## Container node whose Node2D children define spawn positions.
## Set in the arena scene inspector. Each child's global_position is used at
## spawn time (not cached — markers may not be in the world during _ready()).
@export var spawn_points_container: Node

## Enemy composition parameters. Set in the scene inspector to override per-layer
## defaults. Falls back to a default EnemyPoolConfig (10–18 budget, all 4 archetypes,
## SEEKER + SWARMER guaranteed). (LD-03)
@export var enemy_pool_config: EnemyPoolConfig = null

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted when the current wave's enemies are all defeated.
## Forward-compatibility: declared now; GameStateManager connects to drive multi-wave flow.
## At FP scope (single wave) this fires immediately before all_waves_cleared.
signal wave_cleared

## Emitted when all waves in the encounter are cleared (sole emitter: WaveManager).
## Drives GameStateManager to RUN_SUMMARY. (TR-WES-001, TR-WES-005)
signal all_waves_cleared

## Emitted immediately after all_waves_cleared at FP scope (no separate boss encounter).
## At FP scope both fire in the same handler. (TR-WES-001, TR-WES-005)
signal boss_defeated

# ── Private state ─────────────────────────────────────────────────────────────

## Current wave lifecycle phase.
var _wave_state: WaveState = WaveState.IDLE

## Enemies currently alive in the active wave. Decremented by _on_enemy_killed.
var _enemies_alive: int = 0

## Total enemies spawned for the active wave. Set atomically in _spawn_wave.
var _enemies_total: int = 0

## Ordered spawn composition entries for the current wave.
## Each entry: { scene: PackedScene, type_id: int }
## Populated in _on_preparation_started() from FP constants.
var _wave_composition: Array[Dictionary] = []

## Preview Polygon2D nodes shown at projected spawn positions during preparation.
## Cleared and freed when combat starts.
var _preview_nodes: Array[Node2D] = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
	all_waves_cleared.connect(GameStateManager.receive_all_waves_cleared)
	boss_defeated.connect(GameStateManager.receive_boss_defeated)


func _exit_tree() -> void:
	# ADR-0003 Rule 4: scene nodes must disconnect from Autoload signals in _exit_tree().
	# Godot 4.6 auto-invalidates orphaned Callables but prints an error on next emit;
	# explicit disconnect suppresses that noise.
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
	if all_waves_cleared.is_connected(GameStateManager.receive_all_waves_cleared):
		all_waves_cleared.disconnect(GameStateManager.receive_all_waves_cleared)
	if boss_defeated.is_connected(GameStateManager.receive_boss_defeated):
		boss_defeated.disconnect(GameStateManager.receive_boss_defeated)

# ── Signal handlers ───────────────────────────────────────────────────────────

## Resets all wave state on new-run preparation. (ADR-0014 — Wave Reset Contract)
## Called at the start of every run, and between waves in multi-wave encounters.
## After this call the system is IDLE and ready for the next _spawn_wave().
## Story 002: also rebuilds _wave_composition from EnemyCatalog and FP constants.
func _on_preparation_started(_wave_index: int, _waves_remaining: int) -> void:
	_enemies_alive = 0
	_enemies_total = 0
	_wave_state = WaveState.IDLE
	_build_wave_composition()
	_show_wave_preview()


## Handles combat phase start.
## FP-scope guard: boss combat_started is always a no-op — the boss is the same wave.
## (No separate boss encounter exists at FP scope; is_boss:true is a self-transition.)
## If is_boss is false, delegate to _spawn_wave().
func _on_combat_started(is_boss: bool) -> void:
	if is_boss:
		push_warning("WaveManager: combat_started(is_boss:true) received while wave active — FP scope guard")
		return
	_clear_wave_preview()
	_spawn_wave()


## Tracks enemy deaths and emits wave completion signals when all enemies are defeated.
## ADR-0014 Kill Signal Contract: guard on WAVE_ACTIVE first (before decrement) → decrement
## → _enemies_alive <= 0 check → WAVE_COMPLETE → all_waves_cleared.emit() → boss_defeated.emit().
## The <= 0 guard (not == 0) protects against duplicate-signal edge cases. (TR-WES-003, TR-WES-005)
func _on_enemy_killed(_instance_id: int, _type_id: int,
		_prana_affiliation: GameEnums.DamageClass) -> void:
	if _wave_state != WaveState.WAVE_ACTIVE:
		return  # WAVE_COMPLETE guard: ignore late/duplicate signals (ADR-0014)
	_enemies_alive -= 1
	if _enemies_alive <= 0:
		_wave_state = WaveState.WAVE_COMPLETE
		wave_cleared.emit()
		all_waves_cleared.emit()
		boss_defeated.emit()  # FP: no boss encounter; fires immediately after (TR-WES-005)

# ── Internal ──────────────────────────────────────────────────────────────────

## Returns the active enemy pool config, loading defaults on first access. (LD-03)
## Scene authors override via the @export enemy_pool_config in the inspector.
func _get_pool_config() -> EnemyPoolConfig:
	if enemy_pool_config == null:
		enemy_pool_config = EnemyPoolConfig.new()
	return enemy_pool_config


## Builds _wave_composition using a random threat budget (level-generation.md).
## Guarantees SEEKER and SWARMER always appear; fills remaining budget randomly.
## Called from _on_preparation_started() so composition is fresh each room.
## Tests may inject _wave_composition directly instead of calling this.
## Reads composition parameters from enemy_pool_config resource (LD-03).
##
## [param seed] RNG seed. -1 (default): randomize from system entropy.
##  >= 0: deterministic output — same seed always produces the same composition.
##  Tests can assert exact compositions via seed injection. (LD-05)
func _build_wave_composition(seed: int = -1) -> void:
	_wave_composition.clear()
	var cfg: EnemyPoolConfig = _get_pool_config()
	var rng := RandomNumberGenerator.new()
	if seed >= 0:
		rng.seed = seed
	else:
		rng.randomize()
	var budget: int = rng.randi_range(cfg.threat_budget_min, cfg.threat_budget_max)
	var type_ids: Array[int] = []
	for type_id: int in cfg.guaranteed_types:
		type_ids.append(type_id)
		budget -= cfg.threat_cost.get(type_id, 1)
	while budget >= 1:
		var affordable: Array[int] = []
		for tid: int in cfg.enemy_pool:
			if cfg.threat_cost.get(tid, 1) <= budget:
				affordable.append(tid)
		if affordable.is_empty():
			break
		var pick: int = affordable[rng.randi_range(0, affordable.size() - 1)]
		type_ids.append(pick)
		budget -= cfg.threat_cost.get(pick, 1)
	# Seeded Fisher-Yates — avoids first-type bias in spawn order.
	for i: int in range(type_ids.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = type_ids[i]
		type_ids[i] = type_ids[j]
		type_ids[j] = tmp
	for type_id: int in type_ids:
		var et: EnemyType = EnemyCatalog.get_type(type_id)
		var scene: PackedScene = et.scene if et != null else null
		_wave_composition.append({ "type_id": type_id, "scene": scene })


## Returns the ordered array of spawn marker Node2Ds from spawn_points_container.
## Falls back to an empty array (caller handles the zero-marker case).
func _get_spawn_markers() -> Array[Node2D]:
	if spawn_points_container == null:
		push_error("WaveManager: spawn_points_container is null — set it in the arena scene inspector")
		return []
	var markers: Array[Node2D] = []
	for child: Node in spawn_points_container.get_children():
		if child is Node2D:
			markers.append(child as Node2D)
	return markers


## Spawns the wave composition into the scene tree.
## Strict ADR-0014 spawn order: instantiate() → register_enemy() → add_child()
## → set global_position → init(type_id).
## register_enemy() MUST precede add_child() so H&D's HP pool is live before
## EnemyInstance._ready() fires.
## AC-WES-04: all enemies added in the same frame (no deferred add).
## AC-WES-06: if markers run out, logs push_error, spawns up to marker count only.
func _spawn_wave() -> void:
	var markers: Array[Node2D] = _get_spawn_markers()
	var spawn_idx: int = 0
	for entry: Dictionary in _wave_composition:
		if markers.is_empty():
			push_error("WaveManager: no spawn markers — cannot spawn enemies")
			break
		var enemy_scene: PackedScene = entry["scene"] as PackedScene
		var enemy: EnemyInstance = enemy_scene.instantiate() as EnemyInstance
		HealthAndDamage.register_enemy(enemy, entry["type_id"])  # ADR-0014: BEFORE add_child
		add_child(enemy)
		var base_pos: Vector2 = markers[spawn_idx % markers.size()].global_position
		var wrap_lap: int = spawn_idx / markers.size()
		# Cap jitter at 12 px — tile center is ≥14 px from its nearest wall edge,
		# so enemies never spawn outside the walkable area regardless of direction.
		var jitter: float = 12.0 if wrap_lap > 0 else 0.0
		var spread: Vector2 = Vector2(cos(spawn_idx * 2.4), sin(spawn_idx * 2.4)) * jitter
		enemy.global_position = base_pos + spread
		enemy.init(entry["type_id"])
		spawn_idx += 1
	_enemies_total = spawn_idx
	_enemies_alive = _enemies_total
	if _enemies_total == 0:
		push_error("WaveManager: no enemies spawned — wave vacuously complete")
		_wave_state = WaveState.WAVE_COMPLETE
		all_waves_cleared.emit()
		boss_defeated.emit()
		return
	_wave_state = WaveState.WAVE_ACTIVE


## Instantiates the actual enemy scenes at projected spawn positions during preparation.
## Enemies are neutralized (no physics, no combat, no HitArea) and rendered at 50% alpha
## so the player sees exactly which enemies will spawn where.
## Mirrors the same position distribution as _spawn_wave() so previews match actual spawns.
func _show_wave_preview() -> void:
	_clear_wave_preview()
	var markers: Array[Node2D] = _get_spawn_markers()
	if markers.is_empty():
		return
	var spawn_idx: int = 0
	for entry: Dictionary in _wave_composition:
		var enemy_scene: PackedScene = entry["scene"] as PackedScene
		if enemy_scene == null:
			spawn_idx += 1
			continue
		var base_pos: Vector2 = markers[spawn_idx % markers.size()].global_position
		var wrap_lap: int = spawn_idx / markers.size()
		var jitter: float = 12.0 if wrap_lap > 0 else 0.0
		var spread: Vector2 = Vector2(cos(spawn_idx * 2.4), sin(spawn_idx * 2.4)) * jitter
		var enemy: EnemyInstance = enemy_scene.instantiate() as EnemyInstance
		add_child(enemy)
		# _ready() adds to "enemy" group — remove immediately so spell targeting and
		# separation steering cannot find this preview node (it's not in H&D registry).
		enemy.remove_from_group(&"enemy")
		# Neutralize after _ready() wired signals and collision nodes.
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.collision_layer = 0
		enemy.collision_mask = 0
		var hit_area: Area2D = enemy.get_node_or_null("HitArea") as Area2D
		if hit_area != null:
			hit_area.monitoring = false
			hit_area.monitorable = false
		enemy.init(entry["type_id"])   # colors DebugCircle, sets archetype — no H&D registration
		enemy.modulate.a = 0.5
		enemy.global_position = base_pos + spread
		# Name label above the enemy so the player knows which type is spawning where.
		var et: EnemyType = EnemyCatalog.get_type(entry["type_id"])
		if et != null:
			var lbl := Label.new()
			lbl.text = et.name
			lbl.add_theme_font_size_override("font_size", 14)
			lbl.position = Vector2(-30.0, -26.0)
			lbl.size = Vector2(60.0, 18.0)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.modulate = Color(et.debug_color.r, et.debug_color.g, et.debug_color.b, 1.0)
			enemy.add_child(lbl)
		_preview_nodes.append(enemy)
		spawn_idx += 1


## Frees all preview nodes created by _show_wave_preview().
## Uses remove_child() + free() (synchronous) instead of queue_free() (deferred)
## so that get_child_count() reflects the true child count immediately after this
## call returns. Required for deterministic integration test assertions.
func _clear_wave_preview() -> void:
	for node: Node2D in _preview_nodes:
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	_preview_nodes.clear()
