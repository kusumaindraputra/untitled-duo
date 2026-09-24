# Bullet Hell Layer — Visual Evidence (ADR-0018)

Captured 2026-09-24 with `--write-movie` under xvfb (Godot 4.6.2, Compatibility
renderer, god mode on) from a throwaway harness that boots `demo.tscn` straight into
combat with a scripted composition.

| Shot | What it shows |
|------|---------------|
| `bullet-hell/roster-combat.png` | Mortar closing rings on Fayde, Weaver sine fans (green), Rifter fans (blue), an elite Rifter's golden aura and homing shots, a Sniper laser telegraph (red line, right), Fayde's white hurtbox dot. |
| `bullet-hell/boss-phase3.png` | Warped Warden below 33 % HP: "PHASE 3" callout, 4-arm spiral (violet), ring wall (pink) and the SLAM telegraph. |

Checks: every volley is telegraphed (windup glow, laser line, mortar ring); bullets draw
above entities with a dark rim; the hurtbox dot draws above bullets.
Headless counts at 4 s in the roster run: 57 Spinner, 48 Weaver, 6 Rifter bullets live;
no script errors.
