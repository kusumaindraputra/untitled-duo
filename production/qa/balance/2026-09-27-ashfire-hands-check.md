# Ashfire check after the two-hands rule (2026-09-27)

Question: PR #104 (ADR-0057) lets Faith's column lengthen the core status by 12 % per
Prana (x1.5 when the hands touch). A longer Burn means more ticks, so is an Ashfire
build now too strong?

Method: balance bot (ADR-0051), god mode, 8 seeds per batch, `--core=N` forces the
starting Prana. Main at 780dff1 plus the debug-kill fix in this PR.

| Batch | Full runs | Est. player run | Room medians F1/F2/F3 | Boss medians F1/F2/F3 |
|---|---|---|---|---|
| Ashfire (core 0) | 8/8 | 20:50 | 31 / 30 / 32 s | 43 / 60 / 118 s |
| Voidblue (core 1) | 8/8 | 20:12 | 36 / 29 / 29 s | 49 / 77 / 88 s |

An earlier batch, before the fix, compared Ashfire with `control_per_prana = 0.12`
against `0.0` (the rule switched off): room medians were 31/28/31 s and 28/31/33 s.
That is no measurable difference.

Verdict: no tuning. Burn refreshes on every hit and the bot casts faster than the 2 s
Burn window, so a longer Burn adds few extra ticks. Ashfire and Voidblue both stay
inside the 15-25 min target. Revisit if playtests show Burn builds leaving the fight
early.

Found on the way: 5 of the first 24 runs timed out. Each time, the bot's stall guard
called `HealthAndDamage.debug_kill_all_enemies()` (the F2 QA key), and a kill spawned
reinforcements that registered mid-loop. The function then cleared the whole registry,
leaving those enemies alive but undamageable. This is fixed in the same PR, with a
regression test. After the fix, 16 of 16 runs finish.
