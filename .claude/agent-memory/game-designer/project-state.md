---
name: project-state
description: The Last Cipher — MVP single-arena roguelike; currently in GDD authoring and design review phase
metadata:
  type: project
---

**The Last Cipher** is a 2D top-down roguelike (Godot 4.6, GDScript, Compatibility renderer).

Player: Fayde, an amnesiac child android. Core mechanic: arrange Prana types on a 3x3
drag-and-drop grid during a Preparation Phase, then fight locked-loadout in Combat Phase.

**MVP scope (as of 2026-05-22):** Single arena, multiple enemy waves, boss encounter.
States: MAIN_MENU, PREPARATION_PHASE, COMBAT_PHASE, BOSS_ENCOUNTER, RUN_SUMMARY,
DEATH_SCREEN, PAUSED.

**Vertical Slice scope:** Multi-room roguelike with PATH_SELECTION, ROOM_TRANSITION,
SHOP_PHASE, REST_PHASE, CIPHERS_TRIAL.

**Game Pillars:**
1. Every Run Tells a Different Story
2. Power is Earned Through Understanding
3. Chaos Has Consequences (legible, fair, consistent)
4. Depth Over Breadth
5. Memory Returns (narrative via memory fragments)

**Current phase:** GDD authoring + design review. game-state-scene-flow.md is In Review
(Post-Design-Review Revision 2026-05-22). Systems index has unresolved scope conflicts
(BOSS_ENCOUNTER, Pause Menu #25 tagged MVP here but VS in systems-index).

**Why:** MVP needs to validate the core Prep→Combat loop rhythm before committing to
full roguelike structure.

**How to apply:** All design recommendations must be scoped to either MVP or VS. Never
conflate them. The core loop rhythm (heartbeat two-phase) is the central design bet of
the MVP — prioritize findings that threaten it.
