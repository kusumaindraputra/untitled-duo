# HUD Design

> **Status**: Approved — /ux-review 2026-05-31 (0 blocking, 4 advisory)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-31
> **Template**: HUD Design

---

## HUD Philosophy

> **One-sentence rule:** The HUD is a dungeon instrument, not a game interface — present always, intrusive never.

The Last Cipher's HUD philosophy is **minimal but present**: only what the player must have in peripheral awareness is always visible. The game world owns ≥80% of screen area at all times. The Prana grid and HP bar are the two permanent anchors — everything else appears only when the current phase or game state makes it genuinely necessary.

This philosophy has a direct relationship with the two-phase combat loop. During **Preparation Phase**, the HUD earns its maximum real estate: the Prana grid is the active decision surface, enemies are visible in the arena at their starting positions, and the player is thinking. During **Combat Phase**, the HUD recedes: the grid dims and locks, the arena takes over. Floating damage numbers appear transiently above hit targets, then vanish. No element competes with the action.

The visual language follows the Art Bible directive: HUD chrome is carved from the same stone as the dungeon — E1 dark fills, E7 warm lantern accents, rounded stone shapes. Not a floating overlay; not a sci-fi readout. An instrument panel built into the dungeon wall, discovered rather than imposed.

**Density covenant:** All permanent HUD elements combined must occupy ≤20% of screen area during Combat Phase. Preparation Phase expands the grid with the Type Selector, but the core UI (HP + grid) cannot exceed 20%.

**Scope covenant (First Playable):** At First Playable, the HUD is: HP bar + damage numbers + cast chain dots + Prana grid. Status effect icons and Wave Counter are designed here but deferred to MVP implementation.

---

## Information Architecture

### Full Information Inventory

Every piece of information the HUD must communicate during an active run, drawn from GDD UI Requirements sections (Combat HUD, Prana Grid, Health & Damage, Status Effects, Wave/Encounter System, Game Concept):

| # | Information | Source GDD |
|---|------------|-----------|
| 1 | Fayde's HP bar fill (current / max) | Health & Damage, Combat HUD |
| 2 | Fayde's HP numeric readout (`72 / 100`) | Health & Damage, Combat HUD |
| 3 | HP zone state treatment (FULL / CAREFUL / DESPERATE) | Health & Damage, Combat HUD |
| 4 | Prana grid arrangement — 3×3 committed state | Prana Grid, Combat HUD |
| 5 | Floating damage numbers (amount + Prana color) | Combat HUD |
| 6 | Cast chain dot indicator (position in cast sequence) | Combat HUD, Spell Casting & Effects |
| 7 | Prana Type Selector — available types for drag/placement | Prana Grid |
| 8 | Confirm / Clear All action buttons | Prana Grid |
| 9 | Wave Counter (`Wave 2 / 5`) | Art Bible §7 |
| 11 | Active status effects on Fayde — icon + duration | Status Effects |
| 12 | Memo companion hints | Game Concept (Core Loop) |

### Categorization

| Category | Definition |
|----------|-----------|
| **Must Show** | Always visible during an active run — player needs it for core decisions at all times |
| **Contextual** | Visible only when the current game phase or state makes it relevant |
| **On Demand** | Player-triggered or auto-surfaced as a non-blocking notification |

