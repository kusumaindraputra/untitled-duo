# Epic: Enemy Data

> **Layer**: Foundation
> **GDD**: design/gdd/enemy-data.md
> **Architecture Module**: EnemyCatalog
> **Status**: Complete
> **Stories**: 3 stories

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [EnemyType Resource Schema](story-001-enemy-type-resource-schema.md) | Logic | Ready | ADR-0006 |
| 002 | [EnemyCatalog Autoload](story-002-enemy-catalog-autoload.md) | Logic | Ready | ADR-0002 |
| 003 | [Four EnemyType .tres Data Files](story-003-enemy-type-tres-files.md) | Config/Data | Ready | N/A |

## Overview

Implements the EnemyType catalog that WaveManager and EnemyInstance consume at spawn time. EnemyCatalog is Autoload #2, loading 4 EnemyType `.tres` Resource files at startup. Each EnemyType carries base stats (HP, move speed, damage), an elemental `prana_affiliation` flag, a spawn weight, an active/inactive flag for `vs_scope` filtering, and a `scene: PackedScene` field so WaveManager can instantiate enemy scenes directly from the catalog entry without a separate scene map.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Autoload Architecture | EnemyCatalog registered at Autoload position 2 | LOW |
| ADR-0006: GameEnums Pure Container | `prana_affiliation` uses `GameEnums.DamageClass` — enum int serialization applies | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ED-001 | EnemyCatalog accessible at `EnemyInstance.init()` and WaveManager spawn — Autoload position 2 | ADR-0002 ✅ |
| TR-ED-002 | EnemyCatalog immutability via `duplicate_deep()` — same pattern as PranaCatalog | ❌ No ADR — covered by ADR-0008 intent; acceptance criterion on story |
| TR-ED-003 | EnemyType Resource has `scene: PackedScene` field — WaveManager spawns via `EnemyType.scene.instantiate()` | ❌ No ADR — acceptance criterion on story |
| TR-ED-004 | `prana_affiliation` uses `GameEnums.DamageClass.NONE = -1` sentinel for unaffiliated enemies — never null in `enemy_killed` signal | ❌ No ADR — acceptance criterion on story |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/enemy-data.md` are verified
- All Logic stories have passing test files in `tests/unit/data/`
- `get_type()` returns isolated deep copies; `get_active_types()` filters correctly
- `EnemyType.scene.instantiate()` produces valid enemy scene roots in WaveManager integration test

## Next Step

Run `/create-stories enemy-data` to break this epic into implementable stories.
