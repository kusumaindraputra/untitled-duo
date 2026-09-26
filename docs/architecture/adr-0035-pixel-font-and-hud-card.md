# ADR-0035: Pixel Font, Body Font and a Lighter HUD Card

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

The art review found that the UI still used Godot's built-in sans font, which clashes
with the pixel art, and that the top-left HUD card was crowded and had a cream HP bar
instead of the art bible's health red. This ADR:

1. Makes **DotGothic16** (OFL) the theme's default font for titles, buttons and the
   HUD, and **Atkinson Hyperlegible** (OFL) the body font for long prose.
2. Colours the HP bar with the art bible's health red `#E61A0D`.
3. Stacks the left HUD card from measured row heights and drops the floor/room line
   from it during combat, so the card holds four rows instead of six.
4. Puts the Settings controls (action, key, pad) in one `GridContainer`, so the
   columns line up at every text size.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI |
| **Knowledge Risk** | LOW: `FontFile`, `FontVariation.fallbacks`, theme type variations, `gui/theme/custom_font` and `GridContainer` are unchanged since 4.0. |

## Context

- ADR-0032 added Text size 100 / 115 / 130 %. Any font has to stay readable and fit at
  all three sizes, which means non-integer pixel sizes.
- The art bible (§7.3) asks for an 8 px bitmap font, with no anti-aliasing and only
  8 / 16 px sizes. That rule predates the Text size setting.
- The HUD card placed every row at a fixed y. At 130 % the floor line spilled out of
  the card and the room line ran into the Style badge.
- In Settings each control row was its own `HBoxContainer`. When an action name was
  wider than its 104 px slot ("Move down", "Move right" at 130 %), that row's buttons
  shifted right of the others.

## Decision

### Fonts

Four pixel fonts were rendered side by side at 14 / 18 / 28 px: Pixelify Sans,
DotGothic16, VT323 and Silkscreen (plus Tiny5 and Jersey 10).

- **Pixelify Sans** was the first choice, but its "5" reads as "S" and its capital "E"
  is a rounded "€" shape. Key prompts ("E place", "C cycle") and HP numbers need to
  be exact.
- **Silkscreen** is capitals only and too wide for 130 %.
- **VT323** and **Tiny5** are too small at the HUD sizes.
- **DotGothic16** has plain letterforms and clear digits, and it is still clearly
  pixel art. It is chosen. The original file is a 2 MB CJK font. It is subset with
  fontTools to Latin, Latin Extended-A, punctuation, arrows, box drawing, shapes and
  symbols (117 KB), which OFL allows because the font declares no Reserved Font Name.

Anti-aliasing stays **on** (hinting off, subpixel positioning off). With it off,
glyphs rendered at 1.3× or 1.15× the design grid drop pixels unevenly ("Floor" read
as "Ploor" at 14 px). That is a deliberate deviation from art bible §7.3. The bible
owner has been asked to update the section.

Long prose uses **Atkinson Hyperlegible**, a font designed for low-vision
readability:

- The theme type variation `BodyLabel` (base `Label`) sets it. Labels opt in with
  `theme_type_variation = UIFeel.BODY_TEXT`: memory fragment body and footer, Memories
  and Spellbook detail text, Heirloom description, pause sigil list and run summary
  list.
- `RichTextLabel` uses it by default (normal and bold).
- The pixel font lists it as a fallback, so glyphs DotGothic16 lacks (for example "♥",
  "→") still render in a matching weight.

Files: `assets/ui/fonts/` (TTFs, OFL licences, README), `pixel_font.tres`
(`FontVariation`), theme `default_font`, and `gui/theme/custom_font` so
`ThemeDB.fallback_font` (used by `draw_string` in SpellVfx and ThreatIcon) matches.

### HP bar

- The fill is still a white `StyleBoxFlat` tinted by `hp_bar.modulate`.
- FULL and CAREFUL use `#E61A0D`. DESPERATE uses the hotter `#FF3333` and keeps its
  pulse and vignette.
- The numeric label carries the zone (white, amber `#FFA500`, red), so CAREFUL still
  reads at a glance.
- The hit flash is now white (`modulate = WHITE` shows the untinted fill), because the
  old pink flash was invisible on a red bar.

### Left HUD card

- `_layout_left_column(combat)` stacks rows at `LEFT_PAD` / `LEFT_ROW_GAP` from each
  label's `get_combined_minimum_size()`, and bars grow to fit their label. The card
  height follows the rows, and `LEFT_PANEL_HEIGHT` is removed.
- In combat the card holds HP, Special, dash and Style. Between rooms it holds HP,
  floor and room. The floor intro banner and the pause map already show where the
  player is during a fight.
- Text size is applied a frame after creation (ADR-0032), so the row labels'
  `minimum_size_changed` re-stacks the card once per frame.

### Settings controls

- One `GridContainer` (3 columns) holds the header and every row. Each column is as
  wide as its widest cell, so the key and pad buttons line up.

## Consequences

- A new screen gets the pixel font automatically. Long prose must opt into
  `UIFeel.BODY_TEXT`.
- Web and desktop builds grow by about 225 KB of fonts.
- `design/ux/hud.md` zone colours are updated. Art bible §7.3 (bitmap font, no AA)
  needs a matching edit by its owner.

## Validation

- `tests/unit/ui-fonts/ui_fonts_theme_test.gd`: theme default font, body font variation,
  fallback, memory modal opt-in, Settings columns aligned at 130 %.
- `tests/unit/combat-hud/combat_hud_layout_test.gd`: card rows never overlap at
  130 %, the floor line only between rooms, health red and white flash.
- `tests/unit/combat-hud/combat_hud_test.gd`: zone colours.
- Screenshots at 100 % and 130 %: `production/qa/evidence/f*-*.png`.

## Related

- ADR-0029 (UIFeel), ADR-0032 (Text size), art bible §4.4 and §7.3, `design/ux/hud.md`.
