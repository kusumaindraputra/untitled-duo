# ADR-0045: Boss Bar Phases, Sigil Strip and Feedback Link

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The high-priority items from the UI/HUD improvement review.

1. **Boss bar shows its phases.** The boss HP bar was a plain `ProgressBar`, and a new
   phase showed up only as text ("— PHASE 2") in the name card. The new
   `BossHealthBar` (`src/ui/boss_health_bar.gd`) is a `Control` drawn by hand, and it
   shows three things:
   - A notch at every HP threshold where the boss gains a pattern layer. It reads
     `EnemyInstance.get_phase_thresholds()`, which lists each layer's
     `BulletPattern.hp_threshold`, including the layers the run's `BossVariant` adds.
     `BossHealthBar.clean_thresholds()` keeps the distinct values inside (0, 1),
     because layers that share a threshold are one phase (ADR-0018). A notch the boss
     has already passed is drawn faint.
   - A ghost chunk. Like Fayde's bar (ADR-0042), the HP lost in a hit stays visible
     in a pale colour for `boss_ghost_hold_sec`, then drains at
     `boss_ghost_drain_per_sec` × max HP per second.
   - A white flash over the bar for `boss_phase_flash_sec` when `phase_changed`
     fires, next to the existing name-card text.

   It keeps ProgressBar's `max_value` / `value` names, so CombatHUD's damage path is
   unchanged.
2. **Sigil strip.** `SigilStrip` (`src/ui/sigil_strip.gd`) is a row of small chips
   between the left HUD card and the combo counter. The Cipher Core is the first chip,
   drawn with a thick border in its accent colour. Every sigil taken follows, in pick
   order, with a two-letter tag from its title ("Ember Wake" → EW) and a stack count
   when it was taken more than once. Behaviour sigils use the gold that their reward
   cards use (`SigilConfig.behaviour_card_color`). When `SigilEffects.effect_fired`
   fires, that sigil's chip lights up for `strip_pulse_sec`. Chips wrap to the card
   width.
3. **Feedback link (beta plan 5.2).** A "Send Feedback" button on the main menu
   (between Settings and Quit) and on the run summary opens the form with
   `OS.shell_open`. On the web build that opens a new tab. The URL is set in
   `assets/data/feedback_config.tres`. The form does not exist yet, so `form_url`
   ships empty, and **both buttons stay hidden until a URL is set**. The optional
   `version_param` pre-fills the game version on the form (for example a Google
   Forms `entry.NNN` key).

## Wiring

- CombatHUD owns both `_boss_bar` and `_sigil_strip`. It exposes the strip through
  `get_sigil_strip()`. `_layout_left_column()` places the strip under the card and
  moves the combo counter below it. The strip emits `layout_changed` when a new row
  appears, and that queues a re-layout.
- `debug_game_loop` feeds the strip: `_start_core()` resets it and sets the Core,
  `_log_sigil()` adds each sigil (Prana rewards are not sigils, and Heirloom stat
  sigils show too), and `SigilEffects.effect_fired` calls `pulse()`.

## Data

All timings and sizes are in `assets/data/hud_readout_tuning.tres` (`HudReadoutTuning`).
The feedback URL is in `assets/data/feedback_config.tres` (`FeedbackConfig`). Button
text is `UICopy.menu_feedback` and `UICopy.summary_feedback`.

## Alternatives considered

- **Keep the ProgressBar and overlay the notches as child nodes.** This was rejected.
  The ghost chunk needs a second fill under the first, and the ProgressBar theme
  cannot draw that without a sibling bar and z-order juggling. The one custom
  `_draw()` is smaller.
- **Icons per sigil.** No sigil art exists, and drawing 16 icons is beyond this
  pass. Two-letter tags in coloured frames read well at 28 px, and the pause
  build view still lists the full names.
- **Show a placeholder feedback URL.** A dead link in a tester's hands costs more
  than a missing button, so an empty URL hides the button.

## Consequences

- A new boss or variant gets notches with no extra work, as long as its phases use
  `hp_threshold`.
- New behaviour sigils light up their chip as long as they emit
  `SigilEffects.effect_fired` with their id.
- Before the beta build, put the form URL in `feedback_config.tres`.

## Tests

`tests/unit/hud-readout/`: boss bar thresholds, the ghost hold and drain, the flash,
HUD wiring on spawn and phase, `EnemyInstance.get_phase_thresholds()`, strip tags,
wrapping, Core and stack order, pulse timing, combo counter placement, and feedback
URL building.
