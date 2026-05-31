# Gate Check: Pre-Production → Production

**Date**: 2026-05-31
**Checked by**: gate-check skill
**Review Mode**: lean
**Previous gate check**: `production/gate-checks/gate-check-pre-production-2026-05-31b.md` (FAIL — 6 blockers)

---

## Required Artifacts: 14/16 present (up from 13/16 this morning)

| # | Artifact | Status |
|---|----------|--------|
| 1 | Vertical slice REPORT.md | ⚠️ CONCERNS — concept prototype (`rune-grid-concept`) PROCEED; full two-phase loop unvalidated |
| 2 | Sprint plan at `production/sprints/` | ✅ `sprint-2.md` — FP-scoped, references `production/epics/*/story-*.md` paths |
| 3 | Art bible — all 9 sections + AD sign-off | ✅ 9 sections complete / ⚠️ AD-ART-BIBLE formal gate never run |
| 4 | Entity inventory | ⚠️ CONCERNS — `design/assets/entity-inventory.md` missing; recommended, not blocking |
| 5 | All MVP-tier GDDs complete | ⚠️ CONCERNS — Status Effects ✅ Run Management ✅ Main Menu ❌ Not Started |
| 6 | Master architecture doc | ✅ `docs/architecture/architecture.md` |
| 7 | ≥3 Foundation-layer ADRs | ✅ 13 ADRs (ADR-0001–0013), all Accepted |
| 8 | All Foundation + Core ADRs Accepted | ✅ 13/13 Accepted |
| 9 | Control manifest | ✅ `docs/architecture/control-manifest.md` |
| 10 | Epics: Foundation AND Core layers | ✅ 4 Foundation (3 complete) + 7 Core epics in `production/epics/` |
| 11 | Vertical Slice playable build | ⚠️ CONCERNS — not built |
| 12 | Vertical Slice playtested | ⚠️ CONCERNS — concept prototype only |
| 13 | Vertical Slice playtest report | ⚠️ CONCERNS — none |
| 14 | UX specs: HUD, Main Menu, Pause Menu | ✅ all three exist — Approved via `/ux-review` |
| 15 | HUD design at `design/ux/hud.md` | ✅ exists, Status: Approved |
| 16 | Key screen UX specs passed `/ux-review` | ✅ all three Approved 2026-05-31 |

---

## Quality Checks: 5/8 passing

| Check | Status |
|-------|--------|
| Core loop fun validated | ⚠️ MANUAL CHECK — grid mechanic validated (PROCEED); two-phase Prep+Combat loop not yet playtested |
| Interaction pattern library | ✅ IP-01–IP-12 documented |
| Architecture Engine Compatibility + GDD References in all ADRs | ✅ confirmed; ADR-0006/ADR-0008 verified by permanent automated tests |
| Accessibility tier addressed in all key screen UX specs | ✅ `design/accessibility-requirements.md` — Basic tier committed |
| Sprint plan references story file paths | ✅ `sprint-2.md` references `production/epics/*/story-*.md` paths |
| Vertical Slice complete (start→challenge→resolution cycle) | ⚠️ CONCERNS — not built |
| Architecture open questions (Foundation/Core) | ✅ TD confirmed: all 11 blocking items from the 2026-05-29 CONCERNS review now closed |
| UX specs cover all UI Requirements from MVP GDDs | ⚠️ MANUAL CHECK — specs exist; content cross-reference deferred |

---

## Concerns

