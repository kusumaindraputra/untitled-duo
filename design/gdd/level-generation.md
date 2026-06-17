# Level Generation

> **Status**: Draft
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-06-17
> **Implements Pillars**: Pillar 1 (Every Run Tells a Different Story), Pillar 3 (Chaos Has Consequences)

## Overview

Level Generation makes each room feel distinct by randomising two independent layers each run:
**obstacle layout** (number and position of half-cover debris within the arena diamond) and
**enemy composition** (a threat-budget draw from the four available archetypes). It also
formalises archetype-distinct attack behaviour so the composition randomisation produces
encounters that feel mechanically different, not just visually different.

## Player Fantasy

No two rooms are the same problem to solve. The obstacle configuration reshapes movement
corridors and line-of-sight before the wave begins — you prep the Prana grid for what the
arrangement affords, not a memorised layout. The enemy mix forces different elemental calls:
a RUSHER-heavy room punishes hesitation in Preparation; a SWARMER swarm punishes standing
still in Combat. The player who survives is the one who read the room layout *and* the wave
peek together, not the one who memorised one strategy.

## Detailed Rules

### Obstacle Placement

1. Each room generates between `_DEBRIS_COUNT_MIN` and `_DEBRIS_COUNT_MAX` (default 2–5)
   half-cover debris obstacles with a fresh RNG seed per run.
2. Valid placement zone: inside the **inner 80 %** of the arena diamond
   (`|x|/256 + |y|/192 ≤ _DEBRIS_INNER_SCALE`). The outer 20 % border is reserved for
   approach lanes and wall clearance.
3. Hard clearance constraints (rejection sampling):
   - ≥ `_DEBRIS_MIN_CENTER_DIST` (60 px) from the arena origin (player start area).
   - ≥ `_DEBRIS_MIN_SPAWN_DIST` (80 px) from every spawn marker global position.
   - ≥ `_DEBRIS_MIN_BETWEEN_DIST` (55 px) between any two obstacles.
4. Each obstacle slot tries up to `_DEBRIS_PLACE_ATTEMPTS` (60) random candidates. Slots
   that exhaust all attempts are silently skipped — room may have fewer than the target count.
5. Obstacles block movement (physics layer `_HALF_COVER_LAYER`) but **not** Prana spells or
   projectiles (half-cover contract from `design/quick-specs/arena-cover-types.md`).

### Enemy Composition

1. A random threat budget `B` is drawn from [`THREAT_BUDGET_MIN`, `THREAT_BUDGET_MAX`]
   (default 10–18) once per room.
2. Guaranteed types: at least **1 SEEKER** and **1 SWARMER** always appear. Their threat
   costs are subtracted from `B` before pool-fill begins.
3. Pool fill: while `B ≥ min_cost_in_pool (1)`, pick a random type whose cost ≤ B, add it,
   subtract its cost. Stop when no affordable type remains.
4. Spawn order is shuffled after composition is built (no first-type bias).
5. Threat costs (local to `WaveManager`):

   | Type ID | Archetype | Cost |
   |---------|-----------|------|
   | 0 | SEEKER (Drifter) | 1 |
   | 1 | RUSHER (Charger) | 2 |
   | 2 | SWARMER (Cluster) | 1 |
   | 4 | SHOOTER (Rifter) | 1 |

### Archetype Behaviours

All archetypes share the existing phase-gating, stun, and speed-modifier contracts.

**SEEKER** — Direct chase at full `_move_speed` + separation force. Contact damage on
overlap. Unchanged from FP implementation.

**RUSHER** — Four-phase charge cycle:
- `APPROACH` (0): Chase slowly (`_move_speed × RUSHER_APPROACH_SPEED_MULT`). When distance to
  Fayde ≤ `RUSHER_CHARGE_RANGE`, transition to TELEGRAPH.
- `TELEGRAPH` (1): Freeze in place for `RUSHER_TELEGRAPH_DURATION`. At expiry, lock
  `_rusher_charge_dir = _dir_last_valid` and transition to CHARGING.
- `CHARGING` (2): Burst in locked direction at `_move_speed × RUSHER_CHARGE_SPEED_MULT` for
  `RUSHER_CHARGE_DURATION`. At expiry, transition to COOLDOWN.
- `COOLDOWN` (3): Hold position (only separation force) for `RUSHER_COOLDOWN_DURATION`. At
  expiry, return to APPROACH.

RUSHER phase is reset to APPROACH on `preparation_started`. Contact damage fires normally on
any phase overlap.

**SWARMER** — Orbit: targets a point offset from Fayde at `SWARMER_ORBIT_RADIUS` (80 px).
The offset angle `_swarmer_angle` advances at `SWARMER_ORBIT_SPEED` (1.4 rad/s) each frame,
so the SWARMER circles Fayde. Each SWARMER instance is assigned a random starting angle on
`init()`, spreading multiple Swarmers around Fayde automatically. Chase speed is `_move_speed`
toward the orbit target; separation force applied as normal.

**SHOOTER** — Unchanged: maintain ≥ `KEEP_DISTANCE` (150 px), fire projectile every
`SHOOT_INTERVAL` (2 s).

## Formulas

**Diamond containment (inner zone)**
```
valid = |x| / WALL_HALF_X + |y| / WALL_HALF_Y  ≤  _DEBRIS_INNER_SCALE
WALL_HALF_X = 256, WALL_HALF_Y = 192, _DEBRIS_INNER_SCALE = 0.80
```

**Threat budget fill**
```
B  = randi_range(THREAT_BUDGET_MIN, THREAT_BUDGET_MAX)
B' = B - cost(SEEKER) - cost(SWARMER)   # after guarantees
while B' ≥ 1:
    pick type t with cost(t) ≤ B'
    add t ; B' -= cost(t)
```

