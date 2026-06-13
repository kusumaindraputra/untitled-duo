# Prana Grid

> **Status**: Approved
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-06-13 (round 3 — GAP-2: compact indicator spec for LOCKED state, S5-04)
> **Implements Pillar**: Pillar 1 (Every Run Tells a Different Story), Pillar 2 (Power is Earned Through Understanding), Pillar 3 (Chaos Has Consequences)

## Overview

Prana Grid is the 3×3 Prana arrangement system that defines Fayde's spell loadout for each combat wave. During Preparation Phase, the player populates the nine grid slots by dragging Prana type tokens (mouse-primary) or navigating with d-pad selection (gamepad-secondary); the resulting arrangement — types chosen, quantities, and spatial positions — determines what spells fire when cast during the subsequent Combat Phase. The grid has four owned responsibilities: rendering each occupied slot with its Prana type's color and icon (sourced from Prana Data), accepting and validating player input within the arrangement window, storing the committed configuration as an ordered 9-slot array, and enforcing phase-gate locking so the arrangement cannot be modified once `combat_started` fires. The grid unlocks and resets to empty on `preparation_started`, giving the player a fresh decision before every wave. Combination Resolution reads the committed array to resolve which spell effects fire; Prana Grid is the decision surface, not the execution engine — it owns the arrangement and nothing else. At MVP, each slot holds at most one Prana token; whether a player may place the same Prana type in multiple slots is a rule owned by Combination Resolution.

## Player Fantasy

The Prana Grid is the game's thinking space. In the 5–15 seconds of Preparation Phase — before the wave begins and the room fills with movement — the player has nine empty slots and full information: which enemies are coming, what Prana types they favour, which combinations might chain. The act of arrangement is the act of forming an intention: *this is the plan*.

The fantasy is the moment of committing. Dragging the last Prana token into position and confirming is a declaration: *I read the wave correctly. I know what this arrangement will do. Let's see if I'm right.* When the plan works — when Deepfrost locks the Charger mid-charge and the follow-up Ashfire burns through the rest of the pack — the satisfaction comes from the pre-combat thinking, not the combat execution. The grid arrangement is the skill expression; the fight is the proof.

The failure version matters equally. A misread wave — the wrong type, the combo that broke down because one enemy closed faster than expected — teaches visibly and without ambiguity. *I should have put Stormgold in the centre to stun the rusher first.* The grid makes reasoning legible in both directions.

*"Power is Earned Through Understanding"* (Pillar 2) lives here. A player who knows that Deepfrost-then-Ashfire chains (freeze root → Shatter bonus on the follow-up hit) fills those slots deliberately. The player who does not will guess. The grid is where accumulated knowledge becomes visible advantage — without stats or levels, purely from understanding the system. *"Every Run Tells a Different Story"* (Pillar 1) — the grid resets to empty before every wave. Knowledge carries; arrangements do not.

## Detailed Design

### Core Rules

1. **Grid structure**: The grid consists of 9 slots arranged in a 3×3 matrix, indexed 0–8 in reading order (left-to-right, top-to-bottom):

   ```
   [0][1][2]
   [3][4][5]
   [6][7][8]
   ```

   Slot 4 (centre) is the designated primary combo-resolution slot — its spatial relationship to surrounding slots is how Combination Resolution derives compound spell effects. Each slot either holds one Prana token (identified by type ID 0–4) or is empty. Empty slots are represented as `null` in the `committed_fragments` array (see Formula 2). No slot holds more than one token.

2. **Phase gating — ARRANGEMENT state**: The grid enters ARRANGEMENT state on `preparation_started`. On entry, all slots reset to empty. In ARRANGEMENT state the grid accepts all player input: place, remove, swap, and confirm.

3. **Phase gating — LOCKED state**: The grid enters LOCKED state on `grid_locked`. (`grid_locked` is emitted by Game State immediately before `combat_started` — guaranteeing the grid is locked before Player Controller enables movement.) All input is disabled. The full grid panel is hidden; a **compact indicator** (≤60×60px, read-only) becomes visible in the bottom-right corner of the screen showing the committed arrangement. No drag, select, place, remove, or confirm input is processed while LOCKED.

   **Compact indicator**: A 3×3 array of 14×14px dots with 4px gaps, positioned in the bottom-right screen corner within the Combat HUD's reserved region (bottom-right, ≤288×216px). Filled slot → dot color == `PranaCatalog.get_type(slot_type_id).color`; empty slot → `Color("#333333")`. Implemented as a `Control` child of PranaGrid (e.g., `%CompactIndicator`) with `mouse_filter = MOUSE_FILTER_IGNORE` on all children — receives no input. Transition is immediate on `grid_locked` (no animation at First Playable). The compact indicator also hides on `grid_hidden`.

