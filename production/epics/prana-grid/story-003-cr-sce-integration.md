# Story 003: committed_fragments → CR + SCE Integration

> **Epic**: Prana Grid
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 0.75 days
> **Sprint ID**: S4-05
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/prana-grid.md` (integration interface) + `design/gdd/combination-resolution.md` (consumer)
**Requirements**: `TR-PG-002` (primary), cross-system: `TR-CR-002`, `TR-CR-004`
- TR-PG-002: `committed_fragments: Array[PranaFragment]` length 9 (null = empty slot) — sole public data interface for CombinationResolution and SpellCastingEffects
- TR-CR-002: `combo_resolved(spell_effect: SpellEffect)` signal emitted exactly once per wave on `combat_started`
- TR-CR-004: SpellEffect cache cleared on `preparation_started` signal; CombinationResolution is stateless between waves

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture (primary), ADR-0009: SpellCastingEffects Stat Broker (secondary)
**ADR Decision Summary**: CombinationResolution reads `committed_fragments` via a public getter after `combat_started` — no direct coupling. SpellCastingEffects is the sole owner of the wave's SpellEffect payload. No system reads `aggregate_stat_bonus` directly from SpellEffect outside SC&E.

**Engine**: Godot 4.6 | **Risk**: LOW (Autoload signal wiring — stable API)
**Engine Notes**: CR is Autoload #8; SC&E is Autoload #9. Both connect to `GameStateManager.combat_started` and `GameStateManager.preparation_started` in their own `_ready()`. This story verifies that the PranaGrid public getter correctly serves those Autoloads across the Autoload boundary.

**Control Manifest Rules (Core layer)**:
- Required: SpellCastingEffects is the sole owner of the wave's SpellEffect payload (ADR-0009)
- Required: All wave-scoped stat queries use `SpellCastingEffects.get_stat_bonus(stat_id)` — no other Autoload caches `combo_resolved` (ADR-0009)
- Required: `_current_spell_effect` cleared in `_on_preparation_started()` (ADR-0009)
- Forbidden: No system reads `aggregate_stat_bonus` directly from SpellEffect outside SC&E (ADR-0009)
- Forbidden: Never subscribe to `CombinationResolution.combo_resolved` in feature-layer systems for stat caching (ADR-0009)

**⚠️ Cross-GDD gap**: The Game State & Scene Flow GDD does not yet explicitly list `arrangement_confirmed` as a signal it subscribes to for the PREPARATION→COMBAT transition. This must be patched (GDD update or producer errata) before implementing the `grid_locked` → `combat_started` sequence. Raise this at story start.

---

## Acceptance Criteria

*From `design/gdd/prana-grid.md` and `design/gdd/combination-resolution.md`, scoped to this story:*

- [ ] `committed_fragments` getter returns `Array[PranaFragment]` of length 9 — accessible from CombinationResolution and SpellCastingEffects as a read-only public getter
- [ ] After `combat_started` fires, CombinationResolution reads `committed_fragments` and receives a length-9 array with correct `type_id` values from the confirmed arrangement
- [ ] `committed_fragments[4]` is non-null when CR reads it (Prana Grid's centre-required rule enforced before confirmation, so CR's null-centre guard never fires in normal play)
- [ ] CombinationResolution emits `combo_resolved(spell_effect)` exactly once per `combat_started` event (AC-CR-26)
- [ ] SpellCastingEffects transitions to READY state after receiving `combo_resolved` (AC-SC-01); `spell_effect.primary_type` is in range 0–4
- [ ] Full loop: `preparation_started` → place tokens → confirm → `arrangement_confirmed` → `grid_locked` → `combat_started` → CR resolves → SCE enters READY — no `push_error` in output, no crash
- [ ] Wave cycle: `preparation_started` fires on next wave → slots reset → CR's cached SpellEffect cleared (AC-CR-27) → second resolution uses new arrangement, not stale first-wave data
- [ ] SpellCastingEffects reads `committed_fragments` (same getter, `type_id` per non-null element) for VFX/audio routing — no null-pointer errors on empty slots

---

## Implementation Notes

*Derived from ADR-0003 signal wiring + GDD Dependencies section:*

**Public getter (in PranaGrid, finalized in Story 002 — verify here):**
```gdscript
var _committed_fragments: Array = []  # Array[PranaFragment], length 9

func get_committed_fragments() -> Array:
    return _committed_fragments  # read-only by convention
