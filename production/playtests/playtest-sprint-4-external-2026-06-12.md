# Sprint 4 External Playtest — Fun Hypothesis Validation
**Date**: 2026-06-12
**Sprint**: Sprint 4 — Fun Hypothesis Validation
**Tester**: SAK (non-developer, unfamiliar with game)
**Build**: main @ 9ba7c34 — Sprint 4 Must Have complete, PranaGrid + CR + SCE wired
**Observer**: Kusuma Putra
**Story**: S4-06

---

## Fun Hypothesis Verdict: PARTIALLY CONFIRMED

> **Decision gate**: Identify failing elements and address via scope adjustment before Sprint 5.
> Do NOT halt Feature layer — core loop is fun. Failing elements are legibility and discoverability,
> not fundamental design problems.

---

## Hard Criteria Results

| Criterion | Result | Notes |
|-----------|--------|-------|
| Tester arranges grid with intent (not randomly) within 10 min | ✅ PASS | Grid was engaged with intentionally |
| Tester verbally identifies elemental strategy without prompting | ❌ FAIL | Did not understand what differentiates combinations |
| All-Ashfire is NOT dominant first strategy | — | Not observed — combination differences were opaque |
| Tester discovers elemental cause-and-effect within 5 min | ❌ FAIL | Combination outcomes not legible (no visual differentiation yet) |
| Tester not stuck in confusion loop >30 seconds | ✅ PASS | Continued playing despite confusion |
| Tester can articulate what went wrong after failed wave | — | Not recorded |

---

## Observations

### What worked
- Core loop (arrange → confirm → fight) was understood and engaged with
- Game was described as **fun** — emotional hook is present
- Tester interacted with PranaGrid without needing instructions

### Failing Elements

**1. Combination legibility — CRITICAL**
Tester did not understand the difference between one combination and another.
Root cause: combination visual/audio differentiation is not yet implemented at FP scope.
SpellCastingEffects fires the same attack regardless of prana arrangement (placeholder behaviour).
Fix priority: HIGH — must be addressed in Sprint 5 Feature layer before next external test.

**2. PranaGrid size — UX**
Grid panel felt too large and intrusive on screen.
Fix priority: MEDIUM — resize panel or make it collapsible after confirmation.

**3. Dash discoverability — UX**
Tester did not know the dash ability existed.
No affordance, keybinding hint, or visual indicator present.
Fix priority: MEDIUM — add keybinding hint to HUD or brief onboarding text.

**4. Dash cooldown not readable — UX**
Tester could not tell when dash was on cooldown.
No cooldown indicator in CombatHUD.
Fix priority: MEDIUM — add cooldown indicator to HUD (icon flash, timer, or bar).

---

## CH-004 Evidence (deferred from Sprint 3)

**Result**: NOT DEMONSTRATED

Chain dots (combo chain visual) were not understood or noticed by the tester.
Suspected cause: chain dots container is positioned in the top-left corner of the HUD,
far from the action. Tester's attention was on the character and enemies.

**Recommendation**: Move chain dots display to above the player character (world-space or
screen-space overlay anchored to player position) so it is in the tester's focal area.
This remains an open advisory item — defer to Sprint 5 HUD polish story.

---

## Sprint 5 Scope Adjustments Required

Based on this verdict, the following must be scoped before Sprint 5 begins:

1. **Combination visual differentiation** — prana type produces distinct visual/audio feedback
   on cast (e.g. fire = red beam, frost = blue beam). Core legibility of the Prana loop.
2. **Dash affordance** — keybinding hint visible in HUD during combat.
3. **Dash cooldown indicator** — visual state for dash availability.
4. **Chain dots position** — move from top-left HUD corner to player-relative position.
5. **PranaGrid panel size** — reduce footprint or add post-confirm collapse.
