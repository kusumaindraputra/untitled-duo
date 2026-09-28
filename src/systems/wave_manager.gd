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

## Seconds between heal animation start and door-unlock (wave_cleared) in REST rooms.
## Gives the player time to see the "+N HP" floating label and green screen wash.
const REST_HEAL_VISUAL_DELAY: float = 0.5

## Elite multipliers, reinforcement warning time and bullet-cancel radii (ADR-0018).
const BULLET_HELL_TUNING: BulletHellTuning = preload("res://assets/data/bullet_hell_tuning.tres")
## Spawn glyph timeline and rise look (ADR-0043).
const SPAWN_GLYPH_TUNING: SpawnGlyphTuning = preload("res://assets/data/spawn_glyph_tuning.tres")
## Height of a preview threat icon above its enemy, px before the enemy's scale (ADR-0032).
const ICON_OFFSET_Y: float = 26.0
## Bullet-cancel meter gain (ADR-0019).
const PACE_TUNING: PaceTuning = preload("res://assets/data/pace_tuning.tres")

# ── Exports ───────────────────────────────────────────────────────────────────

## Container node whose Node2D children define spawn positions.
## Set in the arena scene inspector. Each child's global_position is used at
## spawn time (not cached — markers may not be in the world during _ready()).
@export var spawn_points_container: Node

## Enemy composition parameters. Set in the scene inspector to override per-layer
## defaults. Falls back to a default EnemyPoolConfig (10–18 budget, all 4 archetypes,
## SEEKER + SWARMER guaranteed). (LD-03)
@export var enemy_pool_config: EnemyPoolConfig = null

## Enemy composition config used when room_type == BOSS (type 3).
## If null, falls back to enemy_pool_config. Set by debug_game_loop in _ready().
@export var boss_pool_config: EnemyPoolConfig = null

## ADR-0028 — this run's boss variants, { boss type id: BossVariant }, from
## BossRoster.pick_all(). Set by debug_game_loop once per run. Empty = no variants.
var boss_variants: Dictionary = {}

## Current room type from DungeonGraph (COMBAT=0, ELITE=1, REST=2, BOSS=3).
## REST rooms skip enemy spawn and emit wave_cleared immediately.
## BOSS rooms use boss_pool_config if set.
## Set by debug_game_loop after each room transition.
@export var room_type: int = DungeonGraph.ROOM_TYPE_COMBAT

## True for the final (boss) room of the dungeon. Only the final room emits
## all_waves_cleared and boss_defeated — non-final rooms emit only wave_cleared,
## which unlocks exit doors and lets the player proceed to the next room.
## Set by debug_game_loop after each room transition via DungeonGraph room type.
@export var is_final_room: bool = false

## ADR-0055 — while true, the room's wave is built but neither previewed nor spawned
## when combat starts; the guided first room runs its lessons first and then calls
## [method release_wave]. Set by debug_game_loop before the run starts.
var hold_wave: bool = false

## True when combat started while [member hold_wave] kept the wave back.
var _wave_held: bool = false

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

## Emitted when a BOSS-archetype enemy is spawned, carrying the boss node.
## Drives the boss-intro UI (name card + boss HP bar) in CombatHUD. Presentation
## only — no gameplay system consumes this. [param boss] is the EnemyInstance.
signal boss_spawned(boss: Node)

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

## AudioSystem reference; null-safe — set in _ready().
var _audio: Variant = null

## ADR-0018 — reinforcement groups still waiting to arrive this wave (each an
## Array[Dictionary] of composition entries). Empty when the wave is fully on field.
var _pending_groups: Array = []
## Reinforcement trigger for the active wave (copied from the pool config at spawn).
var _reinforcement_trigger: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	GameStateManager.preparation_started.connect(_on_preparation_started)
	GameStateManager.combat_started.connect(_on_combat_started)
	HealthAndDamage.enemy_killed.connect(_on_enemy_killed)
	_audio = get_node_or_null("/root/AudioSystem")
	wave_cleared.connect(GameStateManager.receive_wave_cleared)
	all_waves_cleared.connect(GameStateManager.receive_all_waves_cleared)
	boss_defeated.connect(GameStateManager.receive_boss_defeated)
	SpellCastingEffects.perfect_cast.connect(_on_perfect_cast)
	SpellCastingEffects.special_fired.connect(_on_special_fired)


