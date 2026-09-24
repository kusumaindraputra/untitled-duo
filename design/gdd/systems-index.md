# Systems Index: The Last Cipher

> **Status**: Draft
> **Created**: 2026-05-20
> **Last Updated**: 2026-06-24
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

The Last Cipher is a 2D isometric (dimetric) roguelike where Fayde composes spells by arranging
Prana types in a 3×3 drag-and-drop grid. Mechanically the game is built from four bands of
systems: a **Prana/spell spine** (grid placement → combination resolution → spell cast),
a **combat layer** (player movement, health/damage, status effects, enemy AI), an
**encounter layer** (waves, wave-peek preview, obstacles, dungeon generation), and a
**run/meta layer** (run lifecycle, loot, meta-progression). The core loop is a
two-phase room cycle — Preparation (peek the wave → arrange the grid into the best
combo/tier/status setup for the enemies present) and Combat (move, dash, cast the
pre-arranged combo). *(Elemental strong/weakness was removed 2026-06-21.)* The game
pillars — *Every Run Tells a Different Story*, *Power is Earned Through Understanding*,
*Chaos Has Consequences*, *Depth Over Breadth*, *Memory Returns* — make the
system set intentionally **deep, not wide**: a small Prana catalog with rich combination
interactions, never a large shallow one.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Prana Grid | Gameplay | First Playable | Approved | design/gdd/prana-grid.md | Prana Data, Game State & Scene Flow |
| 2 | Combination Resolution | Gameplay | First Playable | Approved *(4-layer: +Prana Reactions & Cascade, 2026-06-24 — ADR-0016)* | design/gdd/combination-resolution.md | Prana Grid, Prana Data |
| 3 | Spell Casting & Effects *(simplified)* | Gameplay | First Playable | Approved *(+Perfect Cast & Special attack, 2026-09-24 — ADR-0017, design/gdd/special-attack.md)* | design/gdd/spell-casting-effects.md | Combination Resolution, Player Controller, Health & Damage |
| 4 | Prana Data | Data | First Playable | Approved | design/gdd/prana-data.md | — |
| 5 | Player Controller | Core | First Playable | Approved | design/gdd/player-controller.md | Game State & Scene Flow |
| 6 | Health & Damage | Gameplay | First Playable | Approved | design/gdd/health-damage.md | Game State & Scene Flow |
| 7 | Status Effects *(simplified)* | Gameplay | MVP | Approved | design/gdd/status-effects.md | Health & Damage |
| 8 | Enemy AI *(simplified)* | Gameplay | First Playable | Approved | design/gdd/enemy-ai.md | Enemy Data, Player Controller, Health & Damage |
| 9 | Enemy Data | Data | First Playable | Approved | design/gdd/enemy-data.md | — |
| 10 | ~~Elemental Affiliation & Weakness~~ | Gameplay | — | **REMOVED 2026-06-21** | Strong/weakness affiliation multiplier cut from scope. Damage is element-neutral. `prana_affiliation` survives only for death-burst VFX color and Prana drop typing. | — |
| 11 | Boss Encounter | Gameplay | Vertical Slice | Not Started | — | Enemy AI, Spell Casting & Effects, Health & Damage, Wave / Encounter System |
| 12 | Wave / Encounter System *(simplified)* | Gameplay | First Playable | Approved | design/gdd/wave-encounter-system.md | Enemy AI, Enemy Data, Health & Damage, Game State & Scene Flow |
| 14 | Level Generation *(room obstacles + enemy composition)* | Gameplay | First Playable | Draft | design/gdd/level-generation.md | IsometricRoom, Wave / Encounter System, Enemy AI, Enemy Data |
| 15 | Obstacle System *(full)* | Gameplay | Vertical Slice | Not Started | — | Game State & Scene Flow, Spell Casting & Effects |
| 16 | Procedural Dungeon Generation | Gameplay | Vertical Slice | Not Started | — | Game State & Scene Flow, Obstacle System, Wave / Encounter System |
| 16 | Prana Drop / Loot | Economy | Vertical Slice | Not Started | — | Prana Data, Wave / Encounter System, Procedural Dungeon Generation |
| 17 | Run Management *(simplified)* | Progression | MVP | Approved | design/gdd/run-management.md | Game State & Scene Flow, Wave / Encounter System |
| 18 | Loadout Slots | Progression | Vertical Slice | Not Started | — | Prana Grid, Combination Resolution |
| 19 | Meta-Progression | Progression | Vertical Slice | Not Started | — | Save / Load, Prana Data, Run Management |
| 20 | Difficulty Tiers | Progression | Alpha | Not Started | — | Run Management, Wave / Encounter System, Procedural Dungeon Generation |
| 21 | Lore Fragments | Narrative | Alpha | Not Started | — | Boss Encounter, Save / Load, Run Management |
| 22 | Combat HUD *(minimal)* | UI | First Playable | Approved | design/gdd/combat-hud.md | Health & Damage, Spell Casting & Effects, Combination Resolution |
| 23 | Run Summary Screen | UI | Vertical Slice | Not Started | — | Run Management, Combination Resolution |
| 24 | Main Menu | UI | MVP | Not Started | — | Game State & Scene Flow |
| 25 | Pause Menu | UI | Vertical Slice | Not Started | — | Game State & Scene Flow |
| 26 | Meta-Progression UI | UI | Vertical Slice | Not Started | — | Meta-Progression |
| 27 | Game State & Scene Flow | Core | First Playable | Approved | design/gdd/game-state-scene-flow.md | — |
| 28 | Save / Load | Persistence | Vertical Slice | Not Started | — | — |
| 29 | Audio System | Audio | Vertical Slice | Approved | design/gdd/audio-system.md | — |
| 30 | Game Feel / Juice | Gameplay | Vertical Slice | Not Started | — | Game State & Scene Flow, Audio System |
| 31 | Tutorial / Onboarding | Meta | Vertical Slice | Not Started | — | Prana Grid, Combination Resolution, Spell Casting & Effects, Wave / Encounter System, Run Management |

