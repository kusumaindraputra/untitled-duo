# First Playable Internal Playtest
**Date**: 2026-06-11
**Sprint**: S3 — First Playable
**Tester**: Kusuma Putra (developer self-test)
**Build**: main @ S3-11 session — all Sprint 3 Must Have complete + CombinationResolution

---

## Hard Criteria Checklist

| Criterion | Result | Notes |
|-----------|--------|-------|
| Launch from Godot → main.tscn loads without errors | PASS | |
| Preparation Phase: cast via keyboard shortcut works | PASS | Enter → combat starts; Space → cast |
| Combat starts: 10 enemies spawn simultaneously | PASS | Modulo-wrapped across 3 markers; spread offset applied |
| Enemies move toward Fayde | PASS | Direct vector movement |
| Fayde can cast and deal damage | PASS | Fixed after bug: raycast used wrong property name (`_facing_direction` vs `get_facing_direction()`) |
| Elemental 2× affiliation bonus applies | PASS | Verified via damage numbers (Ashfire vs Ashfire-weak enemy) |
| Enemies deal contact damage; HP bar updates live | PASS | |
| Fayde → 0 HP → result screen loads | PASS | Fixed after bug: PlayerController not connected to `player_died`; result overlay had zero-size Label |
| All enemies killed → result screen loads | PASS | Fixed after bug: same overlay issue + GSM state not reset on scene reload |
| No crash, softlock, or infinite loop | PASS | |
| All Must Have unit/integration tests pass headless | PASS | 539 tests, 0 failures, exit 0 |

**Hard criteria: 11/11 PASS**

---

## Bugs Found and Fixed During Session

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| `attack_index out of bounds` spam | No upper-bound guard in `_trigger_cast()` | Added `if _combo_index >= combo_count: return` |
| Enemies not spawning (WaveManager error) | Only 3 spawn markers for 10-enemy composition | Modulo wrap + spread offset on wrapped positions |
| Attack only hits facing right | `_fayde_ref.get("_facing_direction")` — wrong property name, always null → fallback `Vector2.RIGHT` | Changed to `get_facing_direction()` public method |
| Fayde moves after death | `player_died` not connected to PlayerController | Added `_on_player_died()` → DISABLED + zero velocity |
| No cast visual feedback | `_on_cast_hit_started` stub never connected to signal | Connected `SpellCastingEffects.cast_hit_started` in `_ready()`; cast beam via `debug_circle_2d` |
| Result screen not showing | `set_anchors_preset(PRESET_CENTER)` on zero-size Label = invisible | Full-rect anchors + centered alignment + dark ColorRect bg |
| R restart doesn't respawn enemies | `GameStateManager` Autoload persists across reload in non-MENU state; `start_run()` is no-op | Force `_active_state = MAIN_MENU` before `start_run()` in `debug_game_loop._ready()` |
| HUD elements stacked at (0,0) | No explicit position set on `hp_bar`, `hp_label`, `chain_dots_container` | Added explicit `position` and `size` to each in `_create_ui_nodes()` |
| Stacked enemies looked like 1 dot | Modulo wrapping put 3-4 enemies at identical position | Spread offset: `cos/sin(spawn_idx * 2.4) * 24px * wrap_lap` |

---

## Fun Hypothesis Assessment

> "If the player arranges Prana types in a 3×3 grid before a wave and then casts in combat, the act of deciding which combination to use — and having it work as planned — will feel like a meaningful, satisfying decision."

**Status**: PARTIALLY ASSESSABLE — developer self-test only, PranaGrid not yet implemented.

- The two-phase loop (Preparation → Combat) executes correctly and feels coherent.
- Casting with directional aim and seeing damage numbers is satisfying.
- Without the PranaGrid, the "grid decision" cannot be evaluated. Keyboard-shortcut fallback confirms the combat phase works but bypasses the core hypothesis.
- **External playtest with a real human tester required** before the fun hypothesis can be confirmed or falsified.

---

## Playtest Validation Criteria

| Criterion | Result |
|-----------|--------|
| Player arranges Prana grid with intent | NOT TESTED — PranaGrid not available; keyboard fallback used |
| Player identifies elemental strategy without prompting | NOT TESTED |
| All-Ashfire not first strategy reached | NOT TESTED |
| Weakness discovery (2× bonus) within 5 minutes | NOT TESTED — no external tester |
| No confusion loop > 30 seconds | PASS (developer knew controls) |

---

## Advisory Items

- [ ] CH-004 chain dot animation evidence (`production/qa/evidence/combat-hud-chain-evidence.md`) — chain dots visible during combat; formal screenshot evidence not captured this session
- Prana Grid (S3-17) needed before external fun hypothesis test is meaningful

---

## Next Steps

- PranaGrid implementation (ADR-0013 verified SAFE) required for proper fun hypothesis test
- Schedule external playtest session once PranaGrid is integrated
- Isometric view pass requested for next sprint
