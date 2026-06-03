# ADR-0013 Verification — PranaGrid Dual-Input Focus Model

**Hypothesis**: The three-path input model (mouse, gamepad d-pad cursor, keyboard Tab) from ADR-0013 works
in Godot 4.6 without cross-interference. All four verification tests must PASS before PranaGrid (S3-17) can be implemented.

**Status**: PENDING — run in Godot 4.6 and record results below.

---

## How to Run

1. Open the main project (`D:\Proj\the-last-cipher`) in Godot 4.6.
2. Create a new scene: **Scene → New Scene → Other Node → Node** (plain `Node` root, not Node2D).
3. Attach `dual_input_verify.gd` to the root Node.
4. Save as `res://prototypes/adr-0013-verification/DualInputVerify.tscn`.
5. Run the scene with **F6** (Run Current Scene) or right-click → Run.

The scene shows a 3×3 grid of numbered slots and a **gold border cursor overlay** (yellow ring).
A status bar at the bottom shows current input mode, `_selected_slot_index`, and `cursor_visible`.
The Output panel in Godot prints all index changes and focus events.

---

## Test Protocol

### Test 1 — Gamepad d-pad navigation moves cursor; does not grab_focus()

**Setup**: Connect a gamepad (any joystick/controller). Run the scene.

**Action**: Press d-pad right, left, up, down in sequence.

**PASS criteria**:
- The gold border cursor visibly moves between slots following d-pad direction.
- `_selected_slot_index` changes correctly (printed in Output panel and shown in status bar).
- d-pad wraps correctly: right from column 2 → column 0 (same row); down from row 2 → row 0 (same column).
- The engine's built-in focus highlight (blue outline or theme style) does NOT appear on any slot during d-pad navigation.
- `grab_focus()` is NOT called — verify by checking that no slot shows a focus ring unless you pressed Tab.

**FAIL criteria**: Gold cursor doesn't move; OR engine focus outline appears on slot nodes during d-pad input.

**Result**: [ ] PASS  [ ] FAIL  [ ] NOT TESTED (no gamepad available)

Notes: ________________________________________________________________

---

### Test 2 — Mouse hover does NOT change `_selected_slot_index`

**Setup**: Switch to mouse input (move mouse). The status bar should show `Mode: MOUSE/KB` and `cursor_visible: false`.

**Action**: Hover the mouse over several different slots.

**PASS criteria**:
- `_selected_slot_index` in the status bar does NOT change as you hover.
- The gold cursor overlay is NOT visible.
- The Output panel does NOT print any d-pad index change lines.
- Slots may show mouse hover effects (built-in theme hover state) — that is correct and expected.

**FAIL criteria**: `_selected_slot_index` changes when hovering with mouse.

**Result**: [ ] PASS  [ ] FAIL

Notes: ________________________________________________________________

---

### Test 3 — Keyboard Tab navigation moves engine focus; does NOT move cursor

**Setup**: Click anywhere on the scene window to give it keyboard focus. Press Tab.

**Action**: Press Tab repeatedly to cycle keyboard focus through all 9 slots.

**PASS criteria**:
- Engine focus indicator moves from slot to slot on each Tab press.
- Focused slots highlight in cyan (`_on_slot_focus_entered` callback fires — label turns cyan).
- `_selected_slot_index` in the status bar does NOT change.
- The gold cursor overlay does NOT move.
- The Output panel prints `KB focus: slot N (cursor=M)` where N ≠ M most of the time (cursor stays put).

**FAIL criteria**: Tab key causes `_selected_slot_index` to change; OR cursor moves.

**Result**: [ ] PASS  [ ] FAIL

Notes: ________________________________________________________________

---

### Test 4 — Switching gamepad → mouse hides cursor automatically

**Setup**: Start in gamepad mode (press d-pad once). Confirm `Mode: GAMEPAD` and gold cursor is visible.

**Action**: Move the mouse.

**PASS criteria**:
- On the first mouse movement, `cursor_visible` switches to `false`.
- The gold border cursor disappears immediately.
- Status bar shows `Mode: MOUSE/KB`.
- Output panel prints `MODE → MOUSE (cursor hidden)`.

**FAIL criteria**: Gold cursor remains visible after switching to mouse; OR a delay before it disappears.

**Result**: [ ] PASS  [ ] FAIL  [ ] NOT TESTED (no gamepad available)

Notes: ________________________________________________________________

---

## Verdict

| Test | Result |
|------|--------|
| Test 1 — Gamepad d-pad navigation | [ ] PASS / [ ] FAIL / [ ] NOT TESTED |
| Test 2 — Mouse hover no index change | [ ] PASS / [ ] FAIL |
| Test 3 — Tab navigation no cursor move | [ ] PASS / [ ] FAIL |
| Test 4 — Gamepad→mouse cursor hide | [ ] PASS / [ ] FAIL / [ ] NOT TESTED |

### Overall verdict: [ ] SAFE — PranaGrid (S3-17) may proceed  / [ ] UNSAFE — use keyboard-shortcut fallback

If SAFE: Update `docs/architecture/adr-0013-prana-grid-dual-input-focus-model.md`
Verification Required field to `VERIFIED [date] — all 4 tests PASSED`.

If UNSAFE (any test fails): Document the specific failure. PranaGrid (S3-17) moves to post-FP backlog.
The keyboard-shortcut fallback (one key per Prana type, 5 key bindings) becomes the FP arrangement path.
Update ADR-0013 Verification Required field with failure details and the fallback decision.

---

## Notes on Test 1 / Test 4 Without a Gamepad

If no physical gamepad is available:
- Tests 1 and 4 can be simulated using Godot's Input Map remapping:
  **Project → Project Settings → Input Map**. Add a temporary `joypad_dpad_right` action mapped to a keyboard key,
  then trigger it in the test.
- Alternatively, use the Godot Input Debugger plugin or a virtual gamepad tool.
- If neither is available, mark Tests 1 and 4 as NOT TESTED and note it. S3-17 (PranaGrid) will remain
  blocked until gamepad testing is completed — PranaGrid's gamepad path is a first-class requirement.

---

*Prototype created: 2026-06-03 | ADR: docs/architecture/adr-0013-prana-grid-dual-input-focus-model.md*
*Sprint task: S3-02 | Blocks: S3-17 (PranaGrid implementation)*
