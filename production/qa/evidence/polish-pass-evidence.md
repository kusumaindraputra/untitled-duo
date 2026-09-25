# Polish Pass Evidence (2026-09-25)

Captured under xvfb (Godot 4.6.2, opengl3, 1152×648) with `--write-movie`.

| File | What it shows |
|------|---------------|
| `polish-pass/main-menu-progress.png` | Main menu with a seeded save: shard/stat line, Heirloom row (unlocked, equipped, affordable, too expensive), Hard Mode toggle after one win |
| `polish-pass/combat-coach-and-arrows.png` | First combat of Floor 1: LEARN TO FIGHT checklist ("Move" already ticked, "Cast" is the current goal) under the HUD, and dim red edge arrows on the right for dormant enemies outside the view |

Audio cannot be captured as an image; the 20 new cues are listed in
`tools/audio-gen/synth_sfx.py` and registered in `assets/data/audio_event_registry.tres`.
Test run: 1314 test cases, 0 failures (`tests/unit`, headless GdUnit4).
