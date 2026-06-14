# Story 005: Dash Discoverability + Cooldown Indicator

> **Epic**: CombatHUD
> **Status**: Complete
> **Layer**: UI
> **Type**: UI
> **Estimate**: 1.0 day
> **Sprint ID**: S5-05
> **Manifest Version**: 2026-06-12
> **Last Updated**: 2026-06-14

## Context

**GDD**: `design/gdd/combat-hud.md`
**Supporting GDD**: `design/gdd/player-controller.md` (dash spec)
**Sprint**: Sprint 5 — Legibility Pass

**Playtest finding (Sprint 4)**: Tester SAK did not know dash existed and could not tell when it was available. Dash is a core defensive tool (Pillar 3 — Chaos Has Consequences); its invisibility means the player cannot make informed positioning decisions.

**Two features delivered in one story**:
1. **Keybinding hint** — static text label showing `Shift / LT` visible in CombatHUD during Combat Phase
2. **Cooldown indicator** — icon/bar that dims when dash is on cooldown and restores to full opacity when ready

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
Combat HUD must NOT poll `PlayerController.is_dash_available()` each frame. Player Controller must emit a signal on dash state changes.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (Presentation layer)**:
- Required: Signal-driven cooldown state — subscribe to `PlayerController.dash_cooldown_changed(available: bool)`
- Forbidden: Polling `PlayerController` state in `_process()`
- Required: Hint is hidden during PREPARATION state (not visible when grid is visible)

---

## ~~⚠️ Pre-Implementation Requirement (GAP-3)~~ — RESOLVED 2026-06-13

Two GDD amendments required before this story begins:

**Amendment 1 — Player Controller GDD** (`design/gdd/player-controller.md`):
Add signal declaration to Core Rules Section (after Rule 4 Dash):
```gdscript
signal dash_cooldown_changed(available: bool)
```
- Emit `dash_cooldown_changed(false)` immediately when dash is activated (cooldown starts)
- Emit `dash_cooldown_changed(true)` when `DASH_COOLDOWN` timer expires and dash becomes available again
- Emit `dash_cooldown_changed(true)` on `preparation_started` (dash resets to ready between waves)

**Amendment 2 — Combat HUD GDD** (`design/gdd/combat-hud.md`):
Add to Detailed Design (new Rule 9):
- `DashHintLabel` (Label node): text `"Shift / LT"` (or equivalent per control-manifest); visible only during `COMBAT` state
- `DashCooldownIcon` (TextureRect or ColorRect): full opacity = ready; 40% opacity = on cooldown; no animation (immediate switch)
- Both nodes connect to `PlayerController.dash_cooldown_changed(available: bool)`

Both amendments authored and written to GDD files 2026-06-13. GAP-3 RESOLVED.

---

## Acceptance Criteria

*Derived from playtest feedback + Player Controller GDD dash spec.*

- [ ] **AC-DH-01** — `DashHintLabel` is visible during Combat Phase (after `combat_started`)
- [ ] **AC-DH-02** — `DashHintLabel` is NOT visible during Preparation Phase (after `preparation_started`)
- [ ] **AC-DH-03** — `DashHintLabel.text` contains the keyboard shortcut label (e.g., `"Shift"`)
- [ ] **AC-DH-04** — `dash_cooldown_changed(false)` (dash used): `DashCooldownIcon.modulate.a < 1.0` (depleted state, e.g., 0.4)
- [ ] **AC-DH-05** — `dash_cooldown_changed(true)` (dash ready): `DashCooldownIcon.modulate.a == 1.0` (ready state)
- [ ] **AC-DH-06** — On `preparation_started` while cooldown active: indicator resets to ready state (`modulate.a == 1.0`) — dash always ready at wave start
- [ ] **AC-DH-07** — On `run_started`: both hint and indicator reset to initial states (hint hidden; indicator ready)
- [ ] **AC-DH-08** [M] — Keybinding hint readable at normal play distance (not too small)
- [ ] **AC-DH-09** [M] — Cooldown state transition is distinguishable at a glance without color alone (secondary visual signal required — e.g., dimming + desaturation OR dimming + icon change)
- [ ] **AC-DH-10** [M] — **Discoverability test**: tester uses dash within first combat encounter without prompting

---

## Implementation Notes

*Fill in after GAP-3 amendments are authored.*

**Signal connection in `_ready()`** (after GAP-3 declares the signal):
```gdscript
func _ready() -> void:
    # existing connections...
    PlayerController.dash_cooldown_changed.connect(_on_dash_cooldown_changed)
    GameStateManager.combat_started.connect(_on_combat_started)
    GameStateManager.preparation_started.connect(_on_preparation_started)
    GameStateManager.run_started.connect(_on_run_started)
    # Initial state: hint hidden, indicator ready
    _dash_hint_label.visible = false
    _dash_cooldown_icon.modulate.a = 1.0

func _on_combat_started(_is_boss: bool) -> void:
    _dash_hint_label.visible = true

func _on_preparation_started(_wave_index: int, _remaining: int) -> void:
    _dash_hint_label.visible = false
    _dash_cooldown_icon.modulate.a = 1.0  # reset to ready

func _on_dash_cooldown_changed(available: bool) -> void:
    _dash_cooldown_icon.modulate.a = 1.0 if available else 0.4

func _on_run_started() -> void:
    _dash_hint_label.visible = false
    _dash_cooldown_icon.modulate.a = 1.0
```

