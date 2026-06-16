# Sprint 7 — 2026-07-01 to 2026-07-14

> **Stage**: Production — Feature layer entry
> **Generated**: 2026-06-16
> **Review Mode**: lean

## Sprint Goal

Close the Feature-layer entry gates (GDD blockers, SpellVFX pooling, Audio System skeleton) and unblock sound integration for the first Feature-layer story.

## Capacity

- Total days: 14
- Buffer (20%): 3 days reserved (scene restructure + Audio System engine risk)
- Available: **11 days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S7-01 | Run `/qa-plan sprint` — Sprint 7 QA plan **(DAY 1 GATE — before any story work)** | 0.5 | None | `production/qa/qa-plan-sprint-7-*.md` exists before first story begins |
| S7-02 | ADR-0013 live gamepad gate — connect gamepad, fill `production/qa/evidence/prana-grid-gamepad-adr0013.md` (6 mandatory checks) | 0.5 | Gamepad available | Verdict PASS or FAIL documented; evidence file no longer blank |
| S7-03 | GDD Feature-layer gate — close GDD-B1 through GDD-B5 | 1.0 | None | `apply_status` 4-arg fix merged + all Status Effects tests pass; SC&E header resolved; Enemy Data PROVISIONAL removed; `STATUS_CHILL` + `STATUS_STAGGER` added to `GameEnums` |
| S7-04 | SpellVFX ADR-0015 — document pooling strategy, Autoload position, and layer assignment before any pooling code | 0.5 | None | `docs/architecture/adr-0015-spellvfx.md` written; pool count (5), Autoload position, `src/ui/` vs `src/systems/` layer call stated |
| S7-05 | SpellVFX particle pre-pool — fix PERF-C1; pre-pool 5 `GPUParticles2D` nodes at `_ready()`, one per Prana type | 1.5 | S7-04 | No `GPUParticles2D.new()` called per spell hit; pool reuse confirmed by test or profiler note |
| S7-06 | Audio System — `/create-stories audio-system` + implement AS-001 (Autoload #5), AS-002 (4-bus setup), AS-003 (`play_event()` stub) | 2.5 | S7-01 | `AudioSystem` registered at Autoload position 5; buses Master/Music/SFX/UI configured; `play_event(event_id: String)` exists and compiles; headless tests pass |

**Must Have total: ~6.5 days** (within 11-day available)

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S7-07 | SC&E ADR-0004 fix — replace `SceneTree.create_timer()` in `combination_resolution.gd` echo delay with float accumulator (AV-1) | 0.5 | None | `create_timer()` absent from `combination_resolution.gd`; echo delay uses `_physics_process` accumulator; all CR integration tests pass |
| S7-08 | ADR-0005 fix — move PranaGrid from root `PranaGridLayer` into `IsometricRoom.tscn` SubSceneContainer node (AV-4) | 1.0 | None | PranaGrid node lives under `IsometricRoom.tscn`; `main.tscn` no longer has standalone PranaGrid node; all 46 PranaGrid tests pass |
| S7-09 | WaveManager public signal fix — disconnect private `_on_all_waves_cleared` direct call; connect to public `all_waves_cleared` signal (AV-5) | 0.5 | None | No private GSM method reference in `wave_manager.gd`; signal connection verified in existing test or new smoke test |
| S7-10 | Re-validation playtest — verify Sprint 5 legibility fixes resolve PARTIALLY CONFIRMED verdict (carryover S6-07, 2nd carry) | 1.0 | Non-developer tester | Playtest session documented in `production/playtests/`; legibility verdict CONFIRMED or STILL PARTIAL |
| S7-11 | Tech debt constants migration — log and migrate 8 unlisted hardcoded constants from deep audit 1.7 | 1.0 | None | All 8 constants from audit table either tracked in `docs/tech-debt-register.md` or migrated to config resource |

**Should Have total: 4.0 days** (Must Have + Should Have = 10.5d — within 11d capacity)

### Nice to Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S7-12 | Isometric visual pass — binary decision AND action; a 4th deferral is not permitted | 2.0 | Art call | Either: art pass completed in sprint, OR story formally descoped to post-Feature-layer in sprint-status.yaml with rationale |
| S7-13 | `player_controller.is_alive()` fix — return real HP state instead of literal `true` (W-1 latent bug) | 0.5 | None | `is_alive()` returns `hp > 0`; unit test added confirming death-state returns false |
| S7-14 | ADR-0002 errata — document Godot 4.6 class_name constraint correction (AV-6) | 0.25 | None | Errata section added to `docs/architecture/adr-0002-autoload-architecture.md`; constraint reworded to match 4.6 reality |
| S7-15 | TR-PG-001 registry text fix — "Sprite2D cursor" → "Control overlay" to match ADR-0013 Decision | 0.25 | None | Tech debt registry updated; wording verified against ADR-0013 |
| S7-16 | SEM `duplicate()` optimization — remove per-tick array allocation from `_physics_process` (PERF-W1) | 0.5 | None | `.duplicate()` absent from `status_effects_manager.gd` `_physics_process`; comment or test confirms fix |

---

## Carryover from Sprint 6

| Task | Original Sprint | Times Carried | Reason | Sprint 7 Priority |
|------|----------------|---------------|--------|-------------------|
| Audio System skeleton (S6-06) | Sprint 6 (new) | 1 | Should Have not reached in session | **Must Have (S7-06)** — Feature layer sound blocked without it |
| Re-validation playtest (S6-07) | Sprint 6 (new) | 1 | Non-developer tester not available | **Should Have (S7-10)** — schedule tester at sprint start, not end |
| Isometric visual pass (S6-08) | S4-09 / S5-09 / S6-08 | **3** | Always Nice to Have, never actioned | **S7-12** — AC requires binary decision; "not done" is not acceptable |

---

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0013 gate not achievable (no gamepad in session) | Medium | Low | Document at sprint end; does not block other Must Have stories |
| S7-08 PranaGrid scene move triggers wiring regressions | Medium | Medium | Run full PranaGrid test suite after move; change is structurally small |
| GDD-B2 `apply_status` fix breaks existing Status Effects tests | Medium | Medium | Fix code signature and update tests together in same story |
| Audio System hits Godot 4.6 AudioServer API gaps | Low | Medium | Skeleton only — no SFX dispatch in this sprint; 4-bus setup is well-documented |
| Re-validation tester unavailable again (S7-10) | Medium | Low | Should Have; if deferred a 2nd time → promote to Must Have in Sprint 8 |
| Isometric visual pass deferred again (S7-12) | Low | Low | AC explicitly requires binary outcome — descope is a valid pass condition |

---

## Dependencies on External Factors

- S7-02 (ADR-0013 gate) requires a physical gamepad
- S7-10 (re-validation playtest) requires a non-developer tester

---

## Definition of Done for Sprint 7

- [ ] All Must Have stories implemented, code-reviewed, and closed via `/story-done`
- [ ] QA plan exists (`production/qa/qa-plan-sprint-7-*.md`) — created before first story
- [ ] GDD-B1 through GDD-B5 closed (Feature-layer gate unblocked)
- [ ] SpellVFX pre-pool committed — no per-hit `GPUParticles2D.new()`
- [ ] Audio System Autoload #5 registered and compiling
- [ ] ADR-0015 written and committed before S7-05 implementation begins
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations from GDD

---

> ⚠️ **QA Plan Required First**: Run `/qa-plan sprint` (S7-01) before starting any implementation story. This is Must Have — not optional.

> **Scope check:** Run `/scope-check audio-system` before S7-06 and `/scope-check spell-casting-effects` before S7-03 to confirm stories stay within GDD scope.
