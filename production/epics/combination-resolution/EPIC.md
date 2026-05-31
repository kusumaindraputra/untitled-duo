# Epic: Combination Resolution

> **Layer**: Core
> **GDD**: design/gdd/combination-resolution.md
> **Architecture Module**: `src/systems/combination_resolution.gd` (Autoload #8)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories combination-resolution`

## Overview

Implements the data-driven algorithm that transforms a 9-slot Prana arrangement into a `SpellEffect` resource. CombinationResolution owns the resolution algorithm and loads effect tables from data-driven `Resource` files. It reads `PranaGrid.committed_fragments` after `combat_started` fires, resolves the combination rule set, and emits `combo_resolved(spell_effect: SpellEffect)` which SpellCastingEffects caches for the wave. This is the mechanical core of the game's Preparation Phase decision: the combination result is determined once at wave start, not mid-combat.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal-Driven Architecture | Emits `combo_resolved(SpellEffect)` — sole combination event emitter | LOW |
| ADR-0008: PranaCatalog Immutability | Reads PranaType data via `PranaCatalog.get_type(id)` — always gets a deep copy | LOW |
| ADR-0009: SC&E Wave-Scoped Stat Broker | SpellCastingEffects caches the resolved SpellEffect; CombinationResolution does not retain it after emission | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CR-001 | Autoload #8; triggered by `combat_started` — reads `PranaGrid.committed_fragments` | ADR-0002 ✅ |
| TR-CR-002 | Data-driven combination tables loaded as `Resource` files — no hardcoded rules | ADR-0008 ✅ |
| TR-CR-003 | Resolution algorithm: center slot determines spell type; neighbor slots modify or hybridize | ADR-0003 ✅ |
| TR-CR-004 | Emits `combo_resolved(spell_effect: SpellEffect)` exactly once per `combat_started` | ADR-0003 ✅ |
| TR-CR-005 | SpellEffect resource schema: primary_type, damage multiplier, element, combo_attack_count | ADR-0009 ✅ |
| TR-CR-006 | Reads PranaType colors via `PranaCatalog.get_type(id)` for SpellEffect metadata | ADR-0008 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/combination-resolution.md` are verified
- All Logic stories have passing unit tests in `tests/unit/`

## Next Step

Run `/create-stories combination-resolution` to break this epic into implementable stories.
