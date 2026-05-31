# UX Spec: Main Menu

> **Status**: Approved — /ux-review 2026-05-31 (0 blocking, 4 advisory)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-31
> **Journey Phase(s)**: Unknown — no player journey map
> **Template**: UX Spec

---

## Purpose & Player Need

> **Player goal statement:** *"The player arrives at the Main Menu wanting to begin. The screen exists to give them permission — and to make the beginning feel like something."*

The Main Menu serves two needs simultaneously: **orientation** (this is the world, this is the atmosphere of what you are entering) and **threshold** (one action gets you in). The screen must communicate the emotional register of the game before the player ever controls Fayde — the quiet, mysterious, slightly-melancholy atmosphere of a scrap yard that has been waiting a long time.

The screen is not a hub — it is a doorway. At MVP scope there are no choices to make beyond "start" or "quit." The design honors that simplicity: one dominant action, minimal chrome, atmosphere does the work. When the player presses New Game, they should already feel the weight of stepping into something that has been asleep.

**What would go wrong if this screen was hard to use:** The player's first moment with the game would be friction, not atmosphere. The emotional register established by the Art Bible (§2.1: "curiosity on the edge of a threshold") would be lost before it began. For a game whose identity is mystery and discovery, the first screen must earn trust.

---

## Player Context on Arrival

Four distinct paths lead to the Main Menu:

| Arrival Source | Prior Activity | Emotional State |
|---------------|---------------|-----------------|
| First launch | Nothing — first encounter with the game | Curious, no context, discovering |
| From RUN_SUMMARY | Completed a full run (won) | Satisfied, reflective, wants to go again |
| From DEATH_SCREEN | Fayde died mid-run | Wistful, not ashamed — "I want to know how it ends" (Art Bible §2.5) |
| From PAUSED → Quit | Abandoned a run voluntarily | Pragmatic — chose to stop, may return immediately |

**At MVP scope**, all four paths arrive at a visually identical screen — there is no save state, no "continue" option, and no run history to display. The UI makes no distinction between arrival contexts.

**Voluntary vs. redirected:** Players arrive both voluntarily (first launch, choosing to start over) and redirected by the game (post-death, post-quit). The screen must work as both a chosen destination and a system-assigned landing zone.

**Emotional register:** Contemplative and curious for all four cases. The Art Bible describes this mood as "curiosity on the edge of a threshold — standing before a locked door that is already slightly ajar." Even post-death arrivals are positioned as wistful, not punishing (§2.5). The Main Menu's calm energy is calibrated to feel like a brief exhale before re-entering.

**What the player is NOT doing here:** Managing anything. There are no inventory decisions, no loadout choices, no upgrade selections at MVP. The player's only job on this screen is to decide whether to start or quit.

---

## Navigation Position

The Main Menu is the **root** of the navigation hierarchy. There is no parent screen — all paths eventually return here, and the game always launches to this screen. It is not reachable via "Back" from any other screen; it is a landing zone, not a waypoint.

```
[Game Launch] ──→ MAIN_MENU (root — no parent)
                      │
                      ├── "New Game" → PREPARATION_PHASE → (run loop)
                      │                    │
                      │    ┌───────────────┴────────────────┐
                      │    │                                │
                      │  RUN_SUMMARY ──────────────────→ MAIN_MENU
                      │  DEATH_SCREEN ─────────────────→ MAIN_MENU
                      │  PAUSED (Quit to Menu) ─────────→ MAIN_MENU
                      │
                      └── "Quit" → [exits application]
```

**Pause not available from Main Menu** — the Game State & Scene Flow GDD explicitly blocks pause entry from `MAIN_MENU`, `RUN_SUMMARY`, and `DEATH_SCREEN`. No Pause button is shown on this screen.

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| Game launch | OS / platform launches executable | Nothing — fresh session |
| RUN_SUMMARY | Player activates "Return to Menu" button | Completed run; no persistent MVP state to carry |
| DEATH_SCREEN | Player activates "Return to Menu" button | Failed run; no persistent MVP state to carry |
| PAUSED → Quit | Player activates "Quit to Menu" in Pause Menu | `run_ended(win: false)` already fired by GS&SF before transition completes |

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| PREPARATION_PHASE | Player activates "New Game" button | `run_started` fires first, then `preparation_started` — per GS&SF signal ordering rule (§Signal Ordering). One-way exit for the run: no return to Main Menu mid-run except through death, run completion, or manual quit. |
| Application exit | Player activates "Quit" button | Platform-level exit via `get_tree().quit()`. No further navigation. |

---

## Layout Specification

### Information Hierarchy

Priority ranked — higher priority elements receive more visual weight and spatial dominance:

