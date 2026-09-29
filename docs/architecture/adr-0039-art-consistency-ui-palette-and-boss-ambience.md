# ADR-0039: Art Consistency Pass — UI Palette, Pixel Obstacles and Boss Ambience

## Status

Accepted

## Date

2026-09-27

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

An audit of in-game screenshots against `design/art/art-bible.md` found places where
the game breaks its own colour and shape rules. This pass fixes them:

1. **UI palette (`UIPalette`)**: one class holds the art bible §4.4 UI colours. The
   saturated "gold" used for titles, map rings and counters sat on Stormgold's hue
   (a Prana jewel tone), and secondary text used cool blue-greys. Both are replaced
   with lantern-warm E7 tones (`ACCENT`) and warm greys (`TEXT`, `TEXT_DIM`,
   `TEXT_FAINT`). The theme's default Label and RichTextLabel colour is now
   `#D4C9B8`, and panel fills moved from purple-black to shadowed E1 stone.
2. **No Prana or boss colours on UI**: floor-map markers were violet (Corruption
   Violet, the Warden's reserved colour) for Elite and Cursed and Verdant green for
   Rest. They are now stone, brass, moss, rust and dusty plum, all at or below 40 %
   saturation, and the letters still carry the meaning. Cipher Core names,
   the prep "continue" hint, the tutorial "done" tick and the off-screen boss arrow
   follow the same rule.
3. **Defeat screen mood (§2.5)**: the red wash and red "YOU DIED" became a cool,
   desaturated blue-grey wash with a cool title. The cause line uses a dusty rose.
4. **Title breath (§2.1)**: the game title cycles slowly through the five Prana
   colours and breathes once every two seconds (`TitleGlow`). It holds still with
   reduced motion.
5. **Pixel obstacles**: half-cover debris was drawn with smooth vector polygons in
   the same grey on every floor. It is now `PropArt.Prop.RUBBLE`, a 24×20 pixel
   sprite shown at 2× like the ADR-0038 props and painted in the floor's prop
   palette. Cover pillars lose their anti-aliased strokes and gain a 1 px outline.
   Their rune band was Deepfrost cyan and is now the floor's `prop_glow` (E7
   family). Floor 1 pillars moved from cool grey to warm stone.
6. **Boss arena ambience (§2.7, §4.3)**: `BossProfile` gains `reserved_color`
   (B1–B3), `ambience_strength` and `ambience_fade_sec`. When a boss spawns,
   `BossDirector` asks the room to tint its floor toward that colour
   (`IsometricRoom.set_ambience`). The tint drains when the boss leaves the tree.
   The phase banners were in the wrong hues (the Warden's banner was teal, the
   Sentinel's cyan). They are now each boss's reserved colour lifted for legibility.
7. **Copy and shape fixes**: the main menu subtitle said "Defeat the floor boss" (the
   one-floor demo line) and now reads "Survive three floors." like the in-game title.
   The main-menu vault arches are ogival instead of round (§3.3).
8. **Art bible**: the §4.2 table lists Deepfrost at HSL 188° (its real hex), and the
   hue-separation line and §4.3 note are updated for the Sentinel's lighter bullet
   core (`#57D9BA`, ADR-0037).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Rendering (2D) |
| **Knowledge Risk** | LOW. Uses `Theme` colours, `Tween`, `Sprite2D`, `CanvasItem.draw_*` with `antialiased = false`, all stable since 4.0. |
| **Post-Cutoff APIs Used** | None |

## Decision

### UIPalette is a const class, not a `.tres`

The palette is art direction mirrored from the art bible table, not gameplay
tuning. Many call sites are `const` declarations (`const TITLE_COLOR := ...`), and
a resource cannot feed a constant. A `class_name UIPalette` script with `const`
colours works in both places and gives tests one source to check against.
Gameplay-adjacent colour data (core accents, boss reserved colours, floor pillar
colours) stays in `.tres` resources.

### Boss colour on phase banners

Art bible §4.3 rule 1 kept boss colours off all UI. Phase banners are the boss
speaking, and the old banners were already coloured, only in the wrong hues. They now
use the boss's own hue, lifted to be readable. The rule is amended to allow the phase
banner. The HP bar, map and arrows still never use boss colours.

### Ambience tints the floor only

`set_ambience` tweens the floor `TileMapLayer.modulate` toward
`base * reserved_color` by `ambience_strength` (0.22). Characters, bullets and
Prana VFX are not affected, so jewel tones keep full strength against the boss's
tint ("acts of defiance", §2.7). `ambience_tint()` is a pure static function so the
maths is unit-tested.

## Alternatives Considered

- **CanvasModulate for the boss tint**: this also tints the duo and spell VFX,
  which the art bible forbids. Rejected.
- **Rebuilding the pillar as a baked pixel texture**: this would need textures for
  each crack stage and the hit flash. Removing anti-aliasing and adding the outline
  gets the pixel read at a fraction of the work. Deferred.
- **Circular Prana slots and an octagonal grid frame (§3.4)**: a real gap, but it
  touches drag-and-drop hit areas and the grid layout. It is out of scope for a
  colour pass and is logged below.

## Consequences

- New UI code should use `UIPalette` colours. A hard-coded saturated colour on UI
  is now a visible inconsistency, and `art_consistency_test.gd` guards the palette.
- `CoverPillar.setup()` takes an optional `band_color`. `IsometricRoom.apply_floor_look()`
  also repaints existing debris and pillars.
- Known gaps left for later: circular slots and an octagonal grid frame (§3.4),
  the prep→combat 0.3 s ambient dim (§2.3), and the crumple pose in the defeat
  sequence (§5.3).

## Validation

- `tests/unit/art-consistency/art_consistency_test.gd`: palette saturation cap,
  theme label colour, core accents, title glow maths, boss reserved colours and
  banner hues, ambience tint maths and floor tinting, pillar rune colour, and
  rubble painted in each floor's palette.
- Before and after screenshots are in `production/qa/evidence/adr0039-*.png`.
