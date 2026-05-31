# UX Spec: Pause Menu

> **Status**: Approved — /ux-review 2026-05-31 (0 blocking, 4 advisory)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-31
> **Platform Target**: PC — Keyboard/Mouse (primary), Gamepad (partial)
> **GDD References**: `design/gdd/game-state-scene-flow.md` (PAUSED state, overlay pattern, signal contract)
> **Journey Phase(s)**: Unknown — no player journey map
> **Template**: UX Spec

---

## Purpose & Player Need

> **Player goal statement:** *"The player arrives at the Pause Menu wanting either to step away temporarily and come back, or to end this run cleanly. The screen exists to protect their agency over their time."*

The Pause Menu is a utility interruption layer — not a menu hub, not a narrative beat. At MVP scope it offers exactly two choices: **Resume** (return to where you were) and **Quit to Menu** (end the run and return to the title). No settings, no loadout review, no information display.

The dark dim overlay preserves the game world's visibility while clearly signaling that time has stopped. During `PREPARATION_PHASE` this is particularly valuable: the player can see their current Prana arrangement and the wave composition while deciding whether to continue or quit. During `COMBAT_PHASE` they see the enemy positions and their health — context that informs the "is this run worth continuing?" decision.

**What would go wrong if this screen was hard to use:** A player who needs to leave immediately — a child called for dinner, an adult with a deadline — cannot safely exit without destroying the run through death. The pause route must work on the first attempt under time pressure with zero cognitive load.

---

## Player Context on Arrival

| Arrival Source | Prior Activity | Emotional State | Likely Intent |
|---|---|---|---|
| `PREPARATION_PHASE` | Reviewing wave composition, arranging Prana grid | Deliberate, calm — the held-breath phase | Stepping away, or reconsidering whether the run is worth continuing |
| `COMBAT_PHASE` | Active movement, dodging, casting | Adrenaline — time pressure, possibly stressed | Emergency exit (need to leave RIGHT NOW), or reading enemy positions before deciding to quit |

Pause is always **voluntary and player-initiated** — the game never forces the player into this screen. Unlike the Death Screen or Run Summary, there is no involuntary arrival path. The player chose to stop; the design should respect that choice without delay or friction.

**What the player sees underneath the overlay:** The frozen game world — their current Prana grid arrangement (in PREP) or enemy positions and health (in COMBAT). This context is deliberately preserved and visible through the dim. It informs the "should I quit this run?" decision without requiring the player to remember what they were doing.

---

## Navigation Position

The Pause Menu is **not a screen in the navigation hierarchy** — it is an overlay that temporarily covers the active gameplay state without replacing it. It has no "parent" to navigate back to in the traditional sense; it dismisses and restores `_previous_state` rather than navigating to a prior screen.

```
[PREPARATION_PHASE] ──→ PAUSED overlay (CanvasLayer above game world)
[COMBAT_PHASE]     ──┘         │
                               ├── Resume → ← _previous_state restored
                               └── Quit to Menu → MAIN_MENU
```

**Overlay, not scene swap:** The Pause Menu lives in a persistent `CanvasLayer` with `process_mode = PROCESS_MODE_ALWAYS`. The game world is paused via `get_tree().paused = true` but remains visible and rendered underneath. The SceneManager does not swap scenes when pausing.

**Not reachable from:** `MAIN_MENU`, `RUN_SUMMARY`, `DEATH_SCREEN` — these states have no ongoing game world to suspend. Pause input is silently ignored in those states (GS&SF GDD AC-13).

---

## Entry & Exit Points

### Entry Sources

| Entry Source | Trigger | Player carries this context |
|---|---|---|
| `PREPARATION_PHASE` | Player presses pause input (keyboard or gamepad) | Active Prana grid arrangement, current wave composition visible underneath overlay |
| `COMBAT_PHASE` | Player presses pause input (keyboard or gamepad) | Enemy positions, HP state visible underneath overlay |

In both cases `GameStateManager` fires `game_paused` and stores `_previous_state` before the overlay appears.

### Exit Destinations