1. **Title + Prana glow** — atmospheric identity; the first and most sustained read. Establishes the game's emotional register before any action.
2. **New Game button** — the screen's only primary action at MVP. Must be unmissable at a glance.
3. **Quit button** — secondary; always available but visually subordinate.
4. **Version string** — utility only; must not compete for attention.

### Layout Zones

**Layout type:** Centered vertical stack. Background fills full screen; UI elements are layered above it.

| Zone | Contents | Position | Dimensions (reference 1080p) |
|------|----------|----------|------------------------------|
| Full screen | Atmospheric background scene | Behind all UI — z-order 0 | 1920×1080 |
| Title zone | "The Last Cipher" logotype + Prana glow animation | Vertically centered ~40% from top; horizontally centered | Title: ~400×80px; Glow: extends ~60px beyond title bounds |
| Action zone | New Game button + Quit button (vertical stack) | ~65% from top; horizontally centered; 48px gap between buttons | Each button: ~240×48px |
| Utility zone | Version string | Bottom-right corner, 16px margin | ~80×16px |

**Zone separation rule:** Minimum 48px vertical clearance between Title zone and Action zone. The atmospheric layer (art) is the dominant visual element — UI occupies ≤30% of vertical height.

### Component Inventory

| Component | Zone | Type | Interactive | Pattern |
|-----------|------|------|-------------|---------|
| Background atmospheric scene | Full screen | Scene / AnimatedSprite2D | No | — |
| Title logotype ("The Last Cipher") | Title | Label or Texture2D | No | — |
| Prana glow animation | Title | CPUParticles2D or AnimatedSprite2D | No | — |
| New Game button | Action | Button | Yes — **primary action** | IP-11 Standard Button |
| Quit button | Action | Button | Yes — secondary action | IP-11 Standard Button |
| Version string | Utility | Label | No | — |

**No new interaction patterns introduced.** All interactive components use IP-11 (Standard Button), navigated via IP-10 (Menu Screen Navigation).

### ASCII Wireframe

```
┌────────────────────────────────────────────────────────────────┐
│                                                                │
│                    [ATMOSPHERIC BACKGROUND]                    │
│         deep indigo ambient · warm lantern glow at center      │
│         doorway mist · 2-frame ambient shimmer (Art Bible §2.1)│
│                                                                │
│                                                                │
│                  ✦  THE LAST CIPHER  ✦                         │
│              [Prana glow — slow pulse, ~2s per breath]         │
│                   (last-used Prana color or slow cycle)        │
│                                                                │
│                                                                │
│                       [ New Game ]       ← primary action      │
│                                                                │
│                         [ Quit ]         ← secondary          │
│                                                                │
│                                                  v0.1.0        │
└────────────────────────────────────────────────────────────────┘
```

**Godot implementation note:** Background and Prana glow are rendered below the UI `CanvasLayer`. The UI (title, buttons, version) is on a `CanvasLayer`. This preserves the `CanvasLayer`-per-system architecture defined in ADR-0005 and ensures the HUD separation principle applies to menus as well.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Default** | Screen enters from any path | Full atmospheric background, title with Prana glow cycling, New Game + Quit at full opacity and default focus |
| **First launch (MVP)** | No prior session data | Prana glow slow-cycles through all 5 Prana colors (no "last used" type to reference). Otherwise identical to Default. |
| **Return visit (VS scope)** | Prior run data exists | *[VS only]* Prana glow defaults to last-used Prana type from prior run. At MVP scope, this state is identical to Default — no save state tracked. |
| **Button focused** | Keyboard Tab / arrow / gamepad d-pad navigates to a button | Focused button shows IP-11 focused state: highlight border + 1.03× scale-up. Background and title: unchanged. |
| **Button pressed** | Mouse click or confirm input on focused/hovered button | Button shows IP-11 pressed state (0.97× scale, 0.08s), then transition executes. |

**No loading state:** This screen has no async data to load. The scene is loaded synchronously by SceneManager. No spinner, progress bar, or loading overlay exists.

**No error state:** The screen has no data-dependent elements that can fail. New Game triggers only a state machine transition (cannot fail). Quit calls `get_tree().quit()` (cannot fail). No error handling UI is needed.

**Initial focus:** On screen entry, keyboard/gamepad focus defaults to the **New Game** button — it is the primary action and the most common intent on arrival. The player can Tab to Quit from there.

---

## Interaction Map

**Input context (from `technical-preferences.md`):** Keyboard/Mouse (primary), Gamepad (partial). No hover-only interactions. All actions navigable without mouse.

