# Epic: Prana Grid

> **Layer**: Core
> **GDD**: design/gdd/prana-grid.md
> **Architecture Module**: `src/ui/prana_grid.gd` (CanvasLayer 1 inside IsometricRoom.tscn)
> **Status**: Ready
> **Stories**: 4 stories created

## Overview

Implements the 9-slot drag-and-drop Prana arrangement grid that is central to the game's Preparation Phase loop. PranaGrid owns the 9-slot arrangement array, grid state (ARRANGEMENT / LOCKED / HIDDEN), and the `committed_fragments` payload passed to CombinationResolution on combat start. It supports two input modes per ADR-0013: mouse drag-and-drop (primary) and gamepad d-pad navigation with `_selected_slot_index` + `_gamepad_cursor` overlay. The grid lives in IsometricRoom.tscn as a CanvasLayer child (layer 1) and resets state on each room load. It emits `arrangement_confirmed` when the player confirms a valid loadout.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Signal-Driven Architecture | Emits `arrangement_confirmed`; listens to GSM `preparation_started` / `grid_locked` / `grid_hidden` | LOW |
| ADR-0005: Persistent HUD Sub-Scene Swap | Lives inside IsometricRoom as CanvasLayer 1 — resets on room load (not persistent) | LOW |
| ADR-0013: PranaGrid Dual-Input Focus Model | `_selected_slot_index` + `_gamepad_cursor` overlay for gamepad; mouse drag-and-drop for KB/M; input mode detection via `_input()` | HIGH — dual-focus Godot 4.6 unverified |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-PG-001 | 9-slot grid; mouse drag-and-drop primary input; `_selected_slot_index` + gamepad cursor overlay for gamepad | ADR-0013 ✅ |
| TR-PG-002 | Grid states: ARRANGEMENT (editable), LOCKED (display-only on combat_started), HIDDEN | ADR-0003 ✅ |
| TR-PG-003 | `committed_fragments` getter returns arrangement snapshot to CombinationResolution | ADR-0009 ✅ |
| TR-PG-004 | `is_loadout_valid() -> bool` — center slot non-null check; queried by GameStateManager | ADR-0003 ✅ |
| TR-PG-005 | `arrangement_confirmed` signal — emitted on player confirm; triggers state machine | ADR-0003 ✅ |
| TR-PG-006 | Slot nodes: `mouse_filter = MOUSE_FILTER_STOP`, `focus_mode = FOCUS_ALL`; keyboard Tab/arrow via engine focus | ADR-0013 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/prana-grid.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Visual/Feel stories (drag-and-drop feel, gamepad cursor) have evidence docs in `production/qa/evidence/`
- ⚠️ HIGH ENGINE RISK: dual-input focus must be manually validated on mouse + gamepad paths independently before story is marked Done

## Stories

| # | Story | Type | Status | Sprint ID | ADR |
|---|-------|------|--------|-----------|-----|
| 001 | [Phase Gating (ARRANGEMENT / LOCKED / HIDDEN)](story-001-phase-gating.md) | Logic | Ready | S4-03 | ADR-0013, ADR-0003 |
| 002 | [Mouse Drag-and-Drop Input + Confirm Validation](story-002-mouse-input-confirm.md) | UI (Logic secondary) | Ready | S4-04 | ADR-0013, ADR-0003 |
| 003 | [committed_fragments → CR + SCE Integration](story-003-cr-sce-integration.md) | Integration | Ready | S4-05 | ADR-0003, ADR-0009 |
| 004 | [Gamepad Input (ADR-0013 HIGH Risk Path)](story-004-gamepad-input.md) | UI | Ready | S4-07 | ADR-0013 |
