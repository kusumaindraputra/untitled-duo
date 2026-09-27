# ADR-0046: HUD Toasts, HUD Scale / Card Opacity and the Optional Run Timer

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Three medium-priority HUD items from the UI/HUD review:

1. **Corner toasts.** A sigil taken, a memory fragment found mid-run and bonus Cipher
   Shards each push a short card into the bottom-left corner.
2. **HUD size and HUD card opacity.** Settings used to offer only Text size. The
   corner HUD can now be 85 / 100 / 115 / 130 %, and the left card's background can
   be faded to 30–100 %.
3. **Optional run timer.** A clock in the bottom-left corner, off by default,
   showing the same time the Records save.

## Decisions

### Toasts: `HudToaster` (src/ui/hud_toaster.gd)

- A Control the game loop adds to the HUD CanvasLayer beside CombatHUD, so
  `combat_hud.gd` does not change for toasts. The game loop calls `_toast()` from
  `_log_sigil` (non-Prana sigils, the run's Heirloom included), from the floor-clear
  memory beat and from the flawless-Challenge shard bonus. Run-end memories are not
  toasted because the summary overlay covers the corner.
- **Pausable** (`PROCESS_MODE_PAUSABLE`). The sigil offer, the memory card and the
  pause menu pause the tree, so a toast pushed under one waits and plays once the
  game resumes instead of expiring unseen.
- At most `max_visible` cards at once. Later cards queue, and the queue drops its
  oldest entries past `max_queued`, so a burst never fills the room.
- Timing and layout values live in `assets/data/hud_toast_tuning.tres`
  (`HudToastTuning`). Ages advance in `_process` as float accumulators (ADR-0004).
  `alpha_at()` and `offset_at()` are pure static functions, and `tick()` is the test
  seam.
- With Reduce motion on, a card appears at once with no slide or fade-in. It still
  fades out.
- Copy: `UICopy.toast_sigil_format`, `toast_memory_format`, `toast_shards_format`.

### HUD scale and card opacity

- `GameSettings.hud_scale_idx` (into `HUD_SCALES` = [0.85, 1.0, 1.15, 1.3], default
  index 1) and `hud_card_opacity` (clamped to `HUD_CARD_OPACITY_MIN` = 0.3 … 1.0).
  The static helpers `hud_scale()` and `hud_card_alpha()` return 1.0 when no
  settings are loaded.
- CombatHUD moves the left-card nodes (card, HP ghost chunk and HP row, Special, dash, Style, floor and
  room lines, combo counter) under one `LeftCard` Control in `_group_left_card()`,
  keeping their draw order. Scaling that group from the top-left corner scales the
  whole card, while `_layout_left_column()` keeps working in unscaled px. The floor
  map's `_minimap_root` scales too and stays pinned to the top-right corner.
  `get_floor_map_bottom()` returns the scaled bottom, so the prep panel still sits
  below the map.
- At 130 % the card's right edge (≈ 302 px) still clears the boss bar (x ≈ 316 at
  1152 px wide). A test enforces this.
- Screen-space elements that follow Fayde (chain dots, dash ring, damage numbers)
  are not scaled. They sit in the world, not in a corner.
- Opacity multiplies the alpha of the card's background and border
  (`UIPalette.CARD`, `CARD_BORDER`). Text stays fully opaque. Toast cards use the
  same multiplier.

### Run timer: `RunTimerLabel` (src/ui/run_timer_label.gd)

- `GameSettings.show_run_timer`, off by default.
- The clock is injected as a Callable: the game loop passes
  `RunManager.get_elapsed_sec` (new). It is live during a run and frozen at the final
  `run_time_sec` after the run ends. That is the same wall clock `record_win_time`
  stores, and the label uses `RunSummaryPanel.format_time`, as Records does, so the
  number on screen is the one a record would save. The label reads no game state
  itself (ADR-0003).
- It sits in the **bottom-left** corner. The bottom-right was tried first, but the
  prep panel reaches down there. The toaster stacks above the timer through
  `bottom_inset = timer.corner_height`.

### Live refresh

The Settings panel calls `refresh_hud_prefs()` on the `hud_prefs` group
(`CombatHUD.HUD_PREFS_GROUP`) after every HUD change. CombatHUD, HudToaster and
RunTimerLabel join that group, so a change made from the pause menu shows at once.

### Settings file version

`SETTINGS_VERSION` 2 → 3. The v2 → v3 step in `migrate()` is a no-op, because the
three keys are new and start at their defaults. It still bumps the version, as
v1 → v2 did for the pad section (ADR-0031), so a file's version says which options
it can hold.

## ADR Dependencies

ADR-0003 (signal-driven, display-only UI), ADR-0004 (float accumulator timers),
ADR-0031 (settings file version), ADR-0032 (text size), ADR-0035 (measured left
card), ADR-0042 (HP ghost chunk, now part of the scaled left card).

## Engine Compatibility

Godot 4.6. It uses only APIs that predate 4.4: `Control.scale`, `SceneTree.call_group`,
`Node.PROCESS_MODE_PAUSABLE`, `StyleBoxFlat` and `ConfigFile`.

## Alternatives Considered

- **Scaling the whole CombatHUD Control.** Rejected. The chain dots and the dash ring
  are placed from Fayde's screen position and would drift, and the boss bar would
  outgrow the screen.
- **Toasts inside CombatHUD.** Rejected to keep `combat_hud.gd` changes small, since
  parallel threads edit that file.
- **Reading RunManager from the timer label.** Rejected, per ADR-0003 (UI is display
  only). An injected clock is also easy to fake in tests.

## Consequences

- New left-card rows must be added to the `rows` list in `_group_left_card()`,
  otherwise they will not scale with the card.
- New HUD parts that should follow the HUD size join the `hud_prefs` group and read
  `GameSettings.hud_scale()`.

## Tests

`tests/unit/hud-prefs/`: settings defaults, round trip, clamping and v2 → v3
migration. Also the Settings panel saving the options and refreshing the live HUD,
toast fade/slide math, queueing, expiry, pausability and opacity, the left-card
grouping and scale, the boss-bar clearance at 130 %, the timer's visibility, format
and corner, toasts stacking above the timer, and `RunManager.get_elapsed_sec`.

Evidence: `production/qa/evidence/adr0046-*.png` (text size 130 %).
