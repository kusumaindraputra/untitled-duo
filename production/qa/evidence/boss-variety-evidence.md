# Evidence — Floor Bosses and Per-Run Variants (ADR-0028)

Captured with Xvfb (OpenGL 3, 1152×648) from a throwaway driver that starts a run,
puts the first room in boss mode for the chosen floor, forces one variant and deals
a fixed share of the boss's HP to cross its thresholds. The boss stands off-screen
to the right in these shots (the off-screen arrow points at it). Automated tests:
1403 passing.

| Screen | File | What to check |
|--------|------|---------------|
| Floor 1 name card | `boss-variety/f1-sentinel-name-card.png` | "VAULT SENTINEL · LOCKDOWN": the variant title follows the boss name |
| Floor 1, phase 1 | `boss-variety/f1-sentinel-lockdown-phase1.png` | Sentinel banner "turrets online", turret volley (orange) crossing the room |
| Floor 2, phase 3 | `boss-variety/f2-warden-unstable-phase3.png` | "WARPED WARDEN · UNSTABLE", the phases in between applied in one hit |
| Floor 3, last phase | `boss-variety/f3-keeper-tempest-phase4.png` | "CIPHER KEEPER · TEMPEST", sweep beam, closing ring, mortar target |

Not captured (need a human playtest): whether each variant feels fair, the
Sentinel laser cross and the Warden's vents and pylon framed with the boss in view.
