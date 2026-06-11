# Story 006: Signal Contract, Cache Lifecycle, and Edge Cases

> **Epic**: Combination Resolution
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-11

## Context

**GDD**: `design/gdd/combination-resolution.md`
**Requirement**: `TR-CR-002`, `TR-CR-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Signal-Driven Architecture)
**ADR Decision Summary**: `combo_resolved` must emit exactly once per `combat_started`. CR is stateless between waves — `preparation_started` clears any cached state. Deferred timers (ADJ_ECHO) must be cancelled when the phase changes.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Signal spy pattern in GUT: connect a lambda or inner-class handler to count emissions. `SceneTreeTimer` (via `get_tree().create_timer()`) is the correct pattern for ADJ_ECHO delay — it must be stored and cancelled with `timeout.disconnect()` or by freeing the timer reference. Do NOT use `await` for the delay in a non-coroutine context.

**Control Manifest Rules (Core layer)**:
- Required: `combo_resolved` emitted exactly once per wave; cache cleared on `preparation_started`
- Forbidden: `combo_resolved` emitted zero times (no-op SpellEffect still emits once); emitting from outside `_on_combat_started`
- Guardrail: null-slot error path still emits `combo_resolved` with `primary_type = -1` (GDD Rules 15, Edge Cases)

---

## Acceptance Criteria

*From GDD `design/gdd/combination-resolution.md` ACs CR-24 through CR-28:*

- [x] **AC-CR-24**: slot 4 = null; `push_error` called; `combo_resolved` emitted with `SpellEffect.primary_type == -1`
- [x] **AC-CR-25**: all 9 slots null; same as AC-CR-24 (`push_error` + no-op SpellEffect emitted)
- [x] **AC-CR-26**: valid arrangement (slot 4 non-null); signal spy connected to `combo_resolved`; after `combat_started` fires, spy call count == 1; `spell_effect.primary_type` is 0–4
- [x] **AC-CR-27**: CR resolves wave 1 with primary_type=0 (Ashfire); `preparation_started` fires; `combat_started` fires again with slot 4 = Stormgold (type 2); second `combo_resolved` payload has `primary_type == 2` (not 0); cache was cleared between waves
- [x] **AC-CR-28**: slot 4 has fragment with ADJ_ECHO satisfied; `combat_started` fires; `ADJ_ECHO_DELAY = 0.8s` timer started but not elapsed; `preparation_started` fires; no Echo Strike signal or additional `combo_resolved` emits into the preparation phase; cache is null after `preparation_started`

---

## Implementation Notes

*From GDD States/Transitions and Edge Cases:*

**Null-slot guard (AC-CR-24, AC-CR-25):**
```gdscript
func _on_combat_started(_is_boss: bool) -> void:
    var fragments: Array = PranaGrid.get_committed_fragments()
    if fragments[4] == null:
        push_error("CombinationResolution: slot 4 is null — centre-required rule violated in Prana Grid")
        var no_op: SpellEffect = SpellEffect.new()
        no_op.primary_type = -1
        combo_resolved.emit(no_op)
        return
    _resolve(fragments)
```
The error path still emits `combo_resolved` — SC&E must handle `primary_type == -1` as a no-op.

**Exactly-once guard (AC-CR-26):**
The natural structure of `_on_combat_started` (single `_resolve()` call + single `combo_resolved.emit()`) guarantees exactly one emission per signal handler invocation. Guard against duplicate `combat_started` signals by checking a `_in_combat: bool` flag:
```gdscript
var _in_combat: bool = false

func _on_combat_started(_is_boss: bool) -> void:
    if _in_combat:
        return  # ignore duplicate signals
    _in_combat = true
    ...emit...

func _on_preparation_started(_idx: int, _rem: int) -> void:
    _in_combat = false
    _clear_echo_timer()