| Component | Action | Mouse/Keyboard | Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **New Game button** | Activate | Left-click or Enter (focused) | South face button (focused) | IP-11 pressed state (0.97×, 0.08s) + UI confirm audio | `start_run()` called → GameStateManager transitions MAIN_MENU → PREPARATION_PHASE; emits `run_started` then `preparation_started` |
| **Quit button** | Activate | Left-click or Enter (focused) | South face button (focused) | IP-11 pressed state (0.97×, 0.08s) + UI confirm audio | `get_tree().quit()` — application exits |
| **Focus navigation** | Move focus between buttons | Tab (forward) / Shift-Tab (backward) / Arrow Up-Down | D-pad Up / D-pad Down | IP-11 focused state on newly focused button; UI navigate audio | Focus moves between New Game and Quit (2-item cycle, wraps) |

**Default focus on entry:** New Game button. The player can Tab once to reach Quit.

**Keyboard-only path to New Game:** Screen opens → New Game already focused → press Enter → game begins. Zero Tab presses required for the primary action.

---

## Events Fired

| Player Action | Signal / Call | Payload | Notes |
|---|---|---|---|
| New Game activated | `GameStateManager.start_run()` | None | GS&SF internally emits `run_started` then `preparation_started` in that order (signal ordering rule). No analytics event at MVP scope. |
| Quit activated | `get_tree().quit()` | None | Platform-level exit. No signal emitted — application terminates. |
| Focus navigated | (none — UI-internal) | None | No game event. UI navigate audio plays on UI bus. |

**No state-modifying actions on this screen:** New Game transitions the game state machine (owned by GameStateManager); the Main Menu itself writes nothing. Quit terminates the process. This screen is read/navigate-only.

---

## Transitions & Animations

| Transition | Animation | Duration | Easing | Notes |
|---|---|---|---|---|
| **Screen enter** (any source → MAIN_MENU) | Fade in from black — background first, then title + buttons simultaneously | 0.5s | TRANS_CUBIC / EASE_OUT | Prana glow begins pulsing immediately on entry. Background resolves first to establish atmosphere before the action layer appears. |
| **Screen exit — New Game** (MAIN_MENU → PREPARATION_PHASE) | Fade to black | 0.3s | TRANS_CUBIC / EASE_IN | Faster than entry — player decision made, transition should feel immediate. SceneManager handles scene swap during the black frame. |
| **Screen exit — Quit** | None | — | — | OS/platform closes application. No transition needed. |
| **Prana glow cycle** (ambient, continuous while active) | Color cycle across all 5 Prana types | 2s per breath (10s full cycle at MVP) | Smooth interpolation | Art Bible §2.1 spec: "one breath per two seconds." At MVP, cycles all 5 types continuously. [VS: holds on last-used Prana type instead of cycling.] |
| **Button focus state** | IP-11 highlight border + 1.03× scale | Instant on focus move | None | Per IP Animation Standards: no easing on focus moves. |
| **Button pressed state** | IP-11 press (0.97× scale) | 0.08s | TRANS_LINEAR | Reverts to focused state automatically after 0.08s. |

**Doorway mist ambient:** The background includes a 2-frame ambient shimmer on the doorway mist (Art Bible §2.1). This is a background art animation, not a UI transition — the UI programmer does not own it. It is authored by the art/animation pipeline.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| Game title ("The Last Cipher") | Hardcoded / constant | Read | Not localized as a proper noun; text is in the logotype asset or a constant label. |
| Version string | `ProjectSettings.get_setting("application/config/version")` or build constant | Read | Display only. Not localized. Small utility text in bottom-right corner. |
| *[VS] Last-used Prana type ID* | *Save system (not yet designed)* | *Read* | *Used to set Prana glow color default. Deferred to VS scope; at MVP, glow always cycles all 5 types.* |

**No state-modifying data writes on this screen.** The Main Menu reads a version string and optionally reads save data in future scopes. It writes nothing. New Game triggers a state machine transition (owned by GameStateManager) — the Main Menu itself is the initiator, not the writer.

---

## Accessibility

No formal accessibility tier is committed (`design/accessibility-requirements.md` absent). Applying Art Bible §4.5 as current baseline.

| Check | Status | Notes |
|-------|--------|-------|
| Keyboard-only navigation | ✓ Covered | New Game receives focus on entry. Tab cycles to Quit. Tab from Quit wraps back to New Game. Enter activates. Zero mouse required. |
| Gamepad navigation | ✓ Covered | D-pad Up/Down cycles between 2 buttons. South face button activates. No hover-only interactions. |
| Focus state (color-independent) | ✓ Covered | IP-11 focused state includes highlight border + 1.03× scale — not color alone. |
| Text legibility | ✓ Covered | All text uses bitmap pixel font: minimum 8px × 2× = 16px display. Button labels and title meet ages 7+ legibility standard. |
| Color-only information | ✓ None | No information conveyed by Prana glow color alone — the glow is atmospheric, not informational. |
| Motion sensitivity (Prana glow) | ✓ Safe | Glow cycle rate ~0.5 Hz; well below any motion sensitivity threshold. No seizure risk. |
| Screen reader | Known gap — deferred | Not supported at First Playable scope. |

