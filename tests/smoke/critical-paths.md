# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off or gate check.
**Run via**: `/smoke-check` (reads this file)
**Owner**: QA Lead
**Update policy**: Add entries when a new core system ships. Never remove entries — mark as `[deferred]` if temporarily disabled.

---

## Core Stability (always run)

1. Game launches to main menu without crash or `push_error()` in the Output panel
2. New run can be started from the main menu — Preparation Phase loads
3. Main menu responds to all inputs (keyboard, mouse, gamepad) without freezing or error

## Prana Grid (add when PranaGrid sprint ships)

4. [DEFERRED] Player can place a Prana token in any of the 9 slots
5. [DEFERRED] Slot 4 (centre) empty → Confirm button is greyed out
6. [DEFERRED] Slot 4 filled → Confirm button enabled; pressing it emits `arrangement_confirmed`
7. [DEFERRED] Gamepad d-pad navigates all 9 slots; Place action fills the cursor slot
8. [DEFERRED] Grid locks on `combat_started` — no input accepted during Combat Phase

## Combination Resolution (add when CombinationResolution sprint ships)

9. [DEFERRED] Single Prana type in centre → valid single-type combo resolves without error
10. [DEFERRED] Deepfrost centre + Ashfire corner → Shatter interaction triggers on next hit

## Health and Damage (add when H&D sprint ships)

11. [DEFERRED] Enemy takes damage → HP reduces by the expected formula value
12. [DEFERRED] Fayde takes damage → HP reduces; death triggers `death_started` signal at 0 HP

## Performance

13. No visible frame rate drops during a full combat wave (target 60fps)
14. No `push_error()` entries accumulate in Output panel during 5 minutes of normal play

## Data Integrity (add when Save/Load sprint ships)

15. [DEFERRED] Save game completes without error; `.json` / `.tres` file written to disk
16. [DEFERRED] Load game restores all Autoload state (run count, currency, settings) correctly

---

*Deferred items are placeholders. Remove `[DEFERRED]` when the system they test ships.*
