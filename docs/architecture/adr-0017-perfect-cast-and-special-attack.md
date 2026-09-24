# ADR-0017: Perfect Cast Timing and Special Attack in Spell Casting & Effects

## Status

Accepted

## Date

2026-09-24

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Combat gets a second action (`special`) and a timing judgement on the basic `cast`.
Both live inside the Spell Casting & Effects Autoload (SC&E) rather than a new system:
SC&E already owns the chain timers, the cached `SpellEffect`, and the reaction hooks
the Special must reuse. Knobs live in a new `AttackTuning` Resource. Design:
`design/gdd/special-attack.md`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting / Input |
| **Knowledge Risk** | LOW — `InputMap`, `InputEventMouseButton`, `StyleBoxFlat`, `ProgressBar` are unchanged since 4.0 |

## ADR Dependencies

- ADR-0004 (float accumulator timers) — the Perfect window is derived from the existing
  `_combo_window_timer`, not a new timer: `elapsed = window_duration − _combo_window_timer`.
- ADR-0009 (wave-scoped stat broker) — the Special meter is wave-scoped and resets on
  `preparation_started`, like every other SC&E field.
- ADR-0011 (StatusEffectsManager API) — all Special statuses go through `apply_status`.
- ADR-0016 (reactions & Cascade) — the Special reuses the reaction application hooks.

## Context

Combat was "spam SPACE": cast lock is 0.12 s, so ~8 casts/s with no reason to vary.
The grid's non-primary tiers were computed by Combination Resolution but never read in
combat. The user asked for two buttons (basic + special), Perfect Cast, and for the
Special to reflect the Prana combination.

## Decision

1. **Timing judgement in SC&E.** `get_cast_timing()` returns `CastTiming.NORMAL /
   PERFECT / RUSHED` from `_state` and the combo window. `_trigger_cast()` applies the
   multiplier through a per-attack `_perfect_mult` field read in `_apply_hit` Step 8c,
   gates meter gain and the Cascade on it, and passes `perfect_cascade_mult` to
   `_fire_cascade()` (new optional parameter, default 1.0).
2. **Special in SC&E.** `_trigger_special()` polls the `special` action in `_process`
   (overrides cast lock), resolves shape by `primary_type`, applies infusions from
   `SpellEffect.non_primary_modifiers`, and routes damage through `_special_hit()`
   which mirrors `_apply_hit`'s reaction hooks (Shatter, Thermal Shock, Siphon,
   Detonate) without knockback, crit, or the primary status.
3. **Data.** `AttackTuning` (`src/data/attack_tuning.gd`, authored as
   `assets/data/attack_tuning.tres`) holds every knob, preloaded as a const like
   `ReactionTuning` so headless tests need no Autoload.
4. **Presentation via signals only** (ADR-0003): `perfect_cast`, `special_meter_changed`,
   `special_fired`. CombatHUD draws the meter; SpellVFX draws the callout, the
   sweet-spot marker on the combo ring, and the Special burst.
5. **Input.** SC&E registers `special` (F + right mouse) if missing, mirroring `cast`;
   scenes add the gamepad Y binding in their input setup, mirroring `cast` → A.

## Alternatives Considered

- **Separate SpecialAttack node/Autoload** — rejected: it would need the cached
  SpellEffect, reaction flags, and enemy-query seams SC&E already owns, duplicating state.
- **Charged cast (hold SPACE)** — rejected by the user in favour of two buttons.
- **Perfect as bonus only, no Rushed penalty** — rejected: at 8 presses/s mashing
  out-damages and out-charges the rhythm (GDD Formula 2), making Perfect decorative.

## Consequences

- Positive: rhythm matters; non-primary fragment counts finally affect combat; the
  Special is readable from the grid (shape = core, facets = supports, riders = reactions).
- Negative: SC&E grows (~250 lines). A later split into a `SpecialAttack` helper
  RefCounted is cheap if it keeps growing.
- Risk: balance is paper-only (GDD Appendix A4).

## Validation Criteria

`tests/unit/spell-casting-effects/sce_perfect_special_test.gd` and
`tests/unit/combat-hud/combat_hud_special_meter_test.gd` pass; full suite green.

## Related

- `design/gdd/special-attack.md`
- `design/gdd/spell-casting-effects.md`, `design/gdd/combination-resolution.md`
