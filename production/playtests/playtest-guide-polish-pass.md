# Playtest Guide — Fast-Pace Polish Pass

**Purpose**: close the re-validation playtest carried since Sprint 7 (S9-03) on the
current build, which now has bullet patterns, Perfect Dodge / Cast, Special, stage
hazards, pixel-art visuals, the closer camera, audio for every mechanic, off-screen
enemy arrows, the in-combat tutorial and progress between runs.
**Story**: S9-03 (re-validation playtest)
**Build**: the `polish-pass` export zips (Windows / Linux / Web) from the PR that adds this file.
**Time**: 35–45 minutes per tester. One observer, one tester.

---

## Before the session

1. Use a tester who has **not** played The Last Cipher. Two testers is better than one.
2. Delete the tester's saved progress so they get the first-run experience:
   - Windows: `%APPDATA%\Godot\app_userdata\The Last Cipher\progress.cfg`
   - Linux: `~/.local/share/godot/app_userdata/The Last Cipher/progress.cfg`
   - Web: clear site data for the page.
3. Headphones or speakers on. Audio is part of what is being tested.
4. Say only this: *"It's a fast action game. Play it however you like and think out
   loud. I can't help you while you play."* Do not explain controls or mechanics.

## During the session

Take timestamps. Write what the tester **says and does**, not what you think they mean.

### Part A — First run (about 15 min, no help)

| # | Watch for | Record |
|---|-----------|--------|
| A1 | Time until the first cast in combat | mm:ss |
| A2 | Does the LEARN TO FIGHT checklist get read? Which steps tick on their own? | list of ticked steps at end of run 1 |
| A3 | First dash — on purpose, or by accident? | on purpose / accident / never |
| A4 | First Perfect Dodge — did they notice the slow-mo and the sound? Did they repeat it on purpose? | yes / no + quote |
| A5 | Do they turn toward an edge arrow when an off-screen enemy fires? | count of times seen |
| A6 | Any moment stuck or confused for more than 30 s | timestamp + what |
| A7 | Cause of death (or win) | text |

### Part B — Between runs (about 3 min)

| # | Watch for | Record |
|---|-----------|--------|
| B1 | Do they read the Cipher Shards line on the end screen? | yes / no |
| B2 | On the main menu, do they find and buy an Heirloom without being told? | which one, and why |

### Part C — Second and third run (about 15 min)

| # | Watch for | Record |
|---|-----------|--------|
| C1 | Do they now use Perfect Cast rhythm (not mashing)? | mash / rhythm / mixed |
| C2 | Do they save the Special for a crowd or a boss? | text |
| C3 | Do they get further than run 1? | floor / room reached per run |
| C4 | Do they say "one more" or restart without being asked? | yes / no |

## After the session — five questions

Ask in this order, write answers verbatim.

1. What was the most exciting moment?
2. When did you feel the game was unfair?
3. Was there anything you never figured out?
4. Did the sounds help you, get in the way, or not matter?
5. Would you play another run right now? Why?

## Pass criteria for this build

| Criterion | Pass when |
|-----------|-----------|
| Onboarding | At least 4 of 6 checklist steps tick in run 1 without help |
| Perfect Dodge is discoverable | Tester does one on purpose by run 2 |
| Off-screen threats are readable | No death the tester blames on "something I couldn't see" |
| Audio | Tester does not ask to turn SFX down; no complaint about noise |
| Meta loop | Tester buys an Heirloom and starts another run unprompted |
| No confusion loop | No stuck moment longer than 30 s |

## Writing it up

Save the notes as `production/playtests/playtest-polish-pass-YYYY-MM-DD.md`, using
`playtest-sprint-4-external-2026-06-12.md` as the layout (verdict, criteria table,
observations, failing elements with fix priority). Then mark S9-03 done in
`production/sprint-status.yaml`.
