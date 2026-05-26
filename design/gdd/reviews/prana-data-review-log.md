# Review Log: Prana Data

## Review — 2026-05-26 — Verdict: MAJOR REVISION NEEDED

Scope signal: L
Specialists: game-designer, systems-designer, qa-lead, godot-gdscript-specialist, creative-director
Blocking items: 5 | Recommended: 7 | Nice-to-have: 6
Summary: The design's depth and specification quality are strong, but two game pillars are actively undermined by the blocking items. Blocker #1 (Regen int() truncation) is a silent off-by-up-to-50% heal defect caused by a contract mismatch between Prana Data's formula and Health & Damage's apply_heal implementation. Blockers #2 and #4 (Stun re-application feedback void and Layer 2 no fallback signal) contradict Pillars 3 and 2 respectively. Blocker #3 (Shatter multiplier order unspecified) risks a triple-stacking one-shot combo against the Charger. Blocker #5 (AC type tag omissions on PD-24/25/30) routes timer-based tests to the wrong CI gate. All five blockers are targeted and resolvable in one revision session.
Prior verdict resolved: N/A — first formal review
