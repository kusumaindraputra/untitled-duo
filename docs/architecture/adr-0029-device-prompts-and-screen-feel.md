# ADR-0029: Device-Aware Prompts and Shared Screen Feel

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Two small autoloads back the beta UI/UX pass (beta plan U8 and U9).

1. **`InputPrompts`** (`src/core/input_prompts.gd`) remembers whether the last input
   came from a gamepad or from keyboard and mouse, emits `device_changed`, and builds
   the prompt strings (dash hint, Special ready, prep controls, control summary).
   Keyboard prompts read the live `InputMap`, so a key rebound in Settings shows its
   new name.
2. **`UIFeel`** (`src/ui/ui_feel.gd`) plays menu sounds through `AudioSystem`
   (`ui_focus`, `ui_confirm`, `ui_back` on the UI bus), and owns the shared fade-in
   and typewriter timing. Both respect a new **Reduce motion** setting
   (`GameSettings.reduce_motion`).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Input / Audio |
| **Knowledge Risk** | LOW: `SceneTree.node_added`, `Viewport.gui_focus_changed`, `Label.visible_characters_behavior`, `Tween.set_pause_mode` and `OS.get_keycode_string` all predate 4.4 and are unchanged in 4.6. |

## Context

Prompts were hard-coded as mixed strings ("Shift / LT — Dash", "F / RMB / Y") and some
were wrong (dash is X on the pad, not LT). Gamepad players had no pause button. Menus
made no sound, overlays popped in, and memory cards showed their text all at once.
The UI rules require UI sounds to go through the audio event system and every
animation to be skippable and to respect accessibility settings.

## Decision

- `InputPrompts` switches on a pressed pad button or a stick push past 0.5, and back on
  a key, a mouse click or a mouse move of 4 px or more, so stick drift and desk bumps
  do not flip prompts. HUD, prep panel, main menu and title card rebuild their text on
  `device_changed`; overlays (pause, run summary, Heirlooms) pick their text when they
  open. Start now pauses on a gamepad.
- `UIFeel` wires every `BaseButton` that enters the tree (via `SceneTree.node_added`) to
  a confirm sound, ticks on `Viewport.gui_focus_changed`, and plays a back sound on
  `ui_cancel`. Focus ticks stay silent for two frames after new UI appears, so a screen
  grabbing focus on open does not tick. Buttons with the `ui_silent` meta skip the
  confirm sound.
- Overlays fade in with `UIFeel.fade_in()` (paused-safe tween). Memory and ending cards
  type their body out at 55 characters per second; the first press shows it all, the
  next closes it. The full text is laid out first so the card never grows line by line.
- Reduce motion skips fades and typing and stills the main menu backdrop's motes.
- The three UI cues are synthesised by `tools/audio-gen/synth_sfx.py` and registered in
  `assets/data/audio_event_registry.tres`.

## Alternatives Considered

- **Wire sounds per screen.** Every screen would need the same boilerplate and new
  screens would be silent by default. The global hook costs one autoload.
- **Glyph images for pad buttons.** Better looking, but needs art per controller family.
  Text labels ship now; glyphs can replace the pad strings in `UICopy` later.

## Consequences

- Two more autoloads (`InputPrompts`, `UIFeel`). Both are stateless apart from the last
  device and the last UI frame.
- Every button in the game now makes a sound. A button that plays its own cue should set
  the `ui_silent` meta.
- New prompt text goes in `UICopy` as a keyboard format plus a pad string, not a mixed
  string.

## Validation

- `tests/unit/input-prompts/input_prompts_device_test.gd`
- `tests/unit/ui-feel/ui_feel_screen_test.gd`
- Evidence: `production/qa/evidence/u8-*.png`, `u9-memory-typewriter.png`
