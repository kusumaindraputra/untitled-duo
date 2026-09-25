# Stage Layout — Visual Evidence (ADR-0020)

Captured 2026-09-25 with `--write-movie` under xvfb (Godot 4.6.2, Compatibility
renderer, god mode on). A throwaway harness boots `demo.tscn`, skips the title and core
pick, loads the chosen floor with a forced entry-room template, confirms the build and
zooms the camera out to 0.62 so the whole room is visible.

| Shot | What it shows |
|------|---------------|
| `stage-layout/floor1-pillars.png` | Floor 1 (Deep Scrap Yard) Diamond: two grey full-cover pillars among the half-cover debris. HUD reads "Floor 1 · Deep Scrap Yard". |
| `stage-layout/floor2-crossfire.png` | Floor 2 Cross room with the blue-grey tint. The sweep beam stops at the arena wall on the left and at a pillar on the right. |
| `stage-layout/floor2-vents.png` | Floor 2 Vent Line: one vent burning (orange), two dormant grates. |
| `stage-layout/floor3-core.png` | Floor 3 Ring room: three magenta beams rotate out of the walled core, and a vent burns bottom-right. |
| `stage-layout/floor3-pillar-cover.png` | Floor 3 Furnace: two pillars cracked from absorbing fire (crack lines visible), a turret mid-room, and vents in all three phases. |
| `stage-layout/floor3-crucible.png` | Floor 3 Crucible about 18 s into combat: the closing ring has shrunk, the red band marks the unsafe edge, and a cracked pillar sits on the safe line. |
| `stage-layout/floor-intro.png` | Floor-intro banner "FLOOR 2 / Functional Corridors" over the preparation screen. |

Headless log from the same runs: with Fayde held behind a pillar in the Furnace, all
three pillars were worn down and broken within 14 s at the original 14-hit durability.
That is why durability was raised to 24 (combat, elite) and 32 (boss). In the
Crucible run, a 24-hit pillar ended the room with 7 hits left. No script errors.
