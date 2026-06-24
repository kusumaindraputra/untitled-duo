# Review Log: Combination Resolution

## Review — 2026-05-28 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: None (lean mode)
Blocking items: 3 | Recommended: 5
Summary: The GDD is mathematically sound — all formula examples verified, 28 ACs with strong coverage, and the adjacency pool design delivers well on Pillar 2 and Pillar 4. Three focused implementation contract issues block handoff to SC&E: (1) ADJ_STATUS_EXTEND's "must match primary type" neighbour condition is ambiguous between storing fragment.type_id vs. a dynamic primary-type sentinel; (2) `fallback_status` naming implies the field is skipped when non-primaries are active, contradicting additive non-primary design; (3) ADJ_ECHO target is unspecified. All three are one-to-two sentence fixes requiring no structural redesign.
Prior verdict resolved: N/A — first review

### Blocking Items (must fix before re-review)

**B1.** `ADJ_STATUS_EXTEND` neighbour condition — "must match primary type" is ambiguous.
- Interpretation A: `required_type_id = fragment.type_id` at generation (requires same-type neighbour — implementable in current data model)
- Interpretation B: dynamic sentinel matching slot 4's type at resolution time (requires new sentinel value and pseudocode extension)
Fix: Clarify which interpretation is intended. If Interpretation A: reword pool entry to "must match this fragment's own type." If Interpretation B: add sentinel (e.g., `-2 = PRIMARY_TYPE`) to NeighborCondition data model and extend the pseudocode.

**B2.** `fallback_status` naming hazard — "used when no non-primaries are active" implies SC&E should skip primary status when non-primaries exist, contradicting all non-primary descriptions ("in addition to primary status").
Fix: Rename `fallback_status` → `primary_base_status`. Add contract: "SC&E MUST apply `primary_base_status` on every primary attack regardless of non_primary_modifiers content."

**B3.** `ADJ_ECHO` target unspecified — damage scalar and timing defined but no target specification.
Fix: Add one line, e.g., "Echo Strike targets the nearest live enemy at fire time; if no enemies remain, Echo is suppressed."

### Recommended Revisions (address before production)

**R1.** Verdant T2 barrier multi-hit pool at FP lv.1 = 1 HP (inert against Burn ticks). Add a note clarifying FP-scope behavior.
**R2.** ADJ_CHAIN_LIGHTNING and ADJ_DOUBLE_HIT: target-death mid-chain edge case missing.
**R3.** Add AC-CR-29: primary status present alongside active non-primary modifiers.
**R4.** systems-index.md status corrected to "In Review" this session (was stale "Approved").
**R5.** Prana Drop / Loot FP substitute should be noted in systems-index row #16.

### 7-Item Re-Review Checklist (for round 2)

1. [x] B1 resolved — ADJ_STATUS_EXTEND: `required_type_id = fragment.type_id` at generation (Interpretation A; not a dynamic sentinel)
2. [x] B2 resolved — renamed to `primary_base_status`; SC&E contract added; AC-CR-13 updated
3. [x] B3 resolved — ADJ_ECHO targets nearest live enemy at fire time; suppressed if no enemies remain
4. [x] R2 addressed — target-death edge cases for ADJ_CHAIN_LIGHTNING and ADJ_DOUBLE_HIT
5. [x] R3 addressed — AC-CR-29 added
6. [x] All formula examples still valid after any text changes (spot-check Verdant T2: round(20×0.70×0.10)=1 ✓)
7. [x] Cross-GDD flags for Prana Grid interface update confirmed carried forward (⚠ box in Interactions section + Dependencies bidirectional note)

## Review — 2026-05-29 — Verdict: APPROVED
Scope signal: L
Specialists: None (lean mode)
Blocking items: 0 | Recommended: 4
Summary: All 7 items on the round-2 checklist confirmed resolved — B1 (ADJ_STATUS_EXTEND interpretation A explicit), B2 (primary_base_status named and SC&E contract defined), B3 (ADJ_ECHO target specified), R2 (CHAIN_LIGHTNING + DOUBLE_HIT death edge cases), R3 (AC-CR-29 added), formula spot-checks pass, Prana Grid cross-GDD flags carried forward. One stale ownership claim for Stagger ("CR-owned mechanic") fixed in-session to reference StatusEffectsManager. Remaining recommendations are advisory (ADJ_STATUS_EXTEND formula uses embedded 1.0 instead of ADJ_STATUS_EXT knob name; ADJ_CHAIN_LIGHTNING non-trigger at T1 implicit; Open Questions placeholder). Document clear for implementation handoff.
Prior verdict resolved: Yes

## Review — 2026-06-24 — Verdict: APPROVED
Scope signal: L
Specialists: None (lean mode)
Blocking items: 0 | Recommended: 0 (3 reaction-layer + 1 cascade item resolved inline during authoring)
Summary: Added a fourth resolution layer — **Prana Reactions** (Rule 16 / Formula 9) and the **Cascade** tier (Rule 17 / Formula 10). Reactions are a generative, data-driven recognition layer: 10 unordered element-pair reactions armed by cardinal grid adjacency, previewed live in prep so players reason from 5 element "verbs" rather than memorising recipes; every effect reuses an existing primitive (Burn/Blind/Stun/Freeze/Shatter/lifesteal/AoE/arc/window/heal-amp). The Cascade tier is core-anchored and generative core-sensitive: when the core has ≥2 distinct cardinal neighbours, the core↔neighbour pairwise reactions merge into one core-led burst (lead = core shape, each distinct neighbour = a modifier facet, up to 4), yielding 50+ predictable variants from one rule with no authored catalog and bounded combat clutter (merge replaces icons). Three reaction implementability gaps fixed inline (Thermal-Shock slot in Formula 5 damage order; Short-Circuit exception to the idle-Stun Follow-Through rule; Permafrost×Verdant-NP heal-amp stacking) and one cascade numeric fix (Formula 10 output range corrected to 1.20–1.40 at default, matching AC-CR-43). Added 15 ACs (AC-CR-30→44; total 44), ~24 tuning knobs, `SpellEffect.active_reactions` + `active_cascade`, and cross-GDD contracts to Prana Grid (live preview), SC&E (apply by effect_kind / lead+modifiers), and Combat HUD. Top design risk to watch in playtest: combat cognitive load — `MAX_ACTIVE_REACTIONS` + `MAX_CASCADE_MODIFIERS` are the mitigation levers. Architecture captured in ADR-0016.
Prior verdict resolved: Yes — extends the prior Approved baseline (no prior items reopened)
