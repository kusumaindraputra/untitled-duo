# Sprint 9 — 2026-07-29 to 2026-08-11

> **Stage**: Production — Feature layer implementation (Status Effects + Spell Casting)
> **Generated**: 2026-06-17
> **Review Mode**: lean

## Sprint Goal

Close the two human-gated carryovers (gamepad + playtest), confirm Sprint 8 game feel in Godot, and begin implementing the Feature layer: StatusEffectsManager skeleton and SpellEffect resource as the foundation for all combat mechanics.

## Capacity

- Total days: 14
- Buffer (20%): 3 days reserved
- Available: **11 days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S9-01 | **Manual validation in Godot — Sprint 8 DoD gate** (task 0 — no new stories begin until this passes) | 0.5 | Godot open | Dash blink visual confirmed; arena walls contain player; enemy colors differentiated; Rifter fires + projectile despawns on hit/range |
| S9-02 | **ADR-0013 live gamepad gate** (3rd carry — HARD DEADLINE) | 0.5 | Physical gamepad | 6 mandatory checks in `production/qa/evidence/prana-grid-gamepad-adr0013.md` filled; verdict PASS or FAIL documented; if no gamepad → binary decision: acquire OR close ADR-0013 as "theoretical only" |
| S9-03 | **Re-validation playtest** (3rd carry — HARD DEADLINE) | 1.0 | Non-developer tester | Playtest session documented in `production/playtests/`; legibility verdict CONFIRMED or STILL PARTIAL; if no tester → formal descope note in playtest register |
| S9-04 | **SEM-001**: StatusEffectsManager skeleton + Burn DoT | 1.5 | None | Autoload #7 registers; `apply_status(enemy, BURN, 2.0, 20.0)` creates one StatusInstance; tick fires at 0.5s with 1.6 damage; expiry removes instance; re-apply refreshes; dead/player/zero-duration guards; unit tests AC-SE-01/02/03/04/09/11/20 pass |
| S9-05 | **SCE-001**: SpellEffect resource skeleton + state machine | 1.0 | None | `SpellEffect` resource exists; SCE Autoload #9 registers; IDLE → READY on `combo_resolved`; `preparation_started` resets state; invalid primary_type guard; unit tests AC-SC-01/06/24 pass |

**Must Have total: ~4.5 days**

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S9-06 | **SEM-002**: Freeze + Regen effects | 1.0 | S9-04 | `apply_status(enemy, FREEZE, ...)` slows movement speed to 0; `apply_status(fayde, REGEN, ...)` calls H&D.apply_heal() at tick; all SEM-002 ACs pass |
| S9-07 | **SEM-003**: Stub effects — Blind, Stun, Chill, Stagger | 1.0 | S9-04 | All 4 stubs apply without crash; placeholder effect logged; ACs pass; ready for full impl in later sprint |
| S9-08 | **SCE-002**: Cast chain timing + input loop | 1.5 | S9-05 | `_process()` accumulates delta; cast input in READY state fires chain; `chain_index_changed` emits; `cast_hit_started` emits; float accumulator pattern (no Timer nodes); unit tests pass |

**Should Have total: 3.5 days (Must Have + Should Have = 8.0d — within 11d capacity)**

### Nice to Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S9-09 | **SEM-004**: Kill cleanup + phase clear | 1.0 | S9-04 | `enemy_killed` signal clears all instances for that target; `preparation_started` clears all active statuses; integration test with SEM + H&D |
| S9-10 | **SCE-003**: FP damage formula + targeting | 2.0 | S9-05, S9-04 | `intersect_ray()` hits primary target; damage formula applied via H&D; `apply_status` called via SEM; `spell_hit_element` emitted; unit tests AC-SC formula ACs pass |

---

## Carryover from Sprint 8

| Task | Times Carried | Reason | Sprint 9 Priority |
|------|---------------|--------|-------------------|
| ADR-0013 live gamepad gate (S7-02 → S8-06) | **3** | No physical gamepad in any session | **Must Have — hard deadline. No 4th carry.** |
| Re-validation playtest (S6-07 → S7-10 → S8-07) | **3** | Non-developer tester not available | **Must Have — hard deadline. No 4th carry.** |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Gamepad still unavailable | High | Low | Do the binary decision (acquire / close gate) during S9-01 session; no more deferral |
| Playtest tester still not booked | Medium | Medium | Book before sprint starts, not during. Unavailability → descope + formal note |
| SEM ↔ SCE coupling causes test ordering issues | Low | Low | SEM-001 and SCE-001 are skeletons; no cross-calls until SCE-003. Test each in isolation |
| Manual validation reveals a visual bug in S8 features | Low | Medium | Reserve debug time from buffer; fix before starting S9-04 |

---

## Dependencies on External Factors

- S9-01 requires Godot editor open (local session)
- S9-02 requires a physical gamepad
- S9-03 requires a non-developer tester

---

## Definition of Done for Sprint 9

- [ ] S9-01: Manual validation complete — all S8 visual features confirmed in Godot
- [ ] S9-02: ADR-0013 gate filled OR formally closed (no more "evidence file blank")
- [ ] S9-03: Playtest documented OR formally descoped — no 4th carry
- [ ] S9-04 + S9-05: SEM-001 and SCE-001 unit tests passing headless
- [ ] All new Logic/Integration stories have passing unit tests
- [ ] No S1 or S2 bugs in delivered features
- [ ] `sprint-status.yaml` updated after every story close (lesson from S8-01 gap)

---

> ⚠️ **No QA Plan yet**: Run `/qa-plan sprint` before starting S9-04. S9-01/02/03 can begin immediately — they are validation tasks, not new implementation.
