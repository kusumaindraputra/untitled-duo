# ADR-0031: Gamepad Rebinding, Rumble, Settings File Version and Tutorial Hints

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Three items the beta plan needs before testers get the build:

1. **Gamepad rebinding.** `GameSettings.PAD_REMAPPABLE` (dash, cast, special) can be
   bound to any button in `PAD_BINDABLE` (A/B/X/Y, LB/RB, L3/R3). Overrides live in
   a new `[pad]` section of `user://settings.cfg` and are applied by the same
   `apply_keys()` call that applies keyboard overrides. The Settings panel shows a
   key column and a pad column side by side; a pad rebind that takes a button already
   used swaps the two, like keyboard rebinds. Pad prompts (`dash_hint_pad`,
   `special_ready_pad`, `controls_pad`, tutorial hints) now read the bound button
   through `InputPrompts.pad_label()`.
2. **Rumble.** `Rumble` (`src/core/rumble.gd`, static) turns camera trauma into a
   gamepad pulse, so every hit that shakes the screen also rumbles. Perfect Dodge and
   Special get their own pulses. Strengths live in `assets/data/rumble_tuning.tres`.
   The new `GameSettings.rumble` (0–100 %) scales them, independent of Screen shake.
   Nothing plays unless the last input came from a pad (`InputPrompts.pad_device`).
3. **Settings file version.** The `[game]` section carries `version`
   (`GameSettings.SETTINGS_VERSION`, now 2; files without it are v1). `load_from()`
   runs `migrate()` step by step before reading, and `save_to()` never stamps a lower
   version over a file a newer build wrote. v1 → v2 moves nothing.
4. **Tutorial hints.** The every-run "HOW TO FIGHT" card (built inline in
   `debug_game_loop.gd`) is gone. `TutorialCoach` now shows one short line at a time
   at the bottom centre: two preparation hints (confirm the grid, spell tiers) and six
   combat hints (move, cast, dash, Perfect Dodge, Perfect Cast, Special). It shows the
   first unticked hint of the current phase only, so nothing covers the floor title or
   the prep panel. It still runs only until `MetaProgress.tutorial_done`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Input / Persistence / UI |
| **Knowledge Risk** | LOW: `InputMap`, `InputEventJoypadButton`, `Input.start_joy_vibration` and `ConfigFile` are unchanged in 4.4–4.6. |

## Context

Settings said "Gamepad buttons are fixed for now" while the store page promises full
pad support. `progress.cfg` had a `SAVE_VERSION`, but `settings.cfg` did not, so a
future change to a settings key had no safe way to carry testers' choices over. The
tutorial card sat over the floor title and next to the prep panel on every run (U8
screenshot).

## Decision

- Only combat actions are pad-rebindable. Movement stays on the left stick, and the
  grid keeps its own buttons because it only runs between fights. Start (pause),
  Back, Guide and the D-pad (menu navigation) are never offered.
- Triggers are axes, not buttons, so they are not bindable yet.
- Rumble reuses camera trauma rather than adding calls at each hit site, so new
  impacts rumble automatically.
- The settings version sits in `[game]` because `GameSettings` owns that section;
  `AudioSystem` still saves `[audio]` into the same file and keeps other sections.
- Hint text is per device (`coach_steps_kb` / `coach_steps_pad`) with `%s` filled from
  the live InputMap, so rebinds show up in the tutorial too.

## Alternatives Considered

- **Rebind every pad action, grid included**: rejected. The grid shares A/Y with
  cast/special on purpose (phases never overlap), and swap rules across phases get
  confusing for little gain.
- **A separate rumble call per damage source**: rejected, easy to miss new sources.
- **Wiping settings when the version changes**: rejected, it is exactly the loss the
  version is meant to prevent.
- **Keep the How to Fight card but move it**: rejected. Four lines at once is still a
  wall of text during the first prep phase.

## Consequences

- Any change that renames, moves or reinterprets a settings key must bump
  `SETTINGS_VERSION` and add a step to `GameSettings.migrate()` with a test.
- A new tutorial step needs an entry in `TutorialCoach.STEPS`, `STEP_PHASES`,
  `STEP_ACTIONS` and both copy arrays (a test checks the sizes match).
- New pad prompt copy should use `InputPrompts.pad_label()` instead of naming a button.

## Validation

- `tests/unit/settings/game_settings_test.gd` (pad rebinds, rumble, version, migration)
- `tests/unit/rumble/rumble_pulse_test.gd`
- `tests/unit/tutorial/tutorial_coach_test.gd`
- `tests/unit/input-prompts/input_prompts_device_test.gd` (pad labels follow bindings)
- Evidence: `production/qa/evidence/adr0031-settings-gamepad.png`,
  `adr0031-hint-prep.png`, `adr0031-hint-combat.png`, `adr0031-hint-combat-pad.png`