**RUSHER charge velocity**
```
v_charge = _move_speed × RUSHER_CHARGE_SPEED_MULT
Example: 80 × 3.5 = 280 px/s
```

**SWARMER orbit target**
```
θ(t) = θ₀ + SWARMER_ORBIT_SPEED × t
P_target = P_fayde + SWARMER_ORBIT_RADIUS × (cos θ, sin θ)
Example: SWARMER_ORBIT_RADIUS = 80 px, θ advances at 1.4 rad/s → full circle in ~4.5 s
```

## Edge Cases

- **All obstacle slots fail placement**: Room has 0 obstacles. Acceptable; layout is still
  valid (no constraint violated).
- **Budget negative after guarantees**: Guaranteed types are always added regardless of
  budget deficit. Resulting total may exceed `THREAT_BUDGET_MAX` by at most
  `cost(SEEKER) + cost(SWARMER) = 2`. Pool-fill phase does not run.
- **RUSHER charges into a wall**: `move_and_slide()` handles collision; RUSHER slides along
  the wall and charge timer counts down normally. No special state needed.
- **SWARMER orbit target outside arena**: Arena walls contain the SWARMER via physics;
  wall-hugging may occur near arena edges but SWARMER self-corrects as Fayde moves.
- **Single SWARMER instance**: Orbits alone; no multi-instance spread needed, but the orbit
  still creates a circling threat distinct from SEEKER direct chase.

## Dependencies

| System | Relationship |
|--------|-------------|
| `IsometricRoom` | Provides the arena diamond dimensions and places spawn markers before obstacle generation runs. `_build_debris_obstacles()` is called last in `_ready()`. |
| `WaveManager` | Owns composition randomisation. Reads `EnemyCatalog` for scene references; threat costs are local constants. |
| `EnemyInstance` | Implements per-archetype tick functions. `init()` sets SWARMER starting angle and resets RUSHER phase. |
| `EnemyCatalog` | Supplies `EnemyType` (scene, archetype, base_damage, base_move_speed) for each type ID. |
| `HealthAndDamage` | Contact damage contract unchanged — `ENEMY_MIN_CONTACT_INTERVAL ≥ 0.3 s` hard constraint preserved across all archetypes. |
| `GameStateManager` | `preparation_started` resets RUSHER phase and SWARMER angle (angle reset not required — orbit starts fresh from current position). |

## Tuning Knobs

All constants live in the source file listed — change there to retune without logic edits.

**`src/scenes/isometric_room.gd`**

| Constant | Default | Effect |
|----------|---------|--------|
| `_DEBRIS_COUNT_MIN` | 2 | Minimum obstacles per room |
| `_DEBRIS_COUNT_MAX` | 5 | Maximum obstacles per room |
| `_DEBRIS_INNER_SCALE` | 0.80 | Inner zone fraction (0.8 = inner 80 % of diamond) |
| `_DEBRIS_MIN_CENTER_DIST` | 60 px | Clearance from arena origin |
| `_DEBRIS_MIN_SPAWN_DIST` | 80 px | Clearance from spawn markers |
| `_DEBRIS_MIN_BETWEEN_DIST` | 55 px | Minimum gap between obstacles |
| `_DEBRIS_PLACE_ATTEMPTS` | 60 | Rejection sample limit per slot |

**`src/systems/wave_manager.gd`**

| Constant | Default | Effect |
|----------|---------|--------|
| `THREAT_BUDGET_MIN` | 10 | Minimum threat total per room |
| `THREAT_BUDGET_MAX` | 18 | Maximum threat total per room |

**`src/gameplay/enemy_instance.gd`**

| Constant | Default | Effect |
|----------|---------|--------|
| `RUSHER_CHARGE_RANGE` | 180 px | Distance at which RUSHER enters TELEGRAPH |
| `RUSHER_APPROACH_SPEED_MULT` | 0.65 | Speed during APPROACH relative to `_move_speed` |
| `RUSHER_TELEGRAPH_DURATION` | 0.45 s | Freeze window before burst |
| `RUSHER_CHARGE_SPEED_MULT` | 3.5 | Speed multiplier during CHARGING burst |
| `RUSHER_CHARGE_DURATION` | 0.55 s | Duration of the burst |
| `RUSHER_COOLDOWN_DURATION` | 1.2 s | Rest period after burst |
| `SWARMER_ORBIT_RADIUS` | 80 px | Orbit circle radius around Fayde |
| `SWARMER_ORBIT_SPEED` | 1.4 rad/s | Angular velocity of orbit |

## Acceptance Criteria

| ID | Criterion | Test Type |
|----|-----------|-----------|
| AC-LG-01 | Obstacle count is between 2 and 5 each run | Logic (unit) |
| AC-LG-02 | No obstacle within 60 px of arena origin | Logic (unit) |
| AC-LG-03 | No obstacle within 80 px of any spawn marker | Logic (unit) |
| AC-LG-04 | No two obstacles within 55 px of each other | Logic (unit) |
| AC-LG-05 | Enemy composition threat total is in [10, 18] (or at most +2 from guarantee overflow) | Logic (unit) |
| AC-LG-06 | Every composition contains at least 1 SEEKER and 1 SWARMER | Logic (unit) |
| AC-LG-07 | RUSHER velocity magnitude during CHARGING > velocity during APPROACH | Logic (unit) |
| AC-LG-08 | SWARMER target position changes each frame (orbit advances) | Logic (unit) |
| AC-LG-09 | RUSHER `_physics_process` does not execute SEEKER chase path | Logic (unit) |
| AC-LG-10 | Two consecutive seeded runs produce different obstacle positions | Logic (unit) |