| Exit Destination | Trigger | Notes |
|---|---|---|
| *(previous state — PREPARATION_PHASE or COMBAT_PHASE)* | Player activates Resume button, OR presses pause input again | `game_resumed` emitted; `_previous_state` restored. Game world un-freezes. |
| `MAIN_MENU` | Player activates Quit to Menu → confirms in dialog | `run_ended(win: false)` emitted first (GS&SF signal contract), then scene transitions to MAIN_MENU. Run data is finalized before the transition. |

### Internal State Transition (within overlay — not a navigation exit)

| From | To | Trigger |
|---|---|---|
| Default state | Quit Confirm state | Player activates "Quit to Menu" button |
| Quit Confirm state | Default state | Player activates "Stay" (cancel) button |

"Stay" returns to the Default pause overlay — the player is still paused and must press Resume to return to gameplay.

---

## Layout Specification

### Information Hierarchy

**Default state (priority order):**
1. "PAUSED" heading — confirms game is stopped; first read
2. Resume button — primary action, most likely intent
3. Quit to Menu button — secondary; visually subordinate (lower in the vertical stack)

**Quit Confirm state (priority order):**
1. Warning text — consequence is the critical information; must be read before acting
2. "Keep Playing" button — default focus; safer choice; positioned above Quit Run
3. "Quit Run" button — destructive; requires deliberate navigation to reach

### Layout Zones

**Layout type:** Full-screen overlay — two layers stacked.

| Zone | Contents | Position | Dimensions (reference 1080p) |
|------|----------|----------|------------------------------|
| Dim layer | Dark semi-transparent fill — game world visible beneath | Full screen, z-order above game world, below card | 1920×1080, `color #000000, alpha 0.65` |
| Pause card | Heading + buttons (Default state) OR warning text + buttons (Quit Confirm state) | Horizontally and vertically centered; z-order above dim layer | ~280×176px (Default); ~280×200px (Quit Confirm) |

**Zone separation rule:** The card is the only interactive surface. The dim layer is non-interactive — pointer events pass through to the card only, not to the game world beneath.

### Component Inventory

**Default state:**

| Component | Zone | Type | Interactive | Pattern |
|-----------|------|------|-------------|---------|
| Dim layer | Full screen | ColorRect | No | — |
| Pause card background | Card | Panel / NinePatchRect | No | — |
| "PAUSED" heading label | Card | Label | No | — |
| Resume button | Card | Button | Yes — **primary action** | IP-11 Standard Button |
| Quit to Menu button | Card | Button | Yes — secondary | IP-11 Standard Button |

**Quit Confirm state (replaces card contents — dim layer unchanged):**

| Component | Zone | Type | Interactive | Pattern |
|-----------|------|------|-------------|---------|
| Warning text ("Abandon this run? Progress will not be saved.") | Card | Label | No | — |
| Keep Playing button | Card | Button | Yes — **default focus** in this state | IP-11 Standard Button |
| Quit Run button | Card | Button | Yes — destructive | IP-11 Standard Button |

**No new interaction patterns introduced.** Both states use IP-11 (Standard Button) and IP-10 (Menu Screen Navigation).

### ASCII Wireframe