> **Simplified scope notes**:
> - **Spell Casting & Effects** (FP): hanya deal damage + efek visual minimal; status effects, VFX penuh, dan juice menyusul di MVP/VS
> - **Enemy AI** (FP): move toward player + attack in range saja; pola kompleks dan ability menyusul di MVP
> - **Wave / Encounter System** (FP): 1 arena hardcoded, 1–3 wave, 3–5 musuh per wave; tidak ada procedural, tidak ada loot
> - **Status Effects** (MVP): 1–2 efek saja (misal: Freeze, Burn); tidak perlu full status matrix
> - **Run Management** (MVP): mati = restart saja; tidak ada loot tracking, tidak ada meta-currency
> - **Combat HUD** (FP): HP bar + Prana grid visible; tidak ada status effect icon, tidak ada wave counter lengkap

---

## Categories

| Category | Description | Systems in The Last Cipher |
|----------|-------------|---------------------|
| **Core** | Foundation systems everything depends on | Game State & Scene Flow, Player Controller |
| **Gameplay** | The systems that make the game fun | Prana Grid, Combination Resolution, Spell Casting & Effects, Health & Damage, Status Effects, Enemy AI, Boss Encounter, Wave / Encounter System, Obstacle System, Procedural Dungeon Generation, Game Feel / Juice *(Elemental Affiliation & Weakness removed 2026-06-21)* |
| **Data** | Pure data definitions consumed by gameplay systems | Prana Data, Enemy Data |
| **Economy** | Resource creation and consumption | Prana Drop / Loot |
| **Progression** | How the player grows over time | Run Management, Loadout Slots, Meta-Progression, Difficulty Tiers |
| **Persistence** | Save state and continuity | Save / Load |
| **UI** | Player-facing information displays | Combat HUD, Run Summary Screen, Main Menu, Pause Menu, Meta-Progression UI |
| **Audio** | Sound and music systems | Audio System |
| **Narrative** | Story and lore delivery | Lore Fragments |
| **Meta** | Systems outside the core game loop | Tutorial / Onboarding |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Systems | Design Urgency |
|------|------------|------------------|---------|----------------|
| **First Playable** | Minimum to test the core hypothesis in a single hardcoded arena: is the two-phase Preparation + Combat loop fun? Does combination/positioning create meaningful decisions? | First internal playtest | 11 | Design NOW |
| **MVP** | Shippable to players (itch.io / Steam demo): adds run lifecycle, main menu, and basic status effects above First Playable | Public demo / itch.io | 3 | Design AFTER FP |
| **Vertical Slice** | One complete polished area — boss, dungeon generation, audio, juice, loot, meta-progression | Demo / press build | 10 | Design THIRD |
| **Alpha** | All mechanical scope present in rough form — difficulty tiers, narrative | Alpha milestone | 2 | Design as reached |
| **Full Vision** | Polish and content scale-up (5 layers, 20+ Prana types, full lore) | Beta / Release | — | Design as needed |

