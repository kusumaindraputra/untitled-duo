# Epic: Prana Data

> **Layer**: Foundation
> **GDD**: design/gdd/prana-data.md
> **Architecture Module**: GameEnums + PranaCatalog
> **Status**: Ready
> **Stories**: 4 stories created

## Overview

Implements the shared enum definitions and Prana type catalog that form the raw material of the entire spell spine. GameEnums provides all project-wide constants (DamageClass, BaseStatus, GameState, etc.) as a pure static container accessible via `class_name` — no autoload, no initialization cost. PranaCatalog is Autoload #1, loading 5 PranaType `.tres` Resource files at startup and serving deep-copy instances to all consuming systems via `get_type(id)`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Autoload Architecture | PranaCatalog registered at Autoload position 1 — first in chain | LOW |
| ADR-0006: GameEnums Pure Container | GameEnums uses `class_name` + `extends RefCounted`, NOT Autoload; all enum constants have explicit integer assignments for `.tres` serialization stability | MEDIUM |
| ADR-0008: PranaCatalog Immutability | `get_type()` returns `duplicate_deep()` — consumer mutations cannot corrupt catalog | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PD-001 | PranaCatalog accessible at `_ready()` time — Autoload position 1 | ADR-0002 ✅ |
| TR-PD-002 | `get_type()` returns `duplicate_deep()` copy — consumer mutations isolated | ADR-0008 ✅ |
| TR-PD-003 | All GameEnums constants use explicit integer assignments | ADR-0006 ✅ |
| TR-PD-004 | GameEnums: `class_name` + `extends RefCounted` — NOT Autoload | ADR-0006 ✅ |
| TR-PD-005 | `push_error()` not `assert()` for `_initialized` guard | ADR-0008 ✅ |
| TR-PD-006 | Burn tick constraint startup assert: `burn_tick_magnitude × floor(burn_duration / burn_tick_rate) ≤ 0.60` | ❌ No ADR — acceptance criterion on story |
| TR-PD-007 | PranaType properties must be `@export var` — inspector-editable `.tres` workflow | ❌ No ADR — acceptance criterion on story |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/prana-data.md` are verified
- All Logic stories have passing test files in `tests/unit/data/`
- `PranaCatalog._initialized` guard validated; `get_type()` returns isolated copies (TR-PD-002, TR-PD-005)
- `.tres` int serialization round-trip verified with a test project (ADR-0006 open check)
- `duplicate_deep()` copy isolation verified in GUT test (ADR-0008 open check)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [GameEnums Pure Container](story-001-game-enums-pure-container.md) | Logic | Ready | ADR-0006 |
| 002 | [PranaType Resource Schema](story-002-prana-type-resource-schema.md) | Logic | Ready | ADR-0008 |
| 003 | [PranaCatalog Autoload](story-003-prana-catalog-autoload.md) | Logic | Ready | ADR-0008 |
| 004 | [Five Prana Type .tres Data Files](story-004-prana-type-tres-files.md) | Config/Data | Ready | N/A |

## Next Step

Run `/story-readiness production/epics/prana-data/story-001-game-enums-pure-container.md` then `/dev-story` to begin implementation.
