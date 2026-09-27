# ADR-0053: One New Enemy Per Floor

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Three enemies join the nine ordinary ones, one per floor, each with a pattern shape
the roster did not have yet:

| Id | Enemy | Floor | Role | Pattern |
|----|-------|-------|------|---------|
| 12 | Pulsar (Deepfrost) | 1+ | slow seeker | `pulsar_ring`: two staggered 10-bullet rings, not aimed |
| 13 | Wisp (Voidblue) | 2+ | shooter, keeps 170 px | `wisp_seeker`: two homing shots, 75°/s for 1.4 s |
| 14 | Lancer (Ashfire) | 3 | rusher | `lancer_lance`: 3-wide fan, 4 volleys each 35 px/s faster |

- Data only: `assets/data/enemy_types/enemy_{pulsar,wisp,lancer}.tres`, patterns in
  `assets/data/bullet_patterns/`, appended to `EnemyCatalog._ENTRY_FILES` so ids follow
  list order. Each floor pool lists its newcomer, and later floors keep earlier ones.
- Sprites from `tools/art-gen/generate_character_sprites.gd` (`_pulsar`, `_wisp`,
  `_lancer`): neutral bodies with a desaturated Prana marker (art bible §5), 4×3 sheet
  with the shared wind-up row. Existing sheets regenerate byte-identical.
- Bullets use the default `mob` accent (ADR-0037); boss accents stay reserved.
- Spellbook notes in `UICopy.spellbook_enemy_notes`; threat icons come from
  `ThreatIcon.kind_for()` unchanged.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Data / Content |
| **Knowledge Risk** | LOW: no new engine API. |

## Context

Beta feedback goal: floors should feel different beyond the boss. Nine ordinary
enemies over 24 rooms repeat quickly. ADR-0018 made attacks data, so new enemies cost
a `.tres`, a pattern and a sprite.

## Decision

Pick shapes the player has not had to read yet: a non-aimed ring that punishes standing
still in the open (Pulsar), homing shots that punish running in a straight line (Wisp),
and an accelerating stacked lance that punishes backing straight away (Lancer). Each
teaches a different dodge, which keeps the difficulty climb about skill, not HP.

## Alternatives Considered

- **Two enemies per floor**: more art and balance risk before feature freeze. One per
  floor meets the brief's lower bound; a second can follow as data.
- **New AI archetypes**: new code paths need new tests and risk the bot's balance
  numbers; existing archetypes already give the three roles.

## Consequences

- Threat costs: Pulsar 1, Wisp 2, Lancer 2, so waves do not get bigger, only more varied.
- Enemy catalog count is 15; `enemy_catalog_data_test` and the GDD table updated.

## Validation

`tests/unit/enemy-roster/floor_enemies_test.gd` (sheet, patterns, mob accent, pool
membership, Spellbook notes, threat icon role) and `enemy_catalog_data_test.gd`.
