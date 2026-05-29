# Cross-GDD Review Report

**Date:** 2026-05-29
**Mode:** full (consistency + design theory + cross-system scenarios) — **re-run after B-1/B-2 errata**
**GDDs Reviewed:** 14 system GDDs (+ game-concept, systems-index, entities.yaml registry)
**Systems Covered:** Prana Data, Enemy Data, Game State & Scene Flow, Health & Damage, Player Controller, Prana Grid, Combination Resolution, Spell Casting & Effects, Status Effects, Enemy AI, Wave/Encounter System, Combat HUD, Run Management, Audio System

> This report supersedes the earlier FAIL report of the same date. Both blocking
> issues (B-1, B-2) and one warning (W-8) have been resolved and verified against the
> revised `game-state-scene-flow.md` and `health-damage.md`. Git confirms only those two
> GDDs (plus their review logs and the systems index) changed since the prior full
> review, so all remaining warnings carry forward unchanged.

Registry baseline loaded: 9 entities, 4 formulas, 17 constants. Shared constant values
(FAYDE_MAX_HP=100, base_spell_damage=20, stun 0.8s, freeze 2.0s/0.50, burn 0.08×4 ticks,
enemy HP/damage/speed) are **consistent** across all GDDs and the registry — no value drift found.

---

## Resolved Since Prior Review

**B-1 — RESOLVED ✅** — `game-state-scene-flow.md` now defines `arrangement_confirmed`
as a first-class consumed input event:
- Core Rule 2 names it explicitly as an input event with a required emitting-side GDD entry.
- MVP valid-transitions table: PREPARATION_PHASE → COMBAT_PHASE trigger is now
  `arrangement_confirmed` (loadout validated via Prana Grid `is_loadout_valid()`).
- New **Consumed Input Events** table lists it with handler `_on_arrangement_confirmed()`.
- The most important transition in the game now has a named signal contract on the
  system that owns transitions.

**B-2 — RESOLVED ✅** — Same-frame kill+death now resolves as LOSS, and both GDDs agree:
- `game-state-scene-flow.md` adds a **Signal Ordering: Same-Frame Death Priority** section:
  the `boss_defeated → RUN_SUMMARY` transition executes via `call_deferred`, so a same-frame
  `_on_player_died()` runs immediately and reaches `DEATH_SCREEN` before the deferred WIN
  fires; the deferred WIN is then rejected by the valid-transition table. The Edge Case now
  reads "Loss takes priority"; the old "first transition wins → WIN" wording is removed.
  Tested by AC-01c.
- `health-damage.md` Rule 5 cross-references the exact mechanism; Open Q5 is marked Resolved
  with the same `call_deferred` description. The two documents no longer prescribe opposite
  outcomes for the identical event.

**W-8 — RESOLVED ✅** — `game-state-scene-flow.md` confirm rule now defers to Prana Grid's
`is_loadout_valid()` (slot 4 / centre non-null required), replacing the insufficient
"≥1 slot filled" heuristic. No longer contradicts Prana Grid Rule 6 / Combination Resolution.
(Transition table, Forbidden Transitions, and AC-05 all updated.)

---

## Consistency Issues

### 🔴 Blocking (must resolve before architecture begins)

**None.** Both prior blockers (B-1, B-2) resolved and verified above.

### ⚠️ Warnings (should resolve; not architecture-blocking — carried forward)

**W-1 — `spell_hit_element` signal consumed by Combat HUD does not exist in SC&E** —
`combat-hud.md` (Rule 7, AC-HUD-14) listens for `SpellCastingEffects.spell_hit_element(target,
prana_type_id)` for damage-number coloring and flags "SC&E GDD update required."
`spell-casting-effects.md` does not define or emit it. One-directional dependency (FP scope).

**W-2 — `cast_hit_started` / CAST_LOCKED not added to Player Controller** —
`spell-casting-effects.md` Rule 6 emits `cast_hit_started(lock_duration)` and requires Player
Controller to listen and add a CAST_LOCKED movement sub-state. `player-controller.md` has only
DISABLED/ENABLED/DASHING; its Interactions table lists SC&E only as *reading* position/facing.
The cast-lock movement coupling is unimplemented on the PC side.

