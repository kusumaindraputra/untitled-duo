# ADR-0049: Per-Floor Combat Music, Title Loop and Ending Track

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The game shipped five music loops, and all three floors shared one combat loop
(`mus_combat_floor`). The title/main menu was silent (MAIN_MENU had no cue), and a
won run played the short `sfx_run_win` sting as its "ending".

This ADR gives every floor its own combat loop, adds a title loop and a proper ending
track, and moves the choice of which cue plays where out of GDScript into data.

| State / place | Cue | Source |
|---|---|---|
| Title + main menu (MAIN_MENU) | `mus_title` | new, procedural |
| Preparation | `mus_preparation` | unchanged |
| Floor 1 combat | `mus_combat_floor` | unchanged (ElevenLabs) |
| Floor 2 combat | `mus_combat_floor2` | new, procedural |
| Floor 3 combat | `mus_combat_floor3` | new, procedural |
| Elite / boss / rest rooms | `mus_combat_elite` / `mus_combat_boss` / `mus_rest` | unchanged overrides |
| Won run (END_VICTORY) | `mus_ending` | new, procedural, plays once |
| Lost run (END_DEFEAT) | `sfx_run_lose` | unchanged |

## Decision

### Data: `MusicPlaylist`

`src/data/music_playlist.gd` (`MusicPlaylist`, authored as
`assets/data/music_playlist.tres`) holds `menu_cue`, `preparation_cue`,
`floor_combat_cues` (index 0 = floor 1), `victory_cue` and `defeat_cue`. Every entry is
an event name from `audio_event_registry.tres`. `combat_cue_for_floor(n)` clamps: a
floor below 1 counts as floor 1 and a floor past the list reuses the last entry, so a
longer run never goes silent. An empty entry leaves that state silent.

Swapping a track is a data edit: register the file in the registry and point the
playlist field at it. `AudioSystem.playlist` is swappable in tests.

### AudioSystem

- `_load_music_cues()` reads the playlist instead of a hardcoded list.
- `set_music_floor(n)` stores the floor. `reset_combat_cue()` restores that floor's
  loop, falling back to `mus_combat_floor` if the entry is not registered.
  `debug_game_loop._select_room_music()` calls `set_music_floor(_current_floor)` before
  it picks the per-room cue, so boss, elite and rest overrides keep working as before.
- `play_menu_music()` fades in the title loop. `main_menu.gd` calls it deferred from
  `_ready()`, so at boot it runs after AudioSystem's players have entered the tree.
  It is a no-op when the title loop is already playing. From an END_* state it ends
  the ending or defeat cue early; without this, a run started from the menu while the
  one-shot ending was still playing would ignore `run_started` (END_* is
  non-interruptible) and keep the menu loop through the first preparation phase.
- END_* cues no longer loop. Before, `_crossfade_to()` forced `loop = true` on every
  MP3 cue, so an MP3 end cue would never emit `finished` and never return to the menu.
  Loops still loop.

### Generating the tracks without an API key

`tools/audio-gen/synth_music.py` composes the four new tracks offline with numpy and
encodes MP3 with lameenc (the same format as the existing loops). It is deterministic.
Loops are rendered twice and the second pass is kept, so echo and reverb tails from the
end of the loop are already present at its start and the loop point is seamless. All
tracks are loudness-matched to about -16 dBFS RMS with a soft limiter under -0.6 dBFS.

| Track | Key, tempo | Length | Character |
|---|---|---|---|
| `mus_title` | A minor, 84 BPM | 16 bars, 45.7 s loop | pads, triangle arp, bell melody |
| `mus_combat_floor2` | E phrygian, 140 BPM | 24 bars, 41.1 s loop | wobbling 16th bass, syncopated kit |
| `mus_combat_floor3` | C# minor, 156 BPM | 32 bars, 49.2 s loop | galloping bass, power chords, square arp |
| `mus_ending` | D major, 76 BPM | 16 bars + ring-out, 57.8 s one-shot | hopeful pads and bell line, resolves on D |

`music_manifest.json` also carries ElevenLabs prompts for the four new events, so
`generate_music.py --only ... --force` can replace them with produced versions later
without any code change.

## Compatibility

- **ADR-0044 low-pass muffle.** All new cues play on the Music bus, which carries the
  shared `CipherMuffle` filter, so pause and DESPERATE muffle them like the old loops.
  `play_menu_music()` also calls `clear_muffle()`, so quitting to the menu from the
  pause screen never leaves the title loop muffled.
- **ADR-0041 boss stinger.** `stg_boss_felled` ducks the Music bus volume, not a
  player, so it ducks whichever floor loop or boss cue is playing. On the final floor,
  the END_VICTORY crossfade to `mus_ending` happens while the bus is ducked and the
  stinger's restore brings the ending up, as it did for the old victory sting.

## Alternatives Considered

1. **One combat loop per floor chosen in `debug_game_loop`.** Rejected: puts track
   names in scene code; the playlist keeps them in data.
2. **Wait for an ElevenLabs key.** Rejected: the menu and ending would stay silent. The
   manifest prompts keep that path open.
3. **Pitch-shift or re-tempo `mus_combat_floor` per floor.** Rejected: it still sounds
   like one track.

## Consequences

- The procedural tracks are synth/chip in timbre, while the floor 1, elite and boss
  loops are produced progressive-metal. The contrast is audible; replacing the four new
  events with produced versions is a data-only change.
- MP3 encoder padding can leave a very short gap at the loop point, the same as the
  existing loops.

## Tests

`tests/unit/audio/music_playlist_test.gd`: floor mapping and clamping, shipped playlist
integrity (three distinct floor loops, every cue registered with a stream on the Music
bus), floor-aware `reset_combat_cue()` and its fallback, `_load_music_cues()` from the
playlist, `play_menu_music()` (reaches MAIN_MENU, clears the muffle, ends an ending cue
early), and END_* cues playing once.
