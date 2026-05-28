# Design Review Log: Player Controller

---

## Review — 2026-05-27 — Verdict: MAJOR REVISION NEEDED
Scope signal: L
Specialists: game-designer, systems-designer, audio-director, qa-lead, gameplay-programmer, creative-director
Blocking items: 14 | Recommended: 8
Prior verdict resolved: No — first review

Summary: The GDD had sound structure (8/8 sections) and strong Player Fantasy and Edge Cases sections, but contained three core contradictions: (1) the Health & Damage i-frame contract conflict — two approved GDDs specified incompatible i-frame systems that would make dash i-frames silently non-functional; (2) a lerp formula that produced drift/float feel, contradicting the stated "deliberate weight / every step is a commitment" fantasy; (3) an undocumented mismatch between the 8-directional screen-space dash snap and isometric visual player intent. Formula 1 timing claims were also mathematically incorrect throughout, AC-PC-02 would permanently fail at default values, and half the ACs were untestable without a state getter and AudioSystem DI seam. All 14 blockers resolved in-session. Key changes: delta-corrected lerp + snap-to-stop, DASH_COOLDOWN raised 1.0s → 2.0s, i-frame query pattern resolved (H&D must be updated), testability interface added.

**Re-review checklist (priority order):**
1. Verify Health & Damage GDD has been updated to add `is_invincible()` query at step 1a of `apply_damage`
2. Verify Formula 1 timing claims match the delta-corrected + snap-to-stop implementation
3. Verify AC-PC-02 frame bound is correct with the snap threshold formula
4. Verify all ACs that referenced `_controller_state` now use `get_controller_state()`
5. Verify AudioSystem DI seam is properly specified for mock injection
6. Verify DASH_COOLDOWN default is 2.0s in Tuning Knobs and in AC-PC-18 example

---

## Review — 2026-05-28 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, gameplay-programmer, qa-lead, audio-director, godot-specialist, creative-director
Blocking items: 18 | Recommended: 13
Prior verdict resolved: Partial — round-1 checklist items 2–6 verified ✓; item 1 (H&D update) resolved during this session ✓

Summary: Round-1 revisions were structurally sound — 8/8 sections present, Formula 1 math correct, ACs using getter, DI seam specified. Full 6-specialist review exposed a second layer of precision gaps. Three failure-mode clusters: (1) four implementation-forking self-contradictions (zero-input guard condition inconsistency between Core Rule 3 and Formula 1; 8-directional dash snap with no atan2 algorithm or tie-break; Edge Case #2 directly contradicted itself on whether a cancelled dash triggers cooldown; footstep suspension during DASHING underpowered by velocity check alone); (2) four AC correctness issues (AC-PC-02 formula undefined at MOVE_FRICTION=1.0; AC-PC-05c vacuously true without physics scene; AC-PC-12c asserting unspecified signal-handler behaviour; timer-based ACs uncommitted on Timer vs. float accumulator); (3) audio ownership gaps repeating the round-1 cross-GDD pattern (footstep variant naming/shuffle-bag unresolved; sfx_fayde_dash double-fire risk between PC and Game Feel; dedicated footstep player deferred without deciding; dash SFX at NORMAL priority insufficient when i-frames are invisible). Creative director verdict: NEEDS REVISION; senior finding that "round-2 exposed a precision gap layer, not a design problem layer." All 18 blockers resolved in-session. Key changes: atan2 snap algorithm added; cooldown-on-cancel confirmed (design decision); float accumulator committed; footstep events renamed to sfx_fayde_footstep_a/b/c with shuffle-bag in PC; sfx_fayde_dash raised to HIGH priority; PC declared exclusive caller; AC-PC-02 preconditioned on MOVE_FRICTION<1.0; AC-PC-12c corrected; AC-PC-20/21 added; H&D GDD updated with step 1a; Player Fantasy copy updated to "decisive footing."

**Re-review checklist (priority order):**
1. Verify atan2 snap algorithm is present in Core Rule 4 with tie-break documented
2. Verify Edge Case #2 unambiguously states cooldown starts on dash cancel (no contradictions)
3. Verify footstep timer callback has explicit state guard (`if _controller_state != ENABLED: return`)
4. Verify AC-PC-02 has MOVE_FRICTION < 1.0 precondition and 60-fps-only label
5. Verify AC-PC-12c matches the signal-handler `_is_invincible` clear in Core Rule 2
6. Verify sfx_fayde_dash is HIGH priority in Visual/Audio Requirements
7. Verify H&D GDD step 1a is present and Player Controller is in H&D Dependencies table

---

## Review — 2026-05-28 — Verdict: APPROVED
Scope signal: M
Specialists: lean (no specialist agents)
Blocking items: 0 | Recommended: 3
Prior verdict resolved: Yes — all 7 round-2 checklist items verified ✓

Summary: Round-3 re-review against all 7 checklist items from round 2: all pass. atan2 snap algorithm present with tie-break; Edge Case #2 unambiguous on cancelled-dash cooldown; footstep callback state guard in Core Rule 6; AC-PC-02 correctly preconditioned; AC-PC-12c aligned with signal handler; sfx_fayde_dash at HIGH priority; H&D step 1a verified in the Health & Damage GDD source. No new blocking issues found. Document is implementation-ready: formulas mathematically correct, 21 ACs independently testable, cross-system contracts bidirectionally verified. Three recommended improvements noted (AC for FOOTSTEP_INTERVAL_SEC setter guard; DASH_SPEED/MOVE_SPEED ratio re-validation note; isometric memo hint UX flag) — none blocking.
