---
name: hotpath-audit-2026-06-16
description: First performance pattern audit of 8 hot-path files; findings and severity
metadata:
  type: project
---

Audit date: 2026-06-16. Files audited: player_controller.gd, enemy_instance.gd, health_and_damage.gd, status_effects_manager.gd, combination_resolution.gd, prana_grid.gd, combat_hud.gd, spell_vfx.gd.

Key findings (see full report in conversation):

CRITICAL:
- SpellVFX: ParticleProcessMaterial.new() + GPUParticles2D.new() allocated per spell hit. No pool. At 3 hits/sec × 3 chain attacks that is 9 GPU resource allocs/sec. Recommendation: pool 5 burst nodes keyed by prana type.

WARNING:
- StatusEffectsManager._process(): .duplicate() called on every target's status array every frame. At 10 enemies × 3 statuses = 30 array duplications per frame (60/s = 1800/s). Recommendation: use a dirty-flag or index-stable removal instead of duplicate().
- StatusEffectsManager._on_enemy_killed(): get_nodes_in_group("enemy") called on every enemy death for Burn Contagion scan. Traverses entire scene graph. Recommendation: maintain a live enemy registry in WaveManager/EnemyCatalog.
- CombatHUD._rebuild_dots(): frees and re-allocates all chain-dot ColorRect nodes on every chain_index_changed signal. Called every cast hit. Recommendation: pool/recolor dots in place.
- EnemyInstance._physics_process(): z_index = clamp(int(global_position.y) + 500, 1, 2000) every physics frame per enemy. Same pattern in PlayerController. Both are int() + clamp() per entity per frame. Advisory at current scale; warning at 20+ enemies.

ADVISORY:
- HealthAndDamage._check_hp_zone_change(): roundi(float(FAYDE_MAX_HP) * threshold) computed fresh on every apply_damage call. Should be cached as constants.
- CombatHUD._on_damage_taken(): string format "%d / %d" allocated on every damage event.
- PranaGrid._on_confirm_pressed(): PranaFragment.new() allocated per filled slot (up to 9) on confirm. One-time event; not a frame-loop issue.
- PlayerController._fire_footstep(): Array literal re-assigned when bag empties (~every 3 steps). Minor; typed Array[StringName] is stack-cheap.
- EnemyInstance._fayde_ref re-resolution: get_first_node_in_group() called if _fayde_ref goes null. Guard is correct; risk is if this fires every frame due to a bug.
- spell_vfx._on_cast_started(): get_first_node_in_group("player") called on every cast. Should cache player ref in _ready().

EFFICIENT:
- PlayerController._physics_process(): no allocations, all float accumulators correct, delta-based timers correct for physics frame.
- HealthAndDamage._process(): minimal — only ticks i-frame timer; no allocations.
- StatusEffectsManager tick math: ADR-0004 accumulator pattern correct (+=, not reset).
- PranaGrid._process(): single float timer decrement — negligible cost.
- CombatHUD._process(): float accumulators correct; chain-dot position tracking via canvas transform multiply is fine at 1 player.
- combination_resolution.gd: not in frame loop; fires once per wave on combat_started. No performance concern.

**Why:** First audit before any profiling instrumentation is in place. Baseline for regression detection.
**How to apply:** Use these findings when the engine-programmer picks up optimization tasks. The SpellVFX material alloc and SEM duplicate() are the highest-priority items to fix before enemy count scales past 5.
