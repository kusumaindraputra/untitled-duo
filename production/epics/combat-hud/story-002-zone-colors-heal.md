# Story 002: HP Zone Colors and Heal Tween

> **Epic**: CombatHUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: ~1 hour
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-07 (Complete)

## Context

**GDD**: `design/gdd/combat-hud.md`
**Requirement**: `TR-CH-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
**ADR Decision Summary**: CombatHUD is a pure signal consumer — zone colour changes are driven exclusively by `player_hp_zone_changed(zone)` from HealthAndDamage. CombatHUD never computes zone thresholds.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Color("#FFA500")` hex parsing stable since Godot 4.0. `create_tween()` pattern with `TWEEN_PAUSE_PROCESS` required (same as Story 001). Pulse tween uses `set_loops()`.

**Control Manifest Rules (Presentation Layer)**:
- Required: Signal consumer only — CombatHUD never reads Autoload state directly (ADR-0003 Pattern 1)
- Required: `process_mode = PROCESS_MODE_ALWAYS` — already set in Story 001 skeleton

---

## Acceptance Criteria

*From GDD `design/gdd/combat-hud.md`, scoped to this story:*

- [ ] **AC-HUD-04** — GIVEN current zone = FULL; `player_hp_zone_changed(HPZone.CAREFUL)` fires; WHEN processed; THEN bar fill modulate == `Color("#FFA500")`; numeric label color == `Color("#FFA500")`
- [ ] **AC-HUD-05** — GIVEN current zone = CAREFUL; `player_hp_zone_changed(HPZone.DESPERATE)` fires; WHEN processed; THEN bar fill modulate == `Color("#FF3333")`; numeric label color == `Color("#FF3333")`
- [ ] **AC-HUD-06** — GIVEN current zone = DESPERATE; `player_hp_zone_changed(HPZone.FULL)` fires; WHEN processed; THEN bar fill modulate == `Color("#F5F0E8")`; numeric label color == `Color("#FFFFFF")`
- [ ] **AC-HUD-23** — GIVEN zone = DESPERATE (bar red); `health_restored(fayde, 6, 26)` fires; `HEAL_TINT_DURATION` elapses; WHEN tint reverts; THEN modulate == `Color("#FF3333")` (DESPERATE zone color — NOT warm white)
- [ ] **AC-HUD-24** [M] — GIVEN `player_hp_zone_changed(HPZone.DESPERATE)` fires; WHEN 0.8s elapses; THEN HP bar has visibly pulsed (scale 1.0→1.03→1.0 cycle). Confirm via `is_pulse_active() → bool` if exposed or direct visual.
- [ ] **AC-HUD-25** — GIVEN HP bar pulsing in DESPERATE zone; `player_hp_zone_changed(HPZone.CAREFUL)` fires; WHEN processed; THEN `hp_bar.scale == Vector2(1.0, 1.0)` (pulse stopped)

---

## Implementation Notes

*Derived from GDD Rule 4 and Edge Cases:*

**Zone colours** — `_on_hp_zone_changed(zone: HealthAndDamage.HPZone)`:
```gdscript
func _on_hp_zone_changed(zone: int) -> void:
    if _dead: return
    _current_zone = zone
    match zone:
        0:  # FULL
            hp_bar.modulate = Color("#F5F0E8")
            hp_label.add_theme_color_override(&"font_color", Color("#FFFFFF"))
            _stop_pulse()
        1:  # CAREFUL
            hp_bar.modulate = Color("#FFA500")
            hp_label.add_theme_color_override(&"font_color", Color("#FFA500"))
            _stop_pulse()
        2:  # DESPERATE
            hp_bar.modulate = Color("#FF3333")
            hp_label.add_theme_color_override(&"font_color", Color("#FF3333"))
            _start_pulse()
```

**Zone color revert after heal tint (AC-HUD-23)** — in `_on_health_restored`, apply green tint then schedule revert via `create_tween()`:
```gdscript
hp_bar.modulate = Color(0.6, 1.0, 0.6, 1.0)
var t := create_tween()
t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
t.tween_interval(HEAL_TINT_DURATION)
t.tween_callback(_revert_zone_color)

func _revert_zone_color() -> void:
    _on_hp_zone_changed(_current_zone)  # re-applies correct zone color
```

