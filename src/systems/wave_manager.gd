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

# ── FP Composition Constants (Story 002 — TR-WES-002) ─────────────────────────
## Enemy counts for the First Pass single-wave encounter.
## Tuning knobs: adjust here to retune without touching logic.
## GDD Formula 1 threat values: Drifter=1, Charger=2, Cluster=1, Rifter=1
## Total threat budget: (3×1) + (2×2) + (5×1) + (2×1) = 14

const FP_DRIFTER_COUNT: int = 3
const FP_CHARGER_COUNT: int = 2
const FP_CLUSTER_COUNT: int = 5
const FP_RIFTER_COUNT: int = 2

## EnemyCatalog type IDs for the FP encounter enemies.
const FP_DRIFTER_ID: int = 0
const FP_CHARGER_ID: int = 1
const FP_CLUSTER_ID: int = 2
const FP_RIFTER_ID: int = 4

# ── Exports ───────────────────────────────────────────────────────────────────

## Container node whose Node2D children define spawn positions.
## Set in the arena scene inspector. Each child's global_position is used at
## spawn time (not cached — markers may not be in the world during _ready()).
@export var spawn_points_container: Node

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


## Handles combat phase start.
## FP-scope guard: boss combat_started is always a no-op — the boss is the same wave.
## (No separate boss encounter exists at FP scope; is_boss:true is a self-transition.)
## If is_boss is false, delegate to _spawn_wave().
func _on_combat_started(is_boss: bool) -> void:
	if is_boss:
		push_warning("WaveManager: combat_started(is_boss:true) received while wave active — FP scope guard")
		return
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

## Builds _wave_composition from FP constants and EnemyCatalog scene references.
## Called from _on_preparation_started() so composition is always fresh at wave start.
## Story 002 (TR-WES-002): FP encounter is 3 Drifter + 2 Charger + 5 Cluster.
## Note: EnemyType.scene is null until Story 003 assets land — tests must inject
## _wave_composition directly with a test fixture scene.
func _build_wave_composition() -> void:
	_wave_composition.clear()
	var fp_entries: Array[Dictionary] = [
		{ "type_id": FP_DRIFTER_ID, "count": FP_DRIFTER_COUNT },
		{ "type_id": FP_CHARGER_ID, "count": FP_CHARGER_COUNT },
		{ "type_id": FP_CLUSTER_ID, "count": FP_CLUSTER_COUNT },
		{ "type_id": FP_RIFTER_ID, "count": FP_RIFTER_COUNT },
	]
	for group: Dictionary in fp_entries:
		var et: EnemyType = EnemyCatalog.get_type(group.type_id)
		var scene: PackedScene = et.scene if et != null else null
		for _i: int in range(group.count):
			_wave_composition.append({ "type_id": group.type_id, "scene": scene })


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
		var spread: Vector2 = Vector2(
			cos(spawn_idx * 2.4) * 24.0 * wrap_lap,
			sin(spawn_idx * 2.4) * 24.0 * wrap_lap)
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
