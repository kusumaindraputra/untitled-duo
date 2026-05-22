# Systems Index: The Last Cipher

> **Status**: Draft
> **Created**: 2026-05-20
> **Last Updated**: 2026-05-20
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

The Last Cipher is a 2D top-down roguelike where Fayde composes spells by arranging
Prana types in a 3×3 drag-and-drop grid. Mechanically the game is built from four bands of
systems: a **Prana/spell spine** (grid placement → combination resolution → spell cast),
a **combat layer** (player movement, health/damage, status effects, enemy AI), an
**encounter layer** (waves, wave-peek preview, obstacles, dungeon generation), and a
**run/meta layer** (run lifecycle, loot, meta-progression). The core loop is a
two-phase room cycle — Preparation (peek the wave → arrange the grid to exploit enemy
elemental affiliation) and Combat (move, dash, cast the pre-arranged combo). The game
pillars — *Every Run Tells a Different Story*, *Power is Earned Through Understanding*,
*Chaos Has Consequences*, *Depth Over Breadth*, *Memory Returns* — make the
system set intentionally **deep, not wide**: a small Prana catalog with rich combination
interactions, never a large shallow one.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Prana Grid | Gameplay | MVP | Not Started | — | Prana Data, Game State & Scene Flow |
| 2 | Combination Resolution | Gameplay | MVP | Not Started | — | Prana Grid, Prana Data |
| 3 | Spell Casting & Effects | Gameplay | MVP | Not Started | — | Combination Resolution, Player Controller, Health & Damage, Status Effects |
| 4 | Prana Data | Data | MVP | Not Started | — | — |
| 5 | Player Controller *(inferred)* | Core | MVP | Not Started | — | Game State & Scene Flow |
| 6 | Health & Damage *(inferred)* | Gameplay | MVP | Not Started | — | Game State & Scene Flow |
| 7 | Status Effects | Gameplay | MVP | Not Started | — | Health & Damage |
| 8 | Enemy AI *(inferred)* | Gameplay | MVP | Not Started | — | Enemy Data, Player Controller, Health & Damage |
| 9 | Enemy Data *(inferred)* | Data | MVP | Not Started | — | — |
| 10 | Elemental Affiliation & Weakness | Gameplay | MVP | Not Started | — | Enemy Data, Prana Data, Spell Casting & Effects, Health & Damage |
| 11 | Boss Encounter | Gameplay | Vertical Slice | Not Started | — | Enemy AI, Spell Casting & Effects, Health & Damage, Wave / Encounter System |
| 12 | Wave / Encounter System *(inferred)* | Gameplay | MVP | Not Started | — | Enemy AI, Enemy Data, Health & Damage, Game State & Scene Flow |
| 13 | Wave Peek | Gameplay | MVP | Not Started | — | Wave / Encounter System, Enemy Data, Elemental Affiliation & Weakness, Obstacle System |
| 14 | Obstacle System | Gameplay | MVP | Not Started | — | Game State & Scene Flow, Spell Casting & Effects |
| 15 | Procedural Dungeon Generation | Gameplay | Vertical Slice | Not Started | — | Game State & Scene Flow, Obstacle System, Wave / Encounter System |
| 16 | Prana Drop / Loot | Economy | MVP | Not Started | — | Prana Data, Wave / Encounter System, Procedural Dungeon Generation |
| 17 | Run Management *(inferred)* | Progression | MVP | Not Started | — | Game State & Scene Flow, Wave / Encounter System, Boss Encounter, Procedural Dungeon Generation, Prana Drop / Loot |
| 18 | Loadout Slots | Progression | Vertical Slice | Not Started | — | Prana Grid, Combination Resolution |
| 19 | Meta-Progression | Progression | Vertical Slice | Not Started | — | Save / Load, Prana Data, Run Management |
| 20 | Difficulty Tiers | Progression | Alpha | Not Started | — | Run Management, Wave / Encounter System, Procedural Dungeon Generation |
| 21 | Lore Fragments | Narrative | Alpha | Not Started | — | Boss Encounter, Save / Load, Run Management |
| 22 | Combat HUD *(inferred)* | UI | MVP | Not Started | — | Health & Damage, Status Effects, Spell Casting & Effects, Combination Resolution |
| 23 | Run Summary Screen | UI | MVP | Not Started | — | Run Management, Combination Resolution |
| 24 | Main Menu *(inferred)* | UI | MVP | Not Started | — | Game State & Scene Flow |
| 25 | Pause Menu *(inferred)* | UI | Vertical Slice | Not Started | — | Game State & Scene Flow |
| 26 | Meta-Progression UI *(inferred)* | UI | Vertical Slice | Not Started | — | Meta-Progression |
| 27 | Game State & Scene Flow *(inferred)* | Core | MVP | Approved | design/gdd/game-state-scene-flow.md | — |
| 28 | Save / Load *(inferred)* | Persistence | Vertical Slice | Not Started | — | — |
| 29 | Audio System | Audio | MVP | Not Started | — | — |
| 30 | Game Feel / Juice | Gameplay | MVP | Not Started | — | Game State & Scene Flow, Audio System |
| 31 | Tutorial / Onboarding | Meta | Vertical Slice | Not Started | — | Prana Grid, Combination Resolution, Spell Casting & Effects, Wave / Encounter System, Wave Peek, Run Management |

