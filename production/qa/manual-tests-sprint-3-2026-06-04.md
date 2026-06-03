# Manual Tests — Sprint 3
**Date**: 2026-06-04
**Tester**: Kusuma Putra

---

## 1. ADR-0013 Dual-Input Verification
> **When to run**: NOW — blocks PranaGrid (S3-17) decision
> **Verdict needed**: SAFE = PranaGrid in-scope this sprint | UNSAFE = PranaGrid deferred

**Setup**:
1. Open project in Godot 4.6
2. Scene > New Scene > Other Node > Node (plain Node root)
3. Attach `res://prototypes/adr-0013-verification/dual_input_verify.gd`
4. Save as `res://prototypes/adr-0013-verification/DualInputVerify.tscn`
5. Run with F6

---

### T1 — Gamepad d-pad moves cursor; does NOT trigger engine focus ring
- [ ] Gold border cursor moves when d-pad pressed
- [ ] `_selected_slot_index` printed in Output changes correctly
- [ ] d-pad wraps: right from col 2 → col 0 same row
- [ ] Engine focus ring (blue outline) does NOT appear on slots during d-pad input

**Notes**: _______________________________________________________________

---

### T2 — Mouse hover does NOT change `_selected_slot_index`
- [ ] Status bar `_selected_slot_index` stays unchanged while hovering different slots
- [ ] Gold cursor NOT visible
- [ ] Output does NOT print index change lines during hover

**Notes**: _______________________________________________________________

---

### T3 — Tab key moves engine focus; does NOT move gold cursor
- [ ] Tab/arrow cycles keyboard focus slot-to-slot (label turns cyan)
- [ ] Gold cursor does NOT move
- [ ] Status bar `_selected_slot_index` does NOT change

**Notes**: _______________________________________________________________

---

### T4 — Switching gamepad → mouse hides cursor immediately
- [ ] Start in gamepad mode (press d-pad once; cursor visible)
- [ ] Move mouse → cursor disappears immediately
- [ ] Status bar shows `Mode: MOUSE/KB`

**Notes**: _______________________________________________________________

---

### Overall Verdict

- [ ] **SAFE** — all 4 tests passed → PranaGrid (S3-17) proceeds
- [ ] **UNSAFE** — one or more tests failed → PranaGrid deferred, keyboard fallback confirmed

> ⚠ No gamepad? Remap a keyboard key in Project Settings → Input Map → add action `ui_accept_gamepad` mapped to a key, note it here.

**Gamepad available**: [ ] Yes  [ ] No — used key: _______________

---

---

## 2. ADR-0011 Parser Check
> **When to run**: Before implementing StatusEffects Story 001 (S3-05)
> **Blocks**: S3-05 Story 001

**Setup**: Open any `.gd` file in Godot script editor. Type the line below and check for errors.

```gdscript
var _test: Dictionary[int, Array] = {}
```

- [ ] No red underline / no "invalid syntax" in Godot script editor
- [ ] Typed Dictionary syntax accepted by Godot 4.6 parser

**Notes**: _______________________________________________________________

---

---

## 3. GameEnums BaseStatus — CHILL and STAGGER entries
> **When to run**: Before implementing StatusEffects Story 003 (stubs)
> **Blocks**: S3-05 Story 003

**Setup**: Open `src/core/game_enums.gd`, find `enum BaseStatus`.

- [ ] `CHILL` entry exists with explicit integer value (e.g. `CHILL = 5`)
- [ ] `STAGGER` entry exists with explicit integer value (e.g. `STAGGER = 6`)

If missing — add them before Story 003. Values must be appended (never renumber existing entries).

**Current values found**: _______________________________________________________________

---

---

## 4. SpellCastingEffects — Ray Targeting (AC-SC-07)
> **When to run**: After S3-08 SpellCastingEffects is implemented
> **Type**: Physics — requires running scene

**Setup**: Place in a test scene:
- Fayde at `(100, 100)` facing right (+X)
- Enemy A at `(180, 100)` — 80px away
- Enemy B at `(230, 100)` — 130px away
- `CAST_MAX_RANGE = 150px`
- Cast a Voidblue T1 spell

