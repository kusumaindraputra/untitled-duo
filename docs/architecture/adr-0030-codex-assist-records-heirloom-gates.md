# ADR-0030: Spellbook Codex, Assist Options, Records and Memory-Gated Heirlooms

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The four beta-plan features F1–F4 extend the two existing save files rather than
adding new ones.

1. **Spellbook (F1)**: `MetaProgress` (`user://progress.cfg`) keeps four discovery
   lists: `codex_spells`, `codex_reactions`, `codex_sigils` and `codex_enemies`.
   `Spellbook` (`src/ui/spellbook.gd`) builds the entries from those lists and the
   existing catalogs. `SpellbookPanel` shows them from the main menu and the pause menu.
2. **Assist (F2)**: `GameSettings` (`user://settings.cfg`) holds a master switch,
   `assist_enabled` (off by default), plus `assist_damage`
   (50–100 %), `assist_speed` (70–100 %) and `assist_auto_dash`. Every place that
   used to restore `Engine.time_scale` to 1.0 now restores it to
   `GameSettings.base_time_scale()`. Damage taken is scaled in
   `HealthAndDamage` through `player_damage_mult`. The game reads the
   `effective_*()` getters, which return normal values while the switch is off, so
   the chosen values are kept for the next time Assist is turned on.
3. **Records (F3)**: `MetaProgress` keeps `best_win_sec` and `boss_best_sec`
   (boss enemy id → seconds). Runs with any Assist on set no records.
4. **Heirlooms (F4)**: `MetaTuning.heirloom_memory_gates` runs parallel to
   `heirloom_ids` and `heirloom_costs`. `MetaProgress.can_unlock` requires
   `fragments_found` to reach the gate.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Persistence / UI / Meta progression |
| **Knowledge Risk** | LOW: `ConfigFile`, `Engine.time_scale` and typed dictionaries are unchanged in 4.6. |

## Context

The beta plan asks for a codex, difficulty help, long-term goals and a longer meta
loop before the closed beta. All four only need small amounts of per-player data,
and both save files already had load/save code and tests.

## Decision

- Keep one progress file and one settings file. New keys use defaults when missing,
  so saves from earlier builds load unchanged.
- Discoveries are recorded by the game loop (`debug_game_loop.gd`) from events it
  already handles (combat start, enemy killed, sigil picked). Progress is saved when
  leaving a run, restarting or quitting.
- Assist is a player setting, not run state. The run only remembers whether any assist
  was on, to mark the summary and skip records.
- Heirloom gates and costs stay in `assets/data/meta_tuning.tres`, so tuning needs no
  code change.

## Alternatives Considered

- **A separate codex file**: rejected. It would add a second save path to migrate and
  test for a few dozen ids.
- **Assist as a Hard Mode style run modifier**: rejected. Players who need it would
  have to re-enable it every run.
- **Recording times with assist on, in a separate table**: rejected for beta scope.

## Consequences

- Any new code that pauses or slows time must restore `GameSettings.base_time_scale()`,
  never a literal 1.0 (the main menu is the one exception).
- New Heirlooms must exist in `SigilConfig.sigils`. Behaviour sigils work through
  `SigilManager.apply_sigil` like stat sigils.

## Validation

- `tests/unit/spellbook/spellbook_codex_test.gd`
- `tests/unit/assist/assist_options_test.gd`
- `tests/unit/records/records_best_times_test.gd`
- `tests/unit/meta-progression/heirloom_memory_gate_test.gd`
- Evidence: `production/qa/evidence/f1-spellbook.png`, `f2-assist-settings.png`,
  `f3-records-menu.png`, `f4-heirlooms.png`
