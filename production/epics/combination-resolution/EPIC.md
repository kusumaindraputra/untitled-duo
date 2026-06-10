# Epic: Combination Resolution

> **Layer**: Core
> **GDD**: design/gdd/combination-resolution.md
> **Architecture Module**: `src/systems/combination_resolution.gd` (Autoload #8)
> **Status**: Ready
> **Stories**: 6 stories created 2026-06-10

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

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [PranaFragment Data Model + SpellEffect Extensions](story-001-data-model-spell-effect-extensions.md) | Logic | Ready | ADR-0008 |
| 002 | [Primary Count and Tier Resolution](story-002-primary-resolution.md) | Logic | Ready | ADR-0003 |
| 003 | [Non-Primary Modifier Resolution](story-003-nonprimary-resolution.md) | Logic | Ready | ADR-0003 |
| 004 | [SpellEffect Payload Assembly](story-004-payload-assembly.md) | Logic | Ready | ADR-0008, ADR-0009 |
| 005 | [Adjacency Effect Resolution](story-005-adjacency-resolution.md) | Logic | Ready | ADR-0003 |
| 006 | [Signal Contract, Cache Lifecycle, Edge Cases](story-006-signal-contract-cache.md) | Integration | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/combination-resolution/story-001-data-model-spell-effect-extensions.md` then `/dev-story` to begin implementation. Work through stories in order — each story's `Depends on:` field tells you what must be DONE before you can start it.

---

## S3-16 QA Test Specs (pre-story; verify against story ACs after /create-stories)

> **Test file**: `tests/unit/combination-resolution/combination_resolution_test.gd`
> **Estimated count**: ~20–25 unit tests

**TR-CR-001 — Autoload trigger:**
- `combat_started.emit(false)` → `combo_resolved(spell_effect)` emitted exactly once

**TR-CR-002 — Data-driven (no hardcoded rules):**
- Two different arrangements produce different results via table lookup, not if/match on PranaType IDs

**TR-CR-003 — Center slot primary type:**
- `committed_fragments[4]` = Ashfire (0) → `spell_effect.primary_type == 0`
- Center = Ashfire + 2 Stormgold neighbors → `spell_effect.element` or multiplier reflects neighbor modifier per table

**TR-CR-004 — Emits exactly once:**
- `combat_started` fires once → `combo_resolved` call count == 1, even if signal fires twice

**TR-CR-005 — SpellEffect schema:**
- `primary_type` set; `damage_multiplier > 0`; `element` set; `combo_attack_count >= 1`

**TR-CR-006 — PranaType color from PranaCatalog:**
- Center slot type = 2 → `spell_effect` color == `PranaCatalog.get_type(2).color` (not a hardcoded Color value)

**Edge cases:**
- Empty grid (all 9 slots null): does not crash; returns a valid fallback SpellEffect
- All same type (9 Ashfire): valid SpellEffect, Ashfire primary type
- Sparse array / invalid index: no index-out-of-bounds
