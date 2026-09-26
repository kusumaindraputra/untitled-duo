# ADR-0033: Cipher Cores and Sigil Reroll

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Two small additions give the player more decisions per run:

1. **Sigil reroll (mid-run decision)**: every sigil reward screen has a Reroll
   button. It costs HP, and the price rises with each reroll bought in the run.
   It follows the Wayshrine rule: it never leaves Fayde below 1 HP.
2. **Cipher Cores (build variety)**: the core-pick screen adds a row of four
   Cores next to the five core Prana. The Prana still picks the spell. The Core
   adds a passive with a trade-off for the whole run.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay / UI |
| **Knowledge Risk** | LOW: `Resource`, `ButtonGroup` and `ConfigFile` are unchanged in 4.6. |

## Context

The beta review found that the only choices a player makes during a run are the
sigil pick and the Wayshrine trade. There is also one character and five Prana, so
builds start the same way. The feature freeze is 2026-11-08. That leaves room for
small changes that reuse existing systems, not a new room type or a shop.

## Decision

### Reroll paid in HP (chosen over shards or an event room)

- Cipher Shards are only paid out at the end of a run (`MetaProgress.record_run`),
  so there is no in-run shard balance to spend. Spending banked meta shards
  mid-run would tie a run's difficulty to the meta grind.
- HP is already the run's currency: the Wayshrine sells a sigil for HP, and
  `HealthAndDamage.pay_fayde_hp` refuses a lethal price. The reroll reuses it.
- A narrative event room would need a new room type, door, generator rule and
  writing. It stays on the list for after the beta.
- Price: `reroll_hp_cost + reroll_hp_step × rerolls bought this run`
  (6, 10, 14 … HP by default). The tuning lives in `SigilConfig`
  (`assets/data/sigil_config.tres`), as does `offer_cards` (cards per offer).
- `SigilManager` owns the price logic (`reroll_cost`, `can_reroll`, `try_reroll`,
  `begin_screen`). HP is read and paid through injectable callables, so the logic
  is unit-tested without the autoload.

### Cipher Cores

- `CoreFrame` (`src/data/core_frame.gd`) is a Resource holding only multipliers and
  counts that existing hooks already accept: spell damage
  (`SpellCastingEffects.apply_damage_mult`), move speed and dash charges
  (`PlayerController`), damage taken (`HealthAndDamage.player_damage_mult`), and
  the sigil offer size and free rerolls (`SigilManager`). No combat code knows
  about Cores.
- `CoreRoster` (`assets/data/cores/core_roster.tres`) lists them in display order.
  The first entry (Steady, no passive) is the default.
- Names and passive text are in `UICopy.core_titles` and `core_descs`, keyed by
  Core id.
- The run scene applies the Core right after `GameStateManager.start_run()` (so the
  run-start resets have already happened) and before the Heirloom.
- `MetaProgress.last_core` remembers the pick. It is a new key with a default, so
  older saves load unchanged.
- All four Cores are available from the first run. Gating them behind memories or
  wins can come later if playtests show too much choice on the first run.

| Core | Upside | Cost |
|------|--------|------|
| Steady | none | none |
| Glass | +30 % spell damage | +25 % damage taken |
| Gale | +1 dash charge, +10 % move speed | −15 % spell damage |
| Echo | 4 sigil cards, 1 free reroll per screen | −10 % spell damage |

### Damage-taken share

`HealthAndDamage.player_damage_mult` used to apply only below 1.0 (Assist). It now
applies whenever it is not 1.0. The run scene sets it to the Assist share × the
Core's `damage_taken_mult`, so Assist and a Glass Core stack.

### Run-damage reset (bug fix)

`SpellCastingEffects` is an autoload, and its `_run_damage_mult` was never reset.
Damage sigils from a previous run carried into the next run after a restart. It
now resets on `GameStateManager.run_started`. The Core's multiplier depends on
this reset.

## Consequences

- Positive: two new decisions (reroll or keep; which Core) with no new systems, and
  all values in `.tres` / `UICopy`.
- Positive: the damage-sigil leak between runs is fixed.
- Negative: the pause build list always shows the Core line, so the
  "No sigils yet" hint no longer appears.
- Risk: Glass Core plus Hard Mode may be too punishing. Tune after playtests.

## Validation

- `tests/unit/sigil-system/sigil_reroll_test.gd`: price, rising cost, free rerolls,
  lethal-price refusal and the offer size.
- `tests/unit/cipher-cores/cipher_core_test.gd`: roster defaults, lookup, applying
  each hook, the damage-taken share, the `last_core` save round trip and the
  run-damage reset.

## Related

- ADR-0025 (meta progression), ADR-0026 (Wayshrine, room modifiers), ADR-0030 (Assist)
- Design: `design/gdd/cipher-cores.md`
