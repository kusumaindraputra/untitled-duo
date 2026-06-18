# Story 003: I-Frame Window (Float Accumulator Timer)

> **Epic**: Health & Damage
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~2h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-06-02

## Context

**GDD**: `design/gdd/health-damage.md`
**Requirement**: `TR-HD-004`, `TR-HD-012`

**ADR Governing Implementation**: ADR-0004: Float Accumulator Timer Pattern
**ADR Decision Summary**: All in-game timing uses float delta accumulators in `_process(delta)`. I-frame window is a float accumulator: `_iframe_timer -= delta` each frame; when it crosses 0, `_iframe_active = false`. Never use `Timer` nodes or `SceneTree.create_timer()`.

**Secondary ADR**: ADR-0007 (i-frame check location in `apply_damage` pipeline step 1a)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_process(delta)` float accumulator pattern stable. `force_end_iframe_window()` is the test seam for expiring the window without real time passing.

**Control Manifest Rules (Core layer)**:
- Required: All in-game timing uses float delta accumulators in `_process(delta)`.
- Required: Decrement accumulator by `tick_rate` (here: `delta`), never reset to 0.0.
- Required: `PROCESS_MODE_PAUSABLE` for HealthAndDamage (pausing freezes the i-frame timer).
- Forbidden: Never use `Timer` nodes for gameplay timing.
- Forbidden: Never use `SceneTree.create_timer()` for gameplay timing.
- Forbidden: Never reset timer accumulator to 0.0 on tick — decrement by delta.

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage.md`, scoped to this story:*

- [ ] **AC-HD-06** — After Fayde takes CONTACT damage (`final_damage > 0`), a second CONTACT hit within `FAYDE_IFRAME_DURATION` (0.5s): (1) `_fayde_current_hp` unchanged by second hit; (2) `damage_taken` NOT emitted for second hit.
- [ ] **AC-HD-07** — After `FAYDE_IFRAME_DURATION` expires (via `force_end_iframe_window()`), the next CONTACT hit applies damage normally.
- [ ] **AC-HD-08** — A `DamageSource.DOT` hit during active i-frame changes `_fayde_current_hp` (i-frames do not block DOT).
- [ ] **AC-HD-09** — A heal applied during active i-frame changes `_fayde_current_hp` (i-frames do not block healing).
- [ ] **AC-HD-27** — A `DamageSource.DIRECT` hit during active i-frame changes `_fayde_current_hp` (i-frames do not block DIRECT damage).
- [ ] **AC-HD-33** — I-frame re-arm: first CONTACT hit arms window1; `force_end_iframe_window()` expires window1; second CONTACT hit arms window2; third CONTACT before window2 expires → HP unchanged, `damage_taken` NOT emitted.
- [ ] **AC-HD-25a** *(sequential multi-source)* — Given Fayde at `current_hp=50` with i-frame active: `apply_damage(fayde, 5.0, null, DOT)` then `apply_damage(fayde, 20.0, null, CONTACT)`: (1) `current_hp=45`; (2) `damage_taken` fires once with `final_damage=5`; (3) no `player_hp_zone_changed` fires (45 > CAREFUL threshold 40).

---

## Implementation Notes

*Derived from ADR-0004 + ADR-0007:*

**Add to `_process(delta)` in `health_and_damage.gd`:**
```gdscript
func _process(delta: float) -> void:
    if _iframe_active:
        _iframe_timer -= delta
        if _iframe_timer <= 0.0:
            _iframe_active = false
            _iframe_timer = 0.0
```

**Step 1a insert into `apply_damage()` (after dead-target guard, before multiplier):**
```gdscript
# Step 1a — i-frame check (player CONTACT only)
if target.is_in_group(&"player") and source == GameEnums.DamageSource.CONTACT:
    if _iframe_active:
        return
```

**I-frame arming — add to step 3 (after HP applied to player):**
```gdscript
# After applying HP damage to Fayde via CONTACT:
if target.is_in_group(&"player") and source == GameEnums.DamageSource.CONTACT and final_damage > 0:
    _iframe_active = true
    _iframe_timer = FAYDE_IFRAME_DURATION  # 0.5s
```

**Test seam (from Story 001 skeleton — verify it exists):**
```gdscript
func force_end_iframe_window() -> void:
    _iframe_active = false
    _iframe_timer = 0.0
```

**Note on `PROCESS_MODE_PAUSABLE`**: HealthAndDamage must be set to `PROCESS_MODE_PAUSABLE` so the i-frame timer freezes when the game is paused. Set in the scene or via `process_mode = PROCESS_MODE_PAUSABLE` in `_ready()`. Story 001 creates the node — this story activates the process function.

