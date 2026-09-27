# ADR-0038: Floor Identity — Props, Backdrop Silhouettes and Whimsy

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Each floor gets its own visual set on top of the palette from ADR-0021:

1. **Motif tiles**: the floor's `RoomLook.motif` (SCRAP, CONDUIT, CRYSTAL) adds a
   fifth floor-tile variant. It is a riveted rust plate on floor 1, a conduit groove
   on floor 2 and a glowing crystal vein on floor 3.
2. **Backdrop silhouettes**: the backdrop shader draws the motif in the void on a
   coarse pixel grid. Floor 1 shows junk-heap skylines with leaning girders, floor 2
   shows pipe runs and risers, and floor 3 shows crystal shards rising and hanging.
   This replaces the empty "star" void.
3. **Background props**: `RoomDecor` builds a raised stone ledge one tile outside
   the far (upper) boundary edges. It places 3–5 motif props on the ledge (art
   bible §6.4) and hangs motif props off the slab face under the near edges.
   Boss rooms get a single broken column instead (art bible: 1 architectural
   accent, 0 props).
4. **Whimsy**: every room has exactly one small animated detail from the floor's
   pool, placed on a free ledge tile (art bible Principle 3). Floor 1 has a tin
   critter, a sprouting kettle or breathing moss. Floor 2 has a steam vent or a
   lamp with a moth. Floor 3 has a chiming crystal or a spore mushroom.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / Environment |
| **Knowledge Risk** | LOW: `Image`, `ImageTexture`, `Sprite2D`, `Polygon2D`, `CanvasItem._draw()` and canvas shaders are unchanged in 4.4–4.6. |

## Context

The art review found that the three floors differed only by tint. The same stone
tiles sat in the same empty star-dust void, so a player could not tell Deep Scrap
Yard from Cipher Core without reading the HUD. The art bible asks for a
"ruined facility colonised by machine" (§6.1), one whimsy detail per room
(Principle 3) and restrained prop counts (§6.4). The constraint is that
collision, navigation and the stage layouts from ADR-0020 must not change.

## Decision

- **Data**: `RoomLook` gains a `motif` enum, `motif_chance`, `whimsy_kinds`
  (a `RoomLook.Whimsy` pool), a prop palette (`prop_dark/mid/light/glow`),
  `rim_props_min/max`, `face_props` and a backdrop `silhouette` colour. Floor
  identity lives in the three `room_look_floor*.tres` files. The defaults stay
  STONE, so an unthemed room looks as it did before.
- **Art**: `PropArt` paints every prop at runtime as tones (outline, body, light,
  glow) on a small canvas and colours them from the look. It uses no RNG, so the
  same look always gives the same image. Props and whimsy details are drawn at 2
  world pixels per art pixel so they read at the prep zoom.
- **Placement**: `RoomDecor.ledge_cells()` mirrors each floor tile across its
  upper boundary edge, so every ledge tile lies outside the TileMapLayer. The ledge
  is drawn with `Polygon2D` and never added to the tile map. No decor node owns a
  `CollisionObject2D`, `CollisionShape2D` or `NavigationObstacle2D`. Rim props keep
  90 px from exit doors and spawn points. Standing props use the character depth
  rule (`z = y + 500`), so anyone at the rim draws in front of them.
- **First room**: main.tscn builds its first room before the floor theme is known.
  `IsometricRoom.apply_floor_look()` re-skins that room (tiles, platform edge,
  backdrop, decor) from `debug_game_loop._ready()` without touching its layout.
- **Reduce motion**: `WhimsyDetail` holds a still pose while
  `GameSettings.motion_reduced()` is true.

## Alternatives Considered

- **Props on floor tiles without collision.** Rejected: a rock that looks solid
  but lets Fayde walk through reads as a bug, and it would crowd the bullet-hell
  readability work.
- **Hand-drawn prop PNGs.** Deferred: no artist asset pipeline exists yet, and
  procedural art keeps the look data-driven and palette-locked. `PropArt.texture()`
  is the single swap point when illustrated props arrive.
- **Tint-only backdrops.** Rejected: that is the current state the review flagged.

## Consequences

- Positive: each floor is recognisable at a glance, and every room carries a
  detail that rewards a pause. Layout, collision and pathing are unchanged. Tests
  build the same room with two decor seeds and compare floor tiles and walls.
- Negative: decor adds about 10–25 canvas items per room, which is well inside the
  200 draw-call budget. The procedural props are simpler than hand-drawn art.
- The art bible's "no procedural texture generation" rule (§6.3) is bent here the
  same way ADR-0021 bent it for tiles, until illustrated assets exist.

## Validation

`tests/unit/room-visuals/floor_identity_test.gd` checks that each floor has a
distinct motif and whimsy pool, that props are deterministic and use only their
palette below jewel saturation, that decor has no collision or navigation nodes,
that ledge, props and whimsy lie off the walkable floor and keep clear of doors,
that boss rooms get one accent, that the decor seed does not change the layout,
and that the first-room re-skin works. Screenshots are in
`production/qa/evidence/adr0038-*.png`.

## Related

- ADR-0020 (stage layout, floor themes), ADR-0021 (procedural room visuals)
- design/art/art-bible.md §6.1, §6.4, Principle 3
- design/gdd/stage-layout.md