1. **Main Menu GDD not authored** — `design/gdd/main-menu.md`: MVP-tier, Not Started.
   This is a required artifact per the gate definition ("All MVP-tier GDDs complete"). No director escalated to NOT READY, and sprint-2 is FP-scoped (Main Menu won't be implemented for several sprints). Treated as CONCERNS rather than hard FAIL — but this is a conscious softening. Resolve before the Main Menu epic is created.

2. **Three GDD file headers not updated to Approved** — `design/gdd/enemy-ai.md`, `wave-encounter-system.md`, `combat-hud.md` all passed `/design-review` 2026-05-31 (per session log and `systems-index.md`) but their file Status headers still read "Designed" / "In Design." Documentation hygiene gap. Fix before picking up Enemy Instance story S2-06.

3. **Prana affiliation balance — CD CONCERNS (D-1/D-2/D-3)** — Must resolve before first playtest (2026-06-14):
   - **D-1**: No FP enemy carries Deepfrost or Verdant affiliation — 40% of Prana catalog is unreachable as a meaningful choice. Violates Pillar 4 "Depth Over Breadth."
   - **D-2**: Hardcoded wave fails the ≥30% anti-Ashfire gate from Prana Data's own spec. Charger (Ashfire) makes all-Ashfire the dominant strategy — violates Pillar 2 "Power is Earned Through Understanding."
   - **D-3**: Shatter depends on Freeze (MVP-gated); silently no-ops at FP — erodes player trust in the combo system.
   Fix: re-affiliate one FP enemy non-Ashfire; pull minimal Freeze to FP or scope-gate Shatter. Tuning-level changes, not redesigns.

4. **Animation timing discrepancy** — `design/art/art-bible.md` §7.5 specifies phase lock dim at 0.3s; `design/ux/interaction-patterns.md` Animation Standards specifies 0.15s for the same event. One must be corrected before visual asset authoring begins.

5. **No milestone document** — `production/milestones/` does not exist. Sprint-2 flags this as a sprint deliverable (author `first-playable.md` in the first session). Without it, "Production done" is undefined.

6. **H&D↔WaveManager ADR missing** — ADR-0007 covers HealthAndDamage as a singleton but the `register_enemy()` timing/ownership contract with WaveManager has no dedicated ADR. Write before the first Enemy Instance story (S2-06) to avoid mid-sprint design ambiguity.

7. **AD-ART-BIBLE formal gate never run** — art bible is substantive (9 sections) but no internal consistency review has been performed. One real discrepancy already found (see concern #4). Run before the first visual asset is authored.

8. **Entity inventory absent** — `design/assets/` does not exist. Recommended artifact; not a hard gate requirement, but asset discovery without it creates ad hoc scheduling risk. Create before commissioning sprites.

---

## Director Panel Assessment

```
Creative Director:  CONCERNS
  — Vision is coherent. Three pillar violations in FP content must be fixed
    before the first playtest (D-1: Deepfrost/Verdant trap; D-2: anti-Ashfire
    gate unmet; D-3: Shatter no-ops). These are tuning-level, not redesigns.
    The playtest scheduled for 2026-06-14 will produce invalid evidence if these
    are not resolved beforehand.

Technical Director: READY
  — Foundation is production-ready: 13 Accepted ADRs, working test harness,
    3 Foundation epics complete, 50+ tests passing. All 11 blocking items from
    the 2026-05-29 architecture review are now closed. ADR-0006/ADR-0008
    verification is covered by permanent automated tests (stronger than the
    planned throwaway tests). Sprint-2's H&D + PlayerController + EnemyInstance
    have Accepted, conflict-free ADR coverage. Proceed to Production.

Producer:           CONCERNS
  — Core epics and sprint-2 exist — the structural NOT READY from the previous
    verdict is resolved. Conditional: (1) update enemy-ai.md file header to
    Approved before S2-06; (2) write first-playable.md milestone doc in the
    first sprint session; (3) write H&D↔WaveManager ADR before Enemy Instance;
    (4) run /qa-plan before the final sprint-2 story. H&D and Player Controller
    (S2-02, S2-04) can start immediately on approved designs.

Art Director:       CONCERNS
  — Art bible is production-grade across 9 sections; no creative drift found
    between UX specs and visual direction. Two items before asset authoring:
    (1) Resolve animation timing discrepancy (art bible §7.5 0.3s vs
        interaction-patterns.md 0.15s — same event, different durations);
    (2) Create design/assets/entity-inventory.md before commissioning sprites.
    AD-ART-BIBLE formal gate has never been run — one real discrepancy already
    surfaced; more may exist.
```

---

## Chain-of-Verification

**[Q1]** Main Menu GDD is technically a required artifact (not met). Flagged explicitly. No director NOT READY; FP-sprint context warrants CONCERNS not FAIL. Intentional softening.

**[Q2]** Prana balance concerns compound if left to post-playtest. Must resolve before 2026-06-14.

**[Q3]** GDD file header discrepancy: design reviews were run (session log + systems-index); files not updated. Documentation hygiene, not a re-review needed.

**[Q4 — TOOL]** TD re-read ADRs directly: ADR-0006/ADR-0008 verified by automated tests. Architecture-review CONCERNS verdict from 2026-05-29 is stale — all 11 blocking items now closed.

**[Q5]** No compounding cascade. H&D + Player Controller can start immediately on Accepted ADRs and Approved GDDs.

Chain-of-Verification: 5 questions checked — verdict CONCERNS (improved from FAIL).

---

## Recommendations

**Before starting any Sprint-2 story:**
1. Update `design/gdd/enemy-ai.md`, `wave-encounter-system.md`, `combat-hud.md` Status headers → `Approved` (documentation hygiene — reviews completed 2026-05-31)
2. Resolve Prana affiliation balance (D-1/D-2/D-3) before first playtest — re-affiliate one FP enemy non-Ashfire + decide Shatter scope boundary

**Before starting Enemy Instance story (S2-06):**
3. Write H&D↔WaveManager ADR (enemy registration timing/ownership contract)

**During Sprint-2 first session:**
4. Author `production/milestones/first-playable.md` — define FP exit criteria explicitly

**Before first visual asset is authored:**
5. Resolve animation timing discrepancy: art bible §7.5 (0.3s) vs `interaction-patterns.md` (0.15s)
6. Run AD-ART-BIBLE gate on `design/art/art-bible.md`
7. Create `design/assets/entity-inventory.md` stub

**Not blocking, but before Main Menu epic:**
- Write Main Menu GDD (`design/gdd/main-menu.md`)
- Reconcile boss tier (MVP scope in game concept vs Vertical Slice tier in systems-index) before milestone exit criteria are finalized

---

## Verdict: CONCERNS

Significant improvement from the previous FAIL. All 6 hard blockers from the morning gate are resolved. The project has a working test harness, 13 Accepted ADRs, 3 complete Foundation epics, and a production sprint plan with real story file paths. The Technical Director returned READY for the first time at this gate.

Remaining concerns are concrete and short-path: GDD file header updates (documentation), Prana balance fixes (one wave edit + one enemy re-affiliation), and a milestone document. None block the first two Must Have stories (H&D, Player Controller) from starting immediately on day 1.

**Minimum path to a clean READY:**
1. Update 3 GDD file headers → Approved
2. Fix Prana affiliation (D-1/D-2) + decide Shatter scope at FP (D-3)
3. Write `production/milestones/first-playable.md`
4. Write H&D↔WaveManager ADR

The creative and technical foundations are solid. Production is ready to begin.