**W-3 — Status Effects ↔ Enemy AI interface name mismatch** — `status-effects.md` calls
`target.set_freeze_state(bool)` / `target.set_stun_state(bool)`. `enemy-ai.md` (Downstream #7)
expects to expose `apply_speed_modifier(multiplier)` / `apply_stun(duration)`. Different names and
shapes. The Freeze 50% slow is described two ways (binary `set_freeze_state` vs. `effective_move_speed`
with `slow_percentage=0.50`) with no defined interface to convey the 0.50. Reconcile before MVP.

**W-4 — Stun/Freeze concurrency (pause model) specified in Prana Data is unimplemented in its owner** —
`prana-data.md` defines Stun-pauses-Freeze with ACs (PD-28, PD-35) and transfers ownership to Status
Effects. `status-effects.md` ships Stun as a **stub** ("duration only") and never implements or
mentions the pause interaction. A Frozen+Stunned enemy (both reachable at MVP) has undefined timer
behavior despite Prana Data's detailed spec.

**W-5 — Orphan statuses: STAGGER and CHILL have no owning system** —
`combination-resolution.md`/`spell-casting-effects.md` apply `STATUS_STAGGER` (Voidblue T2) and
`STATUS_CHILL` (Deepfrost non-primary). Neither is in `GameEnums.BaseStatus`
(BURN/BLIND/STUN/FREEZE/REGENERATE), and `status-effects.md` — the declared tick/duration authority —
handles neither. No system tracks their duration or enforces their effect.

**W-6 — Burn-magnitude modifiers cannot pass through the `apply_status` interface** —
`combination-resolution.md` defines `ADJ_BURN_INTENSIFY` (+0.04) and `ASH_BURN_TICK` (+0.06) that
should raise `burn_tick_magnitude`. `status-effects.md`
`apply_status(target, status_type, duration, spell_base_damage)` has no parameter to carry a modified
tick magnitude — ticks always use the constant 0.08. The combined burn cap (`magnitude × ticks ≤ 0.60`)
is delegated to Status Effects but cannot be applied or enforced through the current interface. (VS scope.)

**W-7 — `VER_HEAL_FLAT` application path is ambiguous** — `combination-resolution.md` Rule 11c says
H&D queries SC&E for heal-modifying stats during `apply_heal()`; Formula 8 says VER_HEAL_FLAT applies
to "Regen ticks, Lifesteal, Injury Bloom." But Regen ticks flow Status Effects → `H&D.apply_heal()`
directly, bypassing SC&E's broker, and `health-damage.md` `apply_heal` does not query SC&E. SC&E only
adds the bonus on its own `apply_heal` calls, so Regen-tick VER_HEAL_FLAT is silently dropped. (VS scope.)

### ℹ️ Info (stale references / cosmetic — carried forward)

- **Stale flags in `spell-casting-effects.md`**: repeated "⚠ CR GDD update required: Ashfire attack
  descriptions must be revised." `combination-resolution.md` Formula 5 Type 0 **already** uses the
  melee-dance / `AREA_AROUND_FAYDE` identity (both docs dated 2026-05-28). Flags are resolved-but-not-removed.
- `enemy-ai.md` Open Q2 (arena dims for AGGRO_RADIUS) is resolved by `wave-encounter-system.md` Rule 8
  but remains open in Enemy AI.
- `combination-resolution.md` Rule 11c describes Status Effects *querying* SC&E for status durations;
  the actual flow has SC&E pre-compute durations (Formula 7) and pass them via `apply_status`.
- `wave-encounter-system.md` Rule 2 labels per-type "threat value = 3/4/5" (these are count×value
  subtotals, not per-unit 1/2/1). Formula 1 is correct; the Rule 2 labels mislead.
- `audio-system.md` lists `PREPARATION → DYING`, but `game-state-scene-flow.md` only emits
  `death_started` from COMBAT (Fayde can't die in PREP). Defensive/harmless.

---

## Game Design Issues (carried forward)

### ⚠️ Warnings

**D-1 — At First Playable, 2 of 5 Prana types are mechanically dominated (Pillar 4 risk)** —
`enemy-data.md` Open Q1/Q2 confirm no Deepfrost- or Verdant-affiliated enemy exists at FP. SC&E
Step 9 grants the 2× affiliation bonus only to the primary type matching an enemy's affiliation. So
centering Deepfrost (0.80 mod) or Verdant (0.70 mod) never earns the affiliation payoff at FP, and
their control/sustain value is muted (Status Effects Freeze is MVP-only; Verdant heal is 6 HP).
Two of five types are trap picks in the only FP content.

**D-2 — The single FP wave does not satisfy Prana Data's all-Ashfire pre-implementation gate** —
`prana-data.md` Known Design Tensions defines a BLOCKING pre-implementation gate: ≥30% of MVP waves
must actively disincentivize all-Ashfire play, owned by Wave/Encounter GDD.
`wave-encounter-system.md` defines exactly one hardcoded FP wave whose highest-threat enemy (Charger)
is **Ashfire-affiliated** — i.e., Ashfire double-hits the enemy that matters most. Ashfire is already
1.57 effective vs. 1.15 (Stormgold). The FP wave tends to demonstrate Ashfire dominance rather than
counter it. The gate is unmet at FP scope.

**D-3 — Combo-chain timing trends toward the anti-APM pillar (monitor)** — `game-concept.md`
anti-pillar: "NOT an APM game… Execution tests positioning and timing, not UI management under
pressure." CR + SC&E layer `combo_continuation_window`, per-hit cast-lock, a 1.5s follow-through
window, and dash timing. At FP (lv.1 fragments, 2.0s window) this is within tolerance and the grid is
locked pre-combat, but the stacking timing windows warrant a playtest watch — keep
`combo_continuation_window` generous for the 7+ audience.

---

## Cross-System Scenario Issues

Scenarios re-walked: **4** — (1) confirm→combat→cast chain; (2) FP wave clear→auto-boss-skip;
(3) same-frame kill+death; (4) Shatter on a Frozen enemy at FP.

### 🔴 Blockers
- **None.** The same-frame kill+death scenario (prior B-2 blocker) now resolves correctly as a
  LOSS via Game State's deferred WIN transition. Run Management records a death, not a victory.

### ⚠️ Warnings
- **FP auto-boss-skip emits a zero-duration boss combat** — Wave / Game State / Audio / Player
  Controller. `all_waves_cleared` and `boss_defeated` fire in the same handler: Game State
  self-transitions COMBAT→COMBAT with `combat_started(is_boss:true)`, then (deferred)
  COMBAT→RUN_SUMMARY. Wave System guards the spurious `is_boss:true` (no-op + warning), but Audio
  (`combat_started` while already COMBAT) and Player Controller (ENABLED re-entry then `run_ended`)
  are not explicitly tested for a zero-frame boss entry. Verify downstream tolerance.
- **Shatter depends on Freeze, but Freeze enforcement is MVP while SC&E runs Shatter at FP** — SC&E
  Step 5 (`target.has_status(STATUS_FREEZE)`) is in the FP damage chain, but Enemy AI freeze/root is
  "not applicable at FP" and Status Effects is MVP. At FP, `has_status` has no defined owner and the
  enemy isn't actually rooted — Shatter is inert or undefined. FP scope boundary is fuzzy.

### ℹ️ Info
- **Confirm→combat→cast (happy path)** — now clean end-to-end: `arrangement_confirmed` →
  `_on_arrangement_confirmed()` validates via `is_loadout_valid()` → `grid_locked` →
  `combat_started` → CR SpellEffect → SC&E chain → H&D → `enemy_killed` → Wave. B-1 resolution
  closes the previously-undefined trigger.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| spell-casting-effects.md | Missing `spell_hit_element` signal (W-1); stale CR-revision flags; Shatter@FP boundary | Consistency | Warning |
| player-controller.md | No `cast_hit_started` listener / CAST_LOCKED sub-state (W-2) | Consistency | Warning |
| status-effects.md | Enemy AI interface mismatch (W-3); Stun/Freeze pause unimplemented (W-4); STAGGER/CHILL unowned (W-5); burn-modifier interface gap (W-6) | Consistency | Warning |
| enemy-ai.md | Freeze/Stun interface naming reconciliation (W-3) | Consistency | Warning |
| combination-resolution.md | VER_HEAL_FLAT path (W-7); Rule 11c duration-query text vs. flow | Consistency | Warning |
| combat-hud.md | Depends on `spell_hit_element` (resolves when SC&E adds W-1) | Consistency | Warning |
| wave-encounter-system.md | FP wave doesn't meet all-Ashfire gate (D-2); threat-label wording | Design / Consistency | Warning |

**Cleared:** `game-state-scene-flow.md` and `health-damage.md` — both blockers resolved; both
remain `Approved` in the systems index.

---

## Verdict: CONCERNS

No blocking issues remain. Both B-1 and B-2 are resolved and the two affected GDDs now agree.
Architecture can begin on the Foundation/Core spine — Game State & Scene Flow and Health & Damage
are clean.

The remaining warnings are genuine interface gaps that should be reconciled before architecting the
specific systems that own them, but they do not block starting architecture:
- **FP/MVP-relevant** (resolve before architecting those systems): W-1, W-2, W-3, W-5.
- **VS-scoped** (resolve before Vertical Slice): W-6, W-7.
- **FP balance** (resolve before first playtest): D-1, D-2.

**Highest-leverage next action:** reconcile the **W-3 / W-5 status-effects interface cluster**, since
three FP systems (Status Effects, Enemy AI, Spell Casting & Effects) share those currently-undefined
interfaces — resolving them once unblocks all three.
