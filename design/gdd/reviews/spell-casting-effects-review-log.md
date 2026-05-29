# Review Log — Spell Casting & Effects GDD

## Review — 2026-05-29 — Verdict: APPROVED
Scope signal: XL
Specialists: None (lean mode)
Blocking items: 0 | Recommended: 5
Summary: All prior blockers resolved (confirmed in GDD). Five advisory recommendations raised: R-1 requires a no-op StatusEffectsManager stub at FP scope to prevent runtime crashes when Steps 5/7 are called; R-2/R-3 require a follow-up H&D GDD amendment to define `grant_barrier` and confirm single-hit barrier absorption semantics; R-4 requires Enemy AI or Enemy Data GDD to declare FP stub fields before FP implementation; R-5 requires minimum population of Visual/Audio and UI Requirements sections before handoff. System is implementation-ready; R-1 and R-2/R-3 are pre-implementation prerequisites, not design gaps. Pillar 2/3 alignment confirmed.
Prior verdict resolved: Yes — all round-1/2/3 items resolved

---

## Review — 2026-05-29 — Verdict: NEEDS REVISION (resolved in-session)
Scope signal: XL
Specialists: None (lean mode)
Blocking items: 2 | Recommended: 6
Summary: Both blockers resolved in-session. B-1: `spell_hit_element(target, prana_type_id)` signal added — emitted at Formula 3 Step 10 after each `apply_damage` call, added to Combat HUD Interactions row, and covered by new AC-SC-26. B-2: Formula 3 Steps 5 and 7 corrected — `target.has_status(STATUS_FREEZE)` replaced with `StatusEffectsManager.check_and_apply_shatter(target, raw_damage)`; `target.has_status(STATUS_BLIND)` replaced with `StatusEffectsManager.has_status(target, STATUS_BLIND)`; Rule 8 STATUS_FREEZE FP entry rewritten to remove false "enables Shatter" claim; FP stub disclaimer paragraph added above table; STAGGER row added to status table. Two stale CR revision flags removed (CR Approved 2026-05-29). Remaining recommendations (R-4 through R-6, N-1/N-2) are FP scope clarifications deferred to next review.
Prior verdict resolved: N/A — first review

### Round-2 Checklist — Resolution (reviewed 2026-05-29)

- [x] N-2: Step 9 MVP migration note added to Interactions table — RESOLVED
- [ ] Item 1: `spell_hit_element` declared as Godot signal in Rule 1 — NOT RESOLVED → R-1 in round-3
- [ ] Item 2: AC-SC-19 and AC-SC-25 marked `[FP]` — NOT RESOLVED → R-2 in round-3
- [ ] Item 3 (R-4): CHILL FP note in Rule 9 Deepfrost NP entries — NOT RESOLVED → R-3 in round-3
- [ ] Item 4 (R-5): Stormgold Follow-Through FP note at Formula 2 qualifying interrupt definition — PARTIAL (Rule 8 has it; Formula 2 missing) → R-4 in round-3
- [ ] Item 5 (R-6): Open Questions populated (W-7 VER_HEAL_FLAT; FP stub migration plan) — NOT RESOLVED → R-5 in round-3

---

## Review — 2026-05-29 — Verdict: NEEDS REVISION
Scope signal: XL
Specialists: None (lean mode)
Blocking items: 2 | Recommended: 6
Summary: Round-2 checklist: 1/6 resolved (N-2 migration note), 1/6 partial (Follow-Through FP note in Rule 8 but not Formula 2), 4/6 unresolved. Two new blockers found: B-1 — H&D barrier grant API completely absent from SC&E Interactions table and Formula 2/Rule 10 (Verdant T2 SELF shield pulse and ADJ_BARRIER_HIT both grant barriers but no `grant_barrier` or equivalent H&D method specified); B-2 — `enemy_killed` subscription for ADJ_BARRIER_HIT not in Rule 1 `_ready()` connections, connection pattern (static vs dynamic) unspecified, signal source unconfirmed. Core design sound; all issues are API contract and FP scope documentation gaps.
Prior verdict resolved: No — 2 new blockers found

### Round-3 Checklist — Resolution (revised 2026-05-29)

- [x] B-1: `grant_barrier(fayde, barrier_hp)` named in Rule 10 ADJ_BARRIER_HIT; Formula 2 Verdant T2 SELF updated; H&D Interactions row updated; Cross-GDD flag #5 added requiring H&D GDD to define the method
- [x] B-2: `HealthAndDamage.enemy_killed` dynamic connection added to Rule 1 (CONNECT_ONE_SHOT pattern, chain-start if ADJ_BARRIER_HIT active, disconnected on preparation_started); H&D Dependencies row updated with signal source note
- [x] R-1: "Signals declared on this node" code block added to Rule 1 — `spell_hit_element`, `cast_hit_started`, `chain_index_changed`
- [x] R-2: AC-SC-19 and AC-SC-25 marked `[FP]`; coverage note updated with FP classification and MVP test-suite note
- [x] R-3: CHILL FP no-op note added to Rule 9 Deepfrost NP T1 (field-write stub, Enemy AI inert at FP) and NP T2 (Chill FP note; Freeze per Rule 8 table)
- [x] R-4: `[FP note: _is_attacking undefined at FP — qualifying interrupts never occur; Step 6 is inert at FP]` added to Formula 2 Stormgold qualifying interrupt definition
- [x] R-5: Open Questions populated — (1) VER_HEAL_FLAT per-call vs chain-start query pattern; (2) status_* field ownership and FP stub migration plan
- [x] R-6: `chain_index_changed` emission added to all four Rule 4 branches (index=1 on first press; index=_combo_index on subsequent; index=0 on chain completion; index=0 on window expiry)
