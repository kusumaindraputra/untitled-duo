# ADR-0048: Run Save and Resume, Version 0.10.0-alpha, Playtest Run Log

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Three beta-readiness items:

1. **Save and continue a run.** A run closed mid-way (window closed, browser tab
   closed, Quit, or Main Menu from pause) continues from the **start of the last room
   entered**. The main menu shows **CONTINUE (FLOOR f, ROOM r)** above Play, focused
   first.
2. **Version 0.10.0-alpha** in `project.godot`. The Windows export gets the numeric
   `0.10.0.0` for its file and product version. The feedback form URL stays empty.
3. **Local run log** for playtests: one JSON line per finished run in
   `user://run_log.jsonl`.

## Context

The closed beta opens on itch on 2026-11-30, and many testers will play the web
build. A 15–25 minute run lost to a closed tab is the most common complaint that
kind of build gets. Playtest notes also need hard facts (how far did they get, what
killed them, which spells they cast) that testers don't write down.

## Decision

### Save point: the start of every room

The game loop writes a snapshot at two moments:

- right after the core pick (room 1, floor 1), and
- at the end of `_on_room_transitioned`, once the new room is loaded and its prep
  phase has started. A new floor loads through the same path.

That is the one moment when nothing is in flight: the previous room's sigil offer or
Wayshrine is done, the bag holds what the player has not placed yet, and the loadout
is the last confirmed grid. Saving mid-combat would mean saving enemies, bullets,
hazards and boss phases, which is far more state for little gain. Because the save is
written as soon as a room starts, a closed tab loses at most the room being played.
Nothing needs to run at close time, which a browser does not allow reliably anyway.

Resuming puts the player back at the start of the saved room with the HP, build and
stats they had when they entered it. Quitting mid-room to redo that room is possible.
That is accepted: it costs the time spent in the room, and an anti-scum rule would
punish players whose tab crashed.

### What is saved

`RunSave` (`src/systems/run_save.gd`) stores one Dictionary in a ConfigFile at
`user://run_save.cfg` under `[run] version / data`. It is separate from
`progress.cfg` and `settings.cfg`.

| Key | Source |
|---|---|
| `floor`, `total_floors` | the loop |
| `run_seed`, `rng_seed`, `rng_state` | boss variants (ADR-0028), and the room-modifier RNG for later floors |
| `graph` | `DungeonGraph.to_data()`: room type, state, template resource path, modifier; edges |
| `room_idx`, `rooms_entered` | `RoomTransitionManager`, HUD breadcrumb |
| `core` | Cipher Core id (ADR-0033) |
| `loadout`, `bag` | `PranaLoadout.get_slots()`, `PranaBag.get_items()` |
| `sigils` | non-Prana sigil ids in the order taken, Heirloom included |
| `hp` | `HealthAndDamage.get_fayde_hp()` |
| `run` | `RunManager.snapshot()`: rooms, waves, kills, best combo, floor, run time so far |
| `ranks`, `floors_cleared`, `bonus_shards`, `fragments_at_start`, `assist_used`, `new_records` | the run summary (U5, F2, F3, ADR-0026) |
| `hard`, `ascension` | Hard Mode and Ascension level (ADR-0052) as the run started. Resume writes them back to MetaProgress, so the menu can't change a run halfway |
| `log_builds`, `casts`, `resumes` | the playtest log below |

`RunSave.read()` returns `{}` for a missing file, another `SAVE_VERSION`, or a
snapshot that fails `is_valid()` (required keys, floor within the run, current room
inside the graph, 9-slot loadout, HP above 0). A save that can't be trusted is
dropped, because a lost run is better than a broken one.

### Resume

The main menu's Continue sets the static `RunSave.resume_requested` and loads
`main.tscn`. `debug_game_loop._ready()` wires the scene as usual, then takes the
request (`take_resume_request()` clears it, so a later Restart starts fresh) and
calls `_resume_run()` instead of showing the title:

1. Restore floor, seeds and RNG state. Re-pick the boss variants. Apply the floor
   theme, rebuild the graph with `DungeonGraph.from_data()`, and apply the floor
   pools with the saved Hard Mode flag.
2. Set the loadout, then `GameStateManager.start_run()`. `run_started` resets HP, the
   bag, sigil stacks, spell damage and run stats, so everything below comes after it.
3. Apply the saved Core, refill the bag, and **replay the sigils** through
   `SigilManager.apply_sigil()` in the order they were taken. Replaying rebuilds stat
   multipliers, behaviour-sigil stacks, dash charges, the HUD chip strip and the
   pause-menu build list with the same code that built them the first time. A replayed
   Heal does nothing at full HP.
