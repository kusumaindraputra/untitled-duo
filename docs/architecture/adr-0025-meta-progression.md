# ADR-0025: Progress Between Runs (Cipher Shards, Heirlooms, Hard Mode)

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Every finished run pays Cipher Shards. Shards unlock Heirlooms on the main menu:
an Heirloom is one of the existing stat sigils, granted before the first room of
every run while it is equipped. Winning once unlocks Hard Mode, which scales every
floor's enemy pool and pays 1.5× shards. Progress is saved to
`user://progress.cfg` by a plain `MetaProgress` RefCounted; all numbers live in
`assets/data/meta_tuning.tres`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Persistence / Run flow |
| **Knowledge Risk** | LOW: `ConfigFile`, `Resource.duplicate()` and `Button`/`CheckButton`, all unchanged since 4.0 |

## Context

- Before this, nothing survived a run except the volume settings. Every run
  started from zero, so there was no reason to play "one more".
- The sigil system (between-room rewards) already has effects dispatched by id in
  `SigilManager.apply_sigil()`, with titles and descriptions in `sigil_config.tres`.
- Floors already carry a difficulty curve through `EnemyPoolConfig`
  (`bullet_speed_mult`, `fire_rate_mult`, `telegraph_mult`, `elite_chance`).

## Decision

1. **Heirlooms reuse sigils.** An Heirloom id is a stat-sigil id. Run start calls
   `SigilManager.apply_sigil(id)`, so no new effect code and no duplicated copy.
   Only one Heirloom is equipped at a time, which keeps the start of a run readable.
2. **Hard Mode reuses the pool curve.** `MetaProgress.apply_hard_mode()` returns a
   scaled *copy* of each `EnemyPoolConfig` (the shared preloaded resources are not
   mutated), which `debug_game_loop` hands to `WaveManager`.
3. **No new Autoload.** `MetaProgress` is loaded from disk by the main menu and by
   the run scene, changed, and saved back. The file is the single source of truth;
   tests pass their own path.
4. **Separate file.** `user://progress.cfg`, not `settings.cfg`, so resetting
   progress never touches settings and vice versa.
5. **Pay once.** `debug_game_loop` guards the payout with `_run_recorded`; a run
   abandoned through the pause menu pays nothing.

## Alternatives Considered

- **A shop of new permanent stat upgrades.** More content, but needs new effect code,
  balance passes, and a bigger menu. Rejected for now; Heirlooms can grow into it.
- **Autoload `MetaProgress`.** Simpler access, but another global and harder to
  test. Rejected; two call sites do not justify it.
- **Unlock new Prana types.** The five Prana types are the core combination
  vocabulary, so gating them would weaken the first runs. Rejected.

## Consequences

- Positive: a reason to replay, with a goal ladder (30 → 90 shards) and a hard mode
  after the first win. Zero new gameplay effect code.
- Negative: Heirloom strength follows sigil tuning; buffing a sigil also buffs the
  Heirloom. Accepted; they are meant to be the same thing.
- Save format is versioned (`version = 1`) and read field by field with clamping, so
  old or hand-edited files degrade to sane values instead of failing.

## Validation

`tests/unit/meta-progression/meta_progress_test.gd` covers the payout formula,
unlock/equip rules, Hard Mode gating and scaling, and the save/load round trip.
Main menu evidence: `production/qa/evidence/polish-pass/main-menu-progress.png`.
