# Cipher Cores and Sigil Reroll

> **Status**: Implemented (ADR-0033) · **Code**: `src/data/core_frame.gd`,
> `src/data/core_roster.gd`, `src/systems/sigil_manager.gd`, `src/scenes/debug_game_loop.gd`
> · **Data**: `assets/data/cores/core_roster.tres`, `assets/data/sigil_config.tres`

## Overview

Before a run the player picks a Cipher Core as well as the core Prana. The Core
gives a passive with a trade-off for the whole run. During the run, every sigil
reward screen can be rerolled by paying HP.

## Player Fantasy

"This run I go Glass and kill everything before it touches me." A Core sets the
tone of a run before the first room. The reroll turns a bad reward screen into a
choice: bleed a little for a better sigil, or take what is offered and stay healthy.

## Detailed Rules

- **Core pick**: the pick screen shows the Core row above the five Prana cards.
  The Core last used is selected. Focus starts on the first Prana card, so pressing
  confirm starts a run straight away, as before. Moving focus over a Core shows its
  passive, and pressing it selects it. Picking a Prana starts the run.
- **Core effect**: applied once at run start, after run state resets and before the
  Heirloom. Multipliers stack with sigils. The damage-taken share stacks with Assist.
- **Reroll**: the button below the cards replaces all of them with a fresh roll. It
  does not use up the pick. A free reroll (Echo Core) is used before any paid one.
  A paid reroll is refused when it would leave Fayde below 1 HP, and the button then
  reads "too weak".
- The pause build list starts with the run's Core.

## Formulas

- Reroll price = `max(reroll_hp_cost + reroll_hp_step × bought, 1)`, where `bought` is
  the number of paid rerolls this run. Defaults: 6, 10, 14, … HP.
- Allowed when the price is 0 (free) or `hp − price ≥ 1`.
- Damage taken = base × first-run mercy × (Assist share × Core `damage_taken_mult`).
- Cards per offer = Core `offer_cards` if above 0, else `SigilConfig.offer_cards` (3).

## Edge Cases

- An unknown or empty saved Core id falls back to Steady.
- A multi-pick offer (Cursed, flawless Challenge) refills free rerolls on every screen.
- Paid rerolls never kill and never grant i-frames (same path as the Wayshrine).
- Restarting a run resets the spell-damage multiplier, so Cores and sigils never
  carry into the next run.

## Dependencies

SigilManager · SpellCastingEffects (`apply_damage_mult`, `reset_run_damage_mult`) ·
PlayerController (`apply_move_speed_mult`, `add_dash_charges`) · HealthAndDamage
(`player_damage_mult`, `pay_fayde_hp`) · MetaProgress (`last_core`) · UICopy.

## Tuning Knobs

- `core_roster.tres`: each Core's multipliers, dash charges, offer cards, free
  rerolls and accent colour. Adding an entry adds a Core. Its text goes in
  `UICopy.core_titles` / `core_descs`.
- `sigil_config.tres`: `offer_cards`, `reroll_hp_cost`, `reroll_hp_step`.

## Acceptance Criteria

- The Core roster has Steady first, and an unknown id resolves to Steady.
- Applying a Core calls only the hooks it changes. A neutral Core changes nothing.
- The reroll price rises by the step after each paid reroll, free rerolls cost
  nothing, and a lethal price is refused.
- An Echo Core offers 4 cards.
- `last_core` survives a save and load.
