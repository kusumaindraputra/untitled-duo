# ADR-0057: Two Hands — Ayden and Faith Columns on the Prana Grid

## Status

Proposed (awaiting the user's pick between a rule and a look-only framing)

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The identity direction chosen on 2026-09-27 ("Dua tangan") ties the grid to the
story. Fayde is made from Ayden (raw power) and Faith (precise control), and their
Prana only worked when they touched. The grid now says so. The left column is Ayden's
hand, and each Prana in it adds damage. The right column is Faith's hand, and each
Prana in it lengthens the core status. When both hands hold the same number of Prana,
they touch and both bonuses grow ×1.5. The main menu tagline changes to
"Two brothers' Prana. One pair of hands."

## Decision

- Pure rules in `src/systems/prana_hands.gd` (`PranaHands.read(grid)`), working on
  any 9-slot array where non-null means filled. Combat and the prep preview use the
  same function. Tuning is in `assets/data/hands_tuning.tres` (`HandsTuning`).
- `CombinationResolution._resolve` writes `hand_power_mult`, `hand_control_mult` and
  `hands_touching` to `SpellEffect`. `preview_build` adds a `hands` entry.
- `SpellCastingEffects`: Step 8d multiplies primary chain hits by `hand_power_mult`.
  `_apply_status_effects` multiplies the core status duration by `hand_control_mult`.
- `PranaGrid` places AYDEN / FAITH labels beside the octagon frame, dim until that
  hand holds Prana. `SpellPreview` prints one hands line under the core line.
- Rule 18 in `design/gdd/combination-resolution.md`.

## Alternatives Considered

- **Look only (labels, no rule).** Cheapest, but the labels would promise a meaning
  the rules do not have (Pillar 3: legible, never misleading), and it repeats the
  original problem of story that never reaches play.
- **Scale everything (reactions, Special, all statuses).** Stronger, but it stacks
  with sigils and the Special's own scaling and is harder to balance before the
  feature freeze.

## Consequences

- Placement gains a second axis: corners and side slots now matter by column, and
  slots 3 and 5 trade reaction value against hand balance.
- Longer Burn means more Burn ticks, so Faith's hand also raises Ashfire damage over
  time. This needs a balance pass with the balance thread.
- Tests: `tests/unit/prana-hands/prana_hands_test.gd`.

## Evidence

`production/qa/evidence/adr0057-hands-prep-100.png` and `adr0057-hands-prep-130.png`.
