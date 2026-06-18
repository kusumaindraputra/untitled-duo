# Epic: CombatHUD

> **Layer**: Presentation
> **GDD**: design/gdd/combat-hud.md
> **Architecture Module**: `src/ui/combat_hud.gd` + `src/scenes/CombatHUD.tscn`
> **Status**: Complete
> **Stories**: 4 stories created 2026-06-06

## Overview

Implements the persistent feedback overlay for The Last Cipher's two-phase combat cycle. CombatHUD is a `Control` node living inside a permanent `CanvasLayer` (layer 10) on `main.tscn` — it survives scene transitions and renders during pause (`PROCESS_MODE_ALWAYS`). It is a pure signal consumer: it never polls game state and never calls other systems directly.

At First Playable scope, CombatHUD owns three responsibilities: **(1)** Fayde's HP bar with drain/fill tweens and zone-colour treatment (amber/red), **(2)** floating damage numbers colour-coded by Prana type via same-frame `spell_hit_element` correlation, and **(3)** chain dot indicators driven by `SpellCastingEffects.chain_index_changed`.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0005: Persistent HUD Sub-Scene Swap | CombatHUD lives as Control child of CanvasLayer (layer 10) on permanent main.tscn root; PROCESS_MODE_ALWAYS; survives room transitions | LOW |
| ADR-0003: Signal-Driven Architecture | Pure Pattern-1 consumer — connects to H&D/SC&E/GSM signals in `_ready()`; never reads Autoload state directly | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-CH-001 | CombatHUD is CanvasLayer (layer 10) with PROCESS_MODE_ALWAYS — survives scene transitions on permanent main.tscn root | ADR-0005 ✅ |
| TR-CH-002 | All HP and chain indicator updates via signals from H&D and SC&E — no polling of game state | ADR-0003 ✅ |
| TR-CH-003 | Floating damage numbers: get_viewport().get_canvas_transform() for world-space → viewport coordinate conversion | ADR-0003 ✅ |
| TR-CH-004 | Chain dot colors from PranaCatalog.get_type(id).color — not hardcoded hex values | ADR-0003 ✅ |
| TR-CH-005 | spell_hit_element and damage_taken signals correlated per-frame for damage number Prana-type color assignment | ADR-0003 ✅ |
| TR-CH-006 | Floating label pool cap (12 nodes); oldest-first eviction when cap reached to prevent proliferation during Cluster swarms | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/combat-hud.md` verified (unit tests pass; manual evidence files created)
- HP bar, zone colours, damage numbers, and chain dots all function during a complete FP run

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | [CombatHUD Scene Skeleton, HP Bar, and Dead State](story-001-skeleton-hp-bar.md) | UI | Ready | ADR-0005, ADR-0003 |
| 002 | [HP Zone Colors and Heal Tween](story-002-zone-colors-heal.md) | UI | Ready | ADR-0003 |
| 003 | [Floating Damage Numbers](story-003-damage-numbers.md) | Logic | Ready | ADR-0003 |
| 004 | [Chain Dots](story-004-chain-dots.md) | Visual/Feel | Ready | ADR-0003 |

## Next Step

Run `/story-readiness production/epics/combat-hud/story-001-skeleton-hp-bar.md` then `/dev-story` to begin implementation.
