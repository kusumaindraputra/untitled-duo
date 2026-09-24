# ADR-0018: Data-Driven Bullet Patterns and the Bullet-Hell Layer

## Status

Accepted

## Date

2026-09-24

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Enemy attacks become data. A `BulletPattern` Resource describes one attack layer
(shape, count, bursts, spin, motion, hazard kind, HP gate); `EnemyType.pattern_layers`
lists the layers an enemy fires. A pure `BulletPatternRunner` RefCounted turns a
pattern into timed volleys; `EnemyInstance` spawns them as pooled `Projectile`s or as
`EnemyLaser` / `MortarShell` hazards. On top sit the bullet-hell rules: a 3 px hurtbox,
graze into the Special meter, bullet cancel on Perfect Cast and Special, two dash
charges, elite enemies and mid-wave reinforcements. All knobs live in
`BulletHellTuning`. Design: `design/gdd/bullet-hell.md`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay / Physics 2D |
| **Knowledge Risk** | LOW — `Area2D`, `CollisionObject2D.disable_mode`, `Geometry2D.get_closest_point_to_segment`, typed `Array[Resource]` exports are unchanged since 4.0 |

## ADR Dependencies

- ADR-0004 (float accumulators) — every pattern, hazard and dash-recharge timer.
- ADR-0007 / ADR-0014 (H&D registration) — `register_enemy()` gains an optional
  `hp_mult` for elites; spawn order is unchanged.
- ADR-0008 (catalog immutability) — patterns ride inside `EnemyType`, so
  `duplicate_deep()` isolates them per enemy.
- ADR-0017 (Special meter) — graze feeds `_add_special_meter` through the new public
  `SpellCastingEffects.register_graze()`; cancel listens to `perfect_cast` / `special_fired`.

## Context

The user asked for a fast-paced bullet hell with many enemy attack types. Before this
change the only ranged attacks were the Rifter's single aimed shot every 2 s and the
boss's 6-bullet salvo, both hardcoded constants in `enemy_instance.gd`. Every new
attack would have meant a new archetype branch. Fayde's 8 px movement body was also
her bullet hurtbox, which punishes near misses, and the 2 s dash cooldown is far too
slow for dense patterns.

## Decision

1. **Patterns are Resources.** `BulletPattern` (`src/data/bullet_pattern.gd`) holds
   timing (interval, delay, windup, `hp_threshold`), geometry (`AIMED` / `FAN` / `RING`
   / `SPIRAL`, count, spread, bursts, spin), bullet params (speed, `speed_step`,
   `STRAIGHT` / `SINE` / `HOMING`, damage mult, radius, range, colour) and hazard params
   (`LASER` / `MORTAR`). Authored in `assets/data/bullet_patterns/`.
2. **Runner is pure.** `BulletPatternRunner` returns `windup` / `fire` events from
   `tick(delta, aim)`; `compute_angles()` is static. No nodes, fully unit-tested.
3. **Enemies compose layers.** `EnemyType.pattern_layers`, `death_pattern` and
   `keep_distance`. Layers tick after the archetype movement, only while CHASING.
   SHOOTER without layers keeps the legacy single shot, so old fixtures still work.
   New enemies (Spinner, Sniper, Mortar, Weaver, Splitter) are pure data over the
   existing archetypes.
4. **Boss phases are HP-gated layers.** A layer with `hp_threshold < 1` switches on
   below that HP ratio; a rise in active gated layers emits `EnemyInstance.phase_changed`,
   which CombatHUD calls out.
5. **Bullets.** `Projectile` hits Fayde by distance (`bullet_radius + player_hurt_radius`),
   not by physics against her body; its collision mask is walls only. A bullet that
   reaches a dashing Fayde passes through and grazes. Live bullets join group
   `enemy_bullet`; `Projectile.cancel_in_radius()` clears them.
6. **Pooling.** `BulletPool` (one per arena parent) recycles pattern bullets. Spent
   bullets hide at once and are released deferred, so `process_mode = DISABLED`
   (which removes them from the physics space) never flips during a physics flush.
   Legacy shots and the boss salvo still use `Projectile.new()`.
7. **Cancel and clear in WaveManager.** It already lives in every arena, so it
   listens to `perfect_cast` / `special_fired` and clears all enemy fire (deferred,
   after every `enemy_killed` handler) when the wave completes and on preparation.
8. **Dash charges.** `PlayerController` keeps `_dash_charges`; each recharges after
   `dash_recharge_sec × dash-cooldown sigils`. `dash_cooldown_changed(false)` fires
   only when the last charge is spent, so CombatHUD needs no change.
9. **Elites and reinforcements** are composition data: `EnemyPoolConfig.elite_chance`,
   `reinforcement_groups`, `reinforcement_trigger_alive`. Rolls happen after every
   composition pick, so seeded compositions are unchanged when the chance is 0.

## Alternatives Considered

- **One archetype per attack** — rejected: every new pattern would be code, and the
  boss could not mix patterns per phase.
- **Bullets as a MultiMesh / server-side canvas items** — faster, but loses the
  per-bullet `Area2D` wall collision and complicates cancel. Revisit only if profiling
  shows the pool cannot hold 60 fps.
- **Graze as a second Area2D on Fayde** — rejected: the bullet already measures its
  distance for the hit test, so graze is one extra comparison.

## Consequences

- Positive: new attacks are `.tres` files; boss phases and elites are free
  combinations; near misses are fair and rewarded.
- Negative: `Projectile` does a distance check per bullet per frame (cheap, O(bullets)).
  `enemy_instance.gd` grows ~150 lines.
- Risk: pattern density is tuned on paper (GDD Tuning Knobs); playtest before release.

## Validation Criteria

`tests/unit/bullet-hell/*` and `tests/unit/wave-encounter-system/wave_reinforcement_test.gd`
pass; updated `dash_system_test.gd` and `enemy_catalog_data_test.gd` pass; full suite green.

## Related

- `design/gdd/bullet-hell.md`
- `design/gdd/enemy-data.md`, `design/gdd/enemy-ai.md`, `design/gdd/player-controller.md`,
  `design/gdd/special-attack.md`