> **MVP reduced-scope note**: #16 Prana Drop / Loot and #17 Run Management remain MVP,
> but their MVP versions are simplified because two of their dependencies were deferred
> to Vertical Slice. MVP Prana Drop has no per-floor-theme drop tables (no #15). MVP Run
> Management has no boss as the floor-end marker (no #11) — an MVP run is a sequence of
> waves in a single arena ending in win (all waves cleared) or death. The full
> dependencies are listed above for when those systems are designed at VS scope.

---

## Categories

| Category | Description | Systems in The Last Cipher |
|----------|-------------|---------------------|
| **Core** | Foundation systems everything depends on | Game State & Scene Flow, Player Controller |
| **Gameplay** | The systems that make the game fun | Prana Grid, Combination Resolution, Spell Casting & Effects, Health & Damage, Status Effects, Enemy AI, Elemental Affiliation & Weakness, Boss Encounter, Wave / Encounter System, Wave Peek, Obstacle System, Procedural Dungeon Generation, Game Feel / Juice |
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

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required to test the core hypothesis: the two-phase loop is fun and elemental affiliation drives meaningful decisions. 21 systems. | First playable | Design FIRST |
| **Vertical Slice** | One complete, polished area — boss, dungeon generation, loadouts, meta-progression. 8 systems. | Vertical slice / demo | Design SECOND |
| **Alpha** | All mechanical scope present in rough form — difficulty tiers, narrative. 2 systems. | Alpha milestone | Design THIRD |
| **Full Vision** | Polish and content scale-up (5 layers, 20+ Prana types, full lore). No new systems. | Beta / Release | Design as needed |

---

## Dependency Map

Systems sorted by dependency order — design and build from top to bottom.

### Foundation Layer (no dependencies)

1. Prana Data — defines the Prana catalog and Prana properties; the raw material of the entire Prana/spell spine
2. Enemy Data — defines enemy types and their elemental-affiliation options
3. Game State & Scene Flow — the scene/state framework (incl. top-down camera) every other system plugs into
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
2. Elemental Affiliation & Weakness — depends on: Enemy Data, Prana Data, Spell Casting & Effects, Health & Damage
3. Obstacle System — depends on: Game State & Scene Flow, Spell Casting & Effects
4. Boss Encounter — depends on: Enemy AI, Spell Casting & Effects, Health & Damage, Wave / Encounter System
5. Wave Peek — depends on: Wave / Encounter System, Enemy Data, Elemental Affiliation & Weakness, Obstacle System
6. Procedural Dungeon Generation — depends on: Game State & Scene Flow, Obstacle System, Wave / Encounter System
7. Prana Drop / Loot — depends on: Prana Data, Wave / Encounter System, Procedural Dungeon Generation
8. Run Management — depends on: Game State & Scene Flow, Wave / Encounter System, Boss Encounter, Procedural Dungeon Generation, Prana Drop / Loot
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

1. Tutorial / Onboarding — depends on: Prana Grid, Combination Resolution, Spell Casting & Effects, Wave / Encounter System, Wave Peek, Run Management

**Bottleneck systems** (high dependent count — design with extra care): Game State &
Scene Flow, Prana Data, Health & Damage, Prana Grid, Spell Casting & Effects, Wave /
Encounter System, Run Management.

---

## Recommended Design Order

Combining dependency sort and priority tiers. Effort: **S** = 1 session, **M** = 2-3
sessions, **L** = 4+ sessions (one session = one focused design conversation producing
a complete GDD).

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Game State & Scene Flow | MVP | Foundation | game-designer | S |
| 2 | Prana Data | MVP | Foundation | systems-designer | M |
| 3 | Enemy Data | MVP | Foundation | systems-designer | S |
| 4 | Audio System | MVP | Foundation | audio-director | S |
| 5 | Health & Damage | MVP | Core | systems-designer | M |
| 6 | Player Controller | MVP | Core | game-designer | M |
| 7 | Prana Grid | MVP | Core | game-designer + ux-designer | L |
| 8 | Combination Resolution | MVP | Core | systems-designer | L |
| 9 | Status Effects | MVP | Core | systems-designer | M |
| 10 | Spell Casting & Effects | MVP | Core | game-designer | L |
| 11 | Enemy AI | MVP | Core | game-designer | M |
| 12 | Wave / Encounter System | MVP | Feature | game-designer | M |
| 13 | Elemental Affiliation & Weakness | MVP | Feature | systems-designer | M |
| 14 | Obstacle System | MVP | Feature | game-designer | M |
| 15 | Wave Peek | MVP | Feature | game-designer + ux-designer | M |
| 16 | Prana Drop / Loot | MVP | Feature | economy-designer | M |
| 17 | Run Management | MVP | Feature | game-designer | M |
| 18 | Game Feel / Juice | MVP | Presentation | game-designer | M |
| 19 | Combat HUD | MVP | Presentation | ux-designer | M |
| 20 | Run Summary Screen | MVP | Presentation | ux-designer | S |
| 21 | Main Menu | MVP | Presentation | ux-designer | S |
| 22 | Boss Encounter | Vertical Slice | Feature | game-designer | L |
| 23 | Procedural Dungeon Generation | Vertical Slice | Feature | level-designer | L |
| 24 | Save / Load | Vertical Slice | Foundation | game-designer | S |
| 25 | Loadout Slots | Vertical Slice | Feature | game-designer | M |
| 26 | Meta-Progression | Vertical Slice | Feature | economy-designer | M |
| 27 | Pause Menu | Vertical Slice | Presentation | ux-designer | S |
| 28 | Meta-Progression UI | Vertical Slice | Presentation | ux-designer | M |
| 29 | Tutorial / Onboarding | Vertical Slice | Polish | game-designer + ux-designer | M |
| 30 | Difficulty Tiers | Alpha | Feature | systems-designer | M |
| 31 | Lore Fragments | Alpha | Feature | narrative-director | M |

Total MVP effort estimate: 3 × S + 11 × M + 3 × L (≈ 30-40 design sessions across 21
GDDs). Independent systems at the same layer may be designed in parallel.

---

## Circular Dependencies

No **hard** circular dependencies found.

- **Spell Casting & Effects ↔ Elemental Affiliation & Weakness** — *soft coupling*.
  Spell Casting needs the elemental-bonus result when a spell hits an enemy; Elemental
  Affiliation needs the hit event from Spell Casting. **Resolution**: a signal contract
  — Spell Casting emits an element-tagged `hit` signal; Elemental Affiliation listens
  and applies the bonus. Neither system imports the other directly. This must be stated
  explicitly in both GDDs' Dependencies sections.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Combination Resolution | Design | Exponential combination space — the concept calls this "the single decision that shapes the entire design" | Already prototyped (REPORT.md verdict PROCEED — center-slot + position-based combos); keep balance under constant playtest + `/balance-check` |
| Prana Grid | Design / UX | Drag-and-drop is mouse-optimized; gamepad needs a fully different Prana-selection UX (flagged in technical-preferences.md) | GDD must specify a gamepad interaction model; pair with a `/ux-design` spec before implementation |
| Procedural Dungeon Generation | Technical | Procedural rooms that feel hand-authored is a known-hard problem | Room-template approach; deferred to Vertical Slice tier to keep it out of MVP risk |
| Combination Resolution / overall balance | Scope | Exponential states mean some combos will be degenerate or broken | Early and constant playtesting; run `/balance-check` after each Prana type is added |
| Spell Casting ↔ Elemental Affiliation | Design | Soft coupling — each needs the other | Signal contract (see Circular Dependencies) |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 31 |
| Design docs started | 1 |
| Design docs reviewed | 1 |
| Design docs approved | 1 |
| MVP systems designed | 1 / 21 |
| Vertical Slice systems designed | 0 / 8 |

---

## Next Steps

- [ ] Design MVP-tier systems in design order, starting with Game State & Scene Flow (use `/design-system [system-name]` or `/map-systems next`)
- [ ] Run `/design-review design/gdd/[system].md` on each completed GDD
- [ ] Art bible (`design/art/art-bible.md`) — complete remaining sections (6–9) before the first Prana-facing GDD; establishes the Prana-to-color mapping
- [ ] Run `/gate-check pre-production` when all MVP-tier GDDs are designed and reviewed
- [ ] Validate the highest-risk systems with `/vertical-slice` before committing to Production
