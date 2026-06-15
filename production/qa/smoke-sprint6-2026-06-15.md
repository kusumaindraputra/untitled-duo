# Smoke Check Report
**Date**: 2026-06-15
**Sprint**: Sprint 6 — Post-First Playable housekeeping + PranaGrid gamepad
**Engine**: Godot 4.6
**QA Plan**: `production/qa/qa-plan-sprint-6-2026-06-15.md`
**Argument**: sprint

---

## Automated Tests

**Status**: PASS — 535 test cases | 534 passing | 1 skipped | 0 failures | 0 orphans | exit code 0 | 6.364s

Runner: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/unit --ignoreHeadlessMode`
Report: `reports/report_105/index.html`

---

## Test Coverage

| Story | Type | Test File / Evidence | Coverage Status |
|-------|------|----------------------|----------------|
| S6-01: Sprint 6 QA plan | Config/Data | `production/qa/qa-plan-sprint-6-2026-06-15.md` | EXPECTED |
| S6-02: Test count investigation | Logic | `production/qa/test-count-delta-s4-s6.md` + headless 535 unit / 623 full | COVERED |
| S6-03: Scene wiring rule | Config/Data | `.claude/docs/coding-standards.md` | EXPECTED |
| S6-04: Tech debt review | Config/Data | `docs/tech-debt-register.md` — 38 entries actioned | EXPECTED |
| S6-05: PranaGrid gamepad | UI | `production/qa/evidence/prana-grid-gamepad-adr0013.md` (exists, unchecked) | MANUAL ⚠ |

**Summary**: 1 covered, 1 manual (pending live gamepad gate), 3 expected, 0 missing.

---

## Manual Smoke Checks

Drawn from `tests/smoke/critical-paths.md`.

- [-] Game launches to main menu without crash — NOT TESTED this session
- [-] New run starts — Preparation Phase loads — NOT TESTED this session
- [-] Main menu responds to all inputs — NOT TESTED this session
- [-] PranaGrid: slot placement / Clear / Confirm (mouse path) — NOT TESTED this session
- [-] PranaGrid: grid locks during Combat Phase — NOT TESTED this session
- [-] Combination Resolution: single Prana type in slot 4 resolves without error — NOT TESTED this session
- [-] No visible frame rate drops during full combat wave — NOT TESTED this session
- [-] No push_error() accumulating in Output during 5 minutes of play — NOT TESTED this session
- [x] Save / load — N/A (save system not yet implemented)

**Developer confirmation required**: Run the game and confirm the above checks pass before treating this smoke check as fully cleared.

---

## Missing Test Evidence

No Logic or Integration stories have missing test files for completed Sprint 6 Must Have stories.

**Advisory**: `production/qa/evidence/prana-grid-gamepad-adr0013.md` exists but all 6 ADR-0013 mandatory checks are unchecked. Complete during a live gamepad session — only open evidence gate for Sprint 6.

---

## Verdict: PASS WITH WARNINGS

Automated test suite passes cleanly (534/535 passing, 1 skipped, exit code 0). Manual smoke checks could not be confirmed this session — developer was not at computer. Unconfirmed NOT TESTED is treated as PASS WITH WARNINGS per smoke-check protocol.

**Required before full QA clearance**:
1. Run game, confirm core stability (launch, new run, main menu)
2. Confirm PranaGrid mouse path and Combination Resolution still work
3. Connect gamepad and fill `production/qa/evidence/prana-grid-gamepad-adr0013.md` (ADR-0013 gate)
