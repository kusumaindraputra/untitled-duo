# Room Modifiers (Challenge, Cursed, Wayshrine)

> **Status**: Implemented (ADR-0026) · **Code**: `src/systems/room_modifiers.gd`,
> `src/ui/wayshrine_panel.gd` · **Data**: `assets/data/room_modifier_tuning.tres`

## Overview

Some combat rooms on each floor carry a modifier that changes the fight and its
reward. Rest rooms are Wayshrines, where the player can trade HP for a sigil.

## Player Fantasy

Doors become a decision: "Do I take the Cursed room for two sigils, or the safe
one?" Challenge rooms reward playing clean; Wayshrines let a healthy player turn HP
into power.

## Detailed Rules

- **Roll**: after a floor is generated, each combat room except the entry room rolls
  once: Challenge with `challenge_chance`, else Cursed with `cursed_chance`. At most
  `max_modified_per_floor` rooms per floor. Elite, Rest and Boss rooms never roll.
- **Challenge**: taking any damage during combat in the room loses the bonus
  (banner "Challenge lost"). A flawless clear pays `challenge_shards` Cipher Shards
  at run end and offers `challenge_picks` sigil picks.
- **Cursed**: the room's enemy pool gains `cursed_extra_enemies` threat budget (and
  enemy cap), `cursed_elite_bonus` elite chance and `cursed_bullet_speed_mult`
  bullet speed. Clearing it offers `cursed_picks` sigil picks.
- **Wayshrine**: after the rest heal, a panel offers "Offer `wayshrine_hp_cost` HP"
  for one sigil pick, or "Walk on". The offer is disabled when paying would leave
  Fayde below 1 HP.
- Doors read "⚔ Challenge", "☠ Cursed", "♥ Wayshrine". The minimap marks Challenge
  "!" (white border) and Cursed "X" (violet border). A banner names the modifier on
  entry.

## Formulas

- Picks: Challenge `challenge_picks` if flawless else 1; Cursed `cursed_picks`; else 1.
- Bonus shards: `challenge_shards` for a flawless Challenge, else 0. Added after the
  Hard Mode multiplier.
- Wayshrine allowed when `hp − wayshrine_hp_cost ≥ 1`.

## Edge Cases

- Hard Mode and Cursed stack (Cursed copies the already-hardened pool).
- A hit during preparation does not fail a Challenge (only COMBAT_PHASE counts).
- The Wayshrine HP price never kills and never grants i-frames.

## Dependencies

DungeonGraph · WaveManager (pool config) · SigilManager (`offer_sigils(picks)`) ·
HealthAndDamage (`pay_fayde_hp`, `damage_taken`) · MetaProgress (`bonus_shards`) ·
CombatHUD (banner, minimap) · RoomExitDoor.

## Tuning Knobs

Everything in `room_modifier_tuning.tres`: roll chances, per-floor cap, Challenge
shards and picks, Cursed extras and picks, Wayshrine cost.

## Acceptance Criteria

- The entry room and non-combat rooms are never modified; the cap holds; a seeded
  roll is deterministic (`room_modifiers_test.gd`).
- Cursed returns a harder copy and leaves the shared config unchanged.
- The Wayshrine trade is refused when it would be lethal.
- A two-pick offer re-opens once and then unpauses.