func _exit_tree() -> void:
	if SpellCastingEffects.perfect_cast.is_connected(_on_perfect_cast):
		SpellCastingEffects.perfect_cast.disconnect(_on_perfect_cast)
	if SpellCastingEffects.special_fired.is_connected(_on_special_fired):
		SpellCastingEffects.special_fired.disconnect(_on_special_fired)
	# ADR-0003 Rule 4: scene nodes must disconnect from Autoload signals in _exit_tree().
	# Godot 4.6 auto-invalidates orphaned Callables but prints an error on next emit;
	# explicit disconnect suppresses that noise.
	if GameStateManager.preparation_started.is_connected(_on_preparation_started):
		GameStateManager.preparation_started.disconnect(_on_preparation_started)
	if GameStateManager.combat_started.is_connected(_on_combat_started):
		GameStateManager.combat_started.disconnect(_on_combat_started)
	if HealthAndDamage.enemy_killed.is_connected(_on_enemy_killed):
		HealthAndDamage.enemy_killed.disconnect(_on_enemy_killed)
	if wave_cleared.is_connected(GameStateManager.receive_wave_cleared):
		wave_cleared.disconnect(GameStateManager.receive_wave_cleared)
	if all_waves_cleared.is_connected(GameStateManager.receive_all_waves_cleared):
		all_waves_cleared.disconnect(GameStateManager.receive_all_waves_cleared)
	if boss_defeated.is_connected(GameStateManager.receive_boss_defeated):
		boss_defeated.disconnect(GameStateManager.receive_boss_defeated)

# ── Signal handlers ───────────────────────────────────────────────────────────

## Resets all wave state on new-run preparation. (ADR-0014 — Wave Reset Contract)
## Called at the start of every run, and between waves in multi-wave encounters.
## After this call the system is IDLE and ready for the next _spawn_wave().
## Story 002: also rebuilds _wave_composition from EnemyCatalog and FP constants.
## Rest rooms (room_type=2) skip composition build — no enemies to preview or spawn.
func _on_preparation_started(_wave_index: int, _waves_remaining: int) -> void:
	_enemies_alive = 0
	_enemies_total = 0
	_wave_state = WaveState.IDLE
	_pending_groups.clear()
	_wave_held = false
	_clear_enemy_fire()
	if room_type == DungeonGraph.ROOM_TYPE_REST:
		_clear_wave_preview()
		return
	_build_wave_composition()
	if not hold_wave:
		_show_wave_preview()


## ADR-0055 — lets the held wave go: spawns it when combat already started, otherwise
## shows the usual preview for the preparation phase. No-op when nothing is held.
func release_wave() -> void:
	if not hold_wave:
		return
	hold_wave = false
	if _wave_held:
		_wave_held = false
		_spawn_wave()
	elif GameStateManager.get_active_state() == GameEnums.GameState.PREPARATION_PHASE:
		_show_wave_preview()


## Handles combat phase start.
## FP-scope guard: boss combat_started is always a no-op — the boss is the same wave.
## (No separate boss encounter exists at FP scope; is_boss:true is a self-transition.)
## Rest rooms (room_type=2) emit wave_cleared immediately — no enemies to fight.
## All other room types delegate to _spawn_wave().
func _on_combat_started(is_boss: bool) -> void:
	if is_boss:
		push_warning("WaveManager: combat_started(is_boss:true) received while wave active — FP scope guard")
		return
	_clear_wave_preview()
	if hold_wave:
		_wave_held = true
		return
	if room_type == DungeonGraph.ROOM_TYPE_REST:
		_apply_rest_heal()
		_wave_state = WaveState.WAVE_COMPLETE
		await get_tree().create_timer(REST_HEAL_VISUAL_DELAY).timeout
		wave_cleared.emit()
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
	# ADR-0018 — reinforcements arrive while the fight is still going.
	if not _pending_groups.is_empty() and _enemies_alive <= _reinforcement_trigger:
		_spawn_next_group()
	if _enemies_alive <= 0 and _pending_groups.is_empty():
		_wave_state = WaveState.WAVE_COMPLETE
		# Deferred: the last enemy's own enemy_killed handler (e.g. a Splitter death
		# ring) may run after this one — clear once every handler has fired.
		call_deferred(&"_clear_enemy_fire")
		_apply_final_kill_punch()
		wave_cleared.emit()
		if is_final_room:
			all_waves_cleared.emit()
			boss_defeated.emit()

# ── Internal ──────────────────────────────────────────────────────────────────

