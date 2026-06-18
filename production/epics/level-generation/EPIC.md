# Epic: Level Generation

> **Layer**: Feature
> **GDD**: design/gdd/level-generation.md
> **Architecture Module**: IsometricRoom (obstacle placement) + WaveManager (enemy composition) + EnemyInstance (archetype behaviors)
> **Status**: Complete
> **Stories**: Created retroactively — all acceptance criteria implemented before epic was formalised

## Overview

Level Generation makes each room feel distinct by randomising two independent layers each
run: obstacle layout (half-cover debris placed within the arena diamond via rejection
sampling) and enemy composition (a threat-budget draw from four archetypes with SEEKER +
SWARMER guaranteed). Archetype-distinct tick functions (RUSHER charge cycle, SWARMER orbit)
ensure that composition randomisation produces mechanically different encounters.

All implementation lives in three modules: `IsometricRoom._build_debris_obstacles()` for
placement, `WaveManager._build_composition()` for threat-budget fill, and
`EnemyInstance._tick_rusher()` / `_tick_swarmer()` for per-archetype behaviour.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| *(none)* | All LG requirements implemented without a formal ADR. No engine-specific risks identified — pure GDScript logic. | LOW |

> ⚠️ AC-LG-01 through AC-LG-10 are untraced in the TR registry. This is acceptable for
> a retroactive epic where all criteria were verified in code and unit tests before
> formalisation.

## GDD Requirements

| TR-ID | Requirement | ADR Coverage | Implementation |
|-------|-------------|--------------|----------------|
| AC-LG-01 | Obstacle count is between 5 and 9 each run | ❌ No ADR | `_DEBRIS_COUNT_MIN/MAX` in `isometric_room.gd` |
| AC-LG-02 | No obstacle within 60 px of arena origin | ❌ No ADR | `_DEBRIS_MIN_CENTER_DIST = 90.0` (exceeds criterion) |
| AC-LG-03 | No obstacle within 80 px of any spawn marker | ❌ No ADR | `_DEBRIS_MIN_SPAWN_DIST = 110.0` (exceeds criterion) |
| AC-LG-04 | No two obstacles within 55 px of each other | ❌ No ADR | `_DEBRIS_MIN_BETWEEN_DIST = 75.0` (exceeds criterion) |
| AC-LG-05 | Enemy composition threat total in [10, 18] (+2 overflow) | ❌ No ADR | `THREAT_BUDGET_MIN/MAX` in `wave_manager.gd` |
| AC-LG-06 | Every composition contains at least 1 SEEKER and 1 SWARMER | ❌ No ADR | Guaranteed in `_build_composition()` |
| AC-LG-07 | RUSHER velocity during CHARGING > velocity during APPROACH | ❌ No ADR | `RUSHER_CHARGE_SPEED_MULT=3.5` vs `RUSHER_APPROACH_SPEED_MULT=0.65` |
| AC-LG-08 | SWARMER target position changes each frame (orbit advances) | ❌ No ADR | `_swarmer_angle += SWARMER_ORBIT_SPEED * delta` |
| AC-LG-09 | RUSHER `_physics_process` does not execute SEEKER chase path | ❌ No ADR | `match _archetype` dispatch in `_physics_process` |
| AC-LG-10 | Two consecutive seeded runs produce different obstacle positions | ❌ No ADR | `RandomNumberGenerator` re-seeded per room in `_ready()` |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/level-generation.md` are verified
- All Logic stories have passing test files in `tests/`

**Status**: All AC criteria implemented and verified. Unit tests exist in
`tests/unit/level-generation/`. Epic marked Complete at creation (retroactive).

## Stories

| Story | Description | Status |
|-------|-------------|--------|
| LG-001 | Debris obstacle placement (AC-LG-01 to AC-LG-04, AC-LG-10) | Complete |
| LG-002 | Threat-budget enemy composition (AC-LG-05, AC-LG-06) | Complete |
| LG-003 | RUSHER charge cycle (AC-LG-07, AC-LG-09) | Complete |
| LG-004 | SWARMER orbit behaviour (AC-LG-08) | Complete |
