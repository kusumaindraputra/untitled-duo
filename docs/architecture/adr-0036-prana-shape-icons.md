# ADR-0036: Prana Shape Icons

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Every Prana type gets a pixel shape icon so it reads without colour, as art bible
§4.5 requires. The icons are 12×12 white silhouettes in `assets/art/ui/prana_icons/`
(flame, eye, bolt, snowflake, clover), set as `PranaType.icon` in the five
`assets/data/prana_types/*.tres`. `PranaIcon` (`src/ui/prana_icon.gd`) scales them by
whole numbers and puts them on screen:

| Place | Size | Tint |
|-------|------|------|
| Prep grid slot (`PranaGridSlot`) | 3× (36 px) | black on the Prana colour |
| Bag token (`PranaTypeToken`), above the short name | 2× (24 px) | black on the Prana colour |
| Drag preview (slot and token) | 3× | Prana colour |
| Core Prana pick card (`debug_game_loop.gd`), above the name | 4× (48 px) | Prana colour |
| Prana sigil card (`SigilManager`) | 2× | Prana colour |
| Pause build mini grid (`PausePanel`) | 2× | black on the Prana colour |

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI |
| **Knowledge Risk** | LOW. `Image.resize(..., INTERPOLATE_NEAREST)`, `ImageTexture.create_from_image`, `Button.vertical_icon_alignment` (4.1+) and static vars (4.1+) predate 4.4. |
| **Post-Cutoff APIs Used** | None |

## Context

The grid slots were plain colour squares and the core pick showed only "ASH / VOID /
STRM / DEEP / VERD" text in the Prana colour. Ashfire and Verdant collapse to the same
brown under deuteranopia and protanopia (art bible §4.5, HIGH risk), and the art bible
lists shape icons as the mandatory backup cue. `PranaType.icon` already existed but
held empty placeholder textures.

## Decision

- Author the icons at 12×12, the art bible's colour-blind size, instead of 8×8. The
  test checks that the five silhouettes still differ when squeezed to 8×8, which is
  the art bible's validation rule.
- Keep the icons white and tint them per use, so one file serves both "black on
  colour" tiles and "colour on dark" buttons.
- Scale in code with nearest-neighbour into a cached `ImageTexture` rather than rely
  on `texture_filter`: the project default filter is linear, and `Button.icon` has no
  per-icon filter. The cache is keyed by type and scale.
- `PranaCatalog.get_type_icon(id)` returns the shared texture without the
  `duplicate_deep()` cost of `get_type()`, like `get_type_color()`.
- Icons are always on. The art bible's optional colour-blind toggle (12 px plus a
  letter) is covered: the icons already use 12 px art and the bag tokens keep the
  short name under the icon.
- No theme changes; the icons sit inside whatever theme the font and HUD pass sets.

## Alternatives Considered

- **8×8 art**: five distinct silhouettes at 8×8 lose the flame's spikes and the
  snowflake's arms. 12×12 keeps them and still passes the 8×8 distinctness test.
- **RichTextLabel `[img]` icons in the spell preview**: `[img]` loads by path and
  would draw the 12 px file with the linear filter. The preview keeps its coloured
  short names; the grid right above it shows the icons.
- **SVG icons**: would blur at small sizes and clash with the pixel art.

## Consequences

- New Prana UI should call `PranaIcon.make_rect()` or `PranaIcon.apply_to_button()`.
- A sixth Prana type needs a 12×12 icon whose 8×8 silhouette differs from the others,
  or `prana_icons_test.gd` fails.
- The drag preview used to be a bare number (slot) or name (token); it is now the icon.

## Validation

- `tests/unit/prana-icons/prana_icons_test.gd`: every type has a 12×12 icon, the
  silhouettes are distinct at 12 and 8 px, `PranaIcon.texture()` scales and caches,
  and a grid slot shows the icon only while filled.
- Screenshots: `production/qa/evidence/a3-prana-icons-*.png` (core pick, prep grid,
  pause build, sigil offer).