## Heals Fayde for 10–20 % of max HP when entering a REST room.
## Finds the player via group query (ADR-0004 dependency-injection pattern where
## scene node is not directly wired — WaveManager has no @export ref to PlayerController).
func _apply_rest_heal() -> void:
	if not is_inside_tree():
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player == null:
		push_warning("WaveManager._apply_rest_heal: no player in 'player' group — heal skipped")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var pct: float = rng.randf_range(0.10, 0.20)
	var heal_amount: int = roundi(float(HealthAndDamage.FAYDE_MAX_HP) * pct)
	HealthAndDamage.apply_heal(player, float(heal_amount))
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_rest_heal"):
		_audio.play_event(&"sfx_rest_heal")


## Final-kill punch: adds camera trauma to Fayde so the last kill feels impactful
## (Gamefeel Audit Issue 3.3). Null-safe group query — skipped in headless tests
## where no player node exists in the tree.
func _apply_final_kill_punch() -> void:
	if not is_inside_tree():
		return
	var player: Node = get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method(&"add_camera_trauma"):
		player.add_camera_trauma(ShakeState.DEFAULT_TUNING.medium)


## Returns the active enemy pool config, loading defaults on first access. (LD-03)
## Boss rooms use boss_pool_config when set; all others use enemy_pool_config.
func _get_pool_config() -> EnemyPoolConfig:
	if room_type == DungeonGraph.ROOM_TYPE_BOSS and boss_pool_config != null:
		return boss_pool_config
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
	# Enforce min_counts — add extra copies beyond what guaranteed_types already placed.
	for type_id: int in cfg.min_counts:
		var min_count: int = int(cfg.min_counts[type_id])
		var current_count: int = 0
		for tid: int in type_ids:
			if tid == type_id:
				current_count += 1
		for _j: int in range(max(0, min_count - current_count)):
			type_ids.append(type_id)
			budget -= cfg.threat_cost.get(type_id, 1)
	# Guaranteed + min_count entries placed so far are protected from any cap trim.
	var protected_count: int = type_ids.size()
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
	# Apply enemy caps — trim excess pool-fill entries before grouping. The effective
	# cap is the smaller of the absolute cap (enemy_count_max) and the geometry-relative
	# cap (spawn markers × max_enemies_per_marker), so dense rooms can't overwhelm the
	# player. Guaranteed/min_count entries are prepended first and never trimmed below
	# protected_count.
	var effective_max: int = _effective_enemy_cap(cfg)
	if effective_max > 0:
		effective_max = maxi(effective_max, protected_count)
		if type_ids.size() > effective_max:
			type_ids.resize(effective_max)
	# Split into swarmer/non-swarmer groups. Swarmers go last so _spawn_wave()
	# can assign them to the same marker for proximity spawning.
	var non_swarmers: Array[int] = []
	var swarmers: Array[int] = []
	for tid: int in type_ids:
		var et_check: EnemyType = EnemyCatalog.get_type(tid)
		if et_check != null and et_check.archetype == GameEnums.EnemyArchetype.SWARMER:
			swarmers.append(tid)
		else:
			non_swarmers.append(tid)
	# Fisher-Yates shuffle on each group independently.
	for i: int in range(non_swarmers.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = non_swarmers[i]
		non_swarmers[i] = non_swarmers[j]
		non_swarmers[j] = tmp
	for i: int in range(swarmers.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = swarmers[i]
		swarmers[i] = swarmers[j]
		swarmers[j] = tmp
	non_swarmers.append_array(swarmers)
	# ADR-0018 — contiguous reinforcement groups; elite rolls happen after every
	# composition pick so seeded compositions are unchanged when elite_chance = 0.
	var groups: int = clampi(cfg.reinforcement_groups, 1, maxi(non_swarmers.size(), 1))
	var elite_chance: float = cfg.elite_chance
	if room_type == DungeonGraph.ROOM_TYPE_ELITE and elite_chance > 0.0:
		elite_chance += BULLET_HELL_TUNING.elite_room_bonus
	var n: int = non_swarmers.size()
	for i: int in n:
		var type_id: int = non_swarmers[i]
		var et: EnemyType = EnemyCatalog.get_type(type_id)
		var scene: PackedScene = et.scene if et != null else null
		var base_scale: float = et.base_scale if et != null else 1.0
		var archetype: int = et.archetype if et != null else GameEnums.EnemyArchetype.SEEKER
		var elite: bool = false
		if elite_chance > 0.0 and archetype != GameEnums.EnemyArchetype.BOSS:
			elite = rng.randf() < elite_chance
		_wave_composition.append({
			"type_id": type_id, "scene": scene, "base_scale": base_scale, "archetype": archetype,
			"group": (i * groups) / maxi(n, 1), "elite": elite,
		})
	_roll_duo_foes(rng.randi())


## ADR-0058 — marks some non-boss entries as duo foes (warded or flitting). Uses its own
## RNG seeded from [param seed], so compositions and elite rolls stay as they were.
func _roll_duo_foes(seed: int) -> void:
	var foe_rng := RandomNumberGenerator.new()
	foe_rng.seed = seed
	for entry: Dictionary in _wave_composition:
		var kind: int = DuoFoe.Kind.NONE
		if int(entry.get("archetype", -1)) != GameEnums.EnemyArchetype.BOSS:
			kind = DuoFoe.roll(foe_rng.randf(), foe_rng.randf())
		entry["duo_foe"] = kind


## Returns the number of spawn markers in spawn_points_container, or 0 when unset.
## Unlike _get_spawn_markers(), never logs an error — it runs during composition where
## markers may legitimately be absent (headless tests, pre-room-wiring).
func _spawn_marker_count() -> int:
	if spawn_points_container == null:
		return 0
	var n: int = 0
	for child: Node in spawn_points_container.get_children():
		if child is Node2D:
			n += 1
	return n


## Computes the effective per-wave enemy cap from [param cfg]: the smaller of the
## absolute cap (enemy_count_max) and the geometry cap (markers × max_enemies_per_marker).
## Returns 0 when neither cap applies (uncapped).
func _effective_enemy_cap(cfg: EnemyPoolConfig) -> int:
	var caps: Array[int] = []
	if cfg.enemy_count_max > 0:
		caps.append(cfg.enemy_count_max)
	if cfg.max_enemies_per_marker > 0:
		var marker_count: int = _spawn_marker_count()
		if marker_count > 0:
			caps.append(marker_count * cfg.max_enemies_per_marker)
	if caps.is_empty():
		return 0
	return caps.min()


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
	# ADR-0018 — split the composition into reinforcement groups. Entries without a
	# "group" key (tests injecting _wave_composition directly) all land in group 0.
	var grouped: Dictionary = {}
	for entry: Dictionary in _wave_composition:
		var g: int = int(entry.get("group", 0))
		if not grouped.has(g):
			grouped[g] = []
		grouped[g].append(entry)
	var keys: Array = grouped.keys()
	keys.sort()
	_pending_groups.clear()
	for k: Variant in keys.slice(1):
		_pending_groups.append(grouped[k])
	_reinforcement_trigger = _get_pool_config().reinforcement_trigger_alive
	var first: Array = grouped[keys[0]] if not keys.is_empty() else []
	var total_spawned: int = _spawn_entries(first, false)
	_enemies_total = total_spawned
	_enemies_alive = _enemies_total
	# A group that failed to spawn anything must not strand the wave — pull the
	# next group in until something is on the field or nothing is left.
	while _enemies_alive <= 0 and not _pending_groups.is_empty():
		_spawn_next_group()
	if _enemies_alive <= 0:
		push_error("WaveManager: no enemies spawned — wave vacuously complete")
		_wave_state = WaveState.WAVE_COMPLETE
		wave_cleared.emit()
		if is_final_room:
			all_waves_cleared.emit()
			boss_defeated.emit()
		return
	_wave_state = WaveState.WAVE_ACTIVE

	# Audio: fire-and-forget, null-safe.
	if _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_enemy_spawn"):
		_audio.play_event(&"sfx_enemy_spawn")


## Spawns the next pending reinforcement group (ADR-0018) at the spawn markers
## farthest from Fayde, after a short warning marker. Adds to the alive count.
func _spawn_next_group() -> void:
	if _pending_groups.is_empty():
		return
	var entries: Array = _pending_groups.pop_front()
	var spawned: int = _spawn_entries(entries, true)
	_enemies_total += spawned
	_enemies_alive += spawned
	if spawned > 0 and _audio != null and _audio.has_method(&"has_event") and _audio.has_event(&"sfx_enemy_spawn"):
		_audio.play_event(&"sfx_enemy_spawn")


## Spawns [param entries] into the scene tree and returns how many were spawned.
## Strict ADR-0014 spawn order: instantiate() → register_enemy() → add_child()
## → set global_position → init(type_id).
## register_enemy() MUST precede add_child() so H&D's HP pool is live before
## EnemyInstance._ready() fires.
## AC-WES-04: all enemies of a group are added in the same frame (no deferred add).
## [param reinforcement] picks markers farthest from Fayde and holds the enemies
## behind a warning marker for BulletHellTuning.reinforcement_warning_sec.
func _spawn_entries(entries: Array, reinforcement: bool) -> int:
	var markers: Array[Node2D] = _get_spawn_markers()
	if reinforcement:
		markers = _markers_far_from_player(markers)
	var marker_idx: int = 0
	var total_spawned: int = 0
	var swarmer_base_pos: Vector2 = Vector2.ZERO
	var swarmer_local_count: int = 0
	var hold: float = BULLET_HELL_TUNING.reinforcement_warning_sec if reinforcement else 0.0
	for entry: Dictionary in entries:
		if markers.is_empty():
			push_error("WaveManager: no spawn markers — cannot spawn enemies")
			break
		var enemy_scene: PackedScene = entry["scene"] as PackedScene
		if enemy_scene == null:
			push_warning("WaveManager: null scene for type_id %d — skipping spawn" % entry["type_id"])
			continue
		var is_swarmer: bool = (int(entry.get("archetype", -1)) == GameEnums.EnemyArchetype.SWARMER)
		var final_pos: Vector2
		if is_swarmer:
			if swarmer_local_count == 0:
				swarmer_base_pos = markers[marker_idx % markers.size()].global_position
				marker_idx += 1
			var spread: Vector2 = Vector2(cos(swarmer_local_count * 2.4), sin(swarmer_local_count * 2.4)) * 8.0
			final_pos = swarmer_base_pos + spread
			swarmer_local_count += 1
		else:
			var base_pos: Vector2 = markers[marker_idx % markers.size()].global_position
			var wrap_lap: int = marker_idx / markers.size()
			# Cap jitter at 12 px — tile center is ≥14 px from its nearest wall edge,
			# so enemies never spawn outside the walkable area regardless of direction.
			var jitter: float = 12.0 if wrap_lap > 0 else 0.0
			var spread: Vector2 = Vector2(cos(marker_idx * 2.4), sin(marker_idx * 2.4)) * jitter
			final_pos = base_pos + spread
			marker_idx += 1
		var elite: bool = bool(entry.get("elite", false))
		var enemy: EnemyInstance = enemy_scene.instantiate() as EnemyInstance
		var hp_mult: float = BULLET_HELL_TUNING.elite_hp_mult if elite else 1.0
		var variant: BossVariant = boss_variants.get(int(entry["type_id"])) as BossVariant
		if variant != null:
			hp_mult *= variant.hp_mult
		# ADR-0052 Ascension: the pool's own HP multiplier, bosses and mobs apart.
		var cfg: EnemyPoolConfig = _get_pool_config()
		var is_boss_entry: bool = int(entry.get("archetype", -1)) == GameEnums.EnemyArchetype.BOSS
		var pool_hp_mult: float = cfg.boss_hp_mult if is_boss_entry else cfg.enemy_hp_mult
		hp_mult *= pool_hp_mult
		HealthAndDamage.register_enemy(enemy, entry["type_id"], hp_mult)  # ADR-0014: BEFORE add_child
		add_child(enemy)
		enemy.global_position = final_pos
		enemy.init(entry["type_id"])
		# ADR-0024 — opening-wave enemies wait to notice Fayde; reinforcements arrive
		# already hunting her (bosses are always awake — enter_dormant ignores them).
		if not reinforcement:
			enemy.enter_dormant()
		if elite:
			enemy.make_elite(BULLET_HELL_TUNING)
		enemy.make_duo_foe(int(entry.get("duo_foe", DuoFoe.Kind.NONE)))
		enemy.apply_hp_mult(pool_hp_mult)
		enemy.apply_difficulty(cfg.bullet_speed_mult, cfg.fire_rate_mult, cfg.telegraph_mult)
		if variant != null:
			enemy.apply_boss_variant(variant)
		if enemy.is_boss():
			boss_spawned.emit(enemy)
		_rise_from_glyph(enemy, final_pos, final_scale_of(entry, elite), hold)
		total_spawned += 1
	return total_spawned


## Returns [param markers] sorted farthest-first from Fayde (unchanged without a player).
func _markers_far_from_player(markers: Array[Node2D]) -> Array[Node2D]:
	if not is_inside_tree():
		return markers
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return markers
	var sorted: Array[Node2D] = markers.duplicate()
	var origin: Vector2 = player.global_position
	sorted.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.distance_squared_to(origin) > b.global_position.distance_squared_to(origin))
	return sorted


## ADR-0043 — drops a SpawnGlyph at [param pos] and raises [param enemy] out of it:
## the glyph draws (plus [param hold] for a reinforcement warning), the enemy grows from
## flat to [param final_scale] with its feet on the floor while its tint fades in, then
## it settles and its physics start. Replaces the old scale pop-in (Gamefeel Audit 3.1)
## and the red reinforcement ring.
func _rise_from_glyph(enemy: EnemyInstance, pos: Vector2, final_scale: float, hold: float) -> void:
	var t: SpawnGlyphTuning = SPAWN_GLYPH_TUNING
	enemy.set_physics_process(false)
	var target_mod: Color = enemy.modulate
	enemy.scale = Vector2(final_scale * t.rise_start_width, 0.0)
	enemy.modulate = Color(t.rise_tint.r, t.rise_tint.g, t.rise_tint.b, target_mod.a)
	var size_mult: float = maxf(final_scale, 1.0)
	_spawn_glyph(pos, hold, size_mult)
	var reduced: bool = GameSettings.motion_reduced()
	var tw: Tween = enemy.create_tween()
	tw.tween_interval(SpawnGlyph.rise_delay(t, hold))
	var wm: WaveManager = self
	tw.tween_callback(func() -> void:
		if is_instance_valid(wm):
			wm._spawn_light(pos, size_mult))
	tw.tween_property(enemy, "scale", Vector2(final_scale, final_scale), t.rise_sec) \
		.set_trans(Tween.TRANS_SINE if reduced else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(enemy, "modulate", target_mod, t.rise_sec)
	tw.tween_interval(t.settle_sec)
	var captured_enemy := enemy
	tw.tween_callback(func() -> void:
		if is_instance_valid(captured_enemy):
			captured_enemy.set_physics_process(true))


## Final visual scale of a spawn entry: its EnemyType base_scale, times the elite mult.
static func final_scale_of(entry: Dictionary, elite: bool) -> float:
	var s: float = float(entry.get("base_scale", 1.0))
	if elite:
		s *= BULLET_HELL_TUNING.elite_scale_mult
	return s


## Adds a SpawnGlyph on the floor at [param pos] (ADR-0043).
func _spawn_glyph(pos: Vector2, hold: float, size_mult: float) -> void:
	if not is_inside_tree():
		return
	var g := SpawnGlyph.new()
	g.hold = hold
	g.size_mult = size_mult
	_glyph_parent().add_child(g)
	g.global_position = pos


## Glyphs live in the room that holds the spawn markers, so they go with it on a room
## transition and never count as WaveManager children (enemies). Falls back to self.
func _glyph_parent() -> Node:
	if spawn_points_container != null and spawn_points_container.get_parent() != null:
		return spawn_points_container.get_parent()
	return self


## Asks the room's FloorLighting for a rim-coloured light as an enemy rises.
func _spawn_light(pos: Vector2, size_mult: float) -> void:
	if not is_inside_tree():
		return
	var fl: FloorLighting = get_tree().get_first_node_in_group(FloorLighting.GROUP) as FloorLighting
	if fl != null:
		fl.pulse_spawn(pos, SpawnGlyph.PALETTE.rim, size_mult)


## ADR-0018 — a Perfect Cast wipes enemy bullets around Fayde. ADR-0019 — each wiped
## bullet adds PaceTuning.cancel_meter_gain to the Special meter.
func _on_perfect_cast(_world_pos: Vector2, _streak: int) -> void:
	if not is_inside_tree():
		return
	var player: Node2D = get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		var n: int = Projectile.cancel_in_radius(get_tree(), player.global_position,
			BULLET_HELL_TUNING.perfect_cancel_radius)
		if n > 0:
			SpellCastingEffects.add_special_meter(float(n) * PACE_TUNING.cancel_meter_gain)


## ADR-0018 — the Special wipes enemy bullets inside (a little beyond) its burst.
func _on_special_fired(_prana_type_id: int, world_pos: Vector2, radius: float) -> void:
	if not is_inside_tree():
		return
	var r: float = radius * BULLET_HELL_TUNING.special_cancel_radius_mult if radius > 0.0 \
		else BULLET_HELL_TUNING.special_cancel_fallback_radius
	Projectile.cancel_in_radius(get_tree(), world_pos, r)


## Clears every enemy bullet and hazard (wave cleared, new preparation phase).
func _clear_enemy_fire() -> void:
	if not is_inside_tree():
		return
	Projectile.cancel_in_radius(get_tree(), Vector2.ZERO, -1.0)
	for hazard: Node in get_tree().get_nodes_in_group(&"enemy_hazard"):
		hazard.queue_free()


## Instantiates the actual enemy scenes at projected spawn positions during preparation.
## Enemies are neutralized (no physics, no combat, no HitArea) and rendered at 50% alpha
## so the player sees exactly which enemies will spawn where.
## Mirrors the same position distribution as _spawn_wave() so previews match actual spawns.
func _show_wave_preview() -> void:
	_clear_wave_preview()
	var markers: Array[Node2D] = _get_spawn_markers()
	if markers.is_empty():
		return
	var marker_idx: int = 0
	var swarmer_base_pos: Vector2 = Vector2.ZERO
	var swarmer_local_count: int = 0
	var swarm_counts: Dictionary = threat_swarm_counts(_wave_composition)
	var swarm_icon_done: Dictionary = {}
	for entry: Dictionary in _wave_composition:
		var enemy_scene: PackedScene = entry["scene"] as PackedScene
		if enemy_scene == null:
			marker_idx += 1
			continue
		var is_swarmer: bool = (int(entry.get("archetype", -1)) == GameEnums.EnemyArchetype.SWARMER)
		var final_pos: Vector2
		if is_swarmer:
			if swarmer_local_count == 0:
				swarmer_base_pos = markers[marker_idx % markers.size()].global_position
				marker_idx += 1
			var spread: Vector2 = Vector2(cos(swarmer_local_count * 2.4), sin(swarmer_local_count * 2.4)) * 8.0
			final_pos = swarmer_base_pos + spread
			swarmer_local_count += 1
		else:
			var base_pos: Vector2 = markers[marker_idx % markers.size()].global_position
			var wrap_lap: int = marker_idx / markers.size()
			var jitter: float = 12.0 if wrap_lap > 0 else 0.0
			var spread: Vector2 = Vector2(cos(marker_idx * 2.4), sin(marker_idx * 2.4)) * jitter
			final_pos = base_pos + spread
			marker_idx += 1
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
		var preview_scale: float = entry.get("base_scale", 1.0)
		enemy.scale = Vector2(preview_scale, preview_scale)
		enemy.modulate.a = 0.5
		# ADR-0018 — reinforcements preview fainter: they arrive mid-fight, not now.
		if int(entry.get("group", 0)) > 0:
			enemy.modulate.a = 0.22
		enemy.global_position = final_pos
		_preview_nodes.append(enemy)
		# ADR-0032: a threat icon above the enemy (name labels overlapped). A swarm
		# shows one icon with a count; reinforcements get none (they arrive later).
		var type_id: int = int(entry["type_id"])
		if int(entry.get("group", 0)) > 0 or (is_swarmer and swarm_icon_done.has(type_id)):
			continue
		var et: EnemyType = EnemyCatalog.get_type(type_id)
		if et == null:
			continue
		var icon := ThreatIcon.new()
		icon.kind = ThreatIcon.kind_for(et)
		icon.ring_color = Color(et.debug_color, 1.0)
		icon.elite = bool(entry.get("elite", false))
		if is_swarmer:
			swarm_icon_done[type_id] = true
			icon.count = int(swarm_counts.get(type_id, 1))
		add_child(icon)
		icon.global_position = final_pos + Vector2(0.0, -ICON_OFFSET_Y * preview_scale)
		_preview_nodes.append(icon)


## Swarmer type id → how many of it spawn now (group 0), so the preview can show one
## threat icon per swarm with a count. [param composition] is a wave composition.
static func threat_swarm_counts(composition: Array) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in composition:
		if int(entry.get("archetype", -1)) != GameEnums.EnemyArchetype.SWARMER:
			continue
		if int(entry.get("group", 0)) > 0:
			continue
		var id: int = int(entry.get("type_id", -1))
		counts[id] = int(counts.get(id, 0)) + 1
	return counts


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
