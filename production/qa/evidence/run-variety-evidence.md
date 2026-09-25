# Evidence — Run Variety, Final Boss, Settings (ADR-0026)

Captured headless-with-display (Xvfb, OpenGL 3, 1152×648) from a throwaway capture
driver that starts a run and forces each situation. Automated tests: 1350 passing.

| Screen | File | What to check |
|--------|------|---------------|
| Main menu | `round2-main-menu.png` | Settings and Quit side by side; version `v0.9.0` bottom right; no volume sliders |
| Settings | `round2-settings.png` | Display / Comfort / Audio on the left, keyboard bindings on the right, every action shows its key |
| Pause | `round2-pause.png` | Settings button replaces the three volume sliders; everything fits |
| Cursed room | `round2-cursed-room.png` | Violet "CURSED" banner under the floor intro; minimap "X" (current) and "!" (next room) |
| Wayshrine | `round2-wayshrine.png` | Offer 20 HP / Walk on, trade button focused (forced during prep for the capture) |
| Keeper, start | `round2-keeper-lattice.png` | Gold-tinted Keeper, rotating laser lattice telegraph, off-screen violet arrow |
| Keeper, phase 1 | `round2-keeper-phase1.png` | "The first lock breaks" banner, beam pylon in the room, homing ring (red = hit flash) |
| Keeper, phase 2 | `round2-keeper-ring.png` | Closing ring narrows the room; "The vault closes in" banner |

Found and fixed while capturing:

- A hit that crossed two HP thresholds skipped the phase-1 pylon. Skipped phases are
  now applied in order (`test_final_boss_skipped_phase_is_still_applied`).
- The Keeper's tint did not reach its sprite (`self_modulate` does not reach child
  sprites); it now uses `modulate`.
- Settings opened from the main menu showed "—" for movement and dash, because those
  actions are registered by the run scene. Settings now registers the defaults.

Not captured (need a human playtest): Ember Wake / Static Halo / Riposte visuals in
a real fight, the Challenge "lost" / "FLAWLESS" banners, rebinding by keyboard and
gamepad navigation of the Settings panel.