---

## Dependency Map

Systems sorted by dependency order — design and build from top to bottom.

### Foundation Layer (no dependencies)

1. Prana Data — defines the Prana catalog and Prana properties; the raw material of the entire Prana/spell spine
2. Enemy Data — defines enemy types and their elemental-affiliation options
3. Game State & Scene Flow — the scene/state framework every other system plugs into
4. Save / Load — serialization framework; no runtime dependencies
5. Audio System — audio bus / manager framework

### Core Layer (depends on Foundation)

1. Prana Grid — depends on: Prana Data, Game State & Scene Flow
2. Player Controller — depends on: Game State & Scene Flow
3. Health & Damage — depends on: Game State & Scene Flow
4. Combination Resolution — depends on: Prana Grid, Prana Data
5. Status Effects — depends on: Health & Damage
6. Enemy AI — depends on: Enemy Data, Player Controller, Health & Damage
7. Spell Casting & Effects — depends on: Combination Resolution, Player Controller, Health & Damage, Status Effects

### Feature Layer (depends on Core)

1. Wave / Encounter System — depends on: Enemy AI, Enemy Data, Health & Damage, Game State & Scene Flow
2. ~~Elemental Affiliation & Weakness~~ — **REMOVED 2026-06-21** (strong/weakness cut from scope)
3. Obstacle System — depends on: Game State & Scene Flow, Spell Casting & Effects
4. Boss Encounter — depends on: Enemy AI, Spell Casting & Effects, Health & Damage, Wave / Encounter System
5. Procedural Dungeon Generation — depends on: Game State & Scene Flow, Obstacle System, Wave / Encounter System
7. Prana Drop / Loot — depends on: Prana Data, Wave / Encounter System, Procedural Dungeon Generation
8. Run Management — depends on: Game State & Scene Flow, Wave / Encounter System
9. Loadout Slots — depends on: Prana Grid, Combination Resolution
10. Meta-Progression — depends on: Save / Load, Prana Data, Run Management
11. Difficulty Tiers — depends on: Run Management, Wave / Encounter System, Procedural Dungeon Generation
12. Lore Fragments — depends on: Boss Encounter, Save / Load, Run Management

### Presentation Layer (depends on Features)

1. Game Feel / Juice — depends on: Game State & Scene Flow, Audio System
2. Combat HUD — depends on: Health & Damage, Status Effects, Spell Casting & Effects, Combination Resolution
3. Run Summary Screen — depends on: Run Management, Combination Resolution
4. Main Menu — depends on: Game State & Scene Flow
5. Pause Menu — depends on: Game State & Scene Flow
6. Meta-Progression UI — depends on: Meta-Progression

### Polish Layer (depends on everything)

1. Tutorial / Onboarding — depends on: Prana Grid, Combination Resolution, Spell Casting & Effects, Wave / Encounter System, Run Management

**Bottleneck systems** (high dependent count — design with extra care): Game State &
Scene Flow, Prana Data, Health & Damage, Prana Grid, Spell Casting & Effects, Wave /
Encounter System, Run Management.

---

## Recommended Design Order

### Phase 1 — First Playable (design NOW)

| Order | System | Simplified Scope | Layer | Est. Effort |
|-------|--------|-----------------|-------|-------------|
| 1 | Game State & Scene Flow | ✓ Approved | Foundation | done |
| 2 | Prana Data | ✓ Near-approved | Foundation | done |
| 3 | Enemy Data | ✓ Approved | Foundation | done |
| 4 | Health & Damage | ✓ Approved | Core | done |
| 5 | Player Controller | Full spec | Core | M |
| 6 | Prana Grid | Full spec | Core | L |
| 7 | Combination Resolution | Full spec | Core | L |
| 8 | Spell Casting & Effects | Damage only, no juice | Core | M |
| 9 | Enemy AI | Move + attack only | Core | M |
| 10 | ~~Elemental Affiliation & Weakness~~ | **REMOVED 2026-06-21** | — | — |
| 11 | Wave / Encounter System | 1 arena, 1–3 waves | Feature | S |
| 12 | Combat HUD | HP bar + grid only | Presentation | S |

**First Playable total remaining**: 4 Approved + 4×M + 2×L + 3×S ≈ **12–16 design sessions**

### Phase 2 — MVP (after First Playable validated)

