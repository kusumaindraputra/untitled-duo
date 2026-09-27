# Balance Bot Pass — 2026-09-27 (ADR-0051, beta plan 3.6)

Tool: `tools/balance-bot/run_bot.sh <runs> <jobs> --god` (Godot 4.6.2 headless, fixed 60 fps).
Content: current main plus Pulsar, Wisp and Lancer (ADR-0053). Normal difficulty, no Heirloom.

"bot" is the bot's own clock. "player~" adds the per-screen reading time from
`balance_bot_config.tres` (6 s per prep phase, 5 s per sigil pick, 4 s per other screen)
and replaces each stall's 20 s wait with 5 s of search time.

## Before (boss HP 250 / 500 / 900)

```
seed  outcome floor rooms    bot player~   dmg bosses (s)              
   1      win     3    24   8:59   15:16    60 F1:14 F2:7 F3:12         stalls=0
   2      win     3    24  11:42   17:47    60 F1:20 F2:18 F3:26        stalls=2
   4      win     3    24   8:14   15:16    60 F1:16 F2:8 F3:15         stalls=0

full runs: 3/3  est. player time median 15:16  range 15:16-17:47
floor 1: room fight median 27s over 21 rooms
floor 2: room fight median 17s over 21 rooms
floor 3: room fight median 20s over 21 rooms
floor 1: boss fight median 16s (n=3, 14-20s)
floor 2: boss fight median 8s (n=3, 7-18s)
floor 3: boss fight median 15s (n=3, 12-26s)
```

Run length already sits in the 15–25 min target. Bosses die in 7–26 s, faster than an
ordinary room (17–27 s): the build snowballs by Floor 2 and the boss has less HP than a
full wave.

## After (boss HP 600 / 1800 / 2700)

```
seed  outcome floor rooms    bot player~   dmg bosses (s)              
   1      win     3    24   8:14   14:40    60 F1:25 F2:44 F3:67        stalls=0
   2      win     3    24  13:49   20:42    60 F1:28 F2:93 F3:142       stalls=0
   3  timeout     3    16  45:00   28:02    40 F1:88 F2:293             stalls=85
   4      win     3    24   9:26   15:43    60 F1:28 F2:37 F3:48        stalls=0
   5      win     3    24  17:53   23:22    60 F1:63 F2:20 F3:91        stalls=5
   6      win     3    24  14:16   19:51    60 F1:53 F2:73 F3:72        stalls=4

full runs: 5/6  est. player time median 19:51  range 14:40-23:22
floor 1: room fight median 27s over 42 rooms
floor 2: room fight median 18s over 42 rooms
floor 3: room fight median 17s over 35 rooms
floor 1: boss fight median 41s (n=6, 25-88s)
floor 2: boss fight median 59s (n=6, 20-293s)
floor 3: boss fight median 72s (n=5, 48-142s)
```

Seed 3 timed out: the bot could not reach enemies in 85 rooms-worth of checks (its
build, not the bosses). It is left out of the medians.

## Reading the numbers

- The bot aims perfectly and lands half its Perfect windows, so a player's damage is
  lower. Expect player boss fights of roughly 1–1.5 min (F1) to 1.5–2.5 min (F3).
- Mortal runs (no god mode) die in room 1–2: the bot's dodging is far below a player's,
  so survival and damage-taken numbers need playtests, not the bot.
- Seen once in ~20 runs: Fayde ended far outside the room (y ≈ 11 000 px) and the run
  stalled. Worth a look (dash or knockback through a wall).
- Re-check with 2–3 human playtest timings in beta phase 4.5; tune the same three
  `base_hp` values if players land outside 1–2.5 min per boss.