**Default state:**
```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  [GAME WORLD — frozen, dimmed, ~65% dark overlay]   │
│                                                      │
│               ┌──────────────────┐                  │
│               │    — PAUSED —    │                  │
│               │                  │                  │
│               │  [ Resume ]      │  ← default focus │
│               │                  │                  │
│               │  [ Quit to Menu ]│                  │
│               └──────────────────┘                  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Quit Confirm state:**
```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  [GAME WORLD — frozen, dimmed, still visible]        │
│                                                      │
│               ┌──────────────────┐                  │
│               │ Abandon this run?│                  │
│               │ Progress will    │                  │
│               │ not be saved.    │                  │
│               │                  │                  │
│               │  [ Keep Playing ]│  ← default focus │
│               │  [ Quit Run ]    │                  │
│               └──────────────────┘                  │
│                                                      │
└──────────────────────────────────────────────────────┘
```

**Godot implementation note:** The Pause Menu lives in a `CanvasLayer` node at a high z-index (above the HUD's CanvasLayer). The dim layer is a full-screen `ColorRect`. The card is a `Panel` or `NinePatchRect` centered via anchors. Both `CanvasLayer` and all its children must have `process_mode = PROCESS_MODE_ALWAYS` — without this, they freeze along with the game world and cannot respond to Resume/Quit input.

---

## States & Variants

| State / Variant | Trigger | What Changes |
|---|---|---|
| **Hidden** | Initial state; overlay not visible during gameplay | Dim layer and card not rendered; overlay `CanvasLayer` is hidden. Gameplay runs normally. |
| **Default** | `game_paused` signal received from `GameStateManager` | Dim layer fades in; card appears with "PAUSED" heading, Resume button (focused), Quit to Menu button. |
| **Quit Confirm** | Player activates "Quit to Menu" from Default state | Card contents replace in-place: heading changes to "Abandon this run? Progress will not be saved."; buttons become Keep Playing (focused) and Quit Run. Dim layer unchanged. |

**No loading state:** No data is fetched on overlay open. Appears instantly on `game_paused`.

**No error state:** No data-dependent elements. Resume calls `game_resumed`; Quit Run calls `run_ended(win: false)` — neither can fail at the UI layer.

**No empty state:** No data to be absent.

**Button focus states (IP-11):** Within each content state, keyboard/gamepad focus moves between the two buttons per IP-10 and IP-11. These are visual sub-states within Default and Quit Confirm, not separate overlay states.

**Initial focus on entry:**
- **Default state**: Resume button — most likely intent, zero Tab presses to act
- **Quit Confirm state**: Keep Playing button — safer default; prevents accidental run destruction

**Pause key behavior by state:**
- **Default** → Resume (dismiss overlay, restore `_previous_state`)
- **Quit Confirm** → Return to Default state (cancel confirmation, stay paused)
- Escape follows the same logic as the pause key for keyboard users

---

## Interaction Map

**Input context:** Keyboard/Mouse (primary), Gamepad (partial). All interactions must be reachable without mouse.

**Default state:**

| Component | Action | Mouse/Keyboard | Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **Resume button** | Activate | Left-click or Enter (focused) | South face button (focused) | IP-11 pressed state (0.97×, 0.08s) + UI confirm audio | Overlay hidden; `game_resumed` emitted; `_previous_state` restored |
| **Quit to Menu button** | Activate | Left-click or Enter (focused) | South face button (focused) | IP-11 pressed state (0.97×, 0.08s) + UI confirm audio | Card contents switch to Quit Confirm state; "Keep Playing" receives focus |
| **Focus navigation** | Move focus | Tab / Shift-Tab / Arrow Up-Down | D-pad Up / D-pad Down | IP-11 focused state on newly focused button; UI navigate audio | Focus cycles: Resume → Quit to Menu → Resume (wraps) |
| **Pause key / Escape** | Dismiss | Pause key or Escape (keyboard) | Gamepad pause button (same binding that opened overlay) | IP-11 pressed state on Resume (briefly) + UI confirm audio | Same as activating Resume button |

**Quit Confirm state:**

| Component | Action | Mouse/Keyboard | Gamepad | Immediate Feedback | Outcome |
|---|---|---|---|---|---|
| **Keep Playing button** | Activate | Left-click or Enter (focused) | South face button (focused) | IP-11 pressed state (0.97×, 0.08s) + UI back/cancel audio | Card contents switch back to Default state; Resume button receives focus |
| **Quit Run button** | Activate | Left-click or Enter (focused) | South face button (focused) | IP-11 pressed state (0.97×, 0.08s) + UI confirm audio | `run_ended(win: false)` emitted; overlay hidden; scene transitions to MAIN_MENU |
| **Focus navigation** | Move focus | Tab / Shift-Tab / Arrow Up-Down | D-pad Up / D-pad Down | IP-11 focused state on newly focused button; UI navigate audio | Focus cycles: Keep Playing → Quit Run → Keep Playing (wraps) |
| **Pause key / Escape** | Cancel confirm | Pause key or Escape (keyboard) | Gamepad pause button | IP-11 pressed state on Keep Playing + UI back/cancel audio | Same as activating Keep Playing — returns to Default state |

**Default focus on entry:**
- Default state: Resume button — zero Tab presses to resume
- Quit Confirm state: Keep Playing button — zero Tab presses to cancel

**Keyboard-only path to resume from anywhere:** Press pause → overlay appears (Resume focused) → press Enter. One keypress to open, one to close.

---

## Events Fired

| Player Action | Signal / Call | Payload | Notes |
|---|---|---|---|
| Resume activated (button or pause key) | `GameStateManager.resume_game()` | None | GS&SF internally restores `_previous_state` and emits `game_resumed`. Pause Menu does not emit signals directly. |
| Quit Run activated (in Quit Confirm state) | `GameStateManager.quit_to_menu()` | None | GS&SF emits `run_ended(win: false)` first, then transitions to `MAIN_MENU`. Signal ordering owned by GS&SF. |
| "Quit to Menu" button activated (Default state) | *(none — UI-internal)* | None | Transitions overlay to Quit Confirm state. No game event. |
| "Keep Playing" button activated (Quit Confirm state) | *(none — UI-internal)* | None | Returns overlay to Default state. No game event. |
| Focus navigated | *(none — UI-internal)* | None | UI navigate audio plays on UI bus. No game event. |
| Pause key / Escape (Default state) | `GameStateManager.resume_game()` | None | Identical to Resume button. |
| Pause key / Escape (Quit Confirm state) | *(none — UI-internal)* | None | Returns overlay to Default state. No game event — player is still paused. |

**No state-modifying writes on this screen.** The Pause Menu initiates transitions via GameStateManager API calls; it writes nothing to game state itself.

---

## Transitions & Animations

| Transition | Animation | Duration | Easing | Notes |
|---|---|---|---|---|
| **Overlay appear** (Hidden → Default) | Dim layer fades in (alpha 0→0.65) and card scales up simultaneously (0.9→1.0) | 0.2s | TRANS_CUBIC / EASE_OUT | Per IP Animation Standards (screen enter). Fast enough to feel instant; eased to avoid jarring pop. |
| **Overlay dismiss** (Default → Hidden, via Resume) | Dim layer fades out (0.65→0) and card fades out (alpha 1→0) simultaneously | 0.15s | TRANS_CUBIC / EASE_IN | Per IP Animation Standards (screen exit). Slightly faster than appear — dismissal feels responsive. |
| **Card content swap** (Default ↔ Quit Confirm) | Instant swap — no animation | — | — | Content changes in-place on the same frame. A cross-fade is VS polish; instant is correct for MVP. |
| **Quit to Main Menu transition** | Overlay fades out, then MAIN_MENU screen fades in | 0.15s overlay out + 0.5s scene fade | EASE_IN / EASE_OUT | SceneManager handles scene swap. Overlay dismisses first, then scene transition begins. |
| **Button focus state** | IP-11 highlight border, instant | Instant | None | Per IP Animation Standards: no easing on focus moves. |
| **Button pressed state** | IP-11 press (0.97× scale) | 0.08s | TRANS_LINEAR | Per IP Animation Standards: button press confirm. |

**Audio during pause:** UI bus (`PROCESS_MODE_ALWAYS`) plays normally — button and navigation audio work during pause. SFX bus (`PROCESS_MODE_PAUSABLE`) is silent — game-world audio stops. This is the correct Godot behavior per Audio System GDD.

**HUD during pause:** HUD is preserved underneath the overlay (per `hud.md` — `game_paused` leaves HUD unchanged). Any in-progress tweens (e.g., HP bar drain animations) continue playing under the dim — this is acceptable and expected behavior.

---

## Data Requirements

| Data | Source System | Read / Write | Notes |
|---|---|---|---|
| "PAUSED" heading label | Hardcoded constant | Read | Not localized — it's a state indicator, not narrative text. May be kept in English across locales as a UI keyword, or localized if locale list requires it. |
| Warning text ("Abandon this run? Progress will not be saved.") | Hardcoded constant | Read | Localizable — character count matters (see Localization section). |
| Button labels ("Resume", "Quit to Menu", "Keep Playing", "Quit Run") | Hardcoded constants | Read | Localizable. |

**No dynamic data displayed.** The Pause Menu does not show the player's HP, Prana arrangement, wave index, or any other game state. That information is visible through the dim overlay on the game world underneath — the HUD and game scene render normally, just frozen and dimmed.

**No writes.** All transitions are requested via `GameStateManager` method calls; the Pause Menu writes nothing.

---

## Accessibility

No formal accessibility tier committed (`design/accessibility-requirements.md` absent). Applying Art Bible §4.5 as baseline.

| Check | Status | Notes |
|---|---|---|
| Keyboard-only navigation | ✓ Covered | Resume receives focus on overlay appear. Tab cycles to Quit to Menu. Enter activates. Pause key / Escape dismisses. Zero mouse required. |
| Gamepad navigation | ✓ Covered | D-pad Up/Down cycles between 2 buttons in each state. South face button activates. Pause button dismisses (Default) or cancels confirm (Quit Confirm). No hover-only interactions. |
| Focus state (color-independent) | ✓ Covered | IP-11 focused state: highlight border + 1.03× scale — not color alone. |
| Text legibility — button labels | ✓ Covered | All labels short (≤ 12 chars English). Minimum 16px display at 1080p reference. Ages 7+ legibility met. |
| Text legibility — warning text | ✓ Covered | "Abandon this run? Progress will not be saved." — 44 chars, wraps over 2 lines in the ~240px card inner width. Must be validated at implementation that both lines are above minimum size. |
| Color-only information | ✓ None | No information conveyed by color alone. "Quit Run" is not color-distinguished from "Keep Playing" — distinction is position (Keep Playing is above), label text, and the confirmation heading. |
| Input capture while overlay is visible | ✓ Required | Unlike the lore/memory CanvasLayer overlays (which pass input through), the Pause Menu overlay must **intercept** all input while active. The game world must not receive any input events while the overlay is visible. Implement via `process_mode = PROCESS_MODE_ALWAYS` on the overlay and ensure its top-level `Control` node has `mouse_filter = MOUSE_FILTER_STOP`. |
| Motion sensitivity (overlay fade + scale) | ✓ Safe | 0.2s fade + 0.9→1.0 scale on appear. Well below any motion sensitivity threshold. |
| Screen reader | Known gap — deferred | Not supported at First Playable / MVP scope. |

**No new accessibility gaps** beyond those already acknowledged project-wide (screen reader, formal accessibility tier).

---

## Localization Considerations

| Text Element | English Length | 40% Expansion | Localization Risk |
|---|---|---|---|
| "PAUSED" (heading) | 6 chars | ~8 chars | **LOW** — very short; fits in all locales |
| "Resume" (button) | 6 chars | ~9 chars | **LOW** — short; 240px button has generous margin |
| "Quit to Menu" (button) | 12 chars | ~17 chars | **LOW** — fits in button at 40% expansion |
| "Abandon this run? Progress will not be saved." (warning) | 44 chars | ~62 chars | **HIGH** — English wraps to 2 lines at 240px inner width; 40% expansion could produce 3–4 lines. Card height must grow dynamically with text content, or warning text must use a smaller font size than button labels. Flag for localization engineering. |
| "Keep Playing" (button) | 12 chars | ~17 chars | **LOW** — fits in button |
| "Quit Run" (button) | 8 chars | ~11 chars | **LOW** — short in most languages |

**One HIGH PRIORITY localization risk:** The confirmation warning text. The Quit Confirm card must accommodate multi-line expansion without truncation or overflow. Recommended implementation: `Label` with `autowrap = true`, fixed card width, card height grows dynamically based on label content.

---

## Acceptance Criteria

Classification: **[U]** = Unit/integration test | **[M]** = Manual QA

---

**AC-PM-01 [U]** — Overlay appears within one frame of `game_paused`
GIVEN `GameStateManager` transitions to `PAUSED`
WHEN `game_paused` signal is emitted
THEN the Pause Menu `CanvasLayer` is visible (`visible == true`) within one process frame; the Resume button has keyboard focus (`has_focus() == true`)

**AC-PM-02 [M]** — Keyboard-only navigation cycles exactly 2 elements per state
GIVEN Pause Menu is open in Default state, no mouse input
WHEN player presses Tab repeatedly
THEN focus cycles: Resume → Quit to Menu → Resume (wraps). No other element receives focus.
GIVEN Pause Menu is in Quit Confirm state
WHEN player presses Tab
THEN focus cycles: Keep Playing → Quit Run → Keep Playing (wraps).

**AC-PM-03 [U]** — Resume restores previous state
GIVEN Pause Menu is open (paused from `PREPARATION_PHASE` or `COMBAT_PHASE`)
WHEN Resume button is activated (or pause key pressed in Default state)
THEN `game_resumed` is emitted exactly once; `GameStateManager.get_active_state()` returns the state that was active before pause; Pause Menu `CanvasLayer` is hidden

**AC-PM-04 [U]** — "Quit to Menu" opens confirmation — does NOT immediately quit
GIVEN Pause Menu is in Default state
WHEN "Quit to Menu" button is activated
THEN the card displays Quit Confirm content ("Abandon this run?"); `run_ended` is NOT emitted; `GameStateManager.get_active_state()` remains `PAUSED`

**AC-PM-05 [U]** — "Keep Playing" cancels confirmation without firing game events
GIVEN Pause Menu is in Quit Confirm state
WHEN "Keep Playing" button is activated
THEN card reverts to Default state content; `run_ended` is NOT emitted; `GameStateManager.get_active_state()` remains `PAUSED`; Resume button receives focus

**AC-PM-06 [U]** — "Quit Run" fires `run_ended(win: false)` and transitions to MAIN_MENU
GIVEN Pause Menu is in Quit Confirm state
WHEN "Quit Run" button is activated
THEN `run_ended(win: false)` is emitted exactly once; `GameStateManager.get_active_state()` returns `MAIN_MENU`; Pause Menu `CanvasLayer` is hidden

**AC-PM-07 [U]** — Pause input blocked from non-gameplay states
GIVEN `GameStateManager.get_active_state()` is `MAIN_MENU`, `RUN_SUMMARY`, or `DEATH_SCREEN`
WHEN pause input is triggered (keyboard or gamepad)
THEN `game_paused` signal is NOT emitted; active state is unchanged; Pause Menu overlay is NOT shown

**AC-PM-08 [M]** — Pause key / Escape behavior by overlay state
GIVEN Pause Menu is in Default state
WHEN player presses pause key or Escape
THEN overlay dismisses and game resumes (equivalent to Resume button)
GIVEN Pause Menu is in Quit Confirm state
WHEN player presses pause key or Escape
THEN card reverts to Default state; game remains paused

**AC-PM-09 [M]** — Game world visible and frozen under dim overlay
GIVEN Pause Menu is open in either state
THEN the game world is visible through the semi-transparent dim layer (not a fully opaque black screen); Fayde, enemies (if in COMBAT_PHASE), or Prana grid (if in PREPARATION_PHASE) are visible; no game-world entities are moving

**AC-PM-10 [M]** — Overlay fits at 1280×720
GIVEN Pause Menu is open at 1280×720 resolution
THEN the card is fully visible (not clipped); heading, both buttons, and all text are readable without overlap

---

## Open Questions

1. **Pause key binding not specified** — This spec references "pause input" throughout, but the exact binding (Escape? P key? Start/Menu button on gamepad?) is owned by the Input Map GDD, which has not been authored yet. Confirm bindings before implementation. *Owner: Input Map GDD (not yet created). Priority: before Pause Menu implementation.*

2. **`GameStateManager` public API method names** — This spec assumes `GameStateManager.resume_game()` and `GameStateManager.quit_to_menu()` exist as callable methods. The GS&SF GDD specifies the signal contract but not method names. Verify or define these method names before implementation. *Owner: GS&SF GDD revision or implementation decision.*

3. **CanvasLayer z-index ordering** — The Pause Menu CanvasLayer must render above the HUD CanvasLayer and below any debug or native OS overlays. Exact z-index values are not specified here. The implementer must coordinate with the HUD CanvasLayer z-index (defined in `hud.md`) and any lore/memory fragment overlay CanvasLayers to ensure correct rendering order. *Owner: Implementation decision.*

4. **VS scope — Settings and options** — At Vertical Slice, the Pause Menu (GDD #25) should add a Settings or Options section (audio volume, display settings, keybinding remapping). This spec is MVP-only. The VS GDD must reference this spec and extend it. *Owner: VS sprint planning / Pause Menu GDD #25.*

5. **Player journey map missing** — `design/player-journey.md` does not exist. The arrival context was designed from game concept, GS&SF GDD, and gameplay state context alone. *Owner: UX session.*
