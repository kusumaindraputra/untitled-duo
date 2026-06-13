# Story 005: PranaGrid Compact Mode in Combat

> **Epic**: Prana Grid
> **Status**: Ready
> **Layer**: UI
> **Type**: UI
> **Estimate**: 1.5 days
> **Sprint ID**: S5-04
> **Manifest Version**: 2026-06-12
> **Last Updated**: 2026-06-12

## Context

**GDD**: `design/gdd/prana-grid.md`
**Sprint**: Sprint 5 — Legibility Pass

**Playtest finding (Sprint 4)**: During LOCKED state (Combat Phase), the full-size Prana Grid panel occupied screen space but offered no interactivity, partially blocking the arena. Additionally, at playtest tester SAK was confused about what was on the right side of the screen during combat.

**Desired behavior**: Full panel during Preparation; compact 3×3 indicator (read-only, small) in the bottom-right corner during Combat. This keeps the arrangement visible for reference without crowding the play area.

**GDD status**: This story adds compact mode behavior to the LOCKED state. GAP-2 resolved 2026-06-13 — prana-grid.md Rule 3, UI Requirements, Visual Requirements, and AC-PG-12 updated with compact indicator spec.

**ADR Governing Implementation**: ADR-0003: Signal-Driven Architecture
State transition driven by `combat_started` / `preparation_started` signals — no polling.

**Engine**: Godot 4.6 | **Risk**: LOW

**Control Manifest Rules (UI layer)**:
- Required: Compact indicator uses `PranaCatalog.get_type(id).color` for filled dot colors — no hardcoded hex
- Required: Signal-driven state transitions only
- Forbidden: Compact mode does not process any input — `mouse_filter = MOUSE_FILTER_IGNORE` on all compact node children

---

## ~~⚠️ Pre-Implementation Requirement (GAP-2)~~ — RESOLVED 2026-06-13

`design/gdd/prana-grid.md` amended: Rule 3, UI Requirements (Layout + Grid Panel), Visual Requirements (LOCKED row), and AC-PG-12 all updated with compact indicator spec. Key decisions locked in GDD:
1. **Compact node**: `%CompactIndicator` — `Control` child of PranaGrid, distinct from main grid panel ✅
2. **Dimensions**: ≤60×60px; 3×3 array of 14×14px dots with 4px gaps ✅
3. **Position**: bottom-right corner, within Combat HUD reserved region (≤288×216px) ✅
4. **Visual**: filled dot = `PranaCatalog.get_type(slot_type_id).color`; empty dot = `Color("#333333")` ✅
5. **Transition**: immediate on `grid_locked` (no animation at FP scope) ✅

---

## Acceptance Criteria

*Derived from playtest feedback + GDD LOCKED state rules.*

- [ ] **AC-CG-01** — During ARRANGEMENT state: full 3×3 grid panel visible and interactive; `compact_indicator` NOT visible
- [ ] **AC-CG-02** — On `combat_started`: full grid panel hides; `compact_indicator` becomes visible in bottom-right corner
- [ ] **AC-CG-03** — Compact indicator position: within the Combat HUD bottom-right reserved region (bottom-right quadrant of screen, not overlapping HP bar region)
- [ ] **AC-CG-04** — Compact indicator renders the committed arrangement: slot filled with type N shows dot color == `PranaCatalog.get_type(N).color`; empty slot shows `Color("#333333")`
- [ ] **AC-CG-05** — On `preparation_started`: `compact_indicator` hides; full grid panel becomes visible and resets (ARRANGEMENT entry, all slots empty per AC-PG-01)
- [ ] **AC-CG-06** — `grid_hidden` signal: compact indicator also hides (HIDDEN state applies to all grid representations)
- [ ] **AC-CG-07** — Compact indicator is non-interactive: mouse clicks and gamepad input on compact indicator produce no state change; `mouse_filter == MOUSE_FILTER_IGNORE`
- [ ] **AC-CG-08** [M] — Compact indicator does not visually overlap the HP bar region (top-left ≤ 15% × ≤ 8% screen)
- [ ] **AC-CG-09** [M] — Full 3×3 grid panel is not visible during Combat Phase (does not occupy arena space)

---

## Implementation Notes

*GAP-2 resolved — spec is locked in prana-grid.md Rule 3.*

