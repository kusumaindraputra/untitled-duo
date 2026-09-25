# Room Visuals — Visual Evidence (ADR-0021)

Captured 2026-09-25 under xvfb (Godot 4.6.2, Compatibility renderer, 1152×648, god
mode on). A throwaway harness boots `demo.tscn`, picks the Ashfire core, dismisses the
tutorial, takes the preparation shot, confirms the grid, waits four seconds of combat,
then loads floors 2 and 3 and zooms the camera out to 0.62.

| Shot | What it shows |
|------|---------------|
| `room-visuals/before-prep.png` | Before: sand tile, flat grey void, default grey panel. |
| `room-visuals/after-prep.png` | After: art bible earth floor with worn, cracked and glyph tiles, slab edge under the room, backdrop glow and dust, themed Prana panel and Continue button. |
| `room-visuals/before-combat.png` | Before: combat close-up on the old tiles. |
| `room-visuals/after-combat.png` | After: same framing; Prana bullets and enemies read clearly against the darker floor. |
| `room-visuals/after-floor2.png` | Floor 2 Cross room: cool slate floor and blue haze. |
| `room-visuals/after-floor3.png` | Floor 3 Crucible: mauve floor, violet haze, closing ring band. |
| `room-visuals/after-title.png` | Title card with the themed buttons (focus ring on BEGIN RUN). |

Characters and enemies are still placeholder capsules on purpose; illustrated sprites
come through the art bible §10 pipeline. The HUD floor label reading "Floor 1" in the
floor 2 and 3 shots comes from the harness jumping floors directly (it skips the
room transition; not checked against a normal run).
