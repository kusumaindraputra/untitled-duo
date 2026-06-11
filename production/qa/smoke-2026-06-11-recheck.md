# Smoke Check Report — Re-Check
**Date**: 2026-06-11
**Sprint**: Sprint 3 — First Playable Systems (2026-06-04 → 2026-06-17)
**Engine**: Godot 4.6
**QA Plan**: `production/qa/qa-plan-sprint-3-refresh-2026-06-10.md`
**Argument**: quick
**Supersedes**: `production/qa/smoke-2026-06-11.md`

---

## Automated Tests

**Status**: PASS — 539 tests | 0 errors | 0 failures | 1 skipped | **0 orphans** | exit 0

Two bugs fixed this session before this re-check:

| Commit | File | Fix |
|--------|------|-----|
| `fe14f3f` | `tests/integration/status-effects/sem_cleanup_integration_test.gd` | `MockEnemy extends Node` → `extends Node2D` — was causing runtime error on `global_position` access |
| `629fca5` | `tests/unit/prana-data/prana_tres_data_test.gd` | Added `auto_free(catalog)` in `_load_catalog_from_disk()` helper — 27/28 tests were leaking catalog Node orphans |

---

## Test Coverage

SKIPPED — quick mode. See `smoke-2026-06-11.md` for full coverage table (12 covered, 1 missing advisory).

---

## Manual Smoke Checks

- [x] Game launches without crash — PASS (Godot F5, no crash, CombatHUD renders)
- [x] CombatHUD visible (HP bar "100 / 100") — PASS
- [-] New game / start session — NOT TESTABLE (no game loop entry point yet)
- [-] Sprint mechanics (CR pipeline, WaveManager, SpellCasting) — NOT TESTABLE manually (verified via automated tests)
- [-] Save / load — SKIPPED (quick mode)
- [-] Performance — SKIPPED (quick mode)

---

## Missing Test Evidence

- **CH-004: Chain Dots** — `production/qa/evidence/combat-hud-chain-evidence.md` still missing.
  Advisory — must be created during a live game session before S3-11 playtest.

---

## Verdict: PASS WITH WARNINGS

- Automated tests: 0 failures, 0 orphans, exit 0 ✓
- Core stability: game launches, CombatHUD renders ✓
- No Batch 1 or Batch 2 critical failures

**Advisory to resolve before S3-11 playtest:**
- CH-004 evidence file missing — create `production/qa/evidence/combat-hud-chain-evidence.md`
  and record AC-HUD-26 (chain dot animation) during a live game session.
