# Smoke Check — Enemy Data Story 003

**Date**: 2026-05-30
**Story**: Story 003 — Four EnemyType .tres Data Files
**Tester**: Dev (solo)
**Engine**: Godot 4.6.2.stable

---

## ADR-0006 Verification Gate (Prerequisite AC)

**Reused from**: `production/qa/smoke-2026-05-30.md` (Prana Data Story 004)
**Verdict**: CONFIRMED — enum fields serialize as integers. Safe to author `.tres` files.

---

## Files Authored

| File | ID | Name | archetype | prana_affiliation | status |
|------|-----|------|-----------|-------------------|--------|
| `enemy_type_0.tres` | 0 | Drifter | SEEKER (0) | SHADOW (1) | ACTIVE (0) |
| `enemy_type_1.tres` | 1 | Charger | RUSHER (1) | FIRE (0) | ACTIVE (0) |
| `enemy_type_2.tres` | 2 | Cluster | SWARMER (2) | LIGHTNING (2) | ACTIVE (0) |
| `enemy_type_3.tres` | 3 | Warped Warden | BOSS (3) | NONE (-1) | VS_SCOPE (1) |

Location: `res://assets/data/enemy_types/`

---

## Catalog Startup Validation — AC-1

**Method**: Live Godot 4.6.2 editor run with all 4 .tres files in place.

- Zero `push_error()` calls from `EnemyCatalog._validate_all()` on startup: **PASS**
- `id` field matches expected values (0–3) for all 4 entries: **PASS**
- `name.is_empty()` == false for all 4 entries: **PASS**
- `archetype` valid enum value for all 4 entries: **PASS**

---

## Catalog Query Results — AC-2 through AC-7

- `EnemyCatalog.get_active_types()` returns exactly 3 entries (IDs 0, 1, 2): **PASS** (AC-ED-01)
- Exactly 1 entry with `status == VS_SCOPE` (ID 3 — Warped Warden): **PASS** (AC-ED-02)
- Names round-trip correctly: Drifter/Charger/Cluster/Warped Warden: **PASS** (AC-ED-04)
- `prana_affiliation` values correct: SHADOW(1)/FIRE(0)/LIGHTNING(2)/NONE(-1): **PASS** (AC-ED-05)
- `archetype` values correct: SEEKER(0)/RUSHER(1)/SWARMER(2)/BOSS(3): **PASS** (AC-ED-06)
- Warped Warden `wave_threat_value` is strictly null (not 0): **PASS** (AC-ED-09)
- Warped Warden `drop_prana_type` is strictly null: **PASS** (AC-ED-10)
- `sprite_size` values: 16×16/12×20/24×24/48×48: **PASS** (AC-ED-14)

---

## scene Field Status

All 4 entries have `scene = null`. `EnemyCatalog._validate_all()` does not treat null scene as a fatal error at MVP (documented in story implementation notes). Expected at this stage — enemy scene assets are authored in the Enemy AI epic.

---

## Smoke Check Verdict

**PASS** — All 4 `.tres` files authored with correct GDD values.
EnemyCatalog startup produces zero errors with all 4 files in place.
