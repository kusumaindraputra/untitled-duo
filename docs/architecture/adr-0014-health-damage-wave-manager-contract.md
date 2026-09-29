# ADR-0014: HealthAndDamage ↔ WaveManager Integration Contract

## Status
Accepted

## Date
2026-05-31

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (HP management × Wave lifecycle) |
| **Knowledge Risk** | LOW — `Node.get_instance_id()`, signal connection, `add_child()` ordering unchanged since Godot 4.0 |
| **References Consulted** | `docs/architecture/adr-0007-health-damage-autoload-singleton.md`, `design/gdd/wave-encounter-system.md`, `design/gdd/health-damage.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None — contract is covered by Enemy Instance integration tests |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0007 (Accepted) — H&D Public API; ADR-0002 (Accepted) — Autoload ordering |
| **Enables** | EnemyInstance stories, WaveManager stories |
| **Blocks** | None when Accepted |
| **Ordering Note** | Must be Accepted before any story that implements WaveManager spawn logic or EnemyInstance death sequencing |

## Context

### Problem Statement

HealthAndDamage (ADR-0007) and WaveManager are deeply coupled at runtime: H&D tracks enemy HP and emits `enemy_killed`; WaveManager spawns enemies and tracks wave completion via that signal. ADR-0007 resolved the registration pattern (QQ-03) but left the full lifecycle contract distributed across three GDDs (wave-encounter-system.md, health-damage.md, enemy-ai.md) with no single authoritative record. This causes a sprint-stall risk: a programmer starting the Enemy Instance or WaveManager story without this ADR would have to synthesize three GDDs to determine the correct call order.

### Constraints

- H&D is Autoload #6 (always initialized before any scene's `_ready()`)
- WaveManager is a scene node (not an Autoload); it exists only during an active run
- The enemy registry is owned exclusively by H&D — WaveManager never reads or writes `_enemy_registry` directly
- Signal connections must be made in `_ready()` with no manual polling

## Decision

### Registration Order (WaveManager → H&D)

WaveManager calls `HealthAndDamage.register_enemy(enemy_node, type_id)` **before** `add_child(enemy_node)` in the spawn loop:

```gdscript
# Correct ordering in WaveManager._spawn_wave():
for entry in _wave_composition:
    var enemy: Node = entry.scene.instantiate()
    HealthAndDamage.register_enemy(enemy, entry.type_id)  # ← BEFORE add_child
    add_child(enemy)
    enemy.global_position = _spawn_markers[spawn_idx].global_position
    enemy.init(entry.type_id)
```

**Rationale:** `register_enemy()` sets the enemy's HP pool in H&D's `_enemy_registry` keyed by `enemy.get_instance_id()`. This must happen before `add_child()` because `add_child()` triggers `_ready()` on the enemy node, which may immediately call `apply_damage()` (e.g., if a status effect fires on spawn). Registering after `add_child()` would cause a null-key crash in `apply_damage()`.

### Kill Signal Contract (H&D → WaveManager)

WaveManager tracks wave completion exclusively via H&D's `enemy_killed` signal. It **never** polls `HealthAndDamage._enemy_registry` directly.

```gdscript
# In WaveManager._ready():
HealthAndDamage.enemy_killed.connect(_on_enemy_killed)

func _on_enemy_killed(instance_id: int, type_id: int,
                      prana_affiliation: GameEnums.DamageClass) -> void:
    _enemies_alive -= 1
    if _enemies_alive <= 0:
        _wave_state = WaveState.WAVE_COMPLETE
        emit_signal("all_waves_cleared")
        emit_signal("boss_defeated")  # FP: fires immediately after (no boss)
```

The `<= 0` guard (not `== 0`) protects against a duplicate-signal edge case. H&D's dead-target guard (`inst.is_dead` check in `apply_damage()`) is the primary protection; the WaveManager guard is a safety net.

### Unregistration (H&D internal — WaveManager does not call)

H&D calls `unregister_enemy(instance_id)` internally from the `enemy_killed` emission path. WaveManager **never** calls `unregister_enemy()`. Enemy node lifetime (queue_free()) is managed by EnemyInstance after `enemy_killed` fires, not by WaveManager.

### Run End Contract (the brothers fall)

When `player_died` fires (emitted by H&D), GameStateManager transitions to `DEATH_SCREEN`. WaveManager does NOT emit `all_waves_cleared` or `boss_defeated` in this case. Remaining enemy nodes are freed when SceneManager unloads the arena scene. WaveManager's `_enemies_alive` is left non-zero; it is reset on `preparation_started` at the start of the next run.

### Wave Reset Contract

On `preparation_started(wave_index, waves_remaining)` (emitted by GameStateManager), WaveManager resets:

```gdscript
_enemies_alive = 0
_enemies_total = 0
_wave_state = WaveState.IDLE
```

H&D does not need notification of wave reset — its `_enemy_registry` is emptied when enemies die (each kill triggers `unregister_enemy()`). By the time `all_waves_cleared` fires, `_enemy_registry` contains only the current wave's alive entries; if the duo dies mid-wave, the SceneManager scene unload flushes the registry via H&D's `_exit_tree()` cleanup.

### base_hp Source

`register_enemy(enemy_node, type_id)` reads `base_hp` from `EnemyCatalog.get_type(type_id).base_hp`. H&D owns the lookup; WaveManager passes only the `type_id` and the `enemy_node` reference.

## Consequences

### Positive
- All spawn-time call ordering is explicit in one document — eliminates the sprint-stall risk of synthesizing three GDDs
- WaveManager's kill-tracking path has no H&D internal state access — respects Autoload ownership boundary
- The registration-before-add_child rule prevents a class of null-key crashes that would only surface during integration testing

### Negative
- WaveManager must call `register_enemy()` in a specific position within the spawn loop — easy to get wrong if this ADR is not consulted. Enforce via code review checklist.

### Trade-offs accepted
- H&D holds the unregistration authority (not WaveManager). This means a WaveManager programmer cannot "clean up after themselves" explicitly — they must trust H&D's internal lifecycle. The benefit is a single ownership point for enemy HP state; the cost is a less obvious cleanup path.

## GDD Requirements Addressed

| TR-ID | Requirement | Source GDD |
|-------|-------------|------------|
| TR-HD-006 | `register_enemy(enemy, type_id)` called by WaveManager before `add_child()` — registration ordering contract | health-damage.md |
| TR-HD-007 | `enemy_killed(instance_id, type_id, prana_affiliation)` signal — sole emitter, carries kill metadata | health-damage.md |
| TR-WES-003 | Kill tracking: H&D `enemy_killed` signal → WaveManager `_enemies_alive -= 1`; `<= 0` guard triggers completion | wave-encounter-system.md |
| TR-WES-005 | FP scope: `all_waves_cleared` and `boss_defeated` fire sequentially in same handler after last enemy death | wave-encounter-system.md |
