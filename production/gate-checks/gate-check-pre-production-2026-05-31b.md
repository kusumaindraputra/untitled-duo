# Gate Check: Pre-Production → Production

**Date**: 2026-05-31
**Checked by**: gate-check skill
**Review Mode**: lean
**Previous gate check**: `production/gate-checks/gate-check-pre-production-2026-05-31.md` (FAIL — 6 blockers)

---

## Required Artifacts: 13/16 present (up from 11/16 this morning)

| # | Artifact | Status |
|---|----------|--------|
| 1 | Vertical slice REPORT.md | ⚠️ CONCERNS — concept prototype (`prototypes/rune-grid-concept/REPORT.md`) PROCEED; two-phase Prep+Combat loop unvalidated |
| 2 | Sprint plan at `production/sprints/` | ✅ `sprint-1.md` exists (design sprint — quality check flags below) |
| 3 | Art bible — all 9 sections + AD sign-off | ✅ 9 sections complete / ⚠️ AD-ART-BIBLE sign-off skipped in lean mode |
| 4 | Entity inventory | ⚠️ CONCERNS — `design/assets/entity-inventory.md` missing; recommended, not blocking |
| 5 | All MVP-tier GDDs complete | ❌ FAIL — Main Menu (MVP, Not Started); Enemy AI, Wave/Encounter System, Combat HUD (FP tier, Designed not Approved) |
| 6 | Master architecture doc | ✅ `docs/architecture/architecture.md` |
| 7 | ≥3 Foundation-layer ADRs | ✅ 13 ADRs (ADR-0001–0013), all Accepted |
| 8 | All Foundation + Core ADRs Accepted | ✅ 13/13 Accepted |
| 9 | Control manifest | ✅ `docs/architecture/control-manifest.md` |
| 10 | Epics: Foundation **AND** Core layers present | ❌ FAIL — Foundation epics complete; Core layer epics not created |
| 11 | Vertical Slice playable build | ⚠️ CONCERNS — not built |
| 12 | Vertical Slice playtested | ⚠️ CONCERNS — concept prototype only |
| 13 | Vertical Slice playtest report | ⚠️ CONCERNS — none |
| 14 | UX specs: HUD, Main Menu, Pause Menu | ✅ all three exist — NEW since morning gate |
| 15 | HUD design at `design/ux/hud.md` | ✅ exists, Status: Approved — NEW since morning gate |
| 16 | Key screen UX specs passed `/ux-review` | ❌ FAIL — Pause Menu not reviewed; Main Menu file status not updated to APPROVED |

---

## Quality Checks: 3/8 passing

| Check | Status |
|-------|--------|
| Core loop fun validated | ⚠️ MANUAL CHECK — grid mechanic confirmed (PROCEED); full Prep+Combat two-phase loop not playtested |
| Interaction pattern library | ✅ IP-01–IP-12 documented |
| Architecture Engine Compatibility + Dependencies in all ADRs | ✅ confirmed in /architecture-review |
| Accessibility tier addressed in all key screen UX specs | ❌ `accessibility-requirements.md` not created |
| Sprint plan references story file paths | ❌ `sprint-1.md` is a GDD authoring sprint; no story file paths |
| Vertical Slice complete (start→challenge→resolution cycle) | ⚠️ CONCERNS — not built |
| Architecture open questions in Foundation/Core layers | ⚠️ MANUAL CHECK — /architecture-review verdict CONCERNS (39 TR gaps, 17 partial) |
| UX specs cover all UI Requirements from MVP GDDs | ⚠️ MANUAL CHECK — specs exist, content cross-reference deferred |

---

## Blockers

1. **Enemy AI, Wave/Encounter System, Combat HUD GDDs not Approved** — three First Playable-tier GDDs are "Designed" but not approved. Core-layer epics and ADRs cannot be fully written until these are accepted. Run `/design-review` on each.
2. **Main Menu GDD not authored** — MVP tier, status "Not Started" in systems-index. Required before a production sprint covers the full MVP scope.
3. **Core layer epics missing** — `/create-epics layer:core` has not been run. Nothing is ready to pick up with `/dev-story` on day one of Production.
4. **`accessibility-requirements.md` not created** — accessibility tier is a gate requirement. Neither `design/accessibility-requirements.md` nor `design/ux/accessibility-requirements.md` exists.
5. **`/ux-review pause-menu` not run** — Pause Menu spec (Status: In Review) has not passed /ux-review. All key screen specs must pass before advancing.
6. **No production sprint plan** — `sprint-1.md` is a Systems Design sprint (GDD tasks). A sprint referencing real story file paths from `production/epics/` is required.

---

## Director Panel Assessment