| Order | System | Simplified Scope | Layer | Est. Effort |
|-------|--------|-----------------|-------|-------------|
| 13 | Status Effects | 1–2 effects (Freeze, Burn) | Core | S |
| 14 | Run Management | Die = restart only | Feature | S |
| 15 | Main Menu | Press Start only | Presentation | S |

**MVP total above FP**: 3×S ≈ **3–4 design sessions**

### Phase 3 — Vertical Slice (after MVP shipped)

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 16 | Audio System | Vertical Slice | Foundation | S |
| 17 | Obstacle System | Vertical Slice | Feature | M |
| 19 | Prana Drop / Loot | Vertical Slice | Economy | M |
| 20 | Boss Encounter | Vertical Slice | Feature | L |
| 21 | Procedural Dungeon Generation | Vertical Slice | Feature | L |
| 22 | Save / Load | Vertical Slice | Foundation | S |
| 23 | Loadout Slots | Vertical Slice | Feature | M |
| 24 | Meta-Progression | Vertical Slice | Feature | M |
| 25 | Game Feel / Juice | Vertical Slice | Presentation | M |
| 26 | Run Summary Screen | Vertical Slice | Presentation | S |
| 27 | Pause Menu | Vertical Slice | Presentation | S |
| 28 | Meta-Progression UI | Vertical Slice | Presentation | M |
| 29 | Tutorial / Onboarding | Vertical Slice | Polish | M |

### Phase 4 — Alpha

| Order | System | Priority | Layer | Est. Effort |
|-------|--------|----------|-------|-------------|
| 30 | Difficulty Tiers | Alpha | Feature | M |
| 31 | Lore Fragments | Alpha | Feature | M |

---

## Circular Dependencies

No **hard** circular dependencies found.

- ~~**Spell Casting & Effects ↔ Elemental Affiliation & Weakness**~~ — **N/A as of 2026-06-21**:
  Elemental Affiliation & Weakness was removed from scope, so this soft coupling no
  longer exists. SC&E delivers element-neutral damage.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Combination Resolution | Design | Exponential combination space — the concept calls this "the single decision that shapes the entire design" | Already prototyped (REPORT.md verdict PROCEED — center-slot + position-based combos); keep balance under constant playtest + `/balance-check` |
| Prana Grid | Design / UX | Drag-and-drop is mouse-optimized; gamepad needs a fully different Prana-selection UX (flagged in technical-preferences.md) | GDD must specify a gamepad interaction model; pair with a `/ux-design` spec before implementation |
| Procedural Dungeon Generation | Technical | Procedural rooms that feel hand-authored is a known-hard problem | Room-template approach; deferred to Vertical Slice tier to keep it out of MVP risk |
| Isometric rendering setup | Technical | TileMapLayer isometric di Godot 4.6 belum diverifikasi; Y-sort edge cases pada sprite besar | ADR-0001 Accepted; wajib verifikasi dengan test project sebelum implementasi room pertama (lihat ADR-0001 Validation Criteria) |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 30 (Elemental Affiliation & Weakness removed 2026-06-21) |
| First Playable systems | 11 (was 12; EA&W cut) |
| MVP systems (above FP) | 3 |
| Vertical Slice systems | 14 |
| Alpha systems | 2 |
| Design docs approved | 11 (Prana Grid, Combination Resolution, Spell Casting & Effects, Prana Data, Player Controller, Health & Damage, Status Effects, Enemy Data, Run Management, Game State & Scene Flow, Audio System) |
| First Playable systems designed | 11 / 11 — all First Playable systems designed |
| MVP systems designed | 2 / 3 (Status Effects, Run Management designed; Main Menu not started) |

---

## Next Steps

- [ ] Close pending GDD reviews: Audio System (round 3), Prana Data (fresh session) — Sprint 1 tasks S1-01, S1-02
- [ ] Design Player Controller GDD — Sprint 1 task S1-03
- [ ] Design Prana Grid GDD — Sprint 1 task S1-04
- [ ] Design Combination Resolution GDD — Sprint 1 task S1-05
- [ ] Then: Spell Casting & Effects (simplified), Enemy AI (simplified), Wave/Encounter (simplified), Combat HUD (minimal)
- [ ] Verify isometric TileMapLayer in Godot 4.6 with a test project (ADR-0001 prerequisite)
- [ ] Run `/gate-check pre-production` when all First Playable GDDs are approved
- [ ] First internal playtest after First Playable implementation complete
