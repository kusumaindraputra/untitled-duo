# Interaction Pattern Library

> **Status**: In Design
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-30
> **Template**: Interaction Pattern Library

---

## Overview

This library catalogues the reusable interaction patterns for *The Last Cipher*. Every UX spec, HUD design, and implementation story must reference patterns from this document by ID (e.g., `IP-01`) rather than re-specifying interaction behaviour inline. When a screen introduces a new interaction not yet in this library, that pattern must be added here before the UX spec can be marked Ready for Implementation.

**Input context:** All patterns are specified for two input modes — **Mouse/Keyboard** (primary, all PC players) and **Gamepad** (partial support, no hover-only interactions). Touch is not supported. Patterns that require different implementations per input mode document them as sub-specifications.

**Audience constraint:** *The Last Cipher* targets ages 7+. All feedback patterns must communicate state clearly without relying on text literacy alone. Color-only state communication is acceptable at First Playable but must be supplemented with shape or icon signals by Vertical Slice (see individual pattern accessibility notes).

**Art Bible alignment:** All pattern visual treatments must use only colors from the Art Bible palette. Specifically: the five Prana type colors (Ashfire #F24C1D, Voidblue #4A5EF5, Stormgold #FFCC00, Deepfrost #3DD9F0, Verdant #1AC953), the warm-neutral world palette (dark fills, warm white highlights), and the Combat HUD zone colors (Amber #FFA500, Red #FF3333). The Corruption Violet #9B2ED4 (boss reserved) must not appear in any reusable pattern.

---

## Pattern Catalog

| ID | Pattern | Category | Used In |
|----|---------|----------|---------|
| IP-01 | Resource Bar | Data Display | Combat HUD |
| IP-02 | Floating Feedback Label | Feedback | Combat HUD |
| IP-03 | Sequence Dot Indicator | Data Display | Combat HUD |
| IP-04 | Grid Slot | Input / Data Display | Prana Grid |
| IP-05 | Drag-and-Drop Token | Input | Prana Grid |
| IP-06 | Type Selector Panel | Input / Data Display | Prana Grid |
| IP-07 | Gamepad Grid Navigator | Input | Prana Grid |
| IP-08 | Conditional Action Button | Input / Feedback | Prana Grid |
| IP-09 | Phase State Overlay | Feedback / Data Display | Prana Grid, Combat HUD |
| IP-10 | Menu Screen Navigation | Navigation | Main Menu, Run Summary, Death Screen |
| IP-11 | Standard Button | Input | Main Menu, Run Summary, Death Screen, Pause Menu |
| IP-12 | Screen-Edge Notification | Feedback | Memory Fragment Pickup, system events |

---

## Standards

### Animation Standards

| Animation Type | Duration | Tween Type | Easing | Notes |
|---|---|---|---|---|
| Screen enter | 0.2s | TRANS_CUBIC | EASE_OUT | Full-screen panel sliding or fading into view |
| Screen exit | 0.15s | TRANS_CUBIC | EASE_IN | Exit faster than enter — dismissal feels responsive |
| Button press confirm | 0.08s | TRANS_LINEAR | — | Scale 1.0→0.97→1.0; same duration for release revert |
| Error flash | 0.4s | TRANS_LINEAR | — | Red border pulse; codified from IP-08 |
| HP bar drain | 0.15s | TRANS_LINEAR | — | Codified from IP-01; fast to feel responsive |
| HP bar fill | 0.20s | TRANS_LINEAR | — | Codified from IP-01; slightly slower for deliberate feel |
| Floating label | 0.8s | TRANS_LINEAR (pos) / TRANS_CUBIC (alpha) | EASE_IN (alpha only) | Codified from IP-02; fade starts at 0.5s mark |
| HUD overlay fade | 0.1s | TRANS_LINEAR | — | Enter and exit; for phase overlays (IP-09) |
| Phase lock dim | 0.15s | TRANS_LINEAR | — | Opacity 100%→70%; codified from IP-09 |
| Notification enter | 0.2s | TRANS_CUBIC | EASE_OUT | Slide in from screen edge (IP-12) |
| Notification exit | 0.15s | TRANS_CUBIC | EASE_IN | Fade out only — no slide-out (IP-12) |
| Stack reposition | 0.1s | TRANS_LINEAR | — | Notification stack adjusts when an item is removed (IP-12) |

**Easing conventions:**

| Rule | When to apply |
|---|---|
| TRANS_LINEAR | Data-driven value displays (bars, counters, overlays proportional to game state) |
| TRANS_CUBIC | UI motion with intentional feel (screen transitions, notification slide) |
| EASE_OUT | Enter / appear animations — decelerate into final position |
| EASE_IN | Exit / disappear animations — accelerate away from view |
| No easing modifier | Instantaneous state changes (zone color shifts in IP-01, focus moves in IP-10) |

---

### Sound Standards

| Event | Bus | Timing | Notes |
|---|---|---|---|
| UI Confirm | UI | On press release (not press start) | Triggers when button action executes, not on initial press |
| UI Back / Cancel | UI | On press | |
| UI Navigate | UI | On focus move | Low-volume; consider player-toggleable in settings |
| Drag Lift | UI | On drag start | IP-05 lift cue |
| Drag Drop — success | UI | On placement | Type-specific variant for Prana tokens (IP-05) |
| Drag Drop — fail (off-grid) | — | — | Explicitly silent per IP-05; no audio on invalid drop |
| Error Reject | UI | On input receipt | Accompanies IP-08 error flash; plays even when flash is subtle |
| Phase Transition | SFX | On phase signal | Preparation→Combat; diegetic — use SFX bus, not UI |
| Resource Gain | SFX | On fill tween start | IP-01 fill event; distinct from UI bus |
| Resource Loss | SFX | On drain tween start | Reserve event slot; audio spec deferred to Combat HUD implementation |
| Notification Appear | UI | On enter animation start | IP-12; short non-intrusive chime |
| Notification Dismiss | — | — | No audio on auto-dismiss; silence avoids repetitive notification spam |

**Bus rules:** UI bus is for interface-layer sounds (buttons, drags, focus moves). SFX bus is for game-world-adjacent feedback (phase changes, resource events). Never route UI actions to the SFX bus or vice versa.

---

## Patterns

### IP-01: Resource Bar

**Category**: Data Display
**Used In**: Combat HUD (HP bar)

**Description**: A horizontal fill bar representing a bounded numeric resource (e.g., HP). The bar tracks the current value against a fixed maximum using a linear fill fraction. The fill level updates with a short tween on every change — drain and fill have separate durations to make damage feel immediate and healing feel deliberate. A numeric readout alongside the bar provides an exact value for players who need precision. The bar communicates urgency through zone-based color states: a neutral full-health color, an amber warning zone, and a red critical zone. Zone transitions are instantaneous — the color shift IS the alarm signal and must not be softened.

**Specification**:
- **Node type**: `ProgressBar` or `TextureProgressBar` (pixel art style — 2px border, no rounded corners)
- **Fill fraction formula**: `bar_fill = current_value / max_value` (clamped 0.0–1.0)
- **Drain tween**: `HP_BAR_DRAIN_DURATION` (default 0.15s) — TRANS_LINEAR. Fast enough to feel responsive, not a snap.
- **Fill tween**: `HP_BAR_FILL_DURATION` (default 0.20s) — slightly slower than drain; healing feels deliberate
- **Rapid hit handling**: If a new change arrives mid-tween, cancel the active tween and start a new one from the current mid-animation value. Never snap back to the pre-hit value.
- **Numeric readout**: `Label` updated synchronously (no tween — the bar tweens, the number snaps). Format: `"72 / 100"`. Font: monospace/tabular figures.
- **Zone states** (triggered by upstream signal — bar does not compute thresholds itself):
  - FULL: warm white `#F5F0E8` fill, white `#FFFFFF` label
  - CAREFUL: amber `#FFA500` fill, amber `#FFA500` label — instantaneous transition
  - DESPERATE: red `#FF3333` fill, red `#FF3333` label — instantaneous transition. Add looping scale pulse (1.0→1.03→1.0 over 0.8s) while in DESPERATE; stop immediately on zone exit.
- **Heal feedback**: On fill event, apply a green tint modulate `Color(0.6, 1.0, 0.6, 1.0)` for the fill tween duration, then revert to the current zone color (not to full-zone color — respect the active zone).
- **Mouse/Keyboard**: Display only — no user interaction.
- **Gamepad**: Same as Mouse/Keyboard.
- **Accessibility (FP scope)**: Zone state communicated by color only — known gap. At Vertical Slice, add a secondary signal (texture pattern or icon) so zone state is readable without color.

**When to Use**: Any persistent bounded numeric resource the player needs constant peripheral awareness of during active gameplay (health, shield, stamina). Use when the value changes frequently and the *direction* of change (gaining vs. losing) is significant.

**When NOT to Use**: For resources the player manages on demand (Prana tokens, inventory count) — use a counter label instead. For binary state (alive/dead) — use an icon. For cooldowns with a fixed endpoint — use [[IP-03]] or a countdown timer.

**Reference**: `design/gdd/combat-hud.md` → Rules 3, 4; Formulas 1, 2 (HP bar fill fraction, zone color)

---

### IP-02: Floating Feedback Label

**Category**: Feedback
**Used In**: Combat HUD (damage numbers)

**Description**: A transient text label that spawns at a world-space position, converts to screen space, then floats upward and fades out. Used to confirm that a point-in-time event occurred (e.g., "this hit dealt 23 damage") at the location of the affected entity. The label is purely informational — it does not block input and does not persist. A pool cap prevents label proliferation during high-frequency events (e.g., cluster enemy swarms). Color encodes the source or type of the event.

**Specification**:
- **Node type**: `Label` (pixel art font, bold, 1px black outline for legibility, no drop shadow at FP scope)
- **Position**: Spawns at `target.global_position` converted to viewport coordinates via `get_viewport().get_canvas_transform()`. Parented to the parent `CanvasLayer` (not the game world).
- **Spawn jitter**: Random X offset ±8px to prevent labels stacking on simultaneous hits.
- **Animation**: Floats upward `DAMAGE_FLOAT_DISTANCE` px (default 32px) over `DAMAGE_FLOAT_DURATION` (default 0.8s). Alpha fades 1.0→0.0 from `DAMAGE_FADE_START` (default 0.5s) to end of duration. Position: TRANS_LINEAR. Alpha: TRANS_CUBIC / EASE_IN. `queue_free()` on tween completion.
- **Pool cap**: Maximum `DAMAGE_LABEL_POOL_CAP` (default 12) concurrent labels. When the cap is reached, the oldest label is freed immediately before the new one spawns.
- **Color encoding**: The label color encodes event source. Specific color assignments are defined per use-case (e.g., Combat HUD uses: Prana type color for elemental hits, white `#FFFFFF` for neutral hits, grey `#AAAAAA` for player-received contact damage).
- **Mouse/Keyboard**: Display only — no user interaction.
- **Gamepad**: Same as Mouse/Keyboard.
- **Accessibility**: Font size minimum 14px at 1080p reference. Color is supplementary to position — the label location (at the hit target) is the primary context signal.

**When to Use**: Point-in-time events with a spatial source — damage values, resource pickups, status effect triggers. Use when the player benefits from seeing WHERE the event occurred, not just THAT it occurred.

**When NOT to Use**: For persistent state (use [[IP-01]] or [[IP-03]]). For events with no spatial anchor (use a screen-edge notification instead). When the event fires at > 20 Hz sustained — label spam becomes noise; consider a single running counter instead.

**Reference**: `design/gdd/combat-hud.md` → Rule 7; Formula 2 (float/fade animation)

---

### IP-03: Sequence Dot Indicator

**Category**: Data Display
**Used In**: Combat HUD (cast chain dots)

**Description**: A row of N small filled circles (dots) that communicate progress through a multi-step sequence. Exactly one dot is "active" at any moment; the rest are "inactive." The active dot is rendered in a contextually meaningful color (e.g., the current Prana type color). Inactive dots are neutral grey. Used when the player needs peripheral awareness of how many actions remain in a repeating sequence, without needing exact numbers.

**Specification**:
- **Nodes**: N `ColorRect` or `Polygon2D` nodes (filled circles), or a single `Node2D` drawing them procedurally. Preferred: procedural for variable N.
- **Dot size**: 6px diameter, 4px gap between dots. No border or outline at FP scope.
- **Colors**: Active dot — contextually meaningful color provided by the consuming system (e.g., `PranaCatalog.get_type(id).color`). Inactive dot — `#888888` (dim grey).
- **Update**: All N dots are redrawn on each sequence-advance event. The active index and total count are provided by the event.
- **Visibility**: Hidden by default. Shown only when a sequence is active. Hidden when the phase that owns the sequence ends (e.g., `preparation_started` hides cast chain dots).
- **Completion reset**: When the active index returns to 0 after reaching N (sequence loops), all dots reset to inactive grey for one frame before the new cycle begins. This micro-reset communicates the loop boundary.
- **Mouse/Keyboard**: Display only.
- **Gamepad**: Same as Mouse/Keyboard.
- **Accessibility (FP scope)**: Dot state communicated by color only — known gap. At Vertical Slice, supplement with a size difference (active dot: 7px; inactive: 5px) for color-independent readability.

**When to Use**: Fixed-length repeating action sequences where the player needs to track their position (cast chains, rhythm cues, cooldown segments). Use when N is known and small (≤ 6 — larger counts are difficult to read at glance distance).

**When NOT to Use**: For unbounded or variable-length sequences — use [[IP-01]] or a counter label instead. For a single-step action (no sequence) — no indicator needed.

**Reference**: `design/gdd/combat-hud.md` → Rule 5; Formula 3 (chain dot color lookup)

---

### IP-04: Grid Slot

**Category**: Input / Data Display
**Used In**: Prana Grid (3×3 arrangement slots)

**Description**: A fixed-size UI cell that can be empty, occupied (holding one token), or in several interactive sub-states depending on cursor position and system phase. Grid Slots are arranged in a matrix (in this game, 3×3). Each slot is an independent display node; the containing grid system owns slot arrangement and state management. Slots render their token's visual identity (color + icon) when occupied, and provide visual feedback for hover, selection, and drag-over events. In a locked phase, all slots dim uniformly and become non-interactive.

**Specification**:
- **Frame**: Octagonal frame, pixel art style. Dark fill background. All 5 states share the same frame shape.
- **State table**:

  | State | Fill | Overlay | Scale |
  |-------|------|---------|-------|
  | Empty (ARRANGEMENT) | Dark fill + faint inner glow (idle pulse animation) | None | 1.0 |
  | Occupied | Token's canonical color fill + centered type icon | None | 1.0 |
  | Cursor-selected (gamepad) | Same as Occupied or Empty | Bright white/gold border highlight | 1.05× (scale-up) |
  | Drag-over (mouse, valid target) | Same as Occupied or Empty | Pulsed highlight ring | 1.0 |
  | LOCKED | Same as Occupied or Empty | Dim to 70% opacity | 1.0 |

- **Slot 4 (centre) distinction**: May have a subtle accent ring marking its role as the combo primary slot. The accent must not obscure a placed token.
- **Colors**: Token fill color sourced from `PranaCatalog.get_type(id).color` — never hardcoded. Frame, cursor, and drag-over colors from Art Bible warm-neutral palette.
- **Mouse input**: Left-click to place (dropping a dragged token). Right-click to remove an occupied token.
- **Gamepad input**: Slot becomes cursor-selected when the gamepad cursor navigates to it (see [[IP-07]]). Place triggered by South face button; Remove by a dedicated Remove button (per Input Map GDD).
- **Keyboard**: Arrow keys navigate between slots (equivalent to gamepad d-pad). Enter = Place.
- **Accessibility**: Each token must display its type icon in addition to its color — color alone is not sufficient token identity.

**When to Use**: Fixed-size arrangeable decision spaces where each cell holds at most one item and the position of each item is mechanically meaningful. Use when arrangement (which token, in which position) is a core game mechanic.

**When NOT to Use**: For list-based inventories where position doesn't matter (use a scrollable list). For multi-item slots (a grid slot holds one item — use a counter overlay for stacks rather than redesigning this pattern). For slots without spatial identity (use a button row).

**Reference**: `design/gdd/prana-grid.md` → Rules 1, 5; Visual/Audio Requirements → Slot States

---

### IP-05: Drag-and-Drop Token

**Category**: Input
**Used In**: Prana Grid (Prana type token drag from Type Selector to grid)

**Description**: A draggable visual token representing a typed item (in this game, a Prana type). The token originates from a source panel ([[IP-06]]) and is dragged to a target slot ([[IP-04]]). The drag is mouse-primary — the token "lifts" on mouse-down, follows the cursor, and "drops" on mouse-up over a valid target. A ghost token remains in the source panel (tokens are source-infinite — dragging does not remove from source). Landing on an occupied slot replaces the existing token without confirmation. The pattern is one-handed and continuous — the player maintains spatial intention throughout the drag.

**Specification**:
- **Input**: Mouse left-button hold to drag, release to drop.
- **Lift feedback**: Subtle lift audio cue on drag start. Token scales up slightly (1.1×) and follows cursor. The source panel shows a ghost/placeholder at the token's origin.
- **Valid drop target**: A [[IP-04]] grid slot in ARRANGEMENT state. On hover, the target slot shows a pulsed highlight ring (drag-over state).
- **Drop on empty slot**: Token placed in slot. Source panel token remains (source-infinite). Placement audio cue (type-specific).
- **Drop on occupied slot**: Replaces the existing token. No confirmation dialog. Placement audio cue of the incoming token's type.
- **Drop off-grid** (released outside any valid slot): Token returns to nothing — no placement occurs. No audio cue.
- **Drag cancelled by phase change** (`grid_locked` fires mid-drag): Drag cancelled, token does not land. Grid enters LOCKED state with the pre-drag arrangement.
- **Drag cancelled by phase reset** (`preparation_started` fires mid-drag): Drag cancelled, all slots clear, grid enters ARRANGEMENT empty.
- **Gamepad equivalent**: [[IP-07]] cursor navigation + Place button — no drag gesture. This pattern describes mouse input only.
- **Keyboard equivalent**: Tab/arrow navigation to source panel → select type → navigate to target slot → confirm. Exact bindings per Input Map GDD.
- **Accessibility**: All drag actions must have a non-drag keyboard/gamepad alternative. No capability is available exclusively through drag.

**When to Use**: Spatial arrangement tasks where position matters mechanically and the player is placing typed items into fixed slots. Use when the physical "spatial" feel of moving tokens is core to the player fantasy.

**When NOT to Use**: When slot positions are equivalent (use a list selector). When arrangement happens frequently enough that per-token drag becomes tedious (consider click-to-assign). When gamepad is the primary platform (use [[IP-07]] instead).

**Reference**: `design/gdd/prana-grid.md` → Rule 9 (mouse input model); Visual/Audio Requirements → Audio events table

---

### IP-06: Type Selector Panel

**Category**: Input / Data Display
**Used In**: Prana Grid (Prana type source panel — mouse mode: draggable tokens; gamepad mode: type indicator with cycle)

**Description**: A panel adjacent to the grid that gives the player access to all available typed items (Prana types). In **mouse mode**, it displays all types as draggable tokens — the source for [[IP-05]] drag operations. In **gamepad mode**, it is replaced by a **Type Indicator widget** showing only the currently selected type, with cycling controls to advance the selection. Both sub-implementations serve the same purpose (type selection) with distinct interaction models. In LOCKED state, the entire panel dims and becomes non-interactive.

**Specification**:

*Mouse Mode (primary):*
- Displays all N available Prana types as token icons in a row or column, adjacent to the grid (exact position deferred to `design/ux/hud.md`).
- Each token shows the type's canonical color and icon from `PranaCatalog.get_type(id)`.
- Tokens are source-infinite — dragging one does not remove it from the panel. All N types are always visible.
- On drag start from a panel token: [[IP-05]] Drag-and-Drop Token pattern takes over.
- LOCKED state: tokens dim to 70% opacity; pointer events disabled.

*Gamepad Mode (secondary):*
- Displays a **Type Indicator**: a small widget showing the currently selected type (color + icon + type name label).
- Left/Right shoulder buttons (exact binding per Input Map GDD) cycle the active type through all N types. Cycling wraps: past the last type returns to first.
- The indicator shows one type at a time — cycle affordance (arrow icons) indicates there are more.
- LOCKED state: indicator dims, cycling disabled.

*Shared rules:*
- All N types are always available (shown in mouse mode; cyclable in gamepad mode) — no type is hidden at MVP scope.
- Colors and icons sourced from `PranaCatalog` — never hardcoded.
- **Accessibility**: Type identity must be communicated by icon + color, not color alone. Gamepad Type Indicator satisfies this via the type name label. Mouse tokens must have distinct icons per type.

**When to Use**: Selection panels where the player chooses from a fixed set of typed items to assign to a spatial surface, and items are source-infinite (position in the source panel is cosmetic).

**When NOT to Use**: When items are consumable with counts (use an inventory list). When N > 8 items (use a scrollable list). When selection is binary (use a toggle).

**Reference**: `design/gdd/prana-grid.md` → Rules 9, 10 (mouse and gamepad input models); Visual/Audio Requirements → Type Selector Panel

---

### IP-07: Gamepad Grid Navigator

**Category**: Input
**Used In**: Prana Grid (d-pad/stick cursor over the 3×3 grid)

**Description**: A software cursor that navigates a fixed-size grid of [[IP-04]] Grid Slots using d-pad or left stick directional input. The cursor highlights the current slot (cursor-selected state) and does not require mouse hover to activate. Place and Remove actions are triggered by face buttons, not by cursor movement. The cursor is separate from the grid's phase state — its position is preserved when the grid locks for combat, and the highlight hides during LOCKED state.

**Specification**:
- **Navigation**: D-pad / left stick directional input moves cursor one slot in the pressed direction. Grid edges are hard boundaries — the cursor stops at the edge and does not wrap around.
- **Cursor-selected state**: The currently focused slot renders in "cursor-selected" state (white/gold border highlight, 1.05× scale-up — per [[IP-04]]).
- **Place action**: South face button assigns the currently selected type from [[IP-06]] to the cursor's current slot. Replaces any existing token without confirmation.
- **Remove action**: Dedicated Remove button (per Input Map GDD) clears the token from the cursor's current slot. No-op on an empty slot.
- **Cursor during LOCKED state**: Cursor position preserved but highlight hidden. All slots show LOCKED dim state. On ARRANGEMENT re-entry (`preparation_started`), cursor resets to slot 0 (top-left).
- **Initial position**: Slot 0 (top-left) on `preparation_started`.
- **Keyboard equivalents**: Arrow keys = d-pad directions. Tab key = cycle slots in reading order (0→8, wraps to 0). All 9 slots reachable without mouse.
- **Input mode switching**: When mouse drag begins, gamepad cursor hides. On next d-pad/stick input, cursor reappears at the last-held slot. No mode-lock required.
- **Accessibility**: Cursor-selected state communicated via border highlight + scale-up (1.05×) — not color alone. All 9 slots reachable without mouse via keyboard arrow keys or gamepad d-pad. Cursor hidden during LOCKED state by design — grid content remains readable at 70% opacity per [[IP-09]].

**When to Use**: Fixed-size grid UI where the player navigates cells with a directional controller (gamepad d-pad or keyboard arrow keys). Use when the grid is ≤ 5×5 — cell-by-cell navigation is fast enough.

**When NOT to Use**: For list-based navigation (use a vertical focus system). For grids larger than 5×5 (navigation becomes slow — consider jump-to-cell). When mouse-only input is guaranteed.

**Reference**: `design/gdd/prana-grid.md` → Rule 10 (gamepad input model); ADR-0013 (PranaGrid Dual-Input Focus Model — use `_selected_slot_index` + `Sprite2D` cursor, NOT `grab_focus()`)

---

### IP-08: Conditional Action Button

**Category**: Input / Feedback
**Used In**: Prana Grid (Confirm button — enabled only when centre slot is filled)

**Description**: A button whose availability (enabled/disabled) is determined by a game state condition the player actively builds toward. In disabled state, the button is visibly greyed out and non-interactive — the visual state communicates "this action is not yet valid" without text. When the player attempts to trigger the disabled action via keybinding, an error flash provides feedback that the input was received and rejected, plus a brief explanatory label. This prevents silent failures where the player doesn't know whether their input registered.

**Specification**:
- **Enabled state**: Full opacity, active color, interactive. Keyboard/gamepad shortcut active.
- **Disabled state**: 40% opacity, greyed color, non-interactive. Shortcut still received but produces error flash.
- **Error flash (disabled, shortcut pressed)**:
  - The related container/surface flashes a red border for 0.4s.
  - A brief explanatory label appears near the button (e.g., "place a fragment in the centre slot"). Auto-dismisses after 1.5s. No state change.
  - Critical for gamepad users who may not clearly perceive the button's disabled state.
- **Enable condition**: Defined per use-case and driven by upstream state — the button does not own or compute the condition.
- **Mouse/Keyboard**: Click or keyboard shortcut. Shortcut key shown as a label on or near the button.
- **Gamepad**: Face button shortcut. Error flash applies when shortcut pressed while disabled.
- **Accessibility**: Disabled state communicated by opacity + color together (not color alone). Error flash label: font size ≥ 14px.

**When to Use**: Primary actions that require a precondition the player actively builds (confirm arrangement, proceed, submit). Use when the button should always be visible but only becomes active when conditions are met.

**When NOT to Use**: When the action should be entirely hidden until available (use reveal-on-unlock instead). When the condition is too complex to communicate visually — if a disabled button requires reading to understand, reconsider the information architecture.

**Reference**: `design/gdd/prana-grid.md` → Rule 6 (Confirm button behavior); Visual/Audio Requirements → Confirm button states

---

### IP-09: Phase State Overlay

**Category**: Feedback / Data Display
**Used In**: Prana Grid (LOCKED state during Combat Phase), Combat HUD (read-only pass-through)

**Description**: A visual treatment applied to an interactive UI surface when it enters a non-interactive phase — typically because the game's phase state has changed (preparation → combat). The overlay modifies the opacity and interactivity of all child elements uniformly. The arrangement or content remains fully readable (the player can see what they committed), but all input is disabled. An optional supplementary indicator (padlock icon or border tint) signals the locked state explicitly.

**Specification**:
- **Opacity**: All child elements dim to 70% opacity uniformly.
- **Input**: All pointer events and keyboard/gamepad shortcuts for the covered surface are disabled. Attempts produce no feedback — this is a system-level phase lock, not a user-condition lock (contrast: [[IP-08]] error flash is for user-driven conditions).
- **Content**: Arrangement and display content remains visible and readable at 70% opacity — locking does not hide information.
- **Supplementary indicator**: Optional padlock icon or border tint on the container. Communicates read-only to players who may not associate opacity with non-interactivity.
- **Entry trigger**: Game phase signal (e.g., `grid_locked`, `combat_started`) — not a user action.
- **Exit trigger**: Game phase signal returning to active state (e.g., `preparation_started`). On exit: opacity reverts to 100%, input re-enables.
- **Mouse/Keyboard**: No pointer events. No keyboard shortcuts processed.
- **Gamepad**: No button events processed for this surface.
- **Accessibility**: Transition from interactive to locked communicated through at least two channels (opacity + supplementary indicator) — not opacity alone.

**When to Use**: UI surfaces that become read-only during a game phase change, where the player still benefits from seeing the content during the non-interactive phase.

**When NOT to Use**: When the surface should be fully hidden during the non-interactive phase (use `visible = false` or remove from scene tree). When the locked state is permanent (hide instead of dim). When the surface has no meaningful content to show while locked.

**Reference**: `design/gdd/prana-grid.md` → Rules 3, 3a (LOCKED and HIDDEN states); Visual/Audio Requirements → LOCKED state overlay

---

### IP-10: Menu Screen Navigation

**Category**: Navigation
**Used In**: Main Menu, Run Summary, Death Screen

**Description**: The interaction model for navigating and activating elements on a full-screen menu UI (not an in-game overlay). Menu screens must be fully navigable via keyboard and gamepad — no hover-only interactions, no mouse-required steps. Focus is managed sequentially across interactive elements in a logical tab order (top-to-bottom, left-to-right). The focused element is always visually distinct. Confirm and Cancel/Back bindings are global to the menu.

**Specification**:
- **Focus management**: One element focused at a time. Focus moves via Tab / Shift-Tab (keyboard) or d-pad Up/Down (gamepad). Arrow keys may also move focus when the layout has spatial structure.
- **Focus indicator**: The focused element shows a distinct visual state (highlight border, color shift, or 1.05× scale-up). Visible at a glance — not subtle.
- **Confirm**: Enter (keyboard) / South face button (gamepad) activates the focused element. Mouse left-click on any element also activates it directly.
- **Cancel/Back**: Escape (keyboard) / East face button (gamepad) navigates back or closes a sub-menu. Always available unless no back action exists (e.g., main menu with no parent screen).
- **Tab order**: All interactive elements reachable via keyboard Tab cycle. Order must be logical (reading order). No element may be keyboard-unreachable.
- **No hover-only interactions**: All affordances visible to a mouse user must be accessible via keyboard focus. No tooltip-only information that requires hover.
- **Mouse coexistence**: Mouse click always works alongside keyboard — modes coexist. Mouse hover may provide visual feedback but cannot be the sole action trigger.
- **Gamepad**: D-pad navigation + South (confirm) + East (back). All elements reachable without mouse.
- **Accessibility**: Focus state must not rely on color alone — use a shape or size change alongside color. All text ≥ 14px at 1080p reference.
- **Screen-specific specs**: Focus order, confirm actions, and back behavior for each screen are defined in the screen's UX spec (`design/ux/main-menu.md`, `design/ux/run-summary.md`, `design/ux/death-screen.md`). This pattern defines the shared rules those specs must conform to.

**When to Use**: All full-screen menu states where the player makes choices between runs (Main Menu, Run Summary, Death Screen, Pause Menu) — any screen that replaces the gameplay view entirely.

**When NOT to Use**: For in-game overlays coexisting with gameplay (preserve game input state alongside overlay navigation). For the HUD (display-only). For the Prana Grid (uses [[IP-07]] instead of sequential tab focus).

**Reference**: `design/gdd/game-state-scene-flow.md` → UI Requirements (keyboard-navigable MVP menu states)

---

### IP-11: Standard Button

**Category**: Input
**Used In**: Main Menu, Run Summary, Death Screen, Pause Menu

**Description**: The base interactive element for all full-screen menu screens. A rectangular clickable target that triggers a single action on confirm. Unlike [[IP-08]] (whose primary design intent is a condition-driven disabled state), the Standard Button defaults to always enabled — it exists only when its action is unconditionally available. Standard Buttons are arranged and navigated via [[IP-10]].

**Specification**:
- **Node type**: `Button` (theme-overridden for pixel art style). No rounded corners. 2px border.
- **State table**:

  | State | Fill | Border | Scale | Duration |
  |---|---|---|---|---|
  | Default | Base panel color | Subtle 1px warm-neutral border | 1.0 | — |
  | Hover (mouse) | Lighten 15% | Same | 1.02× | 0.08s — per Animation Standards |
  | Focused (keyboard/gamepad) | Same as Hover | Bright highlight border (white/gold) | 1.03× | Instant on focus move |
  | Pressed | Darken 10% | Same as Focused | 0.97× | 0.08s — per Animation Standards |
  | Disabled | 40% opacity, greyed | None | 1.0 | — |

- **Confirm**: Left-click / Enter (keyboard) / South face button (gamepad). Triggers `pressed` signal. Pressed visual lasts 0.08s, then reverts to Default (or Focused if focus remains).
- **Focus**: Managed by [[IP-10]] (Tab / Shift-Tab / d-pad). Do not call `grab_focus()` from outside the button's own scene — let IP-10's focus system drive focus order.
- **Disabled state**: Use only for transient unavailability when the button must remain visible. If the button should not appear at all, remove it from the scene tree instead. For condition-driven enable/disable with error feedback on attempted activation, use [[IP-08]].
- **Mouse/Keyboard**: Click or Enter. Hover state visible on mouse pass. Keyboard focus shows Focused state.
- **Gamepad**: D-pad navigate via [[IP-10]], South button to confirm. Hover state not shown — no cursor position to hover from.
- **Accessibility**: Focus state must use a border/shape change in addition to color — color alone is insufficient. Text label minimum 14px at 1080p reference. Disabled state communicated by opacity + color, not color alone.

**When to Use**: Menu actions that are always available when visible (New Game, Continue, Quit, Restart, Return to Menu). Navigation actions within any full-screen menu screen.

**When NOT to Use**: When availability depends on a game state condition — use [[IP-08]]. When the element is decorative — use a `Label` or `Panel`. For Prana Grid interaction — use [[IP-07]] cell navigation. When an action should be hidden until available — remove from scene tree rather than disabling.

**Reference**: `design/gdd/game-state-scene-flow.md` → UI Requirements (keyboard-navigable MVP menu states); [[IP-10]] for navigation context; [[IP-08]] for the condition-gated variant.

---

### IP-12: Screen-Edge Notification

**Category**: Feedback
**Used In**: Memory Fragment Pickup (GAP-04), system events without a world-space anchor

**Description**: A transient notification panel that appears at a fixed screen-edge zone to communicate events with no spatial anchor in the game world. Unlike [[IP-02]] (which spawns at the world-space position of an affected entity), this pattern anchors to the screen. Used for off-screen or abstract events the player should notice but that do not require acknowledgement. Notifications queue when multiple arrive simultaneously; each auto-dismisses after a fixed duration.

**Specification**:
- **Anchor zone**: Top-right corner, 16px inset from screen edges (safe zone). Specific use cases may specify alternative anchors (e.g., bottom-center for narrative hint overlay — see GAP-03).
- **Layout**: Icon (left, 24×24px) + short label text (right). Max label: 28 characters. Localization allowance: 40% expansion → target 39 characters max in localized strings.
- **Animation** (per Animation Standards):
  - Enter: slide in from screen edge, 0.2s, TRANS_CUBIC / EASE_OUT.
  - Exit: fade out, 0.15s, TRANS_CUBIC / EASE_IN. No slide-out — fade reads as "gone" faster than a reverse slide.
- **Display duration**: `NOTIFICATION_DISPLAY_DURATION` (default 2.5s) measured from when the enter animation completes.
- **Queue behavior**: Maximum `NOTIFICATION_QUEUE_CAP` (default 3) simultaneous panels. When a 4th arrives while 3 are visible, the oldest is dismissed immediately (exit fade at 2× speed). Notifications queue FIFO.
- **Stack layout**: Multiple active panels stack vertically, 16px gap between panels, newest at top. Stack repositions with a 0.1s TRANS_LINEAR tween when any panel is removed mid-stack.
- **Dismiss**: Auto-dismiss only — the player cannot manually dismiss. Notifications are advisory; interrupting gameplay to dismiss would break flow.
- **Mouse/Keyboard**: Display only — no interaction.
- **Gamepad**: Display only.
- **Accessibility**: Icon required alongside label text — neither color nor text alone is sufficient notification identity. Label minimum 14px at 1080p. Notification does not intercept focus or block input at any time.
- **Audio**: Notification Appear cue on enter animation start (per Sound Standards). No dismiss audio — silence avoids repetitive spam on queue flush.

**When to Use**: Events the player should notice but not be blocked by, with no spatial source — item pickups, run milestone markers, narrative memory triggers, background system events.

**When NOT to Use**: When player acknowledgement is required — use a modal or pause the game. When the event has a world-space source — use [[IP-02]]. When missing the notification would cause player confusion — use a more prominent interrupt, or reconsider whether the information belongs in the HUD instead.

**Reference**: `design/gdd/game-concept.md` → Core Loop (Pillar 5: Memory Returns — memory fragment surfacing); GAP-04 (Memory Fragment Pickup — base pattern defined here; specific icon, label text, and trigger conditions still need a UX spec).

---

## Gaps & Patterns Needed

The following interactions are referenced in GDDs but do not yet have a pattern in this library. Each must be added before the relevant UX spec can be marked Ready for Implementation.

| Gap ID | Interaction | Source Reference | Priority |
|--------|------------|-----------------|----------|
| GAP-01 | Pause Menu — single-action resume at MVP, full settings/quit at VS | `design/gdd/game-state-scene-flow.md` → UI Requirements | MVP (before pause implementation) |
| GAP-02 | Path Selection node map — non-color-only affordance for Cipher's Trial nodes; pre-entry consent pattern | `design/gdd/game-state-scene-flow.md` → UI Requirements [VS design artifacts] | VS scope |
| GAP-03 | Memo hint/dialogue display — how Memo's hints appear on screen during a run | `design/gdd/game-concept.md` → Core Loop; no GDD specifies the display pattern | MVP (before Memo implementation) |
| GAP-04 | Memory fragment pickup notification — base pattern now IP-12; specific icon, label text, and trigger conditions still need a UX spec | `design/gdd/game-concept.md` → Core Loop (Pillar 5); [[IP-12]] | MVP (before memory fragment implementation) |
| GAP-05 | Run Summary screen — no UX spec yet; menu navigation model is IP-10 but layout, data display, and actions need speccing | `design/gdd/game-state-scene-flow.md` → `RUN_SUMMARY` state | MVP (before Run Summary implementation) |
| GAP-06 | Death Screen — no UX spec yet; restart/quit actions and run data display need speccing | `design/gdd/game-state-scene-flow.md` → `DEATH_SCREEN` state | MVP (before Death Screen implementation) |

---

## Open Questions

1. **Accessibility tier** — `design/accessibility-requirements.md` does not yet exist. All patterns currently note FP-scope color-only gaps with VS-scope remediation plans. Before Vertical Slice, define the committed accessibility tier (WCAG-AA recommended as baseline) and verify each pattern's VS-scope accessibility note satisfies it. Run `/gate-check pre-production` to check whether this blocks the phase gate.

2. **Player journey context** — `design/player-journey.md` does not yet exist. Pattern decisions (especially IP-09 Phase State Overlay and IP-10 Menu Screen Navigation) would benefit from knowing the player's emotional state on arrival at each screen. Consider authoring a player journey map before speccing individual screens.

3. **Input Map GDD** — several patterns (IP-07, IP-08, IP-10) defer exact button binding decisions to "Input Map GDD (not yet authored)." This GDD must be authored before any pattern with gamepad interaction can be fully implemented. Owner: QQ-06 open question in `production/session-state/active.md`.

4. **Pattern reuse across future systems** — IP-01 (Resource Bar) and IP-02 (Floating Feedback Label) are currently used only in Combat HUD, but are likely to appear in status effect indicators and narrative event feedback. When new systems are designed, check this library before re-inventing any of these patterns inline.
