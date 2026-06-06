# Story 001: CombatHUD Scene Skeleton, HP Bar, and Dead State

> **Epic**: CombatHUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: ~2 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: 2026-06-06 (Complete)

## Context

**GDD**: `design/gdd/combat-hud.md`
**Requirement**: `TR-CH-001`, `TR-CH-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005: Persistent HUD Sub-Scene Swap (primary) + ADR-0003: Signal-Driven Architecture (secondary)
**ADR Decision Summary**: CombatHUD is a `Control` node child of a `CanvasLayer` (layer 10) on the permanent `main.tscn` root — never freed across scene transitions. `process_mode = PROCESS_MODE_ALWAYS`. Connects to H&D and GSM signals in `_ready()`; never polls Autoload state directly.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CanvasLayer`, `PROCESS_MODE_ALWAYS`, `ProgressBar`, `Tween` all stable since Godot 4.0. `create_tween()` is the Godot 4.x API (`SceneTreeTween` — do NOT use `$Tween` or `Tween.new()` patterns from Godot 3). `tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` ensures tween continues during SceneTree pause.

**Control Manifest Rules (Presentation Layer)**:
- Required: Signal consumer only — CombatHUD never reads Autoload state directly (ADR-0003 Pattern 1)
- Required: `process_mode = PROCESS_MODE_ALWAYS` — renders during pause (ADR-0004, ADR-0005)
- Required: CanvasLayer layer 10 — above game world (ADR-0005)
- Forbidden: Polling Autoload state (e.g. `HealthAndDamage._fayde_current_hp`) — use signal params only

---

## Acceptance Criteria

*From GDD `design/gdd/combat-hud.md`, scoped to this story:*

- [ ] **AC-HUD-01** — GIVEN `damage_taken(fayde, 20, 80)` fires; WHEN `HP_BAR_DRAIN_DURATION` (0.15s) has elapsed (drive via `_process` accumulation); THEN `ProgressBar.value == 80`
- [ ] **AC-HUD-02a** — `HP_BAR_DRAIN_DURATION == 0.15` constant guard — verifies contract cannot be broken by accidental tuning to 0
- [ ] **AC-HUD-03** — GIVEN `damage_taken(fayde, 20, 80)` fires; WHEN signal processed (same frame); THEN `hp_label.text == "80 / 100"` (numeric readout updates immediately, no tween)
- [ ] **AC-HUD-07** — GIVEN `player_died` fires (ProgressBar.value == 0); WHEN `damage_taken(fayde, 10, 0)`, `health_restored(fayde, 6, 6)`, and `player_hp_zone_changed(HPZone.FULL)` each fire subsequently; THEN ProgressBar.value remains 0 AND bar fill modulate does NOT change for any of the three subsequent signals
- [ ] **AC-HUD-08** — GIVEN HP bar at 60; `health_restored(fayde, 6, 66)` fires; WHEN processed; THEN ProgressBar is tweening toward 66 (value between 60–66 before tween completes); modulate == `Color(0.6, 1.0, 0.6, 1.0)` at tween start; after `HEAL_TINT_DURATION` (0.20s), modulate == current zone color (NOT green)
- [ ] **AC-HUD-09** — `HP_BAR_FILL_DURATION >= 0.15` constant guard — verifies `sfx_fayde_heal` audio silence contract cannot be broken by tuning
- [ ] **AC-HUD-20** — GIVEN HP bar is mid-drain-tween (animating toward 60); `run_started` fires; WHEN processed; THEN `ProgressBar.value == FAYDE_MAX_HP` (100) immediately; no further tween toward 60
- [ ] **AC-HUD-21** — GIVEN zone = DESPERATE; 3 Label nodes active; chain dots visible; `run_started` fires; WHEN processed; THEN bar modulate == `Color("#F5F0E8")`; chain dots hidden; all 3 prior Labels freed
- [ ] **AC-HUD-22** — GIVEN HP bar is mid-drain-tween; `V_mid = ProgressBar.value` read mid-animation; second `damage_taken` fires with new target `V_new < V_mid`; WHEN new tween starts; THEN tween start value == `V_mid` (not original 100)

---

## Implementation Notes

*Derived from ADR-0005 and ADR-0003, and GDD Detailed Design:*

