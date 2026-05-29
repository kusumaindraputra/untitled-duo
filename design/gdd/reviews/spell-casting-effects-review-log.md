# Review Log — Spell Casting & Effects GDD

## Review — 2026-05-29 — Verdict: NEEDS REVISION (resolved in-session)
Scope signal: XL
Specialists: None (lean mode)
Blocking items: 2 | Recommended: 6
Summary: Both blockers resolved in-session. B-1: `spell_hit_element(target, prana_type_id)` signal added — emitted at Formula 3 Step 10 after each `apply_damage` call, added to Combat HUD Interactions row, and covered by new AC-SC-26. B-2: Formula 3 Steps 5 and 7 corrected — `target.has_status(STATUS_FREEZE)` replaced with `StatusEffectsManager.check_and_apply_shatter(target, raw_damage)`; `target.has_status(STATUS_BLIND)` replaced with `StatusEffectsManager.has_status(target, STATUS_BLIND)`; Rule 8 STATUS_FREEZE FP entry rewritten to remove false "enables Shatter" claim; FP stub disclaimer paragraph added above table; STAGGER row added to status table. Two stale CR revision flags removed (CR Approved 2026-05-29). Remaining recommendations (R-4 through R-6, N-1/N-2) are FP scope clarifications deferred to next review.
Prior verdict resolved: N/A — first review

### Round-2 Checklist (for next review session)

- [ ] Verify `spell_hit_element` signal wiring in SC&E node `_ready()` (not just Formula 3 — must be declared as a Godot signal)
- [ ] AC-SC-19 and AC-SC-25 are FP-scope tests (verify `status_freeze_timer` field write) — mark as `[FP]` so they're not confused with permanent MVP tests
- [ ] R-4: Add CHILL FP note to Rule 9 Deepfrost NP entry — `apply_speed_modifier` is MVP scope on Enemy AI, so CHILL is silently a no-op at FP
- [ ] R-5: Add Stormgold qualifying interrupt FP note — `_is_attacking` undefined at FP; Follow-Through inert at FP
- [ ] R-6: Populate Open Questions (W-7 VER_HEAL_FLAT delivery path; FP stub migration plan)
- [ ] N-2: Add Step 9 MVP migration note to Interactions table (element param to apply_damage → H&D routes to EA&W)
