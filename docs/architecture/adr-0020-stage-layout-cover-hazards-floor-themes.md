# ADR-0020: Stage Layout: Full Cover, Room Hazards and Floor Themes

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Rooms now shape the bullet hell instead of only shaping movement. **Full-cover pillars**
stop enemy bullets and lasers and wear down as they absorb fire. **Room hazards**
(turrets, rotating sweep lasers, floor vents, a closing danger ring) add pressure from
the room itself and only run during combat. Each floor has a **FloorTheme** with its
own template pool, floor tint and pillar colour, so floors 2 and 3 no longer reuse
floor 1's rooms. Two new shapes (**Ring**, with a walled core, and **Cross**) join the
template set. Design: `design/gdd/stage-layout.md`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay / Physics / Level generation |
| **Knowledge Risk** | MEDIUM: see the `monitorable` finding below. `PhysicsRayQueryParameters2D.create`, `PhysicsDirectSpaceState2D.intersect_ray`, `TileMapLayer.map_to_local` are unchanged since 4.0 |

## ADR Dependencies

- ADR-0018 (bullet-hell layer): pillars hook `Projectile._on_body_entered` and
  `EnemyLaser`; turrets reuse `BulletPatternRunner` and `BulletPool`.
- ADR-0019 (fast-pace layer): sweep lasers call `register_perfect_dodge` like enemy
  lasers; hazards use the CONTACT damage source so dash i-frames apply.
- ADR-0014 (HealthAndDamage ↔ WaveManager): hazards deal damage through
  `HealthAndDamage.apply_damage`, never directly.

## Context

Before this change every obstacle was half cover: it blocked walking, and every enemy
shot flew over it. In a bullet hell that makes the layout nearly irrelevant to
survival. All three floors drew from the same Layer 1 template pool
(`RoomSelector` never had `set_pools()` called), and there were five shapes.

While testing, we also found that enemy bullets never collided with anything.
`Projectile` set `monitorable = false`, and in Godot 4.6 an `Area2D` with
`monitorable = false` does not report `body_entered` for static bodies. Bullets flew
through the arena walls. The same bug would have made pillars useless.

## Decision

1. **Physics layer 6 (value 32) = full cover.** `CoverPillar` (StaticBody2D) lives on it.
   `Projectile` masks walls + full cover and is now `monitorable = true`; no Area2D
   masks the projectile layer, so this adds no unwanted overlaps.
   `PlayerController` masks 53 normally and 33 while dashing, so a dash never phases
   through a pillar. `EnemyInstance` masks 49. Spell queries still use mask 5, so
   Prana passes through pillars.
2. **Pillars wear down.** Each bullet costs 1 hit and a laser costs `LASER_HITS` (3).
   Three crack stages are drawn, and the pillar crumbles at 0. Durability, count, radius
   and spacing live in `ObstacleConfig` (`pillar_*`). Mortars arc over pillars.
3. **Lasers are cut by pillars.** `EnemyLaser` raycasts on layer 32 through
   `CoverPillar.cast_beam()` during the telegraph and when it fires.
4. **Hazards are data.** `HazardSpec` resources sit in `RoomTemplate.hazards`.
   `IsometricRoom` builds one `StageHazard` subclass per spec under a `Hazards` node.
   Random-position hazards take a free interior tile clear of spawns, doors and the duo's
   start. Hazards listen to `GameStateManager`: `combat_started` switches them on,
   and preparation, wave end, room clear and death switch them off.
5. **Floor identity is data.** `FloorTheme` holds parallel template/weight arrays per room
   type plus the look. `debug_game_loop` applies the floor's theme to the generator
   (`DungeonGenerator.apply_floor_theme`) before `generate()`, and gives it to
   `RoomTransitionManager`, which sets `IsometricRoom.floor_theme` in the same
   pre-configure step as the template.
6. **New shapes use screen space.** Ring and Cross test `map_to_local()` positions
   against the room diamond, so they hold for the project's stacked isometric layout.
   The older shapes compute in tile coordinates and are left unchanged.

## Alternatives Considered

- **Pillars on the wall layer (1).** Rejected: that is simpler, but pillars could not be
  told apart from walls, and wall-only queries (sweep lasers with `stop_at_walls`
  off) would also hit them.
- **Indestructible pillars.** Rejected: hiding behind one would solve the room,
  which goes against the fast-pace pillar.
- **Hazards as enemies (EnemyInstance with no movement).** Rejected: they would count
  toward wave clear, take Prana damage and show up in the enemy budget. Hazards are
  part of the room, not the wave.
- **Per-floor pools hard-coded in RoomSelector (like L1_*_PRELOADS).** Rejected:
  that would need code changes for every new floor. A `.tres` per floor keeps tuning in data.

## Consequences

- Positive: layout now changes how a fight is survived. Floors look and play
  differently. Enemy bullets finally stop at walls, which also fixes bullets hitting
  The duo from outside the arena.
- Negative: more physics bodies per room (2–4 pillars and up to 4 hazards). They are
  cheap static bodies and one ray per beam per frame.
- Risk: dense patterns can grind pillars down quickly. Durability was raised to 24
  (combat and elite) and 32 (boss) after the first captures. Tune it in the
  obstacle configs.
- The spell-vfx hitstop test fails locally when the whole `res://tests` tree runs,
  and it fails the same way on `main`. It passes on its own, so it is unrelated to
  this change.

## Validation

- `tests/unit/stage-layout/` (43 cases): pillar durability and cracks, masks, a
  bullet flying into a pillar in the physics world, laser raycast, hazard
  timing and geometry, `pick_spread_positions` clearances, floor themes and generator
  pools, Ring and Cross shapes, and every themed room building with pillars on the floor.
- Visual evidence: `production/qa/evidence/stage-layout-evidence.md`.