**CompactIndicator node structure** (placeholder):
```
PranaGrid (Control / Panel)
├── GridPanel (Panel)            ← existing full-size grid
│   └── ...
└── CompactIndicator (Control)   ← new node; mouse_filter = MOUSE_FILTER_IGNORE
    └── DotsContainer (GridContainer, columns=3)
        ├── Dot0 (ColorRect, 14×14)
        ├── Dot1 (ColorRect, 14×14)
        └── ... (9 total)
```

**State transitions**:
```gdscript
func _on_combat_started(_is_boss: bool) -> void:
    # existing LOCKED logic...
    _grid_panel.visible = false
    _update_compact_dots()
    _compact_indicator.visible = true

func _on_preparation_started(_wave_index: int, _remaining: int) -> void:
    _compact_indicator.visible = false
    _grid_panel.visible = true
    # existing ARRANGEMENT reset...

func _update_compact_dots() -> void:
    for i in range(9):
        var dot: ColorRect = _dot_nodes[i]
        var fragment: PranaFragment = _committed_fragments[i]
        dot.color = PranaCatalog.get_type(fragment.type_id).color if fragment != null else Color("#333333")
```

**Position setup**: Set `compact_indicator` anchor to bottom-right via Godot anchor preset in editor. Use absolute offset within the Combat HUD reserved region. Do not compute in code — anchor + offset is more reliable (same lesson as prana-grid panel position in Sprint 4).

---

## Out of Scope

- Compact mode animation / transition effects — FP scope is immediate
- Compact mode showing slot index overlay or type icons — dots only at FP scope
- Accessibility: color-alone compact dots — noted as VS gap (same as main grid accessibility note)

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-5-2026-06-12.md` (S5-04 specs).*

**Test file**: `tests/unit/prana-grid/prana_grid_compact_test.gd`
**Evidence file**: `production/qa/evidence/sprint-5-compact-grid-evidence.md`

- **AC-CG-01/02**: State transitions on signals
  - Given: PranaGrid in ARRANGEMENT; `_compact_indicator` child exists
  - When: `GameStateManager.combat_started.emit(false)` (or directly call `_on_combat_started(false)`)
  - Then: `_grid_panel.visible == false`; `_compact_indicator.visible == true`

- **AC-CG-05**: preparation_started reverses transition
  - Given: PranaGrid in LOCKED (compact visible, panel hidden)
  - When: `GameStateManager.preparation_started.emit(0, 1)`
  - Then: `_compact_indicator.visible == false`; `_grid_panel.visible == true`

- **AC-CG-04**: Compact dot color matches committed fragment
  - Given: slot 4 filled with Ashfire (type_id=0); `arrangement_confirmed` accepted; `combat_started` fires
  - When: compact indicator renders
  - Then: `_dot_nodes[4].color == PranaCatalog.get_type(0).color`

- **AC-CG-04** empty: Empty slot dot = dark color
  - Given: slot 0 is null in committed_fragments
  - Then: `_dot_nodes[0].color == Color("#333333")`

- **AC-CG-03**: Compact position in bottom-right region
  - Given: viewport size 1280×720 (test scene)
  - When: compact visible
  - Then: `_compact_indicator.global_position.x > 1280 * 0.70` AND `_compact_indicator.global_position.y > 720 * 0.70`

- **AC-CG-06**: grid_hidden hides compact
  - Given: compact visible (LOCKED state)
  - When: `GameStateManager.grid_hidden.emit()` (or equivalent)
  - Then: `_compact_indicator.visible == false`

- **AC-CG-07**: mouse_filter on compact
  - Then: `_compact_indicator.mouse_filter == Control.MOUSE_FILTER_IGNORE`

**Manual**:
- **AC-CG-08**: Screenshot confirms compact indicator does not overlap HP bar region
- **AC-CG-09**: Screenshot confirms full grid panel hidden during combat

---

## Test Evidence

**Story Type**: UI
**Required evidence**: `production/qa/evidence/sprint-5-compact-grid-evidence.md` + screenshot (ADVISORY)
**Automated tests**: `tests/unit/prana-grid/prana_grid_compact_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: PranaGrid story-001 (phase gating), story-002 (committed_fragments), story-003 (CR integration) — all DONE
- GAP-2 GDD amendment — DONE 2026-06-13
- Unlocks: S5-07 (gamepad input) depends on S5-04 being Done
