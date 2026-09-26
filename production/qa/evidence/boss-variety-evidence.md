# Evidence — Floor Bosses and Per-Run Variants (ADR-0028)

Captured with Xvfb (OpenGL 3, 1152×648) from a throwaway driver that starts a run,
puts the first room in boss mode for the chosen floor, forces one variant, keeps
Fayde next to the boss so it stays in frame, and deals a fixed share of the boss's
HP to cross its thresholds. The HUD counts phases from 1 at full HP, so "PHASE 2"
is the first HP phase. Automated tests: 1403 passing.

| Screen | File | What to check |
|--------|------|---------------|
| F1 intro | `boss-variety/boss-f1-sentinel-lockdown-intro.png` | "VAULT SENTINEL · LOCKDOWN" name card, aimed double fan |
| F1 phase 1 | `boss-variety/boss-f1-sentinel-lockdown-phase2.png` | Ring pair, turret volleys (orange), Lockdown's aimed laser |
| F1 phase 2 | `boss-variety/boss-f1-sentinel-overclocked-phase3.png` | Overclocked red tint, laser cross phase, turrets still firing |
| F2 phase 1 | `boss-variety/boss-f2-warden-unstable-phase2.png` | Sine spiral, homing fan, burning vents |
| F2 last phase | `boss-variety/boss-f2-warden-mirrored-phase4.png` | Mirrored double spiral, collapsing ring wall, mortar splash, vents |
| F3 phase 1 | `boss-variety/boss-f3-keeper-fractured-phase2.png` | Fractured's triple laser, lattice, homing ring |
| F3 last phase | `boss-variety/boss-f3-keeper-tempest-phase4.png` | Tempest: sweep beam, closing ring, mortar, weave |

Not captured (need a human playtest): whether each variant feels fair.