**Scene structure** (`src/scenes/CombatHUD.tscn`):
```
CombatHUD (Control)          ← root node; script: src/ui/combat_hud.gd
├── HpBar (ProgressBar)      ← max_value = 100; value = 100; no rounding
├── HpLabel (Label)          ← text = "100 / 100"
└── ChainDotsContainer (HBoxContainer)  ← visible = false until combat_started
```
CombatHUD is added as a child of the CanvasLayer (layer 10) in `main.tscn`. Do NOT add a CanvasLayer to the CombatHUD scene itself — the CanvasLayer is the parent, not the root.

**Signal connections in `_ready()`**:
```gdscript
process_mode = PROCESS_MODE_ALWAYS
HealthAndDamage.damage_taken.connect(_on_damage_taken)
HealthAndDamage.health_restored.connect(_on_health_restored)
HealthAndDamage.player_died.connect(_on_player_died)
HealthAndDamage.player_hp_zone_changed.connect(_on_hp_zone_changed)
GameStateManager.run_started.connect(_on_run_started)
GameStateManager.preparation_started.connect(_on_preparation_started)
GameStateManager.combat_started.connect(_on_combat_started)
```
Disconnect all in `_exit_tree()` with `is_connected()` guards (ADR-0003 Rule 4).

**HP drain tween (AC-HUD-01)**:
```gdscript
func _on_damage_taken(target: Node, _amount: float, current_hp: float) -> void:
    if _dead or not target.is_in_group(&"player"): return  # handle enemy hits in Story 003
    hp_label.text = "%d / %d" % [int(current_hp), FAYDE_MAX_HP]  # immediate, no tween
    if _active_tween and _active_tween.is_valid(): _active_tween.kill()
    _active_tween = create_tween()
    _active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    _active_tween.tween_property(hp_bar, "value", current_hp, HP_BAR_DRAIN_DURATION)
```
Store current bar value via `hp_bar.value` before killing the tween — that IS the `V_mid` for AC-HUD-22 (Godot tween kills do not snap the property).

**DEAD state** — set `_dead = true` on `player_died`; early-return on all H&D signal handlers when `_dead == true`. Reset on `run_started`.

**run_started reset**:
```gdscript
func _on_run_started() -> void:
    _dead = false
    if _active_tween and _active_tween.is_valid(): _active_tween.kill()
    hp_bar.value = FAYDE_MAX_HP
    hp_label.text = "%d / %d" % [FAYDE_MAX_HP, FAYDE_MAX_HP]
    hp_bar.modulate = Color(HP_COLOR_FULL)
    hp_label.add_theme_color_override(&"font_color", Color("#FFFFFF"))
    chain_dots_container.visible = false
    _free_all_damage_labels()  # Story 003 method; stub as pass here
```

**Constants**:
```gdscript
const FAYDE_MAX_HP: int = 100
const HP_BAR_DRAIN_DURATION: float = 0.15
const HP_BAR_FILL_DURATION: float = 0.20
const HEAL_TINT_DURATION: float = 0.20
const HP_COLOR_FULL: String = "#F5F0E8"
```

**Testing pattern** — CombatHUD is a Control (scene node, NOT Autoload). Add to tree via `add_child()`:
```gdscript
const CombatHUDScript = preload("res://src/ui/combat_hud.gd")
var hud: Node = CombatHUDScript.new()
add_child(hud)
hud.set_process(false)   # drive manually via _process(delta)
```
Fayde reference: create a `MockFayde` that is `add_to_group(&"player")`. Use `hud.hp_bar` and `hud.hp_label` directly.

---

## Out of Scope

*Handled by neighbouring stories:*

- [Story 002]: Zone color treatment (FULL/CAREFUL/DESPERATE), heal tint revert, DESPERATE pulse
- [Story 003]: Floating damage numbers (enemy hits, label spawning, pool cap)
- [Story 004]: Chain dot indicator

---

## QA Test Cases

*Embedded from `production/qa/qa-plan-sprint-3-2026-06-03.md` (S3-09 specs).*

**Test file**: `tests/unit/combat-hud/combat_hud_test.gd` (HP bar section)
**Evidence file**: `production/qa/evidence/combat-hud-skeleton-evidence.md`

- **AC-HUD-01**: HP bar value updates after drain tween
  - Given: CombatHUD in tree; `hp_bar.value = 100`; MockFayde in "player" group
  - When: `HealthAndDamage.damage_taken.emit(mock_fayde, 20.0, 80.0)`; then `hud._process(0.16)` (> 0.15s)
  - Then: `assert_float(hud.hp_bar.value).is_equal_approx(80.0, 0.1)`