**PlayerController changes required** (stub for reviewer):
```gdscript
# In player_controller.gd — add signal and emit calls
signal dash_cooldown_changed(available: bool)

# In _perform_dash():
_dash_cooldown_timer = DASH_COOLDOWN
dash_cooldown_changed.emit(false)

# In _physics_process() — when cooldown expires:
if _dash_cooldown_timer > 0.0:
    _dash_cooldown_timer -= delta
    if _dash_cooldown_timer <= 0.0:
        _dash_cooldown_timer = 0.0
        dash_cooldown_changed.emit(true)

# In _on_preparation_started():
_dash_cooldown_timer = 0.0
dash_cooldown_changed.emit(true)  # ready for next wave
```

**Note on PlayerController as Autoload**: PlayerController is a scene node, not an autoload singleton. Combat HUD must get a reference to it via `get_tree().get_first_node_in_group("player")` or `@export var player_controller: PlayerController` assigned in the scene. Use the `@export` pattern (consistent with other injected dependencies in this codebase).

---

## Out of Scope

- Animated cooldown fill bar (progress bar depleting) — FP scope is opacity toggle only
- Gamepad-specific button icon (only keyboard text at FP) — gamepad icon display is VS scope
- Cooldown duration display (numeric countdown) — FP scope is binary ready/depleted

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-5-2026-06-12.md` (S5-05 specs).*

**Test file**: `tests/unit/combat-hud/combat_hud_dash_test.gd`
**Evidence file**: `production/qa/evidence/sprint-5-dash-feedback-evidence.md`

- **AC-DH-01/02**: Hint visibility follows combat phase
  - Given: CombatHUD with `_player_controller` injected (mock); hint initially hidden
  - When: `GameStateManager.combat_started.emit(false)` → Then: `_dash_hint_label.visible == true`
  - When: `GameStateManager.preparation_started.emit(0, 1)` → Then: `_dash_hint_label.visible == false`

- **AC-DH-03**: Hint text contains keyboard shortcut
  - Then: `_dash_hint_label.text.contains("Shift") == true`

- **AC-DH-04**: Cooldown depleted state on `dash_cooldown_changed(false)`
  - Given: CombatHUD; `_dash_cooldown_icon.modulate.a == 1.0` initially
  - When: `player_controller.dash_cooldown_changed.emit(false)`
  - Then: `_dash_cooldown_icon.modulate.a < 1.0` (e.g., 0.4)

- **AC-DH-05**: Cooldown ready state on `dash_cooldown_changed(true)`
  - Given: indicator in depleted state (a < 1.0)
  - When: `player_controller.dash_cooldown_changed.emit(true)`
  - Then: `_dash_cooldown_icon.modulate.a == 1.0`

- **AC-DH-06**: preparation_started resets indicator to ready
  - Given: indicator depleted (a < 1.0)
  - When: `GameStateManager.preparation_started.emit(0, 1)`
  - Then: `_dash_cooldown_icon.modulate.a == 1.0`

- **AC-DH-07**: run_started resets both nodes
  - Given: hint visible; indicator depleted
  - When: `GameStateManager.run_started.emit()`
  - Then: `_dash_hint_label.visible == false`; `_dash_cooldown_icon.modulate.a == 1.0`

**Manual**:
- **AC-DH-08**: Hint readable at normal play distance — screenshot in evidence file
- **AC-DH-09**: Cooldown distinguishable at a glance — screenshot showing depleted vs. ready
- **AC-DH-10**: Discoverability test — record tester's first-session dash usage

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/sprint-5-dash-feedback-evidence.md` — screenshots + discoverability test result (ADVISORY gate)
**Automated tests**: `tests/unit/combat-hud/combat_hud_dash_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: CombatHUD story-001 through story-004 DONE; GAP-3 amendments authored
- GAP-3 requires changes to both `design/gdd/player-controller.md` AND `design/gdd/combat-hud.md`
- Unlocks: Re-validation playtest (one of 3 discoverability gates)

---

## Completion Notes
**Completed**: 2026-06-14
**Criteria**: 7/10 passing (AC-DH-08, AC-DH-09, AC-DH-10 deferred — [M] playtest-only ACs)
**Deviations**:
- ADVISORY: `DASH_COOLDOWN_DIMMED_ALPHA` (0.4) and `DASH_HINT_TEXT` are in-file constants (not data-driven). Consistent with codebase-wide pattern. `TODO(l10n)` added to DASH_HINT_TEXT.
- ADVISORY: No manual evidence file at `production/qa/evidence/sprint-5-dash-feedback-evidence.md`. Create during next playtest session.
- CODE REVIEW: `/code-review` returned CHANGES REQUIRED (`modulate.a` → `color.a` on ColorRect); all required changes applied before story close. Review confirmed complete.
**Test Evidence**: `tests/unit/combat-hud/combat_hud_dash_test.gd` — 7/7 PASSED, 0 orphans, exit 0 (2026-06-14)
**Code Review**: Complete — CHANGES REQUIRED resolved (color.a fix applied)