3a. **Phase gating — HIDDEN state**: The grid enters HIDDEN state on `grid_hidden`. The grid is not rendered and does not participate in input. `grid_hidden` is emitted by Game State on entry to `MAIN_MENU`, `RUN_SUMMARY`, `DEATH_SCREEN`; and `[VS]` `PATH_SELECTION`, `SHOP_PHASE`, `REST_PHASE`, `CIPHERS_TRIAL`. The grid exits HIDDEN on `preparation_started` → enter ARRANGEMENT.

3b. **Phase gating — PAUSED**: PAUSED is handled by Godot's `get_tree().paused = true` mechanism. Prana Grid uses `PROCESS_MODE_PAUSABLE` and does not change its grid state on `game_paused` or `game_resumed` — it preserves whatever state (ARRANGEMENT or LOCKED) it was in before the pause.

4. **Token availability**: At MVP scope, all 5 Prana types are available in unlimited quantity per wave. There is no inventory, wave budget, or unlock gate at this scope. The player may place any type in any slot, in any combination. Same types may appear in multiple slots simultaneously; the rule for same-type repetition is owned by Combination Resolution.

5. **Placement rules**: Placing a token on an empty slot fills it. Placing on an occupied slot replaces the token (the prior token is discarded — it returns to the unlimited pool). A filled slot can be cleared by explicit removal action, leaving it empty.

6. **Confirmation rule**: The Confirm action is accepted only if slot 4 (centre) contains a fragment. An arrangement with all surrounding slots empty but slot 4 filled is valid — one centre fragment is a minimum valid arrangement. An arrangement with slot 4 empty is rejected regardless of how many other slots are filled. The Confirm button is visually disabled (greyed out, non-interactive) whenever slot 4 is empty. Pressing the confirm key while slot 4 is empty produces an error-state visual indicator (e.g., grid border flash, "place a fragment in the centre slot" label) but no state change. The all-empty-grid case is also covered by this rule.

   > **⚠ Cross-GDD change (from Combination Resolution GDD):** Centre slot must be non-null before resolution can run. Combination Resolution's `push_error()` path for null centre is a defensive guard — the primary enforcement lives here in Prana Grid.