**No new accessibility gaps** beyond those already acknowledged project-wide (screen reader, formal accessibility tier).

---

## Localization Considerations

| Text Element | English Length | 40% Expansion | Localization Risk |
|---|---|---|---|
| "The Last Cipher" (title) | 15 chars | ~21 chars | **LOW** — title is likely kept as a proper noun in most locales; if localized, a 40% expansion still fits the centered layout comfortably |
| "New Game" (button label) | 8 chars | ~11 chars | **LOW** — button is ~240px wide; 11 chars at 16px font fits on one line with generous margin |
| "Quit" (button label) | 4 chars | ~6 chars | **LOW** — extremely short in all languages |
| Version string (`v0.1.0`) | ~6 chars | N/A — not localized | **NONE** |

**No HIGH PRIORITY localization risks on this screen.** The Main Menu is the simplest screen in the game for localization — all text elements are short, the layout is flexible, and no element is layout-critical at 40% expansion.

---

## Acceptance Criteria

Classification: **[U]** = Unit/integration test | **[M]** = Manual QA

---

**AC-MM-01 [U]** — Screen opens within 200ms with correct initial state
GIVEN GameStateManager transitions to `MAIN_MENU`
WHEN ≤200ms have elapsed
THEN the Main Menu scene is active; the atmospheric background is visible; the title label/texture is visible; the **New Game button has keyboard focus** (verified via `has_focus() == true`)

**AC-MM-02 [M]** — Keyboard-only Tab navigation cycles exactly 2 interactive elements
GIVEN no mouse input; Main Menu is open
WHEN player presses Tab repeatedly
THEN focus cycles: New Game → Quit → New Game (wraps). Each focused button shows a visible focus indicator. No other element receives focus.

**AC-MM-03 [U]** — New Game activates correctly and transitions to PREPARATION_PHASE
GIVEN New Game button is focused
WHEN Enter is pressed (or button is left-clicked)
THEN `run_started` signal is emitted exactly once; `GameStateManager.get_active_state()` returns `PREPARATION_PHASE`; Main Menu scene is no longer the active scene

**AC-MM-04 [M]** — Quit terminates the application
GIVEN Quit button is focused
WHEN Enter is pressed (or button is left-clicked)
THEN the application terminates cleanly with no error dialog

**AC-MM-05 [U]** — New Game has default focus on scene entry
GIVEN Main Menu scene enters from any source (game launch, RUN_SUMMARY, DEATH_SCREEN, PAUSED quit)
THEN `new_game_button.has_focus() == true` within one frame of scene entry — no Tab press required

**AC-MM-06 [M]** — Prana glow is animating on screen entry
GIVEN Main Menu is open for 2 seconds
THEN the title glow has visibly changed color at least once (slow cycle is active)

**AC-MM-07 [M]** — Screen enter fade completes within 0.5s
GIVEN any source screen transitions to Main Menu
THEN atmospheric background, title, and buttons are fully visible (alpha = 1.0) within 0.5s of transition start

**AC-MM-08 [U]** — Pause input has no effect from Main Menu
GIVEN `GameStateManager.get_active_state() == MAIN_MENU`
WHEN pause input is triggered (keyboard or gamepad)
THEN `game_paused` signal is NOT emitted; active state remains `MAIN_MENU`

---

## Open Questions

1. **Prana glow technical implementation** — The glow is specified as CPUParticles2D or AnimatedSprite2D in the Component Inventory. Exact implementation (particle system vs. sprite animation vs. shader glow effect on the title) is deferred to the art pipeline. Spec: pulse at ~2s per breath, color-cycle all 5 Prana types at MVP. *Owner: Technical Artist / Art Director. Priority: before art production sprint.*

2. **"Enter = New Game" global shortcut vs. focus-based only** — Should Enter always trigger New Game regardless of which button is focused? Recommended: focus-based only (standard IP-10 behavior) — if the player Tabs to Quit and presses Enter, they expect Quit, not New Game. Confirm before implementation. *Owner: Implementation decision.*

3. **Settings screen not scoped** — No Settings GDD exists at MVP. If audio volume, display settings, or keybinding options are required (Steam may require a Quit-to-Desktop mechanism at minimum), they must be scoped and specced before the release checklist. At MVP, Quit is accessible from the Main Menu — this satisfies the minimum Steam requirement. *Owner: Producer / release checklist.*

4. **Player journey map missing** — `design/player-journey.md` does not exist. The first-launch emotional context was designed from game concept and Art Bible alone. Consider authoring a player journey map to validate context assumptions for all menu screens. *Owner: UX session.*

5. **VS scope — Continue button** — At Vertical Slice, if meta-progression or run state persists between sessions, a "Continue" button (or equivalent) may be needed. This spec is MVP-only and does not account for save state. *Owner: VS sprint planning / Run Management GDD.*