- [ ] Enemy A takes damage
- [ ] Enemy B takes NO damage
- [ ] Only one `apply_damage` call in Output

**Notes**: _______________________________________________________________

---

## 5. SpellCastingEffects — Ashfire T3 AoE Origin (AC-SC-09)
> **When to run**: After S3-08 SpellCastingEffects is implemented
> **Type**: Physics — requires running scene

**Setup**: Place in a test scene:
- Fayde at `(200, 200)`
- Enemy A at `(240, 200)` — 40px from Fayde (inside 80px radius)
- Enemy B at `(320, 200)` — 120px from Fayde (outside 80px radius)
- Cast Ashfire T3 (third attack in chain)

- [ ] Enemy A takes damage
- [ ] Enemy B takes NO damage (confirms AoE is Fayde-centred, not target-centred)

**Notes**: _______________________________________________________________

---

---

## 6. CombatHUD — HP Bar Animation (AC-HUD-02b)
> **When to run**: After S3-09 CombatHUD is implemented

- [ ] Take damage in a live scene — HP bar visibly animates (smooth drain, no snap)

**Notes**: _______________________________________________________________

---

## 7. CombatHUD — DESPERATE Zone Pulse (AC-HUD-24 + AC-HUD-25)
> **When to run**: After S3-09 CombatHUD is implemented

- [ ] Drop Fayde HP below 20 → bar pulses (scale 1.0 → 1.03 → 1.0, visible loop)
- [ ] Heal back above 20 → pulse stops immediately, bar returns to normal scale

**Notes**: _______________________________________________________________

---

## 8. CombatHUD — Damage Label Float (AC-HUD-26)
> **When to run**: After S3-09 CombatHUD is implemented

- [ ] Hit an enemy → damage number appears over enemy
- [ ] Number rises ~32px from spawn position over 0.8s
- [ ] Number fades out and disappears (label freed after animation)

**Notes**: _______________________________________________________________

---

---

## 9. RunManager AutoLoad Wiring (AC-RM-14)
> **When to run**: After S3-10 RunManager is implemented

**Setup**: Project Settings → AutoLoad — confirm order.

- [ ] `GameStateManager` is listed BEFORE `RunManager`
- [ ] Start the game — no signal-connection errors in Godot Output panel

**Notes**: _______________________________________________________________

---

---

## 10. First Playable Internal Playtest (S3-11)
> **When to run**: After ALL Must Have stories (S3-05 through S3-10) are complete
> **Blocks**: First Playable milestone sign-off

Play a full run from launch to result screen.

### Setup
- [ ] All Must Have stories implemented and smoke check passed

### Gameplay Checklist
- [ ] Game launches without crash
- [ ] New run starts — Preparation Phase loads, Prana Grid visible and editable
- [ ] Prana tokens can be placed and rearranged; confirm button works
- [ ] Combat starts: 10 enemies spawn simultaneously
- [ ] Enemies move toward Fayde (Drifters steady, Charger slow approach, Clusters swarm)
- [ ] Cast fires and deals damage — damage number appears on CombatHUD
- [ ] At least one 2× elemental affiliation hit visible (different colour on damage number)
- [ ] HP bar updates when Fayde takes contact damage
- [ ] HP zone shifts amber at ≤40 HP, red at ≤20 HP
- [ ] Burn or Freeze visual indicator appears on enemies after hit
- [ ] Run ends when last enemy dies — result screen shown, no softlock
- [ ] Win path: result screen allows starting a new run
- [ ] Death path: Fayde dies → death screen shown, no softlock
- [ ] No crash or error in Godot Output during the session

### Fun Hypothesis

> Does arranging the Prana grid in Preparation Phase create a meaningful advantage in Combat Phase?

- [ ] **CONFIRMED** — arrangement felt purposeful; elemental matchup created visible advantage
- [ ] **FALSIFIED** — combat did not reward the prep decision

**What worked**: _______________________________________________________________

**What didn't work**: ___________________________________________________________

**Fun hypothesis notes**: ________________________________________________________

---

*Write full playtest notes to `production/playtests/playtest-sprint3-fp-[date].md` before marking S3-11 Done.*
