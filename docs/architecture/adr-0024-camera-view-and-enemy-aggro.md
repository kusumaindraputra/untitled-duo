# ADR-0024: Combat Camera View and Enemy Aggro

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The combat camera moves in from 1.5× to 2.0× zoom, and enemies of a room's
opening wave now spawn dormant and wake when the duo comes within an aggro radius.
Both sets of numbers moved out of code constants into `.tres` resources:
`assets/data/camera_tuning.tres` and `assets/data/enemy_awareness_tuning.tres`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Camera / Enemy AI |
| **Knowledge Risk** | LOW: only `Camera2D.zoom`, `Resource` exports and `Tween`, all unchanged since 4.0 |

## Context

- The base viewport is 1152×648. At 1.5× the combat view showed 768×432 game px,
  and the duo (about 32 px of art) filled about 7% of the screen height. Playtest
  feedback: the view felt too wide.
- Every enemy chased and fired from the moment it spawned, including ones on the
  far side of a 1280×768 arena, well outside the view. There was no aggro range.
- Reference points, estimated from screenshots at native resolution (character
  height as a share of screen height, and how far you see):

| Game | Character height | Feel |
|------|------------------|------|
| Diablo II (800×600) | ~12% | close, ~1 screen of monsters around you |
| Diablo III / IV (default zoom) | ~10–12% | close, monsters aggro as they enter the screen |
| Hades | ~9–10% | medium, the whole room rarely fits |
| Enter the Gungeon | ~8–9% | medium-wide, bullets need room to read |
| The Last Cipher at 1.5× (old) | ~7% | wide |

## Decision

### Camera

| Knob | Old | New | Visible area |
|------|-----|-----|--------------|
| `combat_zoom` | 1.5 | **2.0** | 576×324 game px, the duo ~10% of height |
| `boss_reveal_zoom` | 1.0 | **1.4** | 823×463, still a pull-out from combat |
| `prep_zoom` | 0.55 | 0.55 | whole arena |
| `look_ahead_max` | 30 | **40** | more lead in the move direction |
| `smooth_speed` | 8 | 8 | |

2.0 sits between Hades and Diablo. Going to a full Diablo 2.4× (480×270) was
tried and left out as the default: the view gets short vertically, and a
150 px/s bullet entering at the top or bottom edge reaches the active brother in 0.9 s
(1.08 s at 2.0, 1.44 s at 1.5). The test suite keeps `combat_zoom` inside
1.5–2.6.

### Enemy aggro

- WaveManager calls `EnemyInstance.enter_dormant()` on every opening-wave spawn.
  Reinforcements arrive awake (they are the fight escalating) and bosses ignore
  it.
- A dormant enemy stands still and runs no bullet patterns.
- It wakes when any of these happens:
  - The duo is within `aggro_radius` = **230** ground px.
  - It takes damage.
  - An ally within `alert_link_radius` = **170** of it wakes up, so packs pull
    together.
  - `max_dormant_sec` = **6 s** of combat has passed, so a room never stalls.
- Distance is measured on the isometric floor: screen y is multiplied by
  `iso_y_scale` = 2 first, so the aggro area is a 2:1 ellipse on screen that
  matches the diamond floor. 230 means 230 px to the side or 115 px above or
  below the duo. That ellipse fits inside the 576×324 combat view, so an enemy is
  always on screen before it wakes and starts shooting. A test locks that
  relationship in, so changing one value without the other fails CI.
- A waking enemy pops a pixel "!" above its head for 0.5 s and emits `alerted`.

## Alternatives Considered

- **Diablo zoom (2.4×) as the default.** Closer and more personal, but too
  little vertical warning for bullet patterns. It is one value in
  `camera_tuning.tres` if the playtest prefers it.
- **Aggro by line of sight.** Needs raycasts per enemy per frame and makes cover
  pillars also block waking. Radius plus alert-on-hit is enough for rooms this
  size.
- **Enemies lose aggro when the duo leaves.** In a bullet hell with small rooms
  this reads as enemies forgetting her mid-fight. Once awake they stay awake.

## Consequences

- Rooms open calmer: the player sees the pack before it fires, and pulls it.
- Enemies far across the arena no longer fire from off screen at the start.
- Tuning either feature is a `.tres` edit, with no code change.
- `PlayerController` no longer has the `ZOOM_COMBAT`, `ZOOM_PREP`,
  `BOSS_REVEAL_ZOOM`, `BOSS_REVEAL_HOLD_SEC`, `CAMERA_SMOOTH_SPEED` and
  `CAMERA_LOOK_AHEAD_MAX` constants. They are read from `CAMERA_TUNING`.