```

**Cache lifecycle (AC-CR-27):**
CR is declared stateless — `_current_spell_effect` is NOT cached in CR (it is cached in SC&E per ADR-0009). CR resolves fresh each `combat_started`. The "cache cleared" test verifies that the second resolution reflects new fragments, not the first wave's data. This is naturally satisfied by reading `PranaGrid.get_committed_fragments()` fresh on each `combat_started`.

**ADJ_ECHO timer cancellation (AC-CR-28):**
```gdscript
var _echo_timer: SceneTreeTimer = null

func _start_echo_timer() -> void:
    _echo_timer = get_tree().create_timer(ADJ_ECHO_DELAY)
    _echo_timer.timeout.connect(_fire_echo_strike, CONNECT_ONE_SHOT)

func _clear_echo_timer() -> void:
    if _echo_timer != null:
        if _echo_timer.timeout.is_connected(_fire_echo_strike):
            _echo_timer.timeout.disconnect(_fire_echo_strike)
        _echo_timer = null
```
`_on_preparation_started` calls `_clear_echo_timer()` before clearing any other state.

**Integration test setup**: These tests require `add_child()` (SceneTree needed for `create_timer`). Use `add_child_autofree(cr_node)` for the node under test. Signal spy via lambda: `cr_node.combo_resolved.connect(func(se): spy_count += 1)`.

---

## Out of Scope

- [Story 005]: Adjacency effect resolution producing the ADJ_ECHO effect_id
- SC&E: applying the no-op SpellEffect (primary_type == -1) as a no-op cast

---

## QA Test Cases

**Test file**: `tests/integration/combination-resolution/cr_integration_test.gd`

- **AC-CR-24**: Null centre → push_error + no-op SpellEffect
  - Given: `committed_fragments` with slot 4 = null (inject via mock PranaGrid)
  - When: `combat_started` fires
  - Then: push_error called; `combo_resolved` emitted once with `spell_effect.primary_type == -1`

- **AC-CR-25**: All-null → same as AC-CR-24
  - Given: all 9 slots null
  - Then: push_error; no-op SpellEffect with primary_type == -1

- **AC-CR-26**: Exactly-once emission on valid arrangement
  - Given: slot 4 = Ashfire lv.1 (valid); spy connected to `combo_resolved`
  - When: `combat_started` fires
  - Then: spy call count == 1; `spell_effect.primary_type` in [0, 1, 2, 3, 4]

- **AC-CR-27**: Cache cleared — second wave reflects new arrangement
  - Given: wave 1 resolves with Ashfire primary; `preparation_started` fires; wave 2 has Stormgold primary
  - Then: second `combo_resolved` carries `primary_type == 2`; not 0

- **AC-CR-28**: ADJ_ECHO timer cancelled by preparation_started
  - Given: fragment with ADJ_ECHO satisfied; `combat_started` fires; timer started (< 0.8s elapsed)
  - When: `preparation_started` fires before timeout
  - Then: no additional `combo_resolved` or echo signal fires; cache null
  - Note: Test may require `await get_tree().create_timer(0.1).timeout` to simulate partial delay

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combination-resolution/cr_integration_test.gd` — must exist and pass headless (GdUnit4 with SceneTree)

**Status**: [x] `tests/integration/combination-resolution/cr_integration_test.gd` — 8/8 PASSED, 0 orphans, exit code 0

---

## Dependencies

- Depends on: Stories 001–005 DONE (full resolution pipeline implemented before integration test)
- Unlocks: CombinationResolution epic is complete when this story is Done

## Completion Notes
**Completed**: 2026-06-11
**Criteria**: 5/5 passing (all auto-verified by integration test suite)
**Deviations**:
- ADVISORY: `_cached_spell_effect` held on CR between waves for ADJ_ECHO timer; cleared in `_on_preparation_started` — stateless-between-waves invariant maintained
- ADVISORY: `echo_strike_fired(spell_effect)` signal added to CR public contract — SC&E must subscribe in a future story
**Test Evidence**: `tests/integration/combination-resolution/cr_integration_test.gd` — 8/8 PASSED, 0 orphans
**Code Review**: Skipped (lean mode)