- **AC-HUD-02a**: HP_BAR_DRAIN_DURATION constant guard
  - Given: CombatHUD loaded
  - When: read constant
  - Then: `assert_float(hud.HP_BAR_DRAIN_DURATION).is_equal(0.15)`

- **AC-HUD-03**: Numeric readout updates immediately (same frame)
  - Given: CombatHUD in tree; `hp_bar.value = 100`
  - When: `HealthAndDamage.damage_taken.emit(mock_fayde, 20.0, 80.0)` (no _process call)
  - Then: `assert_str(hud.hp_label.text).is_equal("80 / 100")`

- **AC-HUD-07**: DEAD state — all HP signals ignored after player_died
  - Given: `HealthAndDamage.player_died.emit()` fired (bar at 0)
  - When: `damage_taken.emit(...)`, `health_restored.emit(...)`, `player_hp_zone_changed.emit(HPZone.FULL)` each fire
  - Then: `hud.hp_bar.value == 0`; modulate unchanged for all three signals

- **AC-HUD-08**: Heal tween fires; green tint applied then reverts
  - Given: `hp_bar.value = 60`; FULL zone (warm white modulate)
  - When: `HealthAndDamage.health_restored.emit(mock_fayde, 6.0, 66.0)`
  - Then: bar is tweening toward 66 (value between 60–66 without process advance); modulate == `Color(0.6, 1.0, 0.6, 1.0)` immediately; after `_process(0.21)`, modulate reverts to zone color

- **AC-HUD-09**: HP_BAR_FILL_DURATION satisfies audio silence contract
  - Then: `assert_bool(hud.HP_BAR_FILL_DURATION >= 0.15).is_true()`

- **AC-HUD-20**: run_started cancels tween and resets to max
  - Given: mid-drain tween active (bar animating toward 60)
  - When: `GameStateManager.run_started.emit()`
  - Then: `assert_float(hud.hp_bar.value).is_equal(100.0)` immediately; no tween continues

- **AC-HUD-21**: run_started resets zone, hides dots, frees labels
  - Given: 3 Label children exist; chain_dots_container visible; modulate = DESPERATE red
  - When: `GameStateManager.run_started.emit()`
  - Then: modulate == `Color("#F5F0E8")`; `chain_dots_container.visible == false`; all 3 labels freed

- **AC-HUD-22**: Mid-tween rapid hit — new tween from current mid-value
  - Given: bar at 100; drain tween started toward 60; `_process(0.07)` advances bar to ~V_mid ≈ 53
  - When: second `damage_taken.emit(mock_fayde, 10.0, 50.0)` fires
  - Then: tween starts from current `hp_bar.value` (≈53), not from 100

**Manual verification** (AC-HUD-02b): confirm HP bar visibly interpolates (no snap) in a real Godot session.

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/combat-hud-skeleton-evidence.md` + sign-off (ADVISORY)
Unit tests in `tests/unit/combat-hud/combat_hud_test.gd` are strongly recommended but ADVISORY for UI stories.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: HealthAndDamage epic DONE (signals live) ✅; GameStateManager epic DONE ✅; main.tscn exists ✅
- Unlocks: Story 002 — HP Zone Colors and Heal Tween

---

## Completion Notes
**Completed**: 2026-06-06
**Criteria**: 9/9 passing (all COVERED by unit tests; manual walkthrough evidence ADVISORY — deferred)
**Deviations**:
- ADVISORY: Float accumulator timers used instead of `create_tween()` from story implementation notes — better ADR-0004 alignment, fully testable headless
- ADVISORY: `SpellCastingEffects.chain_index_changed` and `spell_hit_element` connected as stubs in Story 001 (Story 003/004 forward-compat)
**Test Evidence**: UI story — 10/10 unit tests pass (`tests/unit/combat-hud/combat_hud_test.gd`); manual walkthrough evidence (`production/qa/evidence/combat-hud-skeleton-evidence.md`) deferred (ADVISORY)
**Code Review**: APPROVED WITH SUGGESTIONS — all required changes (tint timer death cancel, RunManager state isolation) and all suggestions applied; re-run clean (10/10, 0 errors, 0 orphans, 0 push_errors)
