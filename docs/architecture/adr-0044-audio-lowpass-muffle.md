# ADR-0044: Audio Low-Pass Muffle on Pause and Critical HP

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Item 9 of the juice review: the mix should "go under water" when the game is paused
and when the duo's HP is critical, so both moments are felt as well as seen.

AudioSystem installs one shared `AudioEffectLowPassFilter` (tagged `CipherMuffle`) on
the Music, SFX and AMB buses. The UI bus stays dry so pause-menu clicks stay crisp.
The filter is bypassed (`set_bus_effect_enabled(false)`) whenever its cutoff is fully
open, so it costs nothing in normal play.

Two sources can muffle the mix:

| Source | Trigger | Default cutoff |
|---|---|---|
| Pause | `GameStateManager.game_paused` / `game_resumed` | 700 Hz |
| Critical HP | `HealthAndDamage.player_hp_zone_changed` = `DESPERATE` (≤20 % HP, same zone as the red vignette) | 2200 Hz |

When both are active the darker (lower) cutoff wins. Pausing while critical goes
darker, and resuming returns to the critical cutoff. `run_started` and `run_ended`
clear both sources, so quitting to the menu from the pause screen never leaves the
menu muffled.

## Tuning

All values live in `assets/data/audio_filter_tuning.tres` (`AudioFilterTuning`):
`enabled`, `buses`, `open_cutoff_hz`, `pause_cutoff_hz`, `critical_cutoff_hz`,
`resonance`, `engage_sec`, `release_sec`.

## Implementation Notes

- The cutoff sweeps with a tween in `TWEEN_PAUSE_PROCESS` and `set_ignore_time_scale(true)`,
  so it moves while the tree is paused and at full speed through the death slow-mo.
- Engaging uses `engage_sec` (fast, 0.2 s), releasing uses `release_sec` (0.45 s) so
  the world "surfaces" a little slower than it sinks.
- `_install_lowpass()` is idempotent: an existing `CipherMuffle` effect is adopted
  instead of stacking a second filter.
- Only the pause menu (through `GameStateManager.pause_game()`) muffles. Modal pauses
  that set `get_tree().paused` directly (sigil offer, wayshrine, memory fragment, the
  title card) do not, because those are choices inside play, not a break from it.
- The filter sits on buses, not players, so it composes with music volume tweens such
  as the boss death cinematic fading music: they change volume, this changes tone.

## Alternatives Considered

- **Filter on Master**: simplest, but muffles UI clicks in the pause menu.
- **Polling `get_tree().paused`**: would catch every modal pause, but AudioSystem is
  pausable and stops processing while paused; signals are also the ADR-0012 contract.
- **Volume duck instead of filter**: quieter is not the same as "far away"; the
  low-pass keeps loudness and removes presence, which reads as distance.

## Tests

`tests/unit/audio/audio_muffle_test.gd` covers the cutoff rule, install on the right
buses, idempotency, engage/release for pause and critical, the combined case, the
disabled switch, the timed sweep and the signal wiring.

## Related

- ADR-0012 Audio System implementation contract
- Low-HP desperate vignette in `src/ui/spell_vfx.gd` and `src/ui/combat_hud.gd`
