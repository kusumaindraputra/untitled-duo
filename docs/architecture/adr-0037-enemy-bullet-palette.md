# ADR-0037: Enemy Bullet Palette

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Every enemy bullet, laser beam and mortar zone is drawn in one hostile colour
family, taken from `assets/data/enemy_bullet_palette.tres`:

- A shared **hostile rim** (magenta, `#FF339E`) for the bullet ring, glow, trail,
  laser edge, mortar rings, turret light and the enemy wind-up flash.
- A **core accent** per `BulletPattern.accent`: `mob` (pale pink) for ordinary
  enemies and hazards, and each boss's reserved colour from the art bible §4.3:
  Warped Warden B1 Corruption Violet `#9B2ED4`, Cipher Keeper B3 Cipher Rose
  `#D42E5E`, and for the Vault Sentinel a lighter mint `#57D9BA` of B2 Vault Teal
  (see below).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Gameplay VFX / Data |
| **Knowledge Risk** | LOW: typed `Dictionary[StringName, Color]` exports (4.4+) are already used by `AudioEventRegistry`; `draw_circle`/`draw_line` are unchanged. |

## Context

The art review found boss bullets in cyan, pink, orange and gold, which are the
same hues as the duo's Prana spells (Deepfrost, Ashfire, Stormgold). Each of the 27
`BulletPattern` files carried its own free-form `color`, so nothing kept enemy
fire apart from player spells. In a dense fight the player could not tell at a
glance which shots hurt them.

## Decision

### One family, told by the rim (chosen over one flat colour for every enemy)

A single flat colour would lose boss identity; free colours per pattern is the
problem we have. The rim + core split keeps both: the rim says "this hurts you"
on every enemy shot, the core says whose shot it is.

- `EnemyBulletPalette` (`src/data/enemy_bullet_palette.gd`) holds `rim`,
  `separator` and `cores: Dictionary[StringName, Color]`. `core_for()` falls back
  to the `mob` core for an empty or unknown accent.
- `BulletPattern.color` is replaced by `BulletPattern.accent: StringName`
  (default `&"mob"`). `core_color()` and the static `rim_color()` read the palette.
- The rim hue (328°) sits in the magenta gap the Prana palette leaves free
  (nearest Prana is Ashfire at 14°, 46° away). Mob cores are pale and low in
  saturation; boss cores reuse the colours already reserved for bosses, so the
  arena tint, the boss sprite and the boss's bullets agree.
- B2 Vault Teal `#23B39A` (hue 170°) is only 18° from Deepfrost's actual colour
  `#3DD9F0` (hue 188°; the art bible table lists 195°). On a 4 px bullet core
  that reads as an ice spell, so Sentinel bullets use `#57D9BA` (hue 166°, lower
  saturation, higher value): the same teal family, clear of Deepfrost and Verdant
  under the §4.3 rule. The Sentinel sprite keeps B2.
- Bullet draw order: family glow → optional ADR-0032 white/black outline → rim
  ring (r + 2.5) → dark separator (r + 1) → accent core → small white pip.
  The high-contrast outline widths move out to 5.5 / 3.5 px so the rim stays
  visible with the option on. Hit radii are unchanged.
- Lasers: telegraph, glow and edge in the rim; accent core; white centre line.
  Mortars: accent fill, rim rings. Wall impacts burst in the rim colour.
- Environmental hazards that are not bullets (vents, pylon beams) keep their own
  `HazardSpec.color`; only a turret's core light, which fires bullets, uses the rim.

## Consequences

- A new pattern needs only an `accent`; the default is the mob look. A new boss
  adds one `cores` entry and sets that accent on its patterns.
- The old `color` lines are gone from all pattern `.tres` files. A pattern from an
  older branch that still sets `color` must switch to `accent` when it merges;
  until then it draws as `mob`.
- Bullets look about 1 px larger on screen with the rim; their hitbox is the same.

## Validation

- `tests/unit/bullet-hell/enemy_bullet_palette_test.gd`: rim and every core pass
  the art bible §4.3 rule against all five Prana colours (40° hue gap, or at least
  20° plus a saturation + value gap); boss accents differ from each other and from
  mobs; every pattern file names a known accent and boss-prefixed files use their
  boss's accent; the projectile takes its core from the pattern and resets to mob.
- Evidence: `production/qa/evidence/art-bullets-before.png`, `art-bullets-after.png`,
  `art-bullets-after-high-contrast.png`, `art-bullets-ingame.png`.

## Related

- ADR-0018 (bullet patterns), ADR-0032 (high-contrast bullets),
  ADR-0034 (boss reserved colours on sprites)
- `design/art/art-bible.md` §4.2, §4.3
