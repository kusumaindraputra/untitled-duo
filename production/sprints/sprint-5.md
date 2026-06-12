# Sprint 5 — 2026-06-26 to 2026-07-10

> **Stage**: Production — Post-First Playable, legibility pass before Feature layer expansion
> **Generated**: 2026-06-12
> **Review Mode**: lean

## Sprint Goal

Address the playtest-identified legibility failures from Sprint 4 — Prana visual differentiation, PranaGrid compact mode, dash feedback, and chain dot repositioning — to reinforce the PARTIALLY CONFIRMED fun hypothesis and establish the visual language before Feature layer epics begin.

## Capacity

- Total days: 14
- Buffer (20%): 3 days reserved
- Available: **11 days**

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S5-01 | Run `/qa-plan sprint` — Sprint 5 QA plan **(DAY 1 GATE — before any story work)** | 0.5 | None | `production/qa/qa-plan-sprint-5-*.md` exists before first story begins |
| S5-02 | Create sprint 5 stories — legibility pass items across epics (spell-casting-effects, prana-grid, combat-hud) | 0.5 | S5-01 | Story files created; each passes `/story-readiness` before implementation begins |
| S5-03 | Prana visual differentiation per type — SC&E emits type-specific visual on each hit (Ashfire: thrust/flame; Voidblue: reach/spiral; Stormgold: snap/lightning; Deepfrost: push/crystal; Verdant: bloom/vine) | 2.5 | S5-02 | Each of 5 Prana types has a visually distinct cast + hit effect; tester can name which type just fired without prompting; all effects are code-driven particles (no art-asset dependency at FP scope) |
| S5-04 | PranaGrid compact mode in combat — full panel during ARRANGEMENT, compact 3×3 indicator in bottom-right during LOCKED/HIDDEN | 1.5 | S5-02 | Full-size panel visible during Preparation; compact mode active on `combat_started`; does not overlap HP bar; transition is clean |
| S5-05 | Dash discoverability + cooldown indicator in CombatHUD | 1.0 | S5-02 | Keybinding hint visible during combat; cooldown depleted vs. ready state visually distinct; tester can identify when dash is available without asking |
| S5-06 | Chain dots repositioned above player character (CH-004, deferred ×3) | 0.75 | S5-02 | Dots rendered above Fayde in screen-space; no longer top-left corner; tester notices chain dots without being directed to them |

**Must Have total: 6.75 days**

### Should Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S5-07 | PranaGrid gamepad input (carryover S4-07) — ADR-0013 HIGH risk path | 2.5 | S5-04 | D-pad slot navigation; type-cycle control; Place + Clear actions; Confirm via gamepad; ADR-0013 gamepad path manually validated independently from mouse path |
| S5-08 | Tech debt review pass — close or formally accept open entries (carryover S4-08) | 0.5 | None | Run `/tech-debt`; each entry marked RESOLVED, ACCEPTED, or SCHEDULED; register updated |

**Should Have total: 3.0 days**

### Nice to Have

| ID | Task | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-----------|--------------|---------------------|
| S5-09 | Isometric visual pass — player/enemy placeholder art + lighting tweak (carryover S4-09) | 2.0 | None | Player and enemies visually distinguishable from floor tiles; improves re-validation playtest quality |

**Nice to Have total: 2.0 days — begin only if Must Have + Should Have complete and buffer not consumed**

## Carryover from Sprint 4

| Task | Original Sprint | Reason | Sprint 5 Priority |
|------|----------------|--------|-------------------|
| S4-07: PranaGrid gamepad input | Sprint 4 Should Have | Time constraint; mouse-first ADR-0013 path absorbed the sprint | Should Have (S5-07) |
| S4-08: Tech debt review pass | Sprint 4 Should Have | Deprioritized for playtest delivery | Should Have (S5-08) |
| S4-09: Isometric visual pass | Sprint 4 Nice to Have | Not started; time constraint | Nice to Have (S5-09) |
| CH-004: Chain dots position | Sprint 2 Advisory (deferred ×3) | Deferred to Sprint 2, 3, 4; tester non-discoverability at S4-06 | **Must Have (S5-06)** — promoted |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| SC&E `Visual/Audio Requirements` section is `[To be designed]` — S5-03 cannot begin without a visual spec | High | High | Author visual spec as part of S5-02 story creation; use `/quick-design sce-visuals` or inline spec before S5-03 story work begins |
| Prana visual differentiation requires art assets | Low | Medium | All FP-scope visuals are code-driven GPUParticles2D with Prana type colors — no art-asset dependency; specify this explicitly in the S5-03 story |
| ADR-0013 gamepad (S5-07) carries HIGH engine risk from Sprint 4 | Medium | Medium | 3-day buffer; gamepad is Should Have — can defer to Sprint 6 if legibility work overruns |
| Fun hypothesis still PARTIALLY CONFIRMED — re-validation playtest needed | Low | High | Schedule a second playtest session after S5-03–S5-06 complete to recheck legibility before Feature layer expansion |

## Dependencies on External Factors

- Visual spec for SC&E type-differentiated effects must be authored before S5-03 story work begins (in-session design work — no external dependency)
- Second playtest tester availability — target after S5-06 completion

## Definition of Done for Sprint 5

- [ ] All Must Have stories implemented, code-reviewed, and closed via `/story-done`
- [ ] QA plan exists (`production/qa/qa-plan-sprint-5-*.md`)
- [ ] All Logic/Integration stories have passing headless tests
- [ ] Prana visual type differentiation manually verified (re-validation playtest or directed manual session)
- [ ] Chain dots visible above player confirmed manually
- [ ] Dash cooldown indicator confirmed distinguishable manually
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] SC&E Visual/Audio section authored before S5-03 implementation
- [ ] Design documents updated for any deviations from GDD
- [ ] Code reviewed and merged

---

> ⚠️ **QA Plan Required First**: Run `/qa-plan sprint` (S5-01) before starting any implementation story. This is Must Have — not optional.

> **Story creation note (S5-02):** The following story files must be created before implementation begins:
> - `production/epics/spell-casting-effects/story-005-type-visual-differentiation.md`
> - `production/epics/prana-grid/story-005-compact-combat-mode.md`
> - `production/epics/combat-hud/story-005-dash-feedback.md`
> - `production/epics/combat-hud/story-004-chain-dots.md` — check implementation status; may need an update/follow-up story for repositioning
>
> S5-07 uses existing `production/epics/prana-grid/story-004-gamepad-input.md`.

> **Scope check:** Run `/scope-check spell-casting-effects` and `/scope-check combat-hud` before implementation begins to confirm legibility stories stay within GDD scope.
