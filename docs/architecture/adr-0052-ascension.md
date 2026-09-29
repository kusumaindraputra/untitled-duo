# ADR-0052: Ascension Above Hard Mode

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

After Hard Mode, winning players get an **Ascension** ladder of 8 stacking levels.
A Hard Mode win at the highest unlocked level opens the next one. Each level adds one
readable change (more enemy HP, faster bullets, more elites, tougher bosses, weaker
healing, one more enemy, faster fire with shorter warnings, then more HP again) and
+10 % shards.

- `AscensionLevel` (`src/data/ascension_level.gd`): the changes one level adds.
  `AscensionConfig` (`src/data/ascension_config.gd`) holds the ladder, `stacked(n)`
  combines levels 1..n, `apply(cfg, n)` returns a scaled copy of an `EnemyPoolConfig`.
- Data: `assets/data/ascension/ascension_config.tres`, referenced by
  `MetaTuning.ascension`. Text: `UICopy.ascension_*`.
- `MetaProgress.ascension` (picked) and `ascension_unlocked` (highest) are saved in
  `user://progress.cfg`. `active_ascension()` is 0 unless Hard Mode is active and
  never above the unlocked level. `record_run()` opens the next level and adds the
  stacked `shard_bonus` to the Hard Mode shard multiplier.
- `EnemyPoolConfig` gains `enemy_hp_mult` and `boss_hp_mult` (default 1.0). WaveManager
  multiplies them into the H&D registration and calls the new
  `EnemyInstance.apply_hp_mult()` so the boss bar matches.
- `HealthAndDamage.player_heal_mult` (default 1.0) scales every heal the duo receives;
  the run scene sets it with the Assist values.
- The run scene builds each pool as Hard Mode then Ascension (`_run_pool()`). The main
  menu shows an Ascension button under the Hard Mode toggle; the run summary names a
  newly opened level.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Data / Meta progression |
| **Knowledge Risk** | LOW: typed `Array[Resource]` exports and `ConfigFile`; nothing post-4.3. |

## Context

The beta roadmap asks for replay value after the first win. Hard Mode is a single
switch; players who beat it have nowhere to go. Slay the Spire's Ascension and Hades'
Heat show that small, stacking, named steps keep a win meaningful.

## Decision

A fixed ladder (not a free menu of modifiers like Heat) because it is one button on the
menu, one line per level, and each level can be tested in isolation. Changes reuse the
knobs Hard Mode already scales (pool configs), plus two new multipliers that only
Ascension sets: pool HP and the duo's healing. Ascension sits on Hard Mode so the existing
unlock flow and shard multiplier stay the single entry point.

## Alternatives Considered

- **Heat-style pact** (pick any modifiers): more UI (a whole screen, gamepad nav),
  more combinations to balance before the 8 Nov feature freeze. Rejected for beta.
- **Scale enemy base HP in the .tres per level**: would need copies of every
  EnemyType. A pool multiplier keeps one source of truth.
- **Replace Hard Mode with Ascension 1**: breaks existing saves and the Hard Mode
  record semantics.

## Consequences

- New shared state: `HealthAndDamage.player_heal_mult`. It is set, never reset, by
  the run scene; tests that touch it restore it.
- `record_run()` now pays the Hard Mode multiplier only when Hard Mode is *active*
  (unlocked), matching what the run actually played. The main menu never lets the
  flag be on while locked, so shipped behaviour is unchanged.
- Balance of the ladder can be checked with the ADR-0051 bot: `--ascension=N`.

## Validation

`tests/unit/meta-progression/ascension_test.gd`: stacking, pool copies, unlock rules,
cycling, shard bonus, save/load and clamping, shipped data and copy in sync, heal and
HP multipliers.
