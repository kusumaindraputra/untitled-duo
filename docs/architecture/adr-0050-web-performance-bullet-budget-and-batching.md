# ADR-0050: Web Performance — Bullet Budget, Batched Bullet Art and Batched Room Edges

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Beta plan task 4.3 profiled the web build in the busiest fights: Floor 3 combat rooms
and the Cipher Keeper's last phase. The report is
`production/qa/perf-web-2026-09-27.md`. Four changes came out of it:

1. **Bullets redraw only when their look changes.** `Projectile` called `queue_redraw()`
   every physics frame although its drawing is in local space. It now redraws only while
   the trail grows, while a homing bullet turns, and during the end-of-range fade.
2. **Bullets draw as batched quads.** `BulletArt` bakes the trail, glow, rims, core and
   pip into a small texture once per radius and outline option. Each bullet draws four
   textured quads with `draw_primitive`, and quads with one texture batch into one draw
   call. Before, every bullet cost about two draw calls.
3. **Room edges draw as one batch.** The rim ledge (ADR-0038) and the platform edge
   (ADR-0021) were one `Polygon2D` or `Line2D` node per face, about 200 nodes and 200
   draw calls per room. They are now one `QuadBatch` each.
4. **A live bullet cap.** `BulletHellTuning.max_live_bullets` (240) is the most enemy
   bullets alive at once. At the cap a volley fires only the bullets that fit.

## Context

- The web export uses the Compatibility renderer (WebGL 2) without threads. The budget in
  `.claude/docs/technical-preferences.md` is 60 fps and under 200 draw calls per frame.
- The Compatibility renderer batches rects and primitives of up to four points that share
  a texture and material. Every `Polygon2D`, `Line2D` and `draw_circle` polygon is its own
  draw call. WebGL makes every draw call expensive, because the browser validates each one.
- Before this ADR, a Floor 3 room drew 200 to 466 draw calls. Bullets caused most of the
  growth (about 1.9 draw calls each), and the static room edges caused most of the base.
- The CPU cost per bullet was mostly the redraw: rebuilding seven canvas commands for every
  bullet on every frame. With 240 bullets that took 7.8 to 10.4 ms of physics time per frame
  natively, and WebAssembly is slower.
- FloorLighting (ADR-0043) was checked and is not a hotspot. Its pools are fixed (1 Fayde
  light, 6 pulses, 8 bullet lights), and turning it off changed draw calls by only a few.

## Decision

### Redraw gating

`Projectile.needs_redraw(alive, traveled, max_range, motion, homing_duration)` is a
static, testable rule. It is true while `alive <= TRAIL_GROW_TIME + REDRAW_SLACK_SEC`,
while a HOMING bullet is inside its homing window (plus slack), and inside the final
`DESPAWN_FADE_DIST`. `launch()` queues one redraw, so a reused bullet never shows its old
look. SINE bullets move their position, not their drawing, so they need no redraw.

### BulletArt

`src/visual/bullet_art.gd` is a static cache keyed by radius, outline option, rim colour
and separator colour. A key bakes one RGBA texture of four cells: the body (glow, optional
white and black outline rings, rim, separator), a white core disc, a white pip and a
solid white cell for the trail. Cells are baked at 2 texels per pixel, which matches the
2.0 combat zoom, with a one-texel anti-aliased edge, and are filtered linearly.
`Projectile._draw()` draws the trail quad, then the body, the core (tinted by the pattern
accent) and the pip, all multiplied by the fade. The colours and widths are the ones
ADR-0032 and ADR-0037 set.

### QuadBatch

`src/visual/quad_batch.gd` is a `Node2D` that stores four-point quads, each with per-corner
colours, and draws them with `draw_primitive` in `_draw()`. It draws once and redraws only
when a quad is added. `RoomDecor._build_ledge()` adds 5 quads per ledge tile (two faces,
the cap and two lip segments). `IsometricRoom._build_platform_edge()` adds one quad per
lower boundary edge. The node names `RimLedge` and `PlatformEdge` stay the same.

### Live bullet cap

`Projectile.at_cap(tree, cap := TUNING.max_live_bullets)` compares the size of the
`enemy_bullet` group to the cap. A cap of 0 turns it off. `BulletPool.acquire()` returns
null at the cap, and every caller (enemy pattern layers, hazard turrets, mortar splash)
stops that volley. The two legacy `Projectile.new()` paths in `EnemyInstance` check the
cap too. The value lives in `assets/data/bullet_hell_tuning.tres` (safe range 160–320).
The busiest measured fight peaks well below it, so the cap is a safety net for stacked
elites, Cursed rooms and Hard mode, not a change to any current pattern.

## Alternatives Considered

- **One renderer node for all bullets.** A single node would redraw every bullet every
  frame, which brings back the CPU cost that redraw gating removes. Batched quads per
  bullet give one draw call without that cost.
- **MultiMeshInstance2D for bullets.** This would give a single draw call, but it needs a
  transform buffer written every frame and a custom shader for the rim and core colours.
  It is more code for no measurable gain over batched quads.
- **Fewer bullets in the Keeper's patterns.** This would change the boss design. The
  measurements show the frame budget holds at the current density once draw calls batch.
- **Turning FloorLighting off on the web.** It is not a hotspot, and it is part of the
  combat look (ADR-0043).

## Consequences

- A Floor 3 fight draws about 110 to 160 draw calls instead of 200 to 466. Bullets add
  almost nothing: 240 bullets went from 460 draw calls to 1 in isolation.
- The per-bullet CPU cost drops by about 70 % (240 bullets: 7.8–10.4 ms down to 2.4–2.7 ms
  of physics time per frame, native).
- Changing the High-contrast bullets option in the pause menu restyles bullets already in
  flight only when they next redraw (their fade). New bullets use it at once.
- New bullet looks go through `BulletArt`, not new `draw_*` calls in `Projectile._draw()`.
  New static room geometry should use `QuadBatch` instead of one `Polygon2D` per face.
- `tools/perf/PerfProbe.tscn` stays in the repo as the profiling harness for later passes
  (beta plan 4.4 soak test). It is not reachable from the game.

## Engine Notes (Godot 4.6)

- `CanvasItem.draw_primitive(points, colors, uvs, texture)` takes 1 to 4 points. Four
  points draw a quad, and consecutive primitives with the same texture batch in the
  Compatibility renderer. This was checked by measurement (see the report), not assumed.
- `SceneTree.get_node_count_in_group()` is a direct size lookup, so the cap check is cheap
  enough to run for every bullet.

## Validation

- `tests/unit/performance/bullet_budget_test.gd`: the cap, `acquire()` at the cap, and the
  redraw rule.
- `tests/unit/performance/bullet_art_test.gd`: cache keys, body size, disc coverage and
  the baked rim colour.
- `tests/unit/room-visuals/`: updated to count `QuadBatch` quads.
- Screenshots in `production/qa/evidence/adr0050-*.png` compare bullets (normal and
  high-contrast) and a Floor 3 room before and after.