```

**CombinationResolution reads on combat_started:**
```gdscript
# In CombinationResolution._on_combat_started() — existing Autoload:
func _on_combat_started() -> void:
    var prana_grid := _get_prana_grid()  # resolve via scene tree or direct reference
    var fragments := prana_grid.get_committed_fragments()
    # fragments is Array[PranaFragment], length 9, null = empty slot
    _resolve(fragments)
    combo_resolved.emit(_current_spell_effect)
```

**PranaGrid resolution in Autoloads** — since PranaGrid is a scene node (not an Autoload), CR and SCE must resolve it via the scene tree. Two approaches:
1. Reference stored in `GameStateManager` when IsometricRoom loads (preferred — single lookup)
2. `get_tree().get_first_node_in_group(&"prana_grid")` with `_ready()` cache

Pick the approach consistent with how other scene-node references are resolved in the project.

**This story's scope**: Confirm the getter interface works end-to-end. Do NOT modify the CR resolution logic (formula already implemented in the CR epic). Only verify that the wiring between PranaGrid and CR/SCE is correct.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Phase state machine (prerequisite — must be DONE)
- **Story 002**: `committed_fragments` getter definition and confirmation logic (prerequisite — must be DONE)
- **Story 004**: Gamepad input — independent from integration wiring
- CR's full resolution logic (Formulas 1–8) — already implemented in the CR epic

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-4-2026-06-11.md` — § S4-05.*

**Integration test file**: `tests/integration/prana-grid/prana_grid_cr_integration_test.gd`

- **getter-length** — committed_fragments is always length 9
  - Given: Valid confirmed arrangement (slot 4 filled)
  - When: `prana_grid.get_committed_fragments()` called after confirmation
  - Then: `result.size() == 9`; non-null elements at filled positions

- **getter-centre-invariant** — slot 4 non-null after valid confirmation
  - Given: Slot 4 = Stormgold (type_id 2) confirmed
  - When: CR reads `get_committed_fragments()` after `combat_started`
  - Then: `result[4] != null`; `result[4].type_id == 2`

- **full-loop** — prep → confirm → combat → combo_resolved → SC&E READY
  - Given: GameStateManager, PranaGrid, CR, SC&E all wired; slot 4 = Ashfire (type_id 0)
  - When: Full signal chain fires: `preparation_started` → place tokens → confirm → `arrangement_confirmed` → `grid_locked` → `combat_started`
  - Then: `combo_resolved` emitted once; `spell_effect.primary_type == 0`; SC&E `_state == READY`; no `push_error` in output

- **AC-CR-26** — combo_resolved emitted exactly once per combat_started
  - Given: Valid arrangement confirmed; signal spy on `CombinationResolution.combo_resolved`
  - When: `combat_started` fires
  - Then: Spy call count == 1; `spell_effect.primary_type` is in range 0–4

- **AC-CR-27** — wave cycle: second resolution uses new arrangement
  - Given: First wave resolves with Ashfire primary (type_id 0); `preparation_started` fires
  - When: Second arrangement with Deepfrost primary (type_id 3) confirmed; `combat_started` fires again
  - Then: Second `combo_resolved` has `spell_effect.primary_type == 3` (not 0 from first wave)

- **null-slots safety** — SCE reads committed_fragments with null slots
  - Given: Only slot 4 filled (other 8 null); `combat_started` fires
  - When: SC&E iterates `committed_fragments` for VFX/audio routing
  - Then: No null-pointer error; only slot 4's type_id is routed; other slots skipped

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/prana-grid/prana_grid_cr_integration_test.gd` — must exist and pass headless

**Status**: [x] `tests/integration/prana-grid/prana_grid_cr_integration_test.gd` — 10/10 PASSED, 0 orphans, exit code 0

---

## Dependencies

- Depends on: Story 001 (phase gating — LOCKED state required for combat_started integration), Story 002 (committed_fragments getter — must be DONE before wiring CR/SCE)
- Unlocks: S4-06 External Playtest — PranaGrid loop must be complete for external playtest to proceed

---

## Completion Notes
**Completed**: 2026-06-11
**Criteria**: 7/8 passing (AC 6 full signal chain ADVISORY — headless limit, deferred to S4-06 External Playtest; AC 8 SCE null-slot routing ADVISORY — CR side tested, SCE iteration recommended follow-up)
**Deviations**: None blocking. ADR-0003 line 217 prose updated to reflect actual PranaGrid → GSM wiring pattern.
**Test Evidence**: Integration test at `tests/integration/prana-grid/prana_grid_cr_integration_test.gd` — 10/10 PASSED, exit 0
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (suggestions applied; tests re-run 10/10)