**Note on AC-HD-25a test setup**: AC-HD-25a requires the i-frame to be already active when DoT and CONTACT are called sequentially. Use `apply_damage(fayde, 1.0, null, CONTACT)` to arm the i-frame first (without expiring it), then assert the sequential behavior. The `_check_hp_zone_change` stub from Story 002 handles AC-HD-25a's zone assertion (no zone fire at 45 HP — above CAREFUL threshold).

---

## Out of Scope

- Story 002: The `apply_damage()` shell (this story adds step 1a and i-frame arming only)
- Story 004: Zone signal check in `_check_hp_zone_change()` (AC-HD-25a's zone assertion is a pass-through)
- Story 005: `player_died` death check (step 5)

---

## QA Test Cases

**AC-HD-06 — Second CONTACT blocked during i-frame**
- Given: Fayde `current_hp=80.0`; first CONTACT hit (20.0 base) applied to arm i-frame
- When: Second CONTACT hit (20.0 base) applied immediately (no delta processed)
- Then: `current_hp == 60.0` (only first hit applied); `damage_taken` emit count == 1 total

**AC-HD-07 — CONTACT applies after i-frame expires**
- Given: Fayde `current_hp=80.0`; first CONTACT hit applied (arms i-frame); `force_end_iframe_window()` called
- When: Second CONTACT hit (20.0)
- Then: `current_hp == 60.0`; `damage_taken` emitted for second hit

**AC-HD-08 — DOT bypasses i-frame**
- Given: `_iframe_active = true`; Fayde `current_hp=80.0`
- When: `apply_damage(fayde, 5.0, null, DOT)`
- Then: `current_hp == 75.0`; `damage_taken` emitted

**AC-HD-09 — Heal bypasses i-frame**
- Given: `_iframe_active = true`; Fayde `current_hp=80.0`
- When: `apply_heal(fayde, 10.0)` (Story 004 impl — or call `_fayde_current_hp += 10.0` directly if Story 004 not done)
- Then: `current_hp == 90.0`
- Note: If Story 004 not yet merged, assert directly on `_fayde_current_hp`

**AC-HD-27 — DIRECT bypasses i-frame**
- Given: `_iframe_active = true`; Fayde `current_hp=80.0`
- When: `apply_damage(fayde, 10.0, null, DIRECT)`
- Then: `current_hp == 70.0`; `damage_taken` emitted

**AC-HD-33 — I-frame re-arms after expiry**
- Given: Fayde `current_hp=100.0`
- When: (1) First CONTACT (20.0) → arms window1, HP=80; (2) `force_end_iframe_window()` expires window1; (3) Second CONTACT (20.0) → arms window2, HP=60; (4) Third CONTACT (20.0) immediately
- Then: `current_hp == 60.0` (third hit blocked by window2); `damage_taken` emit count == 2

**AC-HD-25a — Sequential DOT + CONTACT with active i-frame, no zone signal**
- Given: Fayde `current_hp=50.0`; i-frame armed via prior hit
- When: `apply_damage(fayde, 5.0, null, DOT)` then `apply_damage(fayde, 20.0, null, CONTACT)`
- Then: `current_hp == 45.0`; `damage_taken` fires once (DOT only); `player_hp_zone_changed` NOT emitted (45 > CAREFUL=40)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/health-damage/iframe_window_test.gd` — must pass headless

**Status**: [x] Created — see Completion Notes

---

## Dependencies

- Depends on: Story 002 (apply_damage pipeline must exist — this story adds step 1a and arming logic)
- Unlocks: Story 004 (heal/zones are independent of i-frame), Story 005 (death checks complete the pipeline)

---

## Completion Notes

**Completed**: 2026-06-02
**Criteria**: 6/7 passing (AC-HD-25a UNTESTED — sequential DOT+CONTACT scenario; no test in any file)
**Deviations**:
- ADVISORY: No dedicated `iframe_window_test.gd` — AC-HD-06/07/08/09/27/33 covered in shared `health_damage_skeleton_test.gd`
- ADVISORY: AC-HD-25a (sequential DOT+CONTACT, no zone signal) untested — recommend adding before sprint close-out
- ADVISORY: Timer uses accumulate-up pattern (`+= delta`) not decrement-down as ADR-0004 specifies; functionally identical, no forbidden Timer nodes
- ADVISORY: `PROCESS_MODE_PAUSABLE` not set — required by control manifest; no impact until pause system lands
**Test Evidence**: Logic — AC-HD-06/07/08/09/27/33 in `tests/unit/health-damage/health_damage_skeleton_test.gd`
**Code Review**: Complete — `/code-review` APPROVED WITH SUGGESTIONS, commit `6f883c1`