| # | Information | Category | Trigger / Condition |
|---|------------|----------|---------------------|
| 1 | HP bar fill | **Must Show** | Always during run |
| 2 | HP numeric readout | **Must Show** | Always during run |
| 3 | HP zone color state | **Must Show** | Applied to HP bar (a state of #1, not a separate element); updates on zone crossing |
| 4 | Prana grid arrangement | **Must Show** | Always during run — dimmed to 70% opacity and locked during Combat Phase |
| 5 | Floating damage numbers | **Contextual** | Combat Phase only — transient, world-space, auto-expire |
| 6 | Cast chain dots | **Contextual** | Combat Phase only, and only when a spell has been cached by SC&E |
| 7 | Prana Type Selector + action buttons | **Contextual** | Preparation Phase only — hidden when `combat_started` fires |
| 8 | Wave Counter | **Contextual** | Active run only — visible in top-right from `run_started` to `run_ended`; hidden on Main Menu / Death Screen / Run Summary |
| 10 | Active status effects | **Contextual** | Visible only when ≥1 status effects are active on Fayde; hidden when none are active |
| 11 | Memo hints | **On Demand** | Screen-edge notification (IP-12) — auto-surfaced by game event, auto-dismisses; never blocks gameplay |

**Philosophy check:** The Must Show list has 3 elements (HP bar, HP numeric, Prana grid arrangement). This is consistent with the "minimal but present" philosophy — the game world owns ≥80% of screen area during Combat Phase.

**Scope notes:**
- Items 5, 6: First Playable scope — specified in Combat HUD GDD.
- Items 7, 8: First Playable scope — Prana Grid panel and Type Selector.
- Items 9, 10 (Wave Counter, Status Effects): Designed here; deferred to **MVP implementation** scope.
- Item 11 (Memo hints): Designed here; implementation follows **Companion/Narrative epic**.

---

## Layout Zones

Six zones at 1920×1080 reference resolution. All elements anchor with an 8px margin from screen edges.

### Wireframes

```
PREPARATION PHASE
┌───────────────────────────────────────────────────────────────────────┐
│ [Zone A: HP ████████ 72/100  ● ○ ○]        [Zone B: Wave 2/5 ■■■□□]  │
│                                                                       │
│                    GAME WORLD (enemies visible at start positions)    │
│                        (isometric arena — ≥80%)                       │
│                                                                       │
│ [Zone C: Status ○○○○]   [Zone D: SELECTOR][PRANA GRID]               │
└───────────────────────────────────────────────────────────────────────┘

COMBAT PHASE
┌───────────────────────────────────────────────────────────────────────┐
│ [Zone A: HP ████████ 72/100  ● ● ○]        [Zone B: Wave 2/5 ■■■□□]  │
│                                                                       │
│                        GAME WORLD                                     │
│                 [Zone F: floating dmg numbers]                        │
│                                                                       │
│ [Zone C: Status ○○]                 [Zone D: PRANA GRID — 70% locked] │
└───────────────────────────────────────────────────────────────────────┘
```

### Zone Reference Table

| Zone | Name | Contents | Visible When | Approx Size (1080p) |
|------|------|----------|-------------|---------------------|
| A | **Top-left** | HP bar + numeric readout + chain dots | Always during active run | ≤288px × ≤86px |
| B | **Top-right** | Wave Counter (`Wave 2 / 5`) | Active run — from `run_started` to run end (MVP scope) | ~160px × ~40px |
| C | **Bottom-left** | Active status effect icons + duration rings | Visible when ≥1 effect active on Fayde (MVP scope) | ~96px × ~24px per row; max 4 icons |
| D | **Bottom-right** | Type Selector (left, Prep only) + Prana Grid (always) | Grid always; Type Selector + Confirm/Clear buttons collapse on `combat_started` | Grid: ≤216×216px; Selector: ~40px wide |
| E | **World overlay** | Floating damage numbers | Combat Phase — transient, world-space, auto-expire after 0.8s | Per-label ~40×20px; pool cap = 12 |

### Footprint Accounting (1920×1080)

| Phase | Active Zones | Est. Screen Coverage |
|-------|-------------|---------------------|
| Combat (permanent) | A + B + D (grid only) + C (when active) | ~4–5% |
| Preparation (maximum) | A + B + C + D (full) | ~7–8% |

Both well within the 20% density covenant from HUD Philosophy.

### Zone Rules

- **Zone A must never overlap Zone D.** These are the two permanent anchors — mutual exclusion is a hard constraint.
- **Zone E (floating labels) may overlap any zone.** They are world-space transients and appear where hits occur — overlap with the Prana Grid is accepted per Combat HUD GDD §Rule 8.
- **Scale at non-1080p:** Use Godot anchor presets and `CanvasLayer` stretch. No hardcoded pixel positions — all element sizes scale proportionally with viewport size.

---

## HUD Elements

Elements are organized by layout zone. All GDD cross-references are per the Combat HUD GDD, Prana Grid GDD, Health & Damage GDD, and Interaction Pattern Library.

---

### Zone A: Top-Left — HP & Cast Feedback

The zone occupies ≤288×86px anchored 8px from the top-left screen edges. Three sub-elements stack vertically.

#### A1 — HP Bar (IP-01)

- `ProgressBar` or `TextureProgressBar`, 192×14px. 2px border, no rounded corners (pixel art style). Dark fill track.
- `bar_fill = current_hp / FAYDE_MAX_HP`. Updated via tween on every `damage_taken` / `health_restored` signal from Health & Damage.
- Drain tween: 0.15s TRANS_LINEAR. Fill tween: 0.20s TRANS_LINEAR. Mid-animation hit cancels active tween and starts a new one from the current mid-value — no snap back.
- Zone color transitions — **instantaneous** (the abrupt shift is the alarm signal, not a gradient):
  - FULL: warm white fill `#F5F0E8`, label white `#FFFFFF`
  - CAREFUL: amber fill + label `#FFA500`
  - DESPERATE: red fill + label `#FF3333` + looping scale pulse (1.0→1.03→1.0 over 0.8s; stops immediately on zone exit)
- Heal tint: green modulate `Color(0.6, 1.0, 0.6, 1.0)` for 0.20s on `health_restored`, then reverts to current zone color — not to FULL zone color. Satisfies Health & Damage's `sfx_fayde_heal` audio silence contract (tween ≥0.15s + distinct color shift).
- On `player_died`: bar frozen at 0/max. No further HP updates.
- On `run_started`: immediate reset to `FAYDE_MAX_HP`, zone to FULL. No heal tint — run reset is not a heal event.

#### A2 — HP Numeric Readout

- `Label`, ~72×18px, positioned 4px right of the HP bar.
- Format: `"72 / 100"`. Font: monospace/tabular figures, 16–18px at 1080p.
- Color matches current zone (FULL = white `#FFFFFF`, CAREFUL = amber `#FFA500`, DESPERATE = red `#FF3333`).
- **Updates synchronously** — no tween. The bar tweens, the number snaps. 1px black outline for legibility.

#### A3 — Cast Chain Dots (IP-03)

- Row of N filled circles (6px diameter, 4px gap), positioned 8px below the HP bar.
- **Hidden during Preparation Phase.** Shown only when a spell has been cached by Spell Casting & Effects and Combat Phase is active.
- Active dot (current position in cast sequence): primary Prana type color from `PranaCatalog.get_type(primary_type_id).color`.
- Inactive dots: `#888888` grey.
- On `preparation_started`: all dots hidden, state reset.
- On chain completion (index returns to 0 after reaching N): all dots reset to grey for one frame, then the new cycle begins. This micro-reset communicates the loop boundary.
- Null fallback: if `get_cached_spell_effect()` returns null, active dot falls back to white `#FFFFFF`. No error logged.

---

### Zone B: Top-Right — Wave Counter *(MVP scope)*

- Small panel (~160×40px), anchored 8px from the top-right screen edge.
- Text: `"Wave 2 / 5"` in warm off-white `#D4C9B8` on E1 Dungeon Stone `#3A3530` panel background. 8px bitmap font at 1× scale.
- Enemy composition row: 8×8px archetype silhouette icons showing the type mix of the current wave. No text labels — shape alone identifies archetype (Drifter = wide flat, Charger = tall narrow, Cluster = central+orbiting). Icon fill: E2 Worn Slate `#474B52`.
- Visible from `run_started` to run end. Hidden on Main Menu, Death Screen, and Run Summary.
- **Deferred to MVP implementation.** Design is complete here; implementation awaits Wave/Encounter System epic.

---

### Zone C: Bottom-Left — Status Effects *(MVP scope)*

- Row of up to 4 status effect icons, 12×12px each, 4px gap between icons. Anchored 8px from the bottom-left screen edge.
- Each icon: Prana type's silhouette shape (per Art Bible §4.5 icon set) centered on a Prana-color background fill.
- Duration ring: a radial fill border draining clockwise around the icon. Full ring = freshly applied; empty ring = expiring.
- Icons appear in application order (leftmost = most recent). When an effect expires, its icon removes. At First Playable scope, remaining icons do not reposition (no stack-shift animation — avoids visual noise).
- Visible only when ≥1 effects are active on Fayde. Hidden when no effects are active.
- **Deferred to MVP implementation.** Design is complete; implementation awaits Status Effects system integration.

---

### Zone D: Bottom-Right — Prana Grid + Type Selector

The game's primary decision surface. ≤216×216px for the grid; Type Selector (~40px wide) sits directly left of the grid during Preparation. Combined footprint ≤260×216px. Anchored 8px from the bottom-right and bottom screen edges.

#### D1 — Prana Grid Slots (IP-04)

- 3×3 matrix of circular slot nodes within an octagonal container frame.
- Slot 4 (centre): subtle accent ring marks the combo primary slot — accent must not obscure a placed token.
- **Slot state visual** (per IP-04):

  | State | Fill | Overlay | Scale |
  |-------|------|---------|-------|
  | Empty (ARRANGEMENT) | Dark fill `#1B1B22` + faint inner glow (idle pulse) | None | 1.0 |
  | Occupied | Prana type's canonical color + centered 8×8 icon | None | 1.0 |
  | Cursor-selected (gamepad) | As above | White/gold border highlight | 1.05× |
  | Drag-over (mouse, valid target) | As above | Pulsed highlight ring | 1.0 |
  | LOCKED (Combat Phase) | As above | 70% opacity dim (IP-09) | 1.0 |

- All token colors and icons sourced from `PranaCatalog.get_type(id)` — never hardcoded.
- Phase gating (IP-09): on `combat_started`, grid dims to 70% opacity, all input disabled. On `preparation_started`, grid resets to 100% opacity, all slots clear, input re-enabled.

#### D2 — Type Selector Panel (IP-06) — *Preparation Phase only*

- Positioned directly left of the Prana Grid. Visible during Preparation; hides on `combat_started`; reappears on `preparation_started`.
- **Mouse mode (primary):** Vertical column of 5 draggable Prana type tokens. Each token: Prana color fill + 8×8 icon. Source-infinite — dragging does not remove from panel. All 5 always shown. Initiates IP-05 Drag-and-Drop Token on mouse-down.
- **Gamepad mode:** Replaced by a Type Indicator widget showing the currently selected type (color + icon + type name label). Left/Right shoulder buttons cycle through all 5 types. Cycle wraps. Exact button bindings: Input Map GDD (not yet authored).
- LOCKED state: dims to 70%, interaction disabled.

#### D3 — Confirm Button (IP-08) — *Preparation Phase only*

- Label: "Confirm" or equivalent icon. Keyboard: Enter. Gamepad: South face button (binding: Input Map GDD).
- **Enabled** when slot 4 (centre) is filled — regardless of other slots.
- **Disabled** (40% opacity, greyed, non-interactive) when slot 4 is empty.
- Disabled + shortcut pressed: red border flash on the grid container for 0.4s + brief tooltip `"place a fragment in the centre slot"` for 1.5s. No state change.
- Hidden on `combat_started`. Reappears on `preparation_started`.

#### D4 — Clear All Button (IP-11) — *Preparation Phase only*

- Label: "Clear All" or equivalent icon. Always enabled during ARRANGEMENT state.
- On activate: all 9 slots clear immediately. Confirm button enters disabled state.
- Keyboard/gamepad binding: TBD — Input Map GDD.
- Hidden on `combat_started`. Reappears on `preparation_started`.

#### D5 — Gamepad Grid Navigator (IP-07)

- Software cursor for d-pad/stick navigation across the 9 grid slots.
- Initial position: slot 0 (top-left) on `preparation_started`. Hard edges — no wrap.
- Hidden during LOCKED state; cursor position preserved.
- Keyboard equivalents: Arrow keys = d-pad directions. Tab cycles slots in reading order (0→8, wraps to 0).
- On mouse drag start: cursor hides. On next d-pad/stick input: cursor reappears at last-held slot.

---

### Zone E: World Overlay — Floating Damage Numbers (IP-02) *(Combat Phase only)*

- `Label` nodes parented to the HUD `CanvasLayer` (layer 10). Spawned at the hit target's `global_position` converted to viewport coordinates via `get_viewport().get_canvas_transform()`.
- **Color encoding:**
  - Enemy target + same-frame elemental signal: Prana type color from `PranaCatalog.get_type(prana_type_id).color`
  - Enemy target + no elemental signal: white `#FFFFFF` (neutral hit)
  - Fayde target (CONTACT damage): grey `#AAAAAA`
- **Animation:** float upward 32px over 0.8s (position: TRANS_LINEAR), fade alpha 1.0→0.0 from 0.5s to 0.8s (alpha: TRANS_CUBIC / EASE_IN). `queue_free()` on tween completion.
- **Spawn jitter:** ±8px random X offset per label — prevents stacking on simultaneous hits.
- **Pool cap:** 12 concurrent labels. Oldest label freed before spawning if cap is reached.
- Font: same bitmap pixel font as HP readout, bold, 14–16px at 1080p, 1px black outline.

---

## Dynamic Behaviors

All HUD state changes are driven by `GameStateManager` and system signals. The HUD never polls state — it listens exclusively to signals.

### Signal → HUD State Change Table

| Signal / Trigger | HUD Changes |
|---|---|
| `run_started` | HP bar resets to FAYDE_MAX_HP immediately (no tween). Zone → FULL. Chain dots hidden. All active damage labels freed. Wave Counter appears. Status effect icons clear. |
| `preparation_started` | Type Selector, Confirm, Clear All appear. Grid resets to 100% opacity, all slots empty. Gamepad cursor resets to slot 0. Chain dots hidden. |
| `grid_locked` + `combat_started` | Type Selector, Confirm, Clear All hide. Grid dims to 70% opacity (IP-09). Gamepad cursor hides. Chain dots become active (shown on first `chain_index_changed` received). |
| `player_hp_zone_changed(CAREFUL)` | HP bar fill and numeric label → amber `#FFA500` (instantaneous transition). Pulse animation stops if active. |
| `player_hp_zone_changed(DESPERATE)` | HP bar fill and numeric label → red `#FF3333` (instantaneous). Looping scale pulse begins (1.0→1.03→1.0, 0.8s cycle). |
| `player_hp_zone_changed(FULL)` | HP bar fill and numeric label → warm white `#F5F0E8` / white `#FFFFFF` (instantaneous). Pulse animation stops if active. |
| `damage_taken(target, amount, current_hp)` | HP bar drains (0.15s tween). Numeric readout snaps. Floating damage label spawns at target world position. |
| `health_restored(target, amount, current_hp)` | HP bar fills (0.20s tween). Green tint `Color(0.6, 1.0, 0.6, 1.0)` for 0.20s then reverts to current zone color. Numeric readout snaps. |
| `chain_index_changed(combo_index, attack_count)` | Chain dots redraw — active dot advances to `combo_index` in Prana type color; all others → grey `#888888`. |
| `spell_hit_element(target, prana_type_id)` | Colors the damage number spawned in the same frame for the matching target. |
| `player_died` | HP bar frozen at 0/max. Zone color holds at last state. Chain dots hidden. No further HP signal processing. |
| `game_paused` | HUD state preserved unchanged. Active tweens continue (`PROCESS_MODE_ALWAYS`) — HP bar does not freeze mid-animation. |

### Phase Density Summary

| Phase | Active Zones | Dominant Visual Element |
|-------|-------------|------------------------|
| Preparation | A + B + C (active) + D (full) | Prana Grid (decision surface) + arena view |
| Combat | A + B + C (active) + D (locked) + E (transient) | Game world + floating numbers |
| Run end / menus | None | — |

---

## Platform & Input Variants

**Input context (from `technical-preferences.md`):** Keyboard/Mouse (primary, mouse-optimized for drag-and-drop Prana grid), Gamepad (partial support). No touch, no hover-only interactions.

**Target platform:** PC only (Steam / itch.io). No mobile safe zones. Reference resolution: 1920×1080, 16:9 aspect ratio. Minimum 8px HUD margins at all supported resolutions.

### Input Behavior Per HUD Element

| HUD Element | Mouse/Keyboard | Gamepad |
|-------------|---------------|---------|
| HP bar (A1), chain dots (A3), damage numbers (F) | Display only — no interaction | Same |
| Wave Counter (B), Status Effects (C) | Display only | Same |
| **Type Selector (D2)** | 5 draggable token icons — drag initiates IP-05 Drag-and-Drop | Replaced by Type Indicator widget; Left/Right shoulder buttons cycle types (IP-06) |
| **Grid slots (D1)** | Left-click to drop dragged token onto slot; right-click to remove token; drag-over targets show highlight | D-pad / left stick cursor (IP-07); South button to place; dedicated Remove button (binding: Input Map GDD) |
| **Confirm button (D3)** | Click or Enter key | South face button (binding: Input Map GDD) |
| **Clear All button (D4)** | Click or keyboard shortcut (TBD — Input Map GDD) | Button TBD — Input Map GDD |
| **Gamepad cursor (D5)** | Hidden when mouse drag is active; reappears on next d-pad/stick input | D-pad / left stick; Tab / arrow keys as keyboard equivalents |

### No Platform Variants

This is a PC-only release. No platform-specific layout changes, safe zone adjustments, or resolution breakpoints are required beyond proportional scaling via Godot `CanvasLayer` stretch settings.

---

## Accessibility

No formal accessibility tier has been committed (`design/accessibility-requirements.md` does not exist). The Art Bible §4.5 (Colorblind Safety) provides the current baseline. The pre-production gate check flags accessibility requirements as a blocker — this section documents the current state and known gaps for the `/gate-check` review.

### Current Coverage

| Element | Accessibility Method | Status |
|---------|---------------------|--------|
| Prana type tokens (grid + selector) | Icon silhouette (8×8px) + color — mandatory per Art Bible §4.5 | ✓ Covered |
| Archetype icons (Wave Counter) | Shape silhouette (Drifter/Charger/Cluster distinctly readable) | ✓ Covered |
| Status effect icons | Prana type silhouette shape + color background | ✓ Covered |
| Damage numbers | Position at hit target is the primary context; color is supplementary | ✓ Covered |
| All interactive elements | Fully reachable via keyboard (arrow keys, Tab, Enter) and gamepad. No hover-only interactions. | ✓ Covered |
| Screen reader | Not supported at First Playable scope | Known gap — deferred |

### Known Gaps (First Playable scope)

| Gap | Current State | Planned Remediation |
|-----|--------------|---------------------|
| **HP zone states** | Color only (FULL/CAREFUL/DESPERATE). A player who cannot distinguish red/amber/white receives no secondary signal. | **Vertical Slice:** Add a secondary signal — e.g., a zone icon, animated texture pattern, or distinct visual treatment — independent of color. |
| **Cast chain dots** | Dot position communicated by color only (active = Prana color, inactive = grey). | **Vertical Slice:** Size difference: active dot 7px diameter, inactive dot 5px diameter. |
| **Colorblind mode** | No colorblind-specific mode exists. Art Bible §4.5 identifies Ashfire (red) + Verdant (green) as HIGH risk pair. | **Vertical Slice:** Settings-toggle option to increase slot icons from 8×8 to 12×12px + single-letter label below slot (A, V, S, D, G). Owner: `ui-programmer`. |

### Seizure Safety

Only pulsing element is the HP bar in DESPERATE zone (scale 1.0→1.03→1.0, 0.8s cycle ≈ 1.25 Hz). All other transitions are one-shot fades or instantaneous shifts. No element exceeds 3 Hz. ✓ Safe per Art Bible §4.5 seizure safety rules.

### Font Legibility

All bitmap font text in the HUD: minimum 8px at 1× display (16px at 2× display scale). HP numeric readout: 16–18px. Damage numbers: 14–16px. All meet minimum legibility for ages 7+ at typical monitor distance. 1px black outline applied to all HUD text rendered over the game world.

---

## Acceptance Criteria

Classification: **[U]** = Unit/integration test (headless) | **[M]** = Manual QA (visual or timing-dependent)

---

**AC-HUD-S01 [U]** — HP bar is visible within 100ms of run_started
GIVEN `run_started` fires
WHEN ≤100ms have elapsed
THEN HP bar node is visible; bar fill fraction equals `FAYDE_MAX_HP / FAYDE_MAX_HP` (1.0 = full)

**AC-HUD-S02 [U]** — Zone CAREFUL: amber color fires at correct threshold (instantaneous)
GIVEN Fayde at HP 45 (FULL zone)
WHEN `damage_taken` reduces HP to 38 (crossing the 40% CAREFUL threshold)
THEN HP bar fill color == `#FFA500` (amber) AND numeric label color == `#FFA500` in the same frame — no transition delay

**AC-HUD-S04 [U]** — Type Selector, Confirm, and Clear All are hidden after combat_started
GIVEN Preparation Phase (Type Selector visible, Confirm + Clear All visible)
WHEN `combat_started` fires
THEN Type Selector node is not visible; Confirm button is not visible; Clear All button is not visible

**AC-HUD-S05 [U]** — Grid dims to ≤70% opacity on combat_started
GIVEN Prana Grid at 100% opacity (ARRANGEMENT state)
WHEN `combat_started` fires
THEN `PranaGrid.modulate.a <= 0.71` (70% opacity) within one frame of the signal

**AC-HUD-S06 [U]** — Chain dots hidden during Preparation; appear during Combat when spell cached
GIVEN `preparation_started` fires
THEN chain dot row is not visible (regardless of prior state)
GIVEN `combat_started` fires AND `chain_index_changed(0, 2)` fires
THEN chain dot row is visible with 2 dots

**AC-HUD-S07 [U]** — Floating damage labels are freed after animation completes
GIVEN `damage_taken(enemy_node, 25, 10)` fires during Combat Phase
WHEN 0.8s (`DAMAGE_FLOAT_DURATION`) elapses
THEN the spawned Label node is no longer in the scene tree (queue_free'd)

**AC-HUD-S08 [M]** — HUD permanent elements occupy ≤20% of screen area during Combat Phase
GIVEN Combat Phase is active (Preparation elements hidden)
WHEN screen is captured at 1920×1080
THEN HP bar zone + Prana Grid zone combined occupy ≤20% of screen area (≤414,720 px²) — verified by eye or pixel-area measurement

**AC-HUD-S09 [M]** — All interactive grid elements reachable via keyboard without mouse
GIVEN keyboard-only input, no mouse
WHEN player uses Tab / arrow keys to navigate
THEN all 9 grid slots receive keyboard focus in logical order AND Confirm button is focus-reachable AND Clear All button is focus-reachable AND activating Confirm via Enter key works when slot 4 is filled

**AC-HUD-S10 [U or M]** — DESPERATE pulse animation active while HP below 20%
GIVEN `player_hp_zone_changed(HPZone.DESPERATE)` fires
WHEN 0.8s elapses
THEN HP bar has visibly pulsed (scale 1.0→1.03→1.0 cycle); pulse stops when `player_hp_zone_changed(HPZone.CAREFUL or HPZone.FULL)` fires

---

## Open Questions

1. **Accessibility tier not formally defined** — `design/accessibility-requirements.md` does not exist. The pre-production gate check flags accessibility requirements as a blocker. WCAG-AA is the recommended baseline. Run `/gate-check pre-production` to verify whether this remains a blocking issue. *Owner: UX team. Priority: before Vertical Slice.*

3. **Input Map GDD not authored** — Several HUD elements defer exact gamepad/keyboard bindings to an Input Map GDD (Confirm button South face, Clear All binding, Remove binding for gamepad). This GDD must be authored before HUD stories can be marked implementation-ready. *Owner: QQ-06 in session state. Priority: before HUD epic implementation sprint.*

4. **Player journey map missing** — `design/player-journey.md` does not exist. HUD decisions (especially zone density philosophy) were made without player journey context. Consider authoring a player journey map after this spec is approved. Template at `.claude/docs/templates/player-journey.md` (if exists). *Owner: UX session.*

5. **Wave Counter and Status Effects implementation scope** — Items B (Wave Counter) and C (Status Effects) are designed in this spec but deferred to MVP implementation. They are not in the current sprint. When the MVP sprint is planned, these elements need corresponding implementation stories. *Owner: Producer / sprint planning.*

6. **Art director sign-off on HP zone colors** — CAREFUL `#FFA500` (amber) and DESPERATE `#FF3333` (red) are specified in the Combat HUD GDD but require art-director sign-off before production to confirm they are visually distinct from all 5 Prana type colors and from each other. *Owner: art-director review before HUD implementation begins.*