7. **Committed arrangement**: On successful confirmation, Prana Grid emits `arrangement_confirmed` signal and exports the committed state as a read-only array `committed_fragments: Array[PranaFragment]` (length 9). Each element is a `PranaFragment` resource or `null` (empty slot). Index matches slot index. This array is the sole public data interface for Combination Resolution — it reads `committed_fragments` via a public getter after `combat_started`. Spell Casting & Effects also reads `committed_fragments` for VFX and audio routing per type.

   **PranaFragment properties** (full schema defined in Combination Resolution GDD Rule 1; Prana Grid produces instances):

   | Property | Type | First Playable value | VS+ value |
   |----------|------|---------------------|-----------|
   | `type_id` | `int` (0–4) | Placed Prana type | Same |
   | `level` | `int` ≥ 1 | Always `1` | From Prana Drop / Loot |
   | `stat_property` | `StatProperty` | `null` | Random from type-specific pool |
   | `adjacency_effects` | `Array[AdjacencyEffect]` | `[]` (empty) | N random effects where N = level |

   At First Playable scope, Prana Grid creates all fragments as lv.1 with null stat_property and empty adjacency_effects. Full fragment generation (random stat_property, populated adjacency_effects) is deferred to Vertical Slice when Prana Drop / Loot (#16) is implemented.

8. **Single-cast model**: All filled slots resolve simultaneously on a single Cast action during Combat Phase. The Cast trigger, cooldown, and frequency are owned by Spell Casting & Effects. Prana Grid does not control the cast action — it only provides the arrangement data via `committed_fragments`.

9. **Mouse input model**: A Type Selector panel adjacent to the grid displays all 5 Prana type tokens (rendered with their canonical color and icon from Prana Data). The player drags a token from the selector to a target slot to place it. Dragging to an occupied slot replaces the existing token. A filled slot token can be dragged to another slot (direct swap) or dragged off-grid (removes the token). Right-clicking a filled slot also removes its token. The Confirm button and a "Clear All" action are provided as clickable UI elements.

10. **Gamepad input model**: A cursor navigates the 9 grid slots via left stick or d-pad. A separate Type Cycle control (left/right shoulder buttons, or a dedicated type-ring sub-menu) advances the active Prana type selection through all 5 types; the currently selected type is shown in an on-screen Type Indicator. Pressing Place assigns the selected type to the cursor's current slot. Pressing Clear removes the token from the cursor's current slot. Pressing Confirm triggers the Confirm action if at least one slot is filled. All grid interactions must be fully completable with no hover-only interactions (per `technical-preferences.md`). Exact button bindings are deferred to the Input Map GDD (not yet authored).

---

### States and Transitions

| State | Active During | Entry | Exit |
|-------|-------------|-------|------|
| ARRANGEMENT | `PREPARATION_PHASE` | `preparation_started` (clears all slots) | Confirm accepted → emits `arrangement_confirmed` → Game State receives it, emits `grid_locked` (grid enters LOCKED), then emits `combat_started` |
| LOCKED | `COMBAT_PHASE` | `grid_locked` signal received | `preparation_started` signal received → enter ARRANGEMENT |
| HIDDEN | Outside active run — `MAIN_MENU`, `RUN_SUMMARY`, `DEATH_SCREEN`; `[VS]` `PATH_SELECTION`, `SHOP_PHASE`, `REST_PHASE`, `CIPHERS_TRIAL` | `grid_hidden` signal received | `preparation_started` signal received → enter ARRANGEMENT |

> **PAUSED**: Not a grid state. Grid preserves its current state (ARRANGEMENT or LOCKED) unchanged during PAUSED via `PROCESS_MODE_PAUSABLE` — see Rule 3b.

---

### Interactions with Other Systems

| System | Interaction | Direction |
|--------|-------------|-----------|
| **Game State & Scene Flow** | `preparation_started` → clear grid, enter ARRANGEMENT. `grid_locked` → enter LOCKED. `grid_hidden` → enter HIDDEN. Prana Grid emits `arrangement_confirmed`; Game State listens and owns the PREPARATION→COMBAT transition — it emits `grid_locked` (locking the grid) then `combat_started` as part of that transition. | Bidirectional (signal listener + signal emitter) |
| **Prana Data** | Grid reads `id`, `name`, `color`, and `icon` per type to render the Type Selector panel and placed slot tokens. All reads via `PranaCatalog.get_type(id)`. | Prana Grid → Prana Data |
| **Combination Resolution** | Reads `committed_fragments: Array[PranaFragment]` (length 9, null = empty slot) via a public getter after `combat_started`. Never writes to it. | Combination Resolution → Prana Grid |
| **Spell Casting & Effects** | Reads `committed_fragments` (same getter) to route VFX and audio per type on cast event; uses `type_id` per non-null element. | Spell Casting & Effects → Prana Grid |
| **Combat HUD** *(MVP+)* | At First Playable, Prana Grid owns its own display node in screen space. At MVP, Combat HUD integrates the grid display into the broader HUD; the layout contract is defined in the Combat HUD GDD. | Prana Grid ↔ Combat HUD |

## Formulas

> **Note**: Prana Grid has no gameplay-balance formulas. The mathematical content here is the slot indexing scheme and the committed arrangement data format — the two computations consuming systems must agree on.

### Formula 1: Slot Index from Grid Position

The `slot_index` formula is defined as:

`slot_index = row × 3 + col`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Row | `row` | int | 0–2 | 0 = top row, 1 = middle row, 2 = bottom row |
| Column | `col` | int | 0–2 | 0 = left column, 1 = centre column, 2 = right column |

**Output range:** 0–8 (9 unique values, one per slot)

**Named positions:**

| slot_index | row | col | Position |
|-----------|-----|-----|----------|
| 0 | 0 | 0 | Top-left |
| 1 | 0 | 1 | Top-centre |
| 2 | 0 | 2 | Top-right |
| 3 | 1 | 0 | Middle-left |
| **4** | **1** | **1** | **Centre (combo primary slot)** |
| 5 | 1 | 2 | Middle-right |
| 6 | 2 | 0 | Bottom-left |
| 7 | 2 | 1 | Bottom-centre |
| 8 | 2 | 2 | Bottom-right |

**Inverse:** `row = slot_index / 3` (integer division), `col = slot_index % 3`.

---

### Formula 2: Committed Fragment Array Format

The `committed_fragments` array is defined as:

`committed_fragments[slot_index] = PranaFragment(type_id, level, stat_property, adjacency_effects) OR null`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Slot index | `slot_index` | int | 0–8 | Array position; maps to grid slot via Formula 1 |
| Fragment | `committed_fragments[i]` | `PranaFragment` or `null` | — | Non-null = fragment present; null = empty slot |
| Type ID | `fragment.type_id` | int | 0–4 | 0=Ashfire, 1=Voidblue, 2=Stormgold, 3=Deepfrost, 4=Verdant |
| Level | `fragment.level` | int | ≥ 1 | Always 1 at First Playable |
| Stat property | `fragment.stat_property` | `StatProperty` or `null` | — | Always null at First Playable |
| Adjacency effects | `fragment.adjacency_effects` | `Array[AdjacencyEffect]` | — | Always empty `[]` at First Playable |

**Output:** A fixed-length array of 9 elements. The array is always exactly 9 elements — there is no sparse representation. Empty slots are null, never omitted.

**Slot 4 invariant:** `committed_fragments[4]` is always non-null after a successful confirmation (Rule 6 enforces this).

**Example — Deepfrost centre with Ashfire corners (First Playable, all lv.1):**

```
committed_fragments = [
  PranaFragment(0,1,null,[]),  # slot 0 = Ashfire
  null,                         # slot 1 = empty
  PranaFragment(0,1,null,[]),  # slot 2 = Ashfire
  null,                         # slot 3 = empty
  PranaFragment(3,1,null,[]),  # slot 4 = Deepfrost (centre) — REQUIRED non-null
  null,                         # slot 5 = empty
  PranaFragment(0,1,null,[]),  # slot 6 = Ashfire
  null,                         # slot 7 = empty
  PranaFragment(0,1,null,[]),  # slot 8 = Ashfire
]
```

**Validation:** `committed_fragments.size() == 9` always. `committed_fragments[4] != null` always (enforced by Rule 6). Consuming systems must guard against null elements in all non-centre slots.

## Edge Cases

- **If the Confirm action is triggered with all 9 slots empty**: The Confirm button is disabled (visually greyed out, non-interactive). Pressing the confirm key produces an error-state visual indicator (e.g., grid border flashes red, "fill at least one slot" label briefly appears) but no state change and no `arrangement_confirmed` signal. The ARRANGEMENT state is unchanged.

- **If `grid_locked` is received while the grid is in ARRANGEMENT state without a prior `arrangement_confirmed` this phase**: The grid enters LOCKED state immediately (it cannot ignore `grid_locked`). The `committed_fragments` reflects whatever was last written — if no confirmation occurred this Preparation Phase, it is the all-null array from the phase entry reset. Downstream systems must handle an all-null arrangement without crashing. Log `push_error()` — this is a Game State & Scene Flow sequencing bug.

- **If a drag operation is in progress when `grid_locked` fires**: The in-progress drag is cancelled. The dragged token does not land in any slot. The grid enters LOCKED state with the arrangement as it was at the moment of `grid_locked` (before the drag's hypothetical landing). No partial placement occurs.

- **If `preparation_started` fires while a drag is in progress**: The drag is cancelled, all slots clear, and the grid re-enters ARRANGEMENT state empty. The in-flight token is discarded.

- **If the same Prana type is placed in all 9 slots**: Valid — no type-uniqueness constraint exists in Prana Grid. `committed_fragments` contains the same `type_id` in all 9 positions. What spell effects this produces is entirely Combination Resolution's concern.

- **If the game is PAUSED during ARRANGEMENT state**: Prana Grid is `PROCESS_MODE_PAUSABLE`, so it stops accepting input while the Pause Menu is open. The in-progress arrangement is preserved exactly — no slots change, no tokens are lost. On unpause, the grid resumes accepting input with the arrangement intact.

- **If a token is dragged onto a slot that already contains the same type** (e.g., Ashfire onto an Ashfire slot): The slot contents are unchanged (identical replacement). Drag feedback (visual/audio) should still play to confirm the action registered. The committed array does not change.

- **If `grid_hidden` fires while the grid is in LOCKED state** (e.g., combat ends in a run-ending outcome): The grid enters HIDDEN state immediately. No special handling beyond the state transition.

- **If Combination Resolution or Spell Casting reads `committed_fragments` before `combat_started`**: The array reflects the in-progress (uncommitted) arrangement. Consuming systems must only read `committed_fragments` after receiving `combat_started`. The Prana Grid does not version or lock the array separately — timing discipline is the consuming system's responsibility.

## Dependencies

### Systems That Depend on Prana Grid

| System | What it needs | Nature |
|--------|---------------|--------|
| **Combination Resolution** (#2, First Playable) | `committed_fragments: Array[PranaFragment]` (length 9, null = empty slot) after `combat_started` — reads type_id, level, stat_property, and adjacency_effects per slot to resolve spell effects | Hard — cannot resolve any spells without the arrangement |
| **Spell Casting & Effects** (#3, First Playable) | `committed_fragments` — reads type_id per non-null element to route VFX burst shape and audio signature per type on cast | Hard — cannot route type-specific effects without knowing what was placed |
| **Combat HUD** (#22, First Playable) | Grid display node and/or arrangement state for rendering the grid panel in the HUD during both PREPARATION and COMBAT phases | Soft at FP (Prana Grid owns its own display); hard at MVP when Combat HUD integrates the display |
| **Loadout Slots** (#18, Vertical Slice) | Read/write access to committed arrangements for saving and restoring preset loadouts | Soft — deferred to VS scope; the Prana Grid write interface for preset load is not specified at MVP |
| **Tutorial / Onboarding** (#31, Vertical Slice) | Observes ARRANGEMENT state and slot contents to trigger tutorial prompts | Soft — deferred to VS scope |

### Prana Grid's Own Dependencies

| System | What Prana Grid needs | Nature |
|--------|-----------------------|--------|
| **Prana Data** (approved) | `id`, `name`, `color`, `icon` per Prana type — read via `PranaCatalog.get_type(id)` at startup and for slot rendering | Hard — cannot render the Type Selector or filled slots without type visual properties |
| **Game State & Scene Flow** (approved) | `preparation_started` (→ ARRANGEMENT), `grid_locked` (→ LOCKED), `grid_hidden` (→ HIDDEN) signals — drives all grid state transitions. Prana Grid emits `arrangement_confirmed` which Game State listens to for the PREPARATION→COMBAT transition | Hard — Prana Grid has no independent knowledge of the current game phase |

**Bidirectional consistency notes:**
- Combination Resolution GDD must list Prana Grid as an upstream dependency and specify that it reads `committed_fragments` as a length-9 `Array[PranaFragment]` (null = empty slot). ✓ Confirmed in Combination Resolution GDD.
- Spell Casting & Effects GDD must list Prana Grid as an upstream dependency and specify the `committed_fragments` interface (reads `type_id` per non-null element for VFX and audio routing).
- Game State & Scene Flow GDD must confirm that `arrangement_confirmed` is a valid signal source for the PREPARATION→COMBAT transition. ⚠ **Cross-GDD interlock (open):** The approved Game State GDD's signal contract and Downstream Dependents table do not yet explicitly list `arrangement_confirmed` as a signal it subscribes to. The approved GDD must be updated (or a producer-level errata issued) before the PREPARATION→COMBAT transition can be implemented. This GDD correctly documents the intent; the gap is on the Game State side.
- Combat HUD GDD must specify whether it owns the Prana Grid display at MVP or delegates display to the Prana Grid node.

## Tuning Knobs

Prana Grid is a UI/input surface rather than a balance-sensitive gameplay system. Its tuning knobs are structural constants — they shape the decision space but do not require in-session adjustment at First Playable.

| Knob | Symbol | Current Value | Safe Range | Gameplay Effect |
|------|--------|---------------|------------|-----------------|
| Grid dimensions | `GRID_SIZE` | 3×3 (9 slots) | 2×2 – 4×4 | Larger grids expand the arrangement decision space and the surface area for Combination Resolution patterns. Smaller grids reduce cognitive load during onboarding. **Locked at 3×3 for MVP** — Combination Resolution formulas are authored against the 9-slot index. Do not change without re-authoring Combination Resolution. |
| Minimum slots to confirm | `MIN_FILLED_TO_CONFIRM` | 1 | 1–5 | Minimum occupied slots before Confirm is accepted. At 1, trivially sparse arrangements (single token) are valid choices. Tuning upward forces more deliberate engagement with the grid. Increase only with playtest data showing players chronically under-use the grid. Avoid exceeding 5 — above that, players with partial-fill strategies are unnecessarily punished. |

**Design note**: The number of available Prana types (all 5 at MVP) and the unlimited token pool are scope policy decisions recorded in Detailed Design, not tuning knobs. If types are gated in a future scope revision, Prana Data owns the available-type list and Prana Grid reads from it dynamically via `PranaCatalog`.

## Visual/Audio Requirements

### Visual

**Slot states** — each slot renders differently per state:

| State | Visual |
|-------|--------|
| Empty (ARRANGEMENT) | Octagonal frame, dark fill, faint inner glow (idle pulse) |
| Occupied | Octagonal frame filled with the type's canonical color (`PranaType.color`). Type icon (`PranaType.icon`) centered. Color and icon sourced from `PranaCatalog.get_type(id)` — never hardcoded. |
| Cursor-selected (gamepad) | Occupied or empty slot with a bright white/gold border highlight and slight scale-up (1.05×) |
| Dragging-over (mouse) | Target slot shows a pulsed highlight ring indicating a valid drop target |
| LOCKED | **Full grid panel hidden.** Compact indicator (≤60×60px) visible in bottom-right corner. Filled dot: `PranaCatalog.get_type(id).color`. Empty dot: `Color("#333333")`. Full opacity, no pulse, no interaction. |

**Type Selector panel** — adjacent to the grid, displays all available Prana type tokens in a row or column. Each token uses its canonical color and icon. The panel dims and becomes non-interactive in LOCKED state.

**Confirm button states**:
- **Enabled**: Bright, full opacity, active color — requires slot 4 (centre) to be filled
- **Disabled** (slot 4 empty): Greyed out, 40% opacity, non-interactive — applies even if other slots are filled
- **Error flash** (confirm key pressed while slot 4 empty): Grid border flashes red for 0.4s; a brief "place a fragment in the centre slot" label appears. No state change.

**LOCKED state overlay**: A subtle visual indicator (e.g., padlock icon or border tint change) signals the grid is locked and read-only during Combat Phase.

**Art constraints**: All slot colors and icons must conform to the Art Bible's 5 Prana colors (Ashfire #F24C1D, Voidblue #4A5EF5, Stormgold #FFCC00, Deepfrost #3DD9F0, Verdant #1AC953). Slot frame uses the "octagonal frame, circle slots" motif specified in the Art Bible. Boss reserved color (Corruption Violet #9B2ED4) must not appear in any grid element.

### Audio

| Event | Sound | Notes |
|-------|-------|-------|
| Token placed in slot | Short, type-specific placement click | Pitch/timbre varies by Prana type; exact assets deferred to Sound Designer |
| Token removed from slot | Soft removal sound | Neutral, non-type-specific |
| Token swapped (occupied → occupied) | Placement sound of the incoming type | Plays for the incoming token, not the displaced one |
| Confirm accepted | Confirmation chime | Signals successful commitment; should feel decisive |
| Confirm error (empty grid) | Short negative feedback tone | Clearly distinct from confirmation; not alarming — just informative |
| Drag operation start | Subtle lift sound | Indicates pickup registered |
| Grid enters LOCKED | No audio event | State transition is signalled visually; audio is owned by Game State / Combat Phase onset |

*Exact audio asset IDs are deferred to the Audio System GDD and Sound Designer. This section specifies required events, not implementations.*

## UI Requirements

### Layout

The Prana Grid UI consists of three components displayed together during Preparation Phase:

1. **Grid panel** — the 3×3 slot matrix
2. **Type Selector panel** — the source of draggable Prana tokens (mouse) / current-type indicator (gamepad)
3. **Action buttons** — Confirm and Clear All

During LOCKED state (Combat Phase), the full Grid panel **hides**; the Type Selector panel and Action buttons also hide. A compact indicator (≤60×60px, read-only) appears in the bottom-right corner showing the committed arrangement as colored dots — see Rule 3 for the full compact indicator specification.

### Grid Panel

- 3×3 arrangement of slot nodes, evenly spaced with a small gap between slots
- Slot 4 (centre) may be visually distinguished (e.g., subtle accent ring) to signal its role as the combo primary slot — this distinction must not obscure the placed token
- Total grid display fits within the Preparation Phase UI zone; exact pixel dimensions deferred to the Combat HUD GDD
- During LOCKED state, the full Grid panel is **hidden** and replaced by the compact indicator (Rule 3). The compact indicator occupies the bottom-right corner; the arena is unobstructed.

### Type Selector Panel

**Mouse (primary)**: A panel displaying all 5 Prana type tokens as draggable elements. Tokens are rendered with their canonical color and icon. The panel is positioned adjacent to the grid (left, right, or bottom — position deferred to Combat HUD GDD). Tokens are source-infinite — dragging one does not remove it from the panel; the panel always shows all 5 types.

**Gamepad (secondary)**: The Type Selector is replaced by a Type Indicator widget — a small display showing the currently selected Prana type (color + icon). Left/right shoulder or a dedicated sub-menu cycles through types. No draggable tokens are shown.

### Action Buttons

- **Confirm button**: Labelled "Confirm" (or icon equivalent). Enabled when slot 4 (centre) is filled; disabled (greyed, non-interactive) when slot 4 is empty — regardless of other slot states. Keyboard shortcut: Enter (default). Gamepad: South face button (default; exact binding deferred to Input Map GDD).
- **Clear All button**: Labelled "Clear All" (or icon equivalent). Always enabled during ARRANGEMENT state. Clears all 9 slots immediately. Keyboard shortcut: TBD. Gamepad: TBD (deferred to Input Map GDD).

### Accessibility

- All grid slots must be reachable via keyboard navigation (Tab / arrow key traversal) in addition to mouse drag
- The Confirm button and Clear All button must be reachable via keyboard with no mouse-only interaction
- Type Selector tokens must be selectable via keyboard cycle (not hover-only)
- Color alone must not be the sole distinguishing signal — each Prana type's slot token must also display its icon
- No interaction on the grid requires hover state — all actions must be triggerable by direct click, keyboard press, or gamepad button (per `technical-preferences.md`)

## Acceptance Criteria

Each criterion is independently verifiable by a QA tester.

### AC-PG-01: Grid resets on phase entry
**Given** the grid is in any state (ARRANGEMENT with tokens placed, LOCKED, or HIDDEN)
**When** `preparation_started` is received
**Then** all 9 slots are empty and the grid is in ARRANGEMENT state
**Pass**: All 9 slots are empty (null); grid accepts player input

### AC-PG-02: LOCKED state on combat start
**Given** the grid is in ARRANGEMENT state (with or without tokens placed)
**When** `combat_started` is received
**Then** the grid enters LOCKED state: all input is disabled, drag/place/clear/confirm produce no effect
**Pass**: Attempting drag, key press, and confirm produces zero state change and no signal emission

### AC-PG-03: `arrangement_confirmed` signal emitted correctly
**Given** slot 4 (centre) is filled (with or without other slots filled)
**When** the player triggers Confirm
**Then** the grid emits `arrangement_confirmed` exactly once
**And** `committed_fragments` is a length-9 `Array[PranaFragment]` where filled slots carry a PranaFragment with the correct `type_id` (0–4) and `level = 1` (at First Playable), and empty slots are `null`
**And** `committed_fragments[4]` is non-null
**Pass**: Signal listener receives exactly one emission; array length == 9; non-null elements have correct type_id; slot 4 is non-null

### AC-PG-04: Missing centre blocks confirmation — UI
**Given** slot 4 (centre) is empty (other slots may be filled or empty)
**Then** the Confirm button is visually greyed out and non-interactive (clicking produces no signal, no state change)
**Pass**: QA can click the button and observe no response; no `arrangement_confirmed` emitted; this applies both to all-empty grid AND to any arrangement where only the centre is missing

### AC-PG-05: Missing centre blocks confirmation — keyboard/gamepad
**Given** slot 4 (centre) is empty
**When** the confirm key (Enter) or gamepad confirm button is pressed
**Then** no `arrangement_confirmed` is emitted; a visual error indicator fires (grid border flash, "place a fragment in the centre slot" label)
**Pass**: Error indicator visible; no signal emitted; ARRANGEMENT state unchanged

### AC-PG-06: Slot replace (occupied → occupied)
**Given** slot N contains type A
**When** the player places type B onto slot N
**Then** slot N now contains type B; no crash or duplicate token
**Pass**: `committed_fragments[N].type_id` equals type B's `type_id` after confirm

### AC-PG-07: Slot clear
**Given** slot N contains any token
**When** the player removes it (right-click on mouse, Clear action on gamepad)
**Then** slot N is empty (null)
**Pass**: Slot renders as empty; `committed_fragments[N]` == null after confirm

### AC-PG-08: Clear All
**Given** any number of slots are filled
**When** the player activates Clear All
**Then** all 9 slots become empty; Confirm button becomes disabled
**Pass**: All slot values == −1; Confirm button greyed

### AC-PG-09: Gamepad full-cycle completable
**Given** a gamepad is the only connected input device
**Then** the player can: navigate all 9 slots, cycle through all 5 Prana types, place a token, clear a token, and confirm — without any mouse input
**Pass**: End-to-end arrangement and confirmation completed using only gamepad inputs

### AC-PG-10: `committed_fragments` read-only after confirmation
**Given** `arrangement_confirmed` has fired and the grid is LOCKED
**When** Combination Resolution or Spell Casting reads `committed_fragments`
**Then** the array reflects the arrangement at the moment of confirmation; subsequent lock-state non-events do not alter it; `committed_fragments[4]` remains non-null
**Pass**: Fragment values match the confirmed arrangement throughout the Combat Phase duration; no element mutates during LOCKED state

### AC-PG-11: Drag cancelled on `combat_started`
**Given** a mouse drag operation is in progress
**When** `combat_started` fires mid-drag
**Then** the drag is cancelled; the dragged token does not land; the grid enters LOCKED with the pre-drag arrangement
**Pass**: No partial placement; LOCKED state shows arrangement as it was before drag started

### AC-PG-12: Compact indicator visible during Combat Phase; full panel hidden
**Given** the grid has confirmed an arrangement and entered LOCKED state
**Then** the full grid panel is NOT visible; the compact indicator (≤60×60px dot array) IS visible in the bottom-right corner
**And** filled dot colors match `PranaCatalog.get_type(slot_type_id).color`; empty dots show `Color("#333333")`
**And** compact indicator is non-interactive (`mouse_filter == MOUSE_FILTER_IGNORE`)
**On `preparation_started`**: compact indicator hides, full panel becomes visible (ARRANGEMENT entry)
**Pass**: QA confirms full panel invisible during combat; compact dot colors correct; no mouse interaction registered; full panel reappears on next Preparation Phase

## Open Questions

1. **Combat HUD integration contract** — At MVP, does the Combat HUD own the Prana Grid display node, or does Prana Grid own its own display and Combat HUD composites it? This affects node ownership and scene hierarchy. To be resolved when Combat HUD GDD (#22) is authored.

2. **Confirm button default binding (gamepad)** — South face button is assumed but not locked. To be confirmed in the Input Map GDD (not yet authored). If the south button is claimed by another action in combat, a conflict arises.

3. **Clear All confirmation prompt** — Does "Clear All" require a secondary confirmation (e.g., hold to clear) to prevent accidental full resets, or is it instant? At MVP, instant is assumed. Revisit if playtest shows accidental clears are a friction point.

4. **Arrangement persistence across pause** — The GDD specifies PROCESS_MODE_PAUSABLE for ARRANGEMENT state (arrangement preserved on unpause). Confirm this is the correct pause mode for the Prana Grid node when PAUSED state is designed in Game State & Scene Flow.

5. **Preset loadout write interface** — Loadout Slots (#18, Vertical Slice) needs write access to load a saved arrangement into the grid. The write interface (a `load_arrangement(arr: Array[int])` method or equivalent) is not specified at MVP. Flag for design when Loadout Slots is authored.
