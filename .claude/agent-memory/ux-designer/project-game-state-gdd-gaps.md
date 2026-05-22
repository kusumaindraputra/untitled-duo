---
name: project-game-state-gdd-gaps
description: UX/accessibility gaps in game-state-scene-flow.md from adversarial review 2026-05-22; four BLOCKING findings must be resolved before UX specs can be authored
metadata:
  type: project
---

Adversarial UX review of `design/gdd/game-state-scene-flow.md` (reviewed 2026-05-22).
Severity tags: [BLOCKING], [RECOMMENDED], [ADVISORY].

**Why:** Several deferments in UI Requirements and Visual/Audio Requirements are structural information design decisions — not visual styling decisions — making them blocking for downstream UX spec authoring and implementation.

**How to apply:** Do not author UX specs for `design/ux/main-menu.md`, `design/ux/death-screen.md`, `design/ux/run-summary.md`, `design/ux/path-selection.md`, or `design/ux/ciphers-trial.md` until all BLOCKING items below are resolved in the GDD.

## [BLOCKING] Finding 1 — No Quit-to-Menu Path During an MVP Run

The MVP PAUSED state has exactly one action (resume). No `PAUSED → MAIN_MENU` transition exists in the MVP valid transitions table. Full Pause Menu UI is deferred to VS (GDD #25). A player who needs to abandon a run has no exit path short of closing the application. This is a hard usability and accessibility failure for a 7+ audience.

**Fix:** Add a single "Quit to Menu" action to the MVP pause overlay, and add `PAUSED → MAIN_MENU` as a valid MVP transition. The full Pause Menu GDD (#25) retains ownership of settings and advanced options.

## [BLOCKING] Finding 2 — HUD Interactive Elements Have No Keyboard Navigation Spec

The UI Requirements mandate keyboard navigation for `MAIN_MENU`, `RUN_SUMMARY`, and `DEATH_SCREEN` only. The persistent HUD is absent. The GDD neither enumerates which HUD elements are interactive nor asserts that the HUD contains no interactive elements. Combat HUD GDD #22 has not been authored yet. Implementers have no guardrails.

**Fix:** The GDD must either (a) assert that all HUD interaction is handled by key binding only (no pointer-only controls on the HUD), or (b) require that Combat HUD GDD #22 define the full keyboard navigation model for any interactive HUD element before PREPARATION_PHASE or COMBAT_PHASE implementation proceeds.

## [BLOCKING] Finding 3 — Keyboard Focus Ownership During Overlays Is Unspecified

Core Rule 3 addresses `mouse_filter = MOUSE_FILTER_IGNORE` for overlay mouse pass-through but says nothing about keyboard or gamepad focus. When a lore fragment overlay appears during `PREPARATION_PHASE`, the GDD does not specify: (a) whether keyboard focus shifts to the overlay's dismiss control, (b) what happens to Prana grid focus while the overlay is visible, or (c) whether focus is restored to the grid after dismissal.

**Fix:** Core Rule 3 must add a focus management requirement: overlay appearance shifts keyboard/gamepad focus to the overlay's primary action; dismissal restores focus to the prior focused element.

## [RECOMMENDED] Finding 4 — Cipher's Trial Pre-Entry Affordance Has No Verification AC

Core Rule 6 states "the information requirement is not deferrable" but the visual design is deferred to the VS UX spec. No acceptance criterion verifies this affordance exists before Path Selection implementation proceeds. AC-VS-11 covers disabled-option affordance inside Cipher's Trial, not the pre-entry node map affordance. A credible path exists where Path Selection ships without the pre-entry affordance ever being verified.

**Fix:** Add a `[V]` acceptance criterion: "GIVEN the Path Selection map is displayed, WHEN a Cipher's Trial node is present, THEN a non-color-only affordance indicating committed-interaction is visible without hover or selection."

## [RECOMMENDED] Finding 5 — DEATH_SCREEN Has No Content Constraints for 7+ Audience

Visual/Audio Requirements are entirely "[To be designed]." No content constraint exists for DEATH_SCREEN: no prohibition on distressing imagery, no tone guidance. The Prana bloom dissolve convention is established for enemies but Fayde's death has no equivalent specification. Implementers have no guardrails for a 7+ audience.

**Fix:** Visual/Audio Requirements must include at minimum: death state must not display blood, distressing imagery, or threatening language; failure framing must be consistent with the game's "mysterious, not threatening" tone.

## [BLOCKING] Finding 6 — PREPARATION_PHASE Keyboard/Gamepad Navigation Model Absent for MVP State

The GDD acknowledges the Prana grid is mouse-optimized and that an alternative keyboard/gamepad model is needed (`technical-preferences.md`). Neither the GDD nor a cross-reference defines this model. The UI Requirements section defers gamepad navigation only for VS states. PREPARATION_PHASE is the most interaction-dense MVP state. Deferring this to Prana Grid GDD #1 without an explicit requirement creates a compounding deferment risk — if GDD #1 also defers it, there is no owner.

**Fix:** The GDD must explicitly require that Prana Grid GDD #1 define the full keyboard and gamepad navigation model for grid interaction before MVP PREPARATION_PHASE implementation proceeds. If GDD #1 also defers it, the producer must resolve the ownership gap as a cross-GDD blocker.