**Pulse animation (AC-HUD-24, AC-HUD-25)** — looping tween on `hp_bar.scale`:
```gdscript
var _pulse_tween: Tween = null

func _start_pulse() -> void:
    if _pulse_tween and _pulse_tween.is_valid(): return
    _pulse_tween = create_tween().set_loops()
    _pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _pulse_tween.tween_property(hp_bar, "scale", Vector2(1.03, 1.03), 0.4)
    _pulse_tween.tween_property(hp_bar, "scale", Vector2(1.0, 1.0), 0.4)

func _stop_pulse() -> void:
    if _pulse_tween and _pulse_tween.is_valid():
        _pulse_tween.kill()
        _pulse_tween = null
    hp_bar.scale = Vector2(1.0, 1.0)

func is_pulse_active() -> bool:
    return _pulse_tween != null and _pulse_tween.is_valid()
```
`_stop_pulse()` must be called in `_on_run_started()` (Story 001 reset) and in `_on_player_died()`.

**HPZone enum** — use `HealthAndDamage.HPZone` (defined in `src/systems/health_and_damage.gd`). Check the enum values; they should match FULL=0, CAREFUL=1, DESPERATE=2. If the enum is defined as GameEnums.HPZone, use that path instead.

---

## Out of Scope

- [Story 001]: HP bar skeleton, drain tween, dead state guard, run_started reset
- [Story 003]: Floating damage numbers
- [Story 004]: Chain dots

---

## QA Test Cases

*Embedded from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-09 specs).*

**Test file**: `tests/unit/combat-hud/combat_hud_test.gd` (zone colour section)
**Evidence file**: `production/qa/evidence/combat-hud-zones-evidence.md`

- **AC-HUD-04**: Zone CAREFUL → amber bar and label
  - Given: CombatHUD in tree; zone = FULL
  - When: `HealthAndDamage.player_hp_zone_changed.emit(1)` (CAREFUL)
  - Then: `assert_bool(hud.hp_bar.modulate == Color("#FFA500")).is_true()`; label font color == `Color("#FFA500")`

- **AC-HUD-05**: Zone DESPERATE → red bar and label
  - Given: zone = CAREFUL
  - When: `HealthAndDamage.player_hp_zone_changed.emit(2)` (DESPERATE)
  - Then: bar modulate == `Color("#FF3333")`; label font color == `Color("#FF3333")`

- **AC-HUD-06**: Zone FULL → warm white bar, white label
  - Given: zone = DESPERATE
  - When: `HealthAndDamage.player_hp_zone_changed.emit(0)` (FULL)
  - Then: bar modulate == `Color("#F5F0E8")`; label font color == `Color("#FFFFFF")`

- **AC-HUD-23**: Heal tint reverts to zone-specific color (not warm white)
  - Given: zone = DESPERATE (red modulate); bar at 20
  - When: `HealthAndDamage.health_restored.emit(mock_fayde, 6.0, 26.0)`; then `_process(0.21)` (> HEAL_TINT_DURATION)
  - Then: `hud.hp_bar.modulate == Color("#FF3333")` (DESPERATE red, NOT warm white)

- **AC-HUD-25**: Pulse stops on zone exit
  - Given: zone = DESPERATE (pulse active; `is_pulse_active() == true`)
  - When: `HealthAndDamage.player_hp_zone_changed.emit(1)` (CAREFUL)
  - Then: `hud.is_pulse_active() == false`; `hud.hp_bar.scale == Vector2(1.0, 1.0)`

**Manual [M] AC-HUD-24**: DESPERATE pulse animation
  - Setup: emit `player_hp_zone_changed(HPZone.DESPERATE)` in running Godot scene
  - Verify: HP bar visibly pulses over ~0.8s cycle
  - Pass: `is_pulse_active()` returns true; bar scale cycles between 1.0 and 1.03

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/combat-hud-zones-evidence.md` + sign-off (ADVISORY)
Unit tests in `tests/unit/combat-hud/combat_hud_test.gd` strongly recommended.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (HP bar skeleton, `_current_zone` state var, `_dead` guard live)
- Unlocks: Story 003 — Floating Damage Numbers

---

## Completion Notes
**Completed**: 2026-06-07
**Criteria**: 5/6 passing; AC-HUD-24 [M] DEFERRED (manual visual verification; pulse confirmed active via `is_pulse_active() == true` in AC-HUD-25 precondition)
**Deviations**:
- ADVISORY: `hp_bar.pivot_offset` set lazily in `_start_pulse()` — returns `Vector2.ZERO` headless; visually correct in real Godot session
- ADVISORY: Pulse scale (`1.03`) and duration (`0.4`s) hardcoded — existing project pattern; EnemyStats migration in tech-debt-register
**Test Evidence**: UI story — 16/16 unit tests pass (`tests/unit/combat-hud/combat_hud_test.gd`); manual walkthrough evidence deferred (ADVISORY)
**Code Review**: APPROVED WITH SUGGESTIONS — pivot_offset fix and dead+DESPERATE pulse test applied; 16/16 clean re-run
