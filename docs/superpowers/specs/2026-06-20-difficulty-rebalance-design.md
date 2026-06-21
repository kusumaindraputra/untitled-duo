# Difficulty Rebalance — Design Spec

**Date:** 2026-06-20
**Status:** Approved (Section 1 shipped) — **Section 2 SUPERSEDED 2026-06-21**
**Author:** Kusuma Putra + Claude Code Game Studios

> **⚠ Superseded note (2026-06-21):** Section 2 (Elemental Resistance — the 2.0× match /
> 0.5× mismatch multiplier) was **removed from the game entirely**. The whole elemental
> strong/weakness system was cut; damage is now element-neutral. Section 1 (enemy stat
> rebalance) remains in effect. The "Drifter affiliation = FIRE/Ashfire" example below
> was also incorrect — Drifter is Shadow/Voidblue.

---

## Problem

Game is too easy on two axes simultaneously:
1. Enemies die in one hit (HP too low relative to player damage output)
2. Enemies don't threaten back (damage too low, player can act freely between casts)

The Preparation Phase ("read arena → arrange Prana") has no real consequence because any Prana arrangement clears the room in one cast.

---

## Solution

Two changes applied together:

1. **Enemy stat rebalance** — buff HP 2.5–4× and damage 1.5–2×
2. **Elemental resistance** — non-matching Prana deals 0.5× damage (vs. 2.0× for matching)

Together: correct Prana = enemies die in 1–2 hits (satisfying). Wrong Prana = enemies survive 4–6 hits AND attack back (dangerous). Preparation Phase now has real stakes.

---

## Section 1 — Enemy Stat Rebalance

### Target

- With correct Prana (2.0× multiplier): enemy dies in 1–2 hits
- With wrong Prana (0.5× multiplier): enemy survives 4–6 hits and counterattacks
- Player HP = 100; 3–4 Charger hits = death → positioning matters

### New Values

| Enemy | HP (old → new) | Damage (old → new) | Rationale |
|-------|---------------|-------------------|-----------|
| Drifter | 20 → 50 | 8 → 14 | Standard threat; survive 1 correct hit |
| Charger | 35 → 90 | 20 → 30 | Tank — 3 hits from Charger = dead Fayde |
| Cluster | 12 → 30 | 4 → 10 | Individually weak, dangerous in packs of 3–5 |
| Rifter | 8 → 32 | 7 → 12 | Slow; rewards player who prioritizes it |

### Files Changed

- `assets/data/enemy_types/enemy_drifter.tres`
- `assets/data/enemy_types/enemy_charger.tres`
- `assets/data/enemy_types/enemy_cluster.tres`
- `assets/data/enemy_types/enemy_rifter.tres`

---

## Section 2 — Elemental Resistance System

### Multiplier Table

| Situation | Multiplier |
|-----------|-----------|
| Prana matches enemy affiliation | 2.0× (existing — no change) |
| Prana does not match (neutral) | 0.5× (new) |
| No Prana / `DamageClass.NONE` | 1.0× (fallback — no change) |

### Example: Drifter (HP 50, affiliation = FIRE/Ashfire)

| Prana used | Multiplier | Hits to kill |
|-----------|-----------|-------------|
| Ashfire (match) | 2.0× | 1–2 |
| Stormgold (neutral) | 0.5× | 4–6 |

### Implementation

**File:** `src/systems/spell_casting_effects.gd` — Step 9 (around line 452)

```gdscript
# Before (match only):
if pt != GameEnums.DamageClass.NONE and enemy_affiliation == pt:
    raw *= 2.0
    affiliation_bonus_hit.emit(target, pt)

# After (match + resistance):
if pt != GameEnums.DamageClass.NONE:
    if enemy_affiliation == pt:
        raw *= 2.0
        affiliation_bonus_hit.emit(target, pt)
    else:
        raw *= 0.5
```

**Not touched:** `health_and_damage.gd` Step 3 — stays at `multiplier = 1.0`. Elemental logic remains in the FP inline location (spell_casting_effects.gd Step 9), consistent with existing architecture and the comment at H&D Step 3.

---

## Section 3 — Test Requirements

Per `coding-standards.md` — Logic story type = BLOCKING gate.

| Test | Type | Location |
|------|------|---------|
| Neutral Prana vs enemy → damage = raw × 0.5 | Unit | `tests/unit/spell-casting/` |
| Matching Prana vs enemy → damage = raw × 2.0 | Unit (regression) | `tests/unit/spell-casting/` |
| Floor 1 Drifter wave winnable with correct Prana | Balance smoke | Manual playtest |

---

## Out of Scope

- Boss enemy stats (Vault Sentinel, WarpedWarden) — separate tuning pass
- Visual indicator for "enemy is resisting this Prana" — future polish
- Full ElementalAffinityWeakness autoload — future MVP system (H&D Step 3 hook)
- Difficulty tiers — explicitly NOT in MVP scope (game-concept.md)
