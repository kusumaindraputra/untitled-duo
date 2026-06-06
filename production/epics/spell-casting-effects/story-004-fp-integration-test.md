# Story 004: FP Integration Test

> **Epic**: Spell Casting & Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: ~1 hour
> **Manifest Version**: 2026-06-03
> **Last Updated**: —

## Context

**GDD**: `design/gdd/spell-casting-effects.md`
**Requirement**: `TR-SC-001`, `TR-SC-003`, `TR-SC-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture (primary — integration verifies real signal wiring end-to-end)
**ADR Decision Summary**: SC&E connects to CombinationResolution.combo_resolved, GameStateManager.preparation_started, and GameStateManager.combat_started in _ready(). Integration test verifies the complete chain fires correctly with real Autoloads — no mocks for the signal pathway.

**Secondary ADRs**: ADR-0014 (H&D ↔ WaveManager contract — same H&D patterns apply to SC&E's apply_damage call)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_override_target` test seam bypasses physics ray — targeting remains injectable. Integration tests emit real Autoload signals (same pattern as wave_manager_integration_test.gd).

**Control Manifest Rules (Core Layer)**:
- Required: Integration test verifies Sprint S3-08 AC: player input triggers apply_damage; elemental 2× applies; cast_hit_started fires
- Required: Use real GameStateManager and HealthAndDamage Autoloads — no mocks on the signal pathway
- Required: Teardown: remove_child() then free() — not queue_free() (headless GdUnit4, exit 101 guard)

---

## Acceptance Criteria

*Sprint S3-08 criteria verified end-to-end:*

- [ ] **AC-WES-INT-01** — Full cast flow: `preparation_started` → `combo_resolved` → SC&E transitions to READY; `combat_started` received; cast input → `HealthAndDamage.apply_damage` called; `cast_hit_started` emitted with non-zero lock duration
- [ ] **AC-WES-INT-02** — Elemental affiliation 2× verified end-to-end: MockEnemy with `prana_affiliation = DamageClass.FIRE`; Ashfire T1 SpellEffect injected → `apply_damage` raw_damage ≈ 50.0 (25 × 2.0)
- [ ] **AC-WES-INT-03** — `preparation_started` resets SC&E to IDLE: after a full cast sequence, `preparation_started` fires → `_state == IDLE`, `_current_spell_effect == null`, `_combo_index == 0`

---

## Implementation Notes

*Same patterns as wave_manager_integration_test.gd and sem_cleanup_integration_test.gd:*

**Test harness setup**:
- Load SC&E script via `preload("res://src/systems/spell_casting_effects.gd")`
- Add SC&E to test scene tree via `add_child(sce)` — triggers `_ready()`, connects to real Autoloads
- `sce.set_process(false)` — prevents auto-ticking; test controls timing manually
- Inject `_override_target` with a `MockEnemy` node that exposes `prana_affiliation`, `apply_speed_modifier`, `apply_stun`, `is_alive`
- Inject `_health_and_damage` with a MockHD that records `apply_damage` calls
- Inject `_status_effects` with a MockSEM (pass-through: `check_and_apply_shatter(t, d)` returns d; `has_status()` returns false)

**Signal emission for integration test**:
- `GameStateManager.preparation_started.emit(0, 1)` → SC&E resets to IDLE
- `GameStateManager.combat_started.emit(false)` → SC&E sets `_in_combat = true`
- Inject SpellEffect via `sce._on_combo_resolved(effect)` directly (CombinationResolution stub emits on combat_started in live game; test bypasses stub for cleanliness)
- Assert `sce._state == SCEState.READY`
- Set `sce._override_target = mock_enemy`
- Call `sce._trigger_cast()` (bypasses Input dependency — direct call is cleaner for integration test)
- Assert MockHD.apply_damage_calls.size() >= 1
- Assert cast_hit_started spy count == 1

**Teardown**:
```gdscript
func _teardown_sce(sce: Node) -> void:
    remove_child(sce)
    sce.free()
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: Skeleton, SpellEffect Resource
- [Story 002]: Cast input gating, chain timing
- [Story 003]: Damage formula, spell_hit_element, status stubs

---

## QA Test Cases

*Derived from qa-plan-sprint-3-2026-06-03.md and Sprint S3-08 acceptance criteria.*

**Test file**: `tests/integration/spell-casting-effects/spell_casting_integration_test.gd`

- **AC-WES-INT-01**: Full cast flow — apply_damage fires, cast_hit_started fires
  - Given: SC&E added to tree; MockHD; MockSEM; MockEnemy injected as _override_target; Ashfire T1 SpellEffect with primary_type=0, base_damage_modifier=1.25, combo_attack_count=1
  - When: `preparation_started.emit(0, 1)` → `combat_started.emit(false)` → `sce._on_combo_resolved(spell_effect)` → `sce._trigger_cast()`
  - Then: MockHD received exactly 1 apply_damage call; cast_hit_started spy count == 1 with lock_duration == 0.20

- **AC-WES-INT-02**: Elemental affiliation 2× end-to-end
  - Given: MockEnemy with `prana_affiliation = GameEnums.DamageClass.FIRE`; Ashfire T1 SpellEffect; MockHD
  - When: full flow as above then `sce._trigger_cast()`
  - Then: MockHD.damage_calls[0] ≈ 50.0 (25.0 × 2.0); tolerance ±0.01

- **AC-WES-INT-03**: preparation_started resets SC&E
  - Given: SC&E after a completed cast (state CAST_LOCKED or CHAINING)
  - When: `GameStateManager.preparation_started.emit(0, 1)` fires
  - Then: `sce._state == SCEState.IDLE`; `sce._current_spell_effect == null`; `sce._combo_index == 0`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/spell-casting-effects/spell_casting_integration_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 DONE (damage formula implemented; full SC&E working end-to-end)
- Unlocks: None — this is the final SC&E story for FP scope. Epic complete when this story is Done.
  S3-09 (CombatHUD) and S3-10 (RunManager) are unblocked after this story.
