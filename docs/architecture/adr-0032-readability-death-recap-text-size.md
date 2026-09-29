# ADR-0032: Floor Map Legend, Threat Icons, Death Recap and Text Size

## Status

Accepted

## Date

2026-09-26

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Four readability and accessibility changes for the closed beta:

1. **Floor map**: `FloorMap` nodes, spacing and letters are larger in the HUD, and the
   map gains `map_scale`, `snapshot()` and `from_snapshot()`. `CombatHUD.get_floor_map_data()`
   hands the current map to the game loop, which passes it to `PausePanel` as `map`.
   The pause screen draws it at 1.25× with a legend for room letters, modifiers,
   "you are here", visited rooms and the enemy threat icons.
2. **Threat icons**: `ThreatIcon` (`src/ui/threat_icon.gd`) replaces the name labels
   the wave preview drew over each enemy during preparation. Its kind comes from the
   `EnemyType`: boss, rusher and swarmer archetypes first, then the strongest pattern
   (laser, mortar, bullets), then a death pattern (splits). Every kind has its own
   shape; the ring carries the enemy colour, elites get a second gold ring, and a
   swarm shows one icon with a count.
3. **Death recap**: `HealthAndDamage.apply_damage()` takes an optional `cause`
   Dictionary (`DeathRecap.cause(attacker, attack)`). A hit on the duo that deals damage
   stores it in `last_player_hit`, cleared on `run_started`. Enemies, bullets, lasers,
   mortar shells (and their splash) and stage hazards all pass a cause.
   `DeathRecap.line()` turns it into "Killed by Rifter · a fan of bullets", which the
   run summary shows on a loss.
4. **Accessibility settings**: `GameSettings` gains `text_scale_idx` (100 / 115 / 130 %)
   and `bullet_outline`. `UIFeel` scales the font sizes of every Label, Button,
   LineEdit and RichTextLabel one frame after it enters the tree and keeps the
   unscaled sizes in meta, so the Settings panel can rescale open screens at once.
   `UIFeel.fit_to_viewport()` shrinks the Settings panel and the main menu column
   just enough to stay on screen at 130 %. Bullets draw a white-and-black outline
   when `bullet_outline` is on.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Combat feedback / Settings |
| **Knowledge Risk** | LOW: `CanvasItem` draw calls, theme font-size overrides, `SceneTree.node_added` and `ConfigFile` are unchanged in 4.6. |

## Context

Beta feedback items 4–7 from the improvement review: the HUD map letters were barely
legible, preview name labels overlapped when enemies stood close, a loss did not say
what killed the player, and Settings had no text size or bullet contrast option.
`ui-code.md` already requires scalable text.

## Decision

- The cause of a hit travels with the hit. `apply_damage()` gets an optional last
  parameter so no existing caller changes behaviour, and bullets carry their cause
  in a field that the pool clears on reuse.
- Attack names come from the pattern's data (kind, motion, shape), so new patterns
  need no code change. Player text lives in `UICopy` (`death_attack_names`,
  `death_hazard_names`).
- Text size is applied globally through the existing `UIFeel` autoload instead of in
  each screen, because most screens set explicit font-size overrides.
- Screens that could overflow at 130 % shrink to fit instead of scrolling.

## Alternatives Considered

- **`Window.content_scale_factor` for UI size**: rejected. It zooms the game world
  as well as the UI.
- **Scaling each UI CanvasLayer**: rejected. Full-screen anchored layouts would run
  off screen.
- **Tracking the killer in the game loop from `damage_taken`**: rejected. The signal
  has no source, and every call site would still need to report it.
- **Short names instead of icons over enemies**: rejected. Names still overlap and
  do not say what the enemy does.

## Consequences

- Any new source that damages the duo should pass a `DeathRecap.cause()`; without one
  the recap reads "the duo fell."
- Code that sets a font size on a Label after it entered the tree keeps working: the
  new size becomes the unscaled size on the next rescale.
- Screens added later should be checked at 130 % text and use
  `UIFeel.fit_to_viewport()` when they could overflow.

## Validation

- `tests/unit/death-recap/death_recap_test.gd`
- `tests/unit/threat-icons/threat_icon_test.gd`
- `tests/unit/pause/pause_panel_map_legend_test.gd`
- `tests/unit/accessibility/text_size_and_outline_test.gd`
- Evidence: `production/qa/evidence/r4-pause-map-legend.png`, `r5-threat-icons.png`,
  `r6-death-recap.png`, `r7-settings-130.png`, `r7-menu-130.png`, `r7-bullet-outline.png`
