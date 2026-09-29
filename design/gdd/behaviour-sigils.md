# Behaviour Sigils

> **Status**: Implemented (ADR-0026) · **Code**: `src/systems/sigil_effects.gd` ·
> **Data**: `assets/data/sigil_config.tres` ("Behaviour Sigils" group)

## Overview

Seven sigils in the between-room reward pool that change *how* the duo fights instead
of raising a number. Each hooks onto something the player already does (dash, graze,
Perfect Dodge, Perfect Cast, Special, kills). Picking the same sigil again adds a
stack that scales it.

## Player Fantasy

"My build does something." A run with Ember Wake and Riposte plays like a dash
brawler; one with Static Halo and Unravel plays like a graze dancer. The player
should leave a run remembering the combo, not "+20 % damage".

## Detailed Rules

| Sigil | Trigger | Effect (1 stack) |
|-------|---------|------------------|
| Ember Wake | While dashing, every `ember_spacing` px | Burning patch (radius `ember_radius`, `ember_duration` s) deals `ember_damage` FIRE every `ember_tick_sec` s to enemies inside |
| Static Halo | A graze | Zaps the nearest enemy within `static_range` for `static_damage` LIGHTNING; `static_cooldown` s between zaps |
| Afterglow | A Special fires | Refunds `afterglow_refund` of the Special meter |
| Unravel | An enemy dies | Cancels enemy bullets within `unravel_radius` of it |
| Siphon | Every `siphon_kills` kills | Heals `siphon_heal` HP |
| Riposte | A Perfect Dodge | Deals `riposte_damage` to every enemy within `riposte_radius` of the duo |
| Metronome | A Perfect Cast at streak ≥ `metronome_streak` | Heals `metronome_heal` HP |

- Behaviour cards are tinted gold (`behaviour_card_color`) in the reward overlay.
- Stacks reset at `run_started`.

## Formulas

- Damage / heal with `n` stacks: `base × n` (Ember, Static, Siphon, Riposte, Metronome).
- Afterglow refund: `meter_max × min(afterglow_refund × n, afterglow_refund_cap)`.
- Unravel radius: `unravel_radius × (1 + 0.5 × (n − 1))`.
- Siphon triggers when `kills % siphon_kills == 0` (kills counted only while owned).

## Edge Cases

- No enemy in range: Static Halo does nothing and does not start its cooldown.
- Unravel on a kill with no bullets nearby: no ring, no event.
- A Special refunding into a full meter: `add_special_meter` clamps.
- No player node (headless tests): effect nodes are freed, never leaked.

## Dependencies

SigilManager (routing, overlay) · SpellCastingEffects (graze, special, perfect cast,
meter) · HealthAndDamage (damage, heal, kills) · PaceDirector (Perfect Dodge) ·
Projectile (`cancel_in_radius`) · PlayerController (`is_dashing`).

## Tuning Knobs

All values in the table above live in `sigil_config.tres`. The riskiest are
`static_cooldown` (graze-heavy patterns can chain zaps) and `afterglow_refund_cap`
(too high makes the Special spammable).

## Acceptance Criteria

- Every catalog entry flagged `behaviour` is handled by SigilEffects and no other is
  (`sigil_effects_test.gd`).
- Picking a behaviour sigil adds one stack and emits `sigil_applied`.
- Formulas above match `afterglow_amount`, `unravel_radius`, `siphon_triggers`.