4. `HealthAndDamage.restore_fayde_hp()` sets HP (clamped to 1…max, emits only the zone
   change), and `CombatHUD.sync_hp()` snaps the bar with no hit feedback.
   `RunManager.restore_snapshot()` puts the counters back and rewinds the clock start
   so run time continues from where it was.
5. `RoomTransitionManager.load_floor(graph, room_idx)` loads the saved room. The new
   optional `room_idx` defaults to the entry room, so existing callers are unchanged.
   `_on_room_transitioned` then counts the room, starts prep and writes a fresh save.
   A "RUN RESUMED" banner shows.

A save made by a scene with a different `total_floors` (e.g. the one-floor
`demo.tscn`) is ignored by `main.tscn`.

### When the save is removed

- At the start of `_on_run_ended` (win or death), before the death slow-mo, so closing
  the game during the death beat can't bring the run back.
- On Restart (pause menu, R key, or Run Again). Restart abandons the run.

Main Menu and Quit keep the save, since that is how a player stops for now. Starting
a new run with Play replaces the save at the next core pick.

### Not saved (reset on resume)

The special meter, dash cooldown state, the sigil reroll count, and the TutorialCoach
step. The coach starts again if the tutorial was never finished. All of these are
cheap to lose at the start of a room.

### Version

`application/config/version="0.10.0-alpha"`. The main menu, the run summary and
the feedback link already read it. Windows resource versions must be numeric, so
`export_presets.cfg` sets `file_version` and `product_version` to `0.10.0.0` instead
of relying on the fallback to `config/version`. `feedback_config.tres` `form_url` is
still empty, so the Feedback button stays hidden until a URL is given.

### Playtest run log

`RunLog` (`src/systems/run_log.gd`) appends one JSON object per run to
`user://run_log.jsonl` and keeps the newest `MAX_ENTRIES` (200) lines:

```json
{"time":"2026-09-27T11:41:45Z","version":"0.10.0-alpha","outcome":"death",
 "floor":2,"rooms_cleared":11,"run_sec":612.3,
 "cause":{"attacker":"Vault Sentinel","attack":"laser","text":"…"},
 "core":"glass","spells":["Ember","Frost"],
 "builds":[{"floor":1,"room":1,"core":"Ember","grid":[-1,0,…],"reactions":["…"]}],
 "casts":88,"sigils":["damage"],"assist":false,"hard":false,"resumes":1}
```

- `outcome` is `win`, `death` or `abandoned` (Restart during a run). Quitting to the
  menu is not an end, since the run can be continued.
- `cause` comes from `HealthAndDamage.last_player_hit` (ADR-0032) and
  `DeathRecap.line()`. It is empty unless the outcome is `death`.
- `spells` lists the distinct core spells cast. `builds` holds the grid confirmed for
  every fight (`combat_started`), and `casts` counts `SpellCastingEffects.cast_started`.
  Both are carried in the run save, so a resumed run logs the whole run.
- A `_run_logged` guard writes the line once per run.

Nothing is sent anywhere. On desktop the file sits in Godot's user data folder
(`%APPDATA%\Godot\app_userdata\The Last Cipher\` on Windows). On the web build it
lives in the browser's IndexedDB. A tester can't reach it there without a future
"export log" button, which is a follow-up if web playtest logs are needed.

## Consequences

- **Positive:** a closed tab or crash costs at most one room. Playtest reports can
  quote real numbers.
- **Positive:** resume reuses the normal code paths (`start_run`, `apply_sigil`,
  `load_floor`, `_on_room_transitioned`) instead of a parallel restore path, so new
  sigils and Cores work on resume without extra code.
- **Negative:** new run-scoped state has to be added to `_run_snapshot()` and
  `_resume_run()`. A sigil whose effect depends on something other than its id (e.g.
  a random roll at pick time) would need its roll saved too. None exist today.
- **Negative:** changing the snapshot layout means bumping `RunSave.SAVE_VERSION`,
  which drops saves made by older builds.

## Tests

- `tests/unit/run-save/run_save_resume_test.gd`: graph round trip, write/read/clear,
  version and shape checks, resume request, RunManager snapshot/restore,
  `restore_fayde_hp`, and the main menu Continue button.
- `tests/unit/run-log/run_log_playtest_test.gd`: entry fields per outcome, one line
  per run, trimming to the newest entries, bad lines skipped, build entries.
- Checked in the running game with a temporary driver scene (not committed): pick a
  core, take a sigil and a Prana, lose 30 HP, enter the next room, reload `main.tscn`
  with Continue. Room, breadcrumb, HP (and HUD), loadout, bag, sigil list, Core, graph
  and spell damage multiplier all matched. A death then removed the save and wrote
  one log line.
- Evidence: `production/qa/evidence/adr0048-main-menu-continue.png`.
