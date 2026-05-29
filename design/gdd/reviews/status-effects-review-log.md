# Review Log — Status Effects GDD

## Review — 2026-05-29 — Verdict: APPROVED
Scope signal: L
Specialists: None (lean mode)
Blocking items: 3 | Recommended: 4
Summary: B-1 resolved: Dependencies #4 rewritten from stale `set_freeze_state`/`set_stun_state` model to push-multiplier pattern (`apply_speed_modifier`/`apply_stun`), aligning with Core Rules and Interactions table that were correctly updated in round 1. B-2 resolved: AC-SE-12 corrected to assert `apply_speed_modifier(1.0)` instead of `set_freeze_state(false)`. B-3 resolved: cross-GDD flag added to Dependencies requiring SC&E Rule 8 to pass `effective_base` as the 4th `apply_status` argument for Burn — without this, all Burn ticks deal 0 damage. Four advisory items remain: Chill+Freeze ordering edge case; Burn tick_interval derivation ambiguity; Enemy AI cross-GDD flag now formalized in Dependencies row #4; Regen tick_interval ambiguity.
Prior verdict resolved: Yes — all round-1 blockers resolved in-session; round-2 found 3 new blockers in stale Dependencies #4 and AC-SE-12 text, all resolved in-session.

---

## Review — 2026-05-29 — Verdict: NEEDS REVISION (resolved in-session)
Scope signal: L
Specialists: None (lean mode)
Blocking items: 3 | Recommended: 4
Summary: Three blocking interface issues resolved in-session: (B-1) three conflicting Freeze interface models unified to the push-multiplier pattern (`apply_speed_modifier(float)` / `apply_stun(duration)`), aligning with Enemy AI GDD's stated preference; (B-2) CHILL and STAGGER added as stub statuses with scope, tick, expiry, and 4 new ACs — Freeze-suppresses-Chill rule written in; (B-3) `has_status` defined as a public API with explicit FP-inert scope note and a cross-GDD flag requiring SC&E to call `check_and_apply_shatter` instead of inlining the Freeze check. All four recommended items also addressed: Stun/Freeze pause documented as VS-scope in Rule 5 + Open Question 1; W-6 burn-modifier interface gap noted in Formula 1; dead-target guard mechanism specified via `target.is_alive()`; Open Questions section populated with 4 tracked items.
Prior verdict resolved: N/A (first review)

### Round-2 Checklist (for next review session)

- [ ] **Cross-GDD: Enemy AI GDD** — add `apply_speed_modifier(float)` and `apply_stun(float)` as exposed methods; update Downstream #7 to reference Status Effects push-multiplier interface
- [ ] **Cross-GDD: SC&E GDD** — update Formula 3 Step 5 to call `StatusEffectsManager.check_and_apply_shatter(target, raw_damage)` instead of `target.has_status(STATUS_FREEZE)` inline; update Rule 8 FP stub table to note that Shatter is inert at FP
- [ ] **Cross-GDD: GameEnums / Prana Data** — add `CHILL` and `STAGGER` to `GameEnums.BaseStatus` enum
- [ ] **Cross-GDD: Player Controller GDD** — confirm `is_alive() -> bool` is exposed on Fayde node (required by Status Effects Rule 4 step 1a)
- [ ] Verify CHILL_SLOW_PCT constant (0.15) is in entities.yaml with source: status-effects.md or prana-data.md
- [ ] Verify STAGGER_DURATION constant (0.3s) is in entities.yaml with source: combination-resolution.md or status-effects.md
