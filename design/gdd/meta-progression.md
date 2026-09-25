# Meta Progression

> **Status**: Approved (2026-09-25, ADR-0025)
> **Tuning**: `assets/data/meta_tuning.tres` (MetaTuning)
> **Depends on**: run-management.md, fast-pace.md (sigils), wave-encounter-system.md

## 1. Overview

Each run pays Cipher Shards based on how far it got. Shards unlock Heirlooms: a
stat sigil Fayde starts every run with. The first win unlocks Hard Mode, which makes
enemies faster, denser and more often elite, and pays 1.5× shards.

## 2. Player Fantasy

Every attempt leaves something behind. A bad run still buys progress toward the
next Heirloom, and a win opens a harder version of the dungeon to master.

## 3. Detailed Rules

1. A run is recorded once, when `run_ended` fires (win or death). Quitting from the
   pause menu records nothing.
2. Shards are added to both the spendable balance and the lifetime total.
3. On the main menu each Heirloom button shows its state: locked (cost), unlocked
   (Equip) or equipped. Pressing a locked one buys it if affordable and equips it.
   Pressing an unlocked one toggles equip. Only one Heirloom is equipped.
4. The equipped Heirloom is applied through `SigilManager.apply_sigil()` right after
   the core Prana pick, and named on the core-pick screen.
5. Hard Mode shows as a toggle once `wins >= hard_mode_wins_required`; before that
   the menu says how to unlock it. The first time it unlocks, the end screen says so.

## 4. Formulas

`shards = shards_per_floor × max(floor, 1) + shards_per_room × rooms + kills ÷ kills_per_shard (integer) + (win ? win_bonus : 0)`

On Hard Mode: `shards = round(shards × hard_mode_shard_mult)`.

Defaults: 10 / floor, 3 / room, 1 per 5 kills, +60 for a win, ×1.5 on Hard.
A floor-1 death with 3 rooms and 15 kills pays 10 + 9 + 3 = 22. A full 3-floor win
with 18 rooms and 90 kills pays 30 + 54 + 18 + 60 = 162.

Hard Mode per pool: bullet speed ×1.15, fire rate ×1.2, telegraph ×0.85,
threat budget +2 (and `enemy_count_max` +2 when the pool is capped), elite chance +0.1.

## 5. Edge Cases

- Missing or corrupt save: fresh progress, no error.
- Negative values in a hand-edited save are clamped to 0.
- An equipped id that is not unlocked is ignored at run start.
- An Heirloom id missing from the sigil catalog shows its raw id and applies nothing
  (SigilManager warns); a unit test keeps the shipped list in sync.

## 6. Dependencies

RunManager (run data), SigilManager (Heirloom effects, catalog copy), WaveManager and
EnemyPoolConfig (Hard Mode), main menu and debug_game_loop (UI and flow).

## 7. Tuning Knobs

All in `meta_tuning.tres`: shard rates, win bonus, Hard Mode multiplier, the Heirloom
list and costs (30, 45, 50, 70, 90), wins required for Hard Mode, and the Hard Mode
enemy multipliers.

## 8. Acceptance Criteria

- AC-MP-01: A finished run adds the formula's shards and increments runs (and wins).
- AC-MP-02: A locked Heirloom can be bought only with enough shards; buying equips it.
- AC-MP-03: The equipped Heirloom's sigil is active from the first room.
- AC-MP-04: Hard Mode cannot be enabled before the first win.
- AC-MP-05: Hard Mode scales pool copies; the shipped `.tres` pools are unchanged.
- AC-MP-06: Progress survives a restart (save/load round trip).
