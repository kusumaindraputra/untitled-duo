# ADR-0021: Procedural Environment Look and Game UI Theme

## Status

Accepted

## Date

2026-09-25

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The world no longer looks like a debug build. The floor, the platform edge, the void
behind the room and the UI chrome are now generated from data: a **RoomLook** palette
per floor builds the floor tiles, a slab face under the room edge, a backdrop with glow,
fog and dust, and a vignette. A project-wide **UI theme** styles panels, buttons, bars
and sliders. Characters stay as placeholders until illustrated sprites arrive through
the art bible's pipeline (§10). Design: `design/gdd/stage-layout.md` (Floors, Look).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering (2D, Compatibility renderer) / UI |
| **Knowledge Risk** | LOW: `Image`, `ImageTexture`, `TileSetAtlasSource`, `Polygon2D.vertex_colors`, canvas_item shaders and `Theme` are unchanged since 4.0. 4.4's shader texture type change does not apply (no texture uniforms). |

## ADR Dependencies

- ADR-0020 (stage layout): `FloorTheme` gains a `look`; pillar and debris colours
  stay on `FloorTheme`.

## Context

Every visual was a placeholder. The only art file was a sand-coloured 64×32 floor tile
that contradicted the art bible palette (§4.1 wants dark, low-saturation earth so Prana
colours scream). The room floated on a flat grey clear colour, and all UI used Godot's
default grey theme. Illustrated art is planned (art bible §10) but is weeks of work;
the environment and UI can look finished now without any art files.

## Decision

1. **`RoomLook` resource** (`src/data/room_look.gd`, `assets/data/room_looks/*.tres`):
   floor base, worn, seam, highlight and accent colours; variant chances; platform
   face colours and depth; backdrop gradient, glow and dust colours; vignette strength.
   Defaults are the art bible E1–E7 palette. `FloorTheme.look` points at one per floor;
   a room without one uses the defaults.
2. **`FloorTileAtlas`** (`src/visual/floor_tile_atlas.gd`) paints a 4-tile atlas
   (plain, worn, cracked, etched glyph) pixel by pixel from the look plus an integer
   hash. `variant_for_cell` picks a variant from the cell's hash, so a room looks the
   same every time it is built and tests are deterministic.
3. **Platform edge**: `IsometricRoom` hangs a gradient `Polygon2D` face under each
   boundary edge on the lower half of its tile, at z −1 under the tiles. Left faces
   are lit, right faces 25 % darker.
4. **`RoomBackdrop`** (`src/visual/room_backdrop.gd`) adds two screen-space
   CanvasLayers owned by the room: layer −10 (`room_backdrop.gdshader`: gradient,
   pooled glow, fog, drifting dust) and layer 1 (`vignette.gdshader`), below the
   CombatHUD at layer 10 and every overlay above it.
5. **UI theme** (`assets/ui/game_theme.tres`) set as `gui/theme/custom`. Explicit
   per-node overrides in code still win, so HUD colour logic is unchanged.
6. The clear colour is E6 so menus and transitions never flash grey.

## Alternatives Considered

- **CC0 asset packs**: fastest to look finished, but their clean cartoon style would
  replace the art bible's HD-2D direction. Rejected by the user in favour of this
  interim plus illustrated characters later.
- **2D glow through `WorldEnvironment`**: tried with the Compatibility renderer; no
  visible bloom on the Prana bullets without HDR 2D. Bullets already draw their own
  halos, so glow was left out.
- **Hand-made tile PNGs**: blocked on art production; the procedural atlas can be
  swapped for a real tileset later without touching room code (it only feeds
  `_install_floor_atlas`).

## Consequences

- Positive: every floor has a distinct mood from three small .tres files; no binary
  art in the repo; screenshots now match the art bible palette.
- Negative: tiles are generated at room load (4 × 64×32 pixels, negligible). The
  backdrop shader runs one full-screen pass per frame; cheap on Compatibility.
- The old `assets/art/tiles/iso_floor_stone2.png` is deleted.
- Characters, enemies and Prana tokens are unchanged by this ADR.

## Validation

- `tests/unit/room-visuals/room_visuals_test.gd` (16 cases): atlas size, diamond mask,
  determinism, colours follow the look, variant chances, backdrop layers and
  parameters, every floor theme has its own look, rooms build variants, edges and
  backdrop.
- Visual evidence: `production/qa/evidence/room-visuals-evidence.md`.
