# Concept Prototype Report: Prana Grid

> **Date**: 2026-05-20
> **Prototype Path**: Engine (Godot 4.6, GDScript)
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player arranges Prana types in a drag-and-drop grid and casts spells in real-time
combat, the act of deciding which combination to use + executing the cast will feel
like a meaningful, satisfying decision — evidenced by players spontaneously
rearranging the grid rather than mashing cast blindly.

---

## Riskiest Assumption Tested

**Does the drag-and-drop grid feel like a game mechanic (strategic decision) or like
an inventory screen (menu task)?**

Result: The mechanic works as a game mechanic. Players immediately began thinking
in terms of combinations rather than just casting whatever was available. The "gotcha"
moment of discovering a powerful combination emerged organically without prompting.

---

## Approach

A minimal arena prototype: static player, enemies walking toward center, 3×3 drag-and-drop
Prana grid. 5 Prana types, 5 combos. Center slot determines spell type; neighbor slots
amplify or create hybrid effects. Visual highlight shows which slots contribute to the
active combo.

**Path chosen:** Engine (Godot 4.6)
**Reason for path:** Feel IS the hypothesis — browser latency would give false results
for an action game. Native rendering needed for accurate input response assessment.

**Shortcuts taken (intentional):**
- Static player (no movement) — isolates the grid mechanic from movement complexity
- Colored rectangles for all entities — no art assets
- Hardcoded combo table — no data-driven config
- No menus, audio, save, meta-progression
- All logic in a single file with inner classes

**Iterations to playable:** 3 rounds (type inference error → drag mouse_filter fix →
combo position-awareness rewrite)

---

## Result

Core mechanic validated. Player immediately explored combinations rather than
repeating the same cast. The "gotcha" moment of discovering an effective combo
was identified as the primary emotional peak.

**Critical design insight revealed by the prototype:**

The player's mental model differs from what was prototyped. The intended design is:

> *"Prana arrangement is a strategic setup phase BEFORE the wave begins, not during combat."*

- **Pre-wave**: Player peeks at incoming wave composition → arranges Prana types based on
  enemy weaknesses → locks in loadout
- **Combat phase**: Execute the pre-planned combo with movement, dash, and positioning

This is closer to Slay the Spire's between-fight deck building than to a real-time
action game with mid-combat UI management.

**Additional emergent mechanics identified during debrief:**

1. **Wave peek** — player sees what's coming before committing to a Prana arrangement.
   Creates meaningful information asymmetry: do I know enough to commit?

2. **Obstacle interaction** — some Prana types pierce obstacles (player advantage vs. wave),
   some don't (wave advantage vs. player). Obstacles become spatial puzzle elements,
   not just cover. This creates organic pros/cons without a separate "terrain type" system.

3. **Multiple loadout slots** — pre-load 2+ Prana configurations to switch between
   during a wave. Creates a layered preparation meta: "what's my fallback if my primary
   combo gets countered?"

4. **9-slot combination space** — the 3×3 grid creates far more combination possibilities
   than the developer expected. Quoted: *"9 box Prana, bisa banyak sekali kemungkinan
   kombinasi Prana yang bisa digunakan — in a good way."*

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | Engine (Godot 4.6) |
| Iterations to playable | 3 |
| Prototype duration | ~2 hours |
| Playtesters | 1 internal (developer) |
| Feel assessment | Responsive; combo discovery felt satisfying and surprising |
| Hypothesis verdict | CONFIRMED |

---

## Recommendation: PROCEED

The core Prana-combination mechanic produces the target emotional response: players
think in terms of combinations, feel satisfaction at discovery, and immediately
imagine extensions (movement, obstacles, loadouts). No worst moment was identified.
The prototype revealed an important design correction (pre-wave setup vs. mid-combat
arrangement) that strengthens rather than undermines the concept.

---

## If Proceeding

**Core tuning values discovered:**
- 9 slots (3×3) is the right grid size — large enough for combination depth, small
  enough to scan at a glance
- Center-slot-as-spell-type is intuitive; players oriented to it without instruction
- 5 Prana types is sufficient for meaningful choice without overwhelming a first playthrough

**Assumptions confirmed:**
- Combination discovery creates "gotcha" moments of genuine excitement
- Position-based combos (center + neighbors) make arrangement feel purposeful
- Visual highlighting of active combo slots dramatically improves readability

**Assumptions disproved:**
- *"Prana arrangement works during active combat pressure"* — the player's preferred
  model is pre-wave strategic setup, not mid-combat juggling. This is a meaningful
  design shift: the grid is a planning tool, not a reaction tool.

**Emergent mechanics worth formalizing in GDDs:**
1. Wave peek system (preview wave composition before committing to loadout)
2. Prana-obstacle interaction matrix (which Prana types pierce/blocked by which obstacles)
3. Multiple loadout slots (2+ pre-configured grids switchable during combat)
4. Enemy elemental weaknesses (reasons to choose specific combos over others)

**Design update needed in game-concept.md:**
- Clarify the combat loop into two distinct phases: Preparation Phase + Combat Phase
- Add wave-peek as a core mechanic (not just a tuning knob)
- Add Prana-obstacle interaction as a system (not a stretch goal)

**Next steps:**
1. Update `design/gdd/game-concept.md` to reflect the pre-wave setup model
2. `/gate-check` — validate readiness to advance to Systems Design
3. `/art-bible` — visual identity before writing GDDs
4. `/map-systems` — decompose into individual systems, using prototype learnings
5. `/design-system prana-grid` — use prototype Tuning Knobs findings in the GDD
6. `/design-system wave-system` — formalize wave-peek and enemy weakness systems
7. `/design-system obstacle-system` — formalize Prana-obstacle interaction matrix

---

## Lessons Learned

- **What assumptions were broken by actually building this?**
  The original concept assumed Prana arrangement was a mid-combat action. The developer's
  natural expectation was pre-wave strategic setup. These are different games. The
  pre-wave model is stronger: it creates meaningful decisions with complete information,
  not frantic UI management under pressure.

- **What surprised us that didn't show up in the brainstorm?**
  (1) The obstacle-Prana interaction emerged as a mechanic idea during play — not from
  the design session. (2) Multiple loadout slots surfaced as a natural desire once the
  core was working. (3) The 9-slot grid's combination depth surprised the developer
  positively — the emergent variety was greater than anticipated.

- **What would we test differently next time?**
  Next prototype (if needed) should test the **pre-wave setup flow**: show a wave preview
  screen, let player arrange Prana types, then start combat. Tests whether the preparation
  fantasy (knowing your enemy, planning your loadout) feels as good as the discovery
  fantasy did here.

---

> *Prototype code location: `prototypes/rune-grid-concept/`*
> *This code is throwaway. Never refactor into production.*