```
Creative Director:  CONCERNS
  — Vision is coherent and pillars are faithfully threaded through all GDDs.
    Three design issues must be resolved before First Playable:
    (1) Deepfrost and Verdant are mechanically dominated at FP scope (no FP enemy
        carries their affiliation — 40% of Prana catalog is a trap pick).
    (2) FP wave fails Prana Data's own ≥30%-anti-Ashfire gate — Charger affiliation
        makes all-Ashfire the dominant and demonstrated strategy, contradicting
        "Power is Earned Through Understanding."
    (3) Shatter depends on Freeze, but Freeze is MVP-gated while Shatter runs at FP
        — combo exists in player mental model but silently no-ops.
    Fix: re-affiliate one FP enemy non-Ashfire and either pull minimal Freeze to FP
    or gate Shatter. These are tuning-level changes, not redesigns.

Technical Director: CONCERNS
  — Foundation is production-ready: 13 Accepted ADRs, working test harness, 3 epics
    complete. Advancing wholesale risks "Production" that is really disguised Pre-Production
    for Core systems. Recommend phasing: advance Foundation layer, gate Core on:
    (a) Enemy AI/Wave/Combat HUD GDDs Approved, (b) their ADRs written,
    (c) ADR-0006 (.tres enum) and ADR-0008 (duplicate_deep) verification tests green,
    (d) Core sprint plan with epics created.

Producer:           NOT READY
  — Foundation strong; no production sprint, no Core epics or stories, no milestone
    document. Nothing is ready to pick up /dev-story on day one. Additional note:
    boss is listed in MVP scope but is Vertical Slice tier in systems-index — reconcile
    before milestone authoring. H&D ↔ WaveManager contract has no ADR — write before
    first combat-epic story. Sprint 1 exit criterion should be a fun-checkpoint, not
    just "stories done."

Art Director:       CONCERNS
  — Art bible is substantive and production-grade across all 9 sections. Two procedural
    gaps: (1) AD-ART-BIBLE gate was never formally run — risk of undetected internal
    contradictions surfacing as production asset conflicts; (2) entity inventory missing
    — begin production without it and assets will be discovered ad hoc. Pause Menu UX
    review not run; Main Menu file status not updated.
```

Escalation applied: Producer returned NOT READY → verdict is minimum FAIL.

---

## Chain-of-Verification

**[TOOL ACTION 1]** Re-read `design/ux/pause-menu.md` status header — confirmed "In Review", no /ux-review evidence in file. Blocker #5 is accurate.

**[TOOL ACTION 2]** Glob for `production/milestones/*.md` — not found. No milestone document exists. Producer's concern confirmed (advisory — not in hard gate definition, but a production risk).

**Q1: Have I accurately separated hard blockers from strong recommendations?**
Yes. The 6 blockers map directly to gate definition requirements. VS not built, entity inventory, milestone doc, and art bible formal sign-off are correctly CONCERNS.

**Q2: Are there PASS items I was too lenient about?**
Artifact #2 (sprint plan exists) is correctly separated from the quality check (plan must reference story files). No lenient passes found.

**Q3: Am I missing additional blockers?**
The Producer flagged the missing H&D ↔ WaveManager ADR as a risk. Not in the gate's hard requirements but is a sprint-1 stall risk — surfaced as a recommendation.

**Q4: Can I provide a minimal path to PASS?**
Yes — 7 specific actions, all known, estimated 3–5 sessions.

**Q5: Is the fail condition resolvable, or a deeper design problem?**
Fully resolvable. No design rethink needed — the Creative Director's concerns are tuning-level (re-affiliate one FP enemy), not redesigns.

Chain-of-Verification: 5 questions checked — verdict unchanged (FAIL).

---

## Recommendations

**To resolve blockers (path to PASS):**
1. `/design-review enemy-ai` — approve Enemy AI GDD (required before Core epics)
2. `/design-review wave-encounter-system` — approve Wave/Encounter GDD
3. `/design-review combat-hud` — approve Combat HUD GDD
4. Update `design/ux/main-menu.md` Status → "Approved" (review already completed per session record)
5. `/ux-review pause-menu` — run before gate
6. Create `design/ux/accessibility-requirements.md` — run `/ux-design` which creates it as a byproduct, or author directly
7. `/create-epics layer:core` → `/create-stories [each epic]` → `/sprint-plan new`
8. Write Main Menu GDD (`/design-system main-menu`) — can defer slightly; needed before Core epics fully cover MVP scope

**To resolve concerns (not blocking, but recommended before/during Production):**
- Fix Prana affiliation balance at FP scope (re-affiliate one non-Charger FP enemy non-Ashfire, or pull minimal Freeze to FP — tuning-level per Creative Director)
- ADR-0006/ADR-0008 verification tests: run throwaway tests to lock .tres enum serialization and duplicate_deep isolation behavior
- Write ADR for Health & Damage ↔ WaveManager contract before first combat-epic story (Producer flagged as sprint stall risk)
- Run `/asset-spec` to generate `design/assets/entity-inventory.md`
- Run AD-ART-BIBLE gate on `design/art/art-bible.md` for formal sign-off
- Create `production/milestones/mvp.md` — define what "Production done" means; reconcile boss tier (listed MVP scope but systems-index shows Vertical Slice tier)

---

## Verdict: FAIL

The project has made meaningful progress since this morning's gate check — UX specs for all three key screens now exist, HUD is approved, and Main Menu passed /ux-review. But six hard blockers remain, with the Producer returning NOT READY.

**Minimum path to PASS (~3–5 sessions):**
1. `/design-review` × 3 (Enemy AI, Wave/Encounter, Combat HUD)
2. `/ux-review pause-menu`
3. Create `accessibility-requirements.md`
4. `/create-epics layer:core` → `/create-stories` for each epic → `/sprint-plan new`

The creative and technical foundations are solid. Production is close — it is a planning and design-approval gap, not a design rethink.
