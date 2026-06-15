# Test Count Delta — Sprint 4 to Sprint 6

**Investigated**: 2026-06-15 (S6-02)
**Verdict**: No tests are missing. Discrepancy is a runner scope difference.

## Numbers

| Scope | Command | Count |
|-------|---------|-------|
| Sprint 4 smoke check (full suite) | `-a res://tests/` | ~585 |
| Sprint 5 smoke check (unit-only) | `-a res://tests/unit` | 535 |
| Sprint 6 full suite run | `-a res://tests/` | **623** |
| Sprint 6 unit-only run | `-a res://tests/unit` | 535 |

## Root Cause

Sprint 5's smoke check used `-a res://tests/unit` (unit tests only).
Sprint 4 appears to have used `-a res://tests/` (full suite including integration tests).

The 88-test gap between unit-only (535) and full-suite (623) is integration tests in:
- `tests/integration/combination-resolution/`
- `tests/integration/enemy-instance/`
- `tests/integration/game-state-scene-flow/`
- `tests/integration/prana-grid/`
- `tests/integration/run-management/`
- `tests/integration/spell-casting-effects/`
- `tests/integration/status-effects/`
- `tests/integration/wave-encounter-system/`

## Resolution

No action required on test files — the suite is healthy and has grown from ~585 to 623.

**Going forward**: smoke checks MUST use `-a res://tests/` (full suite) to include integration tests.
The CI command in `coding-standards.md` already specifies this correctly. The Sprint 5 smoke check
command was the anomaly.
