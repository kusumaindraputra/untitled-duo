# Sprint 8 — 2026-07-15 to 2026-07-28

> **Stage**: Production — First Playable feel polish + bullet-hell prototype
> **Generated**: 2026-06-16
> **Review Mode**: lean

## Sprint Goal

Perkuat game feel (dash i-frame, arena bounds, enemy variety + shooter) untuk memvalidasi fun hypothesis pada external playtest.

## Capacity

- Total days: 14
- Buffer (20%): 3 days reserved
- Available: **11 days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S8-01 | Run `/qa-plan sprint` — Sprint 8 QA plan **(DAY 1 GATE — before any story work)** | 0.5 | None | `production/qa/qa-plan-sprint-8-*.md` exists before first story begins |
| S8-02 | Dash invincibility: pass-through enemy + blinking visual | 0.5 | None | Selama dash: player tembus musuh (collision_layer toggled); `modulate.a` berkedip; unit test covers i-frame toggle logic |
| S8-03 | Arena boundaries — invisible collision walls di IsometricRoom | 0.25 | None | Player tidak bisa keluar batas room; `StaticBody2D` walls di 4 sisi sesuai ukuran tile area |
| S8-04 | Enemy color per-archetype — `debug_color` field di `EnemyType` | 0.25 | None | Tiap archetype tampil warna berbeda: Seeker=merah, Rusher=oranye, Swarmer=kuning, Shooter=biru; warna di-apply via `modulate` dari catalog |
| S8-05 | Shooter enemy + Projectile system | 1.5 | S8-04 | Archetype `SHOOTER` baru di `GameEnums.EnemyArchetype`; enemy jaga jarak ≥150px dari player; tembak `Projectile` setiap 2s; `Projectile`: gerak lurus, `apply_damage` saat hit player, `queue_free` setelah habis range atau kena player |

**Must Have total: ~3.0 days**

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S8-06 | ADR-0013 live gamepad gate (carryover S7-02) | 0.5 | Gamepad fisik | 6 mandatory checks di `production/qa/evidence/prana-grid-gamepad-adr0013.md` terisi; verdict PASS atau FAIL |
| S8-07 | Re-validation playtest (carryover S7-10) | 1.0 | Non-developer tester | Playtest session terdokumentasi di `production/playtests/`; legibility verdict CONFIRMED atau STILL PARTIAL |

**Should Have total: 1.5 days** (Must Have + Should Have = 4.5d — sprint ringan, buffer besar)

---

## Carryover dari Sprint 7

| Task | Times Carried | Alasan | Sprint 8 Priority |
|------|---------------|--------|-------------------|
| ADR-0013 gamepad gate (S7-02) | 1 | Butuh gamepad fisik | Should Have (S8-06) |
| Re-validation playtest (S7-10) | 2 | Butuh non-developer tester | Should Have (S8-07) — jika carry ke S9: promosi ke Must Have |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Projectile system lebih kompleks dari estimasi | Medium | Medium | Scope ke 1 tipe saja (straight shot, no homing); complexity gate di S8-05 |
| Gamepad / non-dev tester tidak tersedia lagi | High | Low | Should Have — carry ke S9 boleh, tapi S7-10 sudah carry 2x; pertimbangkan skip jika tester tidak ada |
| Collision layer toggle dash merusak enemy contact detection | Low | Medium | Test coverage di S8-02 memastikan HitArea enemy tidak fire selama i-frame |

---

## Dependencies on External Factors

- S8-06 requires a physical gamepad
- S8-07 requires a non-developer tester

---

## Definition of Done for Sprint 8

- [ ] All Must Have stories implemented and closed via `/story-done`
- [ ] QA plan exists (`production/qa/qa-plan-sprint-8-*.md`) — created before first story
- [ ] Dash i-frame + blinking confirmed playable (manual test in Godot)
- [ ] Arena walls contain player — no escape possible
- [ ] Shooter enemy fires projectiles visibly; projectile despawns on hit or range
- [ ] Enemy color differentiation visible di-play
- [ ] All new unit/integration tests pass headless (GdUnit4)
- [ ] No S1 or S2 bugs in delivered features

---

> ⚠️ **QA Plan Required First**: Run `/qa-plan sprint` (S8-01) before starting any implementation story.
