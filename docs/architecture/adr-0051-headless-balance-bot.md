# ADR-0051: Headless Balance Bot

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

A dev-only bot plays the real `main.tscn` headless at a fixed 60 fps and reports run
length, per-room fight time and per-boss fight time as JSON. It drove the beta plan
3.6 balance pass: boss HP went from 250 / 500 / 900 to **600 / 1800 / 2700**
(Sentinel / Warden / Keeper) while the run stays in the 15–25 min target.

- `tools/balance-bot/balance_bot.gd` + `BalanceBot.tscn`: instances `main.tscn`, calls
  `_begin_run()` / `_on_core_picked()`, then each physics frame: confirms the grid
  (placing reward Prana), fights with `Input.action_press` on the real actions
  (move, cast, dash, special), presses the focused button on any paused screen, closes
  story cards, walks to an exit door. Time = frames / 60.
- Play style and human reading time live in `balance_bot_config.tres`
  (`BalanceBotConfig`). Flags: `--god`, `--seed`, `--hard`, `--ascension=N`, `--out`,
  `--max-min`.
- `run_bot.sh` runs seeds in parallel; `summarize.py` prints the table and medians.
- Report: `production/qa/balance/2026-09-27-balance-bot.md` with the raw JSON.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Tools / QA |
| **Knowledge Risk** | LOW: `--fixed-fps`, `OS.get_cmdline_user_args()`, `Input.action_press()`; all pre-4.4. |

## Context

Beta plan 3.6 asked for a balance pass "from playtest timings", but playtests are
scarce and slow. Spell targeting is a facing cone (80–220 px), so a formula model of
damage per second misses most of what makes a fight long: approach, facing, cover
pillars, reinforcement waves, boss phases.

## Decision

Drive the shipped scene instead of modelling it. The bot uses only public inputs plus a
few private hooks the screenshot driver already uses, so what it measures is the game.
It measures **pace**, not survival: in god mode it clears every run; mortal runs die in
the first rooms because its dodging is crude. Two guards keep a bad spot from eating a
run: a sidestep when blocked by a pillar, and a logged "stall" (debug kill) after 20 s
with no enemy losing HP.

## Alternatives Considered

- **Spreadsheet DPS model**: fast, but ignores targeting cone, movement and waves.
- **Record human inputs and replay**: rooms are randomised per run, so replays desync.
- **Smarter mortal bot** (bullet prediction): large effort before feature freeze for
  numbers playtests give anyway.

## Consequences

- Boss HP retuned in `enemy_vault_sentinel.tres`, `enemy_warped_warden.tres`,
  `enemy_cipher_keeper.tres`; GDD enemy table and `enemy_catalog_data_test` follow.
- The bot reads a few private members (`_begin_run`, `_on_core_picked`,
  `_current_floor`, `SpellCastingEffects._state`, `PranaGrid._on_confirm_pressed`).
  Renaming them breaks the tool, not the game. It is not in CI.
- Rooms are randomised by the game's own RNG, so runs vary; use medians over 6+ runs.

## Validation

Before/after tables in `production/qa/balance/2026-09-27-balance-bot.md`: boss fight
medians 16 / 8 / 15 s → 41 / 59 / 72 s; estimated player run 15:16 → 19:51 median.
