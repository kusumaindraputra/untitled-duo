# Sprint 6 — 2026-06-16 to 2026-06-30

> **Stage**: Production — Post-First Playable, Feature layer entry
> **Generated**: 2026-06-15
> **Review Mode**: lean

## Sprint Goal

Close out post-First Playable housekeeping (test count integrity, tech debt, scene wiring documentation), complete the PranaGrid epic with gamepad input, and begin Audio System to unblock sound for the Feature layer.

## Capacity

- Total days: 14
- Buffer (20%): 3 days reserved (S6-05 ADR-0013 HIGH risk absorbs this)
- Available: **11 days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S6-01 | Run `/qa-plan sprint` — Sprint 6 QA plan **(DAY 1 GATE — before any story work)** | 0.5 | None | `production/qa/qa-plan-sprint-6-*.md` exists before first story begins |
| S6-02 | Investigate + restore missing tests — find what 50 tests went missing between Sprint 4 (585) and Sprint 5 (535) | 0.5 | None | Test count ≥ 585 again OR discrepancy documented with a rationale that it is intentional |
| S6-03 | Document Godot 4 scene wiring rule in `.claude/docs/coding-standards.md` | 0.25 | None | Rule present: cross-sibling `@export Node` references must be wired in parent `_ready()`, not via NodePath override in `.tscn`; committed |
| S6-04 | Tech debt review pass — close or formally accept open entries (carryover S5-08, originally S4-08) | 0.5 | None | Run `/tech-debt`; every entry marked RESOLVED, ACCEPTED, or SCHEDULED; register updated with today's date |
| S6-05 | PranaGrid gamepad input (carryover S5-07, originally S4-07) — ADR-0013 HIGH risk path | 2.5 | S5-04 ✓ done | D-pad slot navigation; type-cycle control; Place + Clear actions; Confirm via gamepad; ADR-0013 gamepad path validated manually independent of mouse path |

**Must Have total: ~4.25 days** *(well within 11-day available — buffer reserved for S6-05 engine risk)*

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S6-06 | Audio System — create stories + implement skeleton (4-bus architecture, Autoload #5 registration) | 2.5 | S6-01 | `/create-stories audio-system` run; skeleton story done; AudioSystem at Autoload position 5; 4 buses (Master, Music, SFX, UI) configured; `play_event()` stub compiles; headless tests pass |
| S6-07 | Re-validation playtest — verify Sprint 5 legibility fixes resolve the PARTIALLY CONFIRMED verdict | 1.0 | S5-03–S5-06 ✓ done | ≥1 session with non-developer tester; legibility verdict (CONFIRMED / STILL PARTIAL) documented in `production/playtests/` |

**Should Have total: 3.5 days** *(Must Have + Should Have = 7.75d — within 11d capacity)*

### Nice to Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S6-08 | Isometric visual pass — player/enemy placeholder art + lighting tweak (carryover S5-09, originally S4-09) | 2.0 | None | Player and enemies visually distinguishable from floor tiles; improves re-validation playtest quality |
| S6-09 | Audio System SFX pool + event dispatch (only if S6-06 done) | 2.0 | S6-06 | 24-node SFX pool implemented; `play_event()` routes by bus; priority eviction test passes headless |

**Nice to Have total: 4.0 days — begin only if Must Have + Should Have complete and buffer not consumed**

## Carryover from Sprint 5

| Task | Original Sprint | Times Carried | Reason | Sprint 6 Priority |
|------|----------------|---------------|--------|-------------------|
| S5-07: PranaGrid gamepad input | S4-07 | 2 | Crowded out by playtest legibility fixes; ADR-0013 HIGH risk | **Must Have (S6-05)** — 2 deferrals is the limit |
| S5-08: Tech debt review | S4-08 (S3 action item) | 2+ | Always below the sprint line | **Must Have (S6-04)** — 3 sprints is too long |
| S5-09: Isometric visual pass | S4-09 | 2 | Art/asset work, non-critical path | Nice to Have (S6-08) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0013 gamepad path hits unforeseen Godot 4.6 API issue (S6-05) | Medium | Medium | 3-day buffer reserved; if overruns badly, can slip S6-06 |
| Test count discrepancy is deeper than a missing file (S6-02) | Low | Medium | Timebox to 0.5d; if cause not found, document as open and escalate to tech debt register |
| Re-validation playtest tester availability (S6-07) | Medium | Low | Should Have — does not block Must Have delivery; schedule early in sprint |
| Audio System story creation reveals scope larger than estimated (S6-06) | Low | Low | S6-06 covers skeleton only; full SFX/music implementation is S6-09 (Nice to Have) and Sprint 7 |

## Dependencies on External Factors

- S6-07 (re-validation playtest) requires a non-developer tester available during the sprint window
- S6-08 (isometric visual pass) requires placeholder art decisions — no external asset dependency at this scope (code-driven sprites/colors acceptable)

## Definition of Done for Sprint 6

- [ ] All Must Have stories implemented, code-reviewed, and closed via `/story-done`
- [ ] QA plan exists (`production/qa/qa-plan-sprint-6-*.md`) — created before first story
- [ ] Test suite count restored to ≥ 585 or discrepancy formally documented
- [ ] Godot 4 scene wiring rule committed to `.claude/docs/coding-standards.md`
- [ ] Tech debt register reviewed — all entries dated and actioned
- [ ] PranaGrid gamepad path manually validated (ADR-0013 gamepad arc complete)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations from GDD

---

> ⚠️ **QA Plan Required First**: Run `/qa-plan sprint` (S6-01) before starting any implementation story. This is Must Have — not optional.

> **Scope check:** Run `/scope-check prana-grid` before S6-05 implementation and `/scope-check audio-system` before S6-06 to confirm stories stay within GDD scope.
