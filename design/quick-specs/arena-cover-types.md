# Quick Spec: Arena Cover Types — Full Cover vs Half Cover

**Status:** Approved — implemented S9-09 (2026-06-17)
**Scope:** First Playable (FP) — debris placement in single arena
**Informed by:** Hades level design principles (Ed Gorinstein thread, 2026-06-17)

---

## The Rule

Arena obstacles fall into two classes:

| Class | Blocks Movement | Blocks Prana Spells | Blocks Rifter Projectiles | Physics Layer |
|-------|----------------|---------------------|--------------------------|---------------|
| **Full Cover** | Yes | Yes | Yes | Layer 1 (value 1) |
| **Half Cover** | Yes | No | No | Layer 5 (value 16) |

**Arena walls** = Full Cover. Nothing passes through the arena boundary.
**Debris** (broken machines, scrap) = Half Cover. Entities can't walk through, but energy passes freely.

---

## Design Rationale

Half cover creates a spatial reward for the Preparation phase: arranging Prana in a direction that fires through debris gives the duo an attack angle that enemies can't easily close. Enemies must walk around debris, taking longer to reach the active brother. Prana can fire straight through.

This directly enriches Pillar 2 (Power is Earned Through Understanding) without adding UI complexity.

---

## FP Implementation

3 debris nodes placed asymmetrically in the arena:
- **(80, -55)** — upper-right quadrant
- **(-100, 25)** — left-center
- **(45, 85)** — lower-center-right

Each debris: `StaticBody2D` on physics layer 16, `CollisionShape2D` with `CircleShape2D(radius=20)`, `NavigationObstacle2D(radius=25, avoidance_enabled=true)`.

---

## Collision Mask Changes (FP)

| Node | Old Mask | New Mask | Reason |
|------|----------|----------|--------|
| PlayerController (normal) | 5 (walls+enemies) | 21 (walls+enemies+debris) | Player can't walk through debris |
| PlayerController (dashing) | 1 (walls only) | 1 (unchanged) | Dash passes through debris — agile feel |
| EnemyInstance | 1 (walls only) | 17 (walls+debris) | Enemies path around debris |
| SCE ray (`_select_primary_target`) | default (all) | 5 (walls+enemies) | Prana passes through debris (layer 16 excluded) |

---

## MVP / VS Evolution

At MVP+, room authors assign each placed obstacle a `cover_type` property:
- `CoverType.FULL` — walls, heavy machinery, energy barriers
- `CoverType.HALF` — debris, low crates, rusted pillars

At VS+, certain Prana types (e.g. Deepfrost) may add a third class: **Full Penetration** (passes through even full cover at max tier) — creates a "snipe through walls" strategic option on the hardest enemy compositions.
