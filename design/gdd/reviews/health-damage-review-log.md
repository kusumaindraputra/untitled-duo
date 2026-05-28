# Review Log: Health & Damage

---

## Review — 2026-05-28 — Verdict: NEEDS REVISION (round 3)
Scope signal: M
Specialists: lean mode (single-session analysis)
Blocking items: 2 | Recommended: 3
Summary: Round 3 re-review of round 2 revisions. All 16 round-2 blockers confirmed resolved. Two new blockers found: (B1) heal formula contradiction — Rule 4 code block still uses `int(round(...))` while the Formulas section uses `roundi()`, a partial application of the round-2 roundi() migration; (B2) enemy `max_hp` initialization contract missing — the damage formula uses `target.max_hp` for enemy targets but no statement in the GDD defines who sets enemy `max_hp` or to what value at spawn. Both are targeted single-line fixes with no structural rework required.
Prior verdict resolved: Yes (round-2 16 blockers confirmed resolved; new issues found in this pass)

---

## Review — 2026-05-28 — Verdict: NEEDS REVISION → Revised in-session (pending re-review)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, audio-director, godot-gdscript-specialist, creative-director
Blocking items: 16 (all resolved in-session) | Recommended: 8 (key items incorporated)
Summary: Re-review of the 2026-05-27 revision. Three root-cause patterns found: (A) Zone state lifecycle — `_current_zone` tracker not reset on `run_started`, AC fixture defect in AC-HD-20/21 (direct HP assignment bypasses tracker), new AC-HD-32 added for zone reset; (B) Pipeline specification gaps — `round()` claim was factually wrong (GDScript uses round-half-away-from-zero, not banker's; corrected to `roundi()` throughout), i-frame check missing from Rule 2 step list (added as step 2b in correct position), `force_end_iframe_window()` test seam promoted to a binding interface requirement, zero-damage CONTACT hit i-frame trigger clarified, AC-HD-06 signal suppression added, AC-HD-28 ordering clause dropped, AC-HD-33 added for re-arm; (C) Audio contract gaps — parameter blend mechanism removed (Audio System GDD owns implementation; H&D specifies observable outcome only), `heavy_hit` stinger priority declared (COMBAT=0), DamageClass/prana_affiliation enum identity asserted + NONE sentinel documented, `health_restored` silence made conditional on Combat HUD GDD meeting perceptibility criteria, `is_instance_valid()` guard added to Prana Drop / Loot contract. CAREFUL/DESPERATE tuning range corrected (DESPERATE upper bound 0.24, not 0.25). All 16 blockers resolved in-session. Re-review required.
Prior verdict resolved: Yes (2026-05-27 revision confirmed addressed; new issues found in this pass)

---

## Review — 2026-05-27 — Verdict: MAJOR REVISION NEEDED → Revised in-session (pending re-review)
Scope signal: M
Specialists: game-designer, systems-designer, qa-lead, audio-director, creative-director
Blocking items: 14 (all resolved in-session) | Recommended: 11 (key items incorporated)
Summary: Prior APPROVED verdict (2026-05-23) superseded. Full adversarial review found 14 blockers the first review missed: audience compatibility gap (7+ audience vs. 20%-HP-per-hit Charger — resolved with FIRST_RUN_DAMAGE_MULTIPLIER tutorial mercy contract); hit-feel gap (no heavy_hit signal for Game Feel/Juice — heavy_hit signal added); four formula correctness issues (threshold invariant overlap, banker's rounding one-shot boundary, compound base_damage_modifier chain in one-shot note, int() vs. round() truncation in heal formula — all corrected); four audio signal contract gaps (damage_taken target untyped, enemy_killed missing affiliation tag, HP zone music treatment unspecified, elemental death variant event keys unowned — all resolved); two AC gaps (partial recovery re-arm, AC-HD-25 non-testable in Godot — both fixed). HP zone signals replaced with comprehensive player_hp_zone_changed(HPZone) enum. Thresholds converted from absolute (33/15) to percentage-based (40%/20%) to match Player Fantasy prose and prevent ratio drift. All 14 blockers resolved in-session. Re-review required to confirm fixes before APPROVED status can be restored.
Prior verdict resolved: Yes (APPROVED 2026-05-23 superseded)

---

## Review — 2026-05-23 — Verdict: APPROVED (post-revision)

Scope signal: M
Specialists: game-designer, systems-designer, qa-lead (structural analysis), creative-director
Blocking items: 5 (all resolved in-session) | Recommended: 8 (all addressed)
Summary: Initial verdict was MAJOR REVISION NEEDED. Five blocking items were identified: Verdant Regen role (unresolved pillar-level question), i-frame source discrimination (`apply_damage` signature could not distinguish CONTACT from DOT), missing `player_hp_critical` threshold signals, formula inconsistency between Rule 2 and Formulas section, and absence of a wave-level integration AC. All five were resolved in-session: Verdant role locked as C (combo-dependent value, 6 HP intentional); `DamageSource` enum added to `apply_damage` signature; two HP zone thresholds added (33 HP careful, 15 HP desperate) with `player_hp_careful` and `player_hp_desperate` signals; Rule 2 formula updated to match Formulas section; integration AC-HD-25 added. Eight recommended items also addressed including dead-target guard, 0-damage signal suppression, negative heal guard, simultaneous death ordering, node-lifetime guarantee, and signal type consistency.
Prior verdict resolved: First review
