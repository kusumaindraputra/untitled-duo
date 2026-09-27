# Evidence — Art Consistency Pass (ADR-0039)

Captured 2026-09-27 with Xvfb (Compatibility renderer, 1152×648). A throwaway
driver starts a run on a chosen floor and can put the first room in boss mode.
It then confirms the build, pauses, and kills Fayde to reach the defeat screen.
Automated tests: 1642 passing.

The side-by-side before/after pairs are in the project files under
`art-pass/consistency/`. The after frames are committed here.

| Screen | File | What to check |
|--------|------|---------------|
| Main menu | `adr0039-main-menu-after.png` | The title is in a Prana colour and breathes and cycles; the arches are ogival; the subtitle reads "Survive three floors." |
| Title card | `adr0039-title-after.png` | Same title glow; warm grey text |
| Core pick | `adr0039-core-pick-after.png` | Core names in muted tones, not jewel colours; lantern-toned heading |
| Prep, floor 1 | `adr0039-prep-floor1-after.png` | Map markers in stone, brass, moss and rust; sage continue hint; HUD cards in shadowed stone |
| Pause | `adr0039-pause-map-after.png` | Legend matches the map; Elite is brass and Cursed is dusty plum (no Warden violet) |
| Defeat | `adr0039-defeat-screen-after.png` | Cool blue-grey wash and title instead of red (§2.5) |
| Sentinel boss | `adr0039-boss1-sentinel-ambience-after.png` | Floor tinted toward Vault Teal |
| Warden boss | `adr0039-boss2-warden-ambience-rubble-after.png` | Floor tinted toward Corruption Violet; pixel rubble in the floor palette |
| Floor 3 prep | `adr0039-floor3-prep-rubble-after.png` | Rubble painted plum to match the crystal floor |
| Floor 3 combat | `adr0039-floor3-combat-rubble-after.png` | Close-up of the pixel rubble with its outline and top-left light |
