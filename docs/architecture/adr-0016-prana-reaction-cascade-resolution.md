# ADR-0016: Prana Reaction & Cascade Resolution (data-driven matrix + generative cascade)

## Status

Accepted

> Accepted 2026-06-24 (solo dev). Additive, LOW knowledge risk, cleared `/design-review` (combination-resolution.md APPROVED) and `/consistency-check` (PASS). Unblocks reaction/cascade story creation and implementation.

## Date

2026-06-24

## Last Verified

2026-06-24

## Decision Makers

Kusuma Putra (solo dev) + Claude Code Game Studios

## Summary

Combination Resolution gains a fourth resolution layer — Prana Reactions (a data-driven element-pair matrix armed by cardinal grid adjacency) and a Cascade tier (a generative, core-anchored higher-order reaction). This ADR fixes the architecture: a single stateless `compute_recognition()` pure function — shared by the prep-phase preview and the `combat_started` resolution — produces `SpellEffect.active_reactions` and `active_cascade`, keeping preview and combat in lockstep and routing all application to Spell Casting & Effects.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Scripting / Core |
| **Knowledge Risk** | LOW — plain GDScript `Resource` subclasses, typed arrays, and a pure function over the existing `committed_fragments` array. No post-cutoff or rendering/physics APIs. |
| **References Consulted** | `design/gdd/combination-resolution.md` (Rules 16–17, Formulas 9–10), `design/gdd/prana-data.md`, ADR-0006 (GameEnums pure container), ADR-0009 (SC&E stat broker) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None engine-level. Behavioural verification is covered by AC-CR-30→44 (unit tests, no SceneTree). |

> **Note**: Knowledge Risk is LOW — no engine-version re-validation required on upgrade.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (GameEnums pure container — `ReactionKind` and the cascade facet routing live in / alongside `GameEnums`); ADR-0008 (Prana Catalog immutability — reactions read `base_damage_modifier`/`base_status` via the catalog) |
| **Enables** | Prana Grid live reaction/cascade preview; SC&E reaction & cascade application |
| **Blocks** | Epic: combination-resolution reaction work — no reaction/cascade `.gd` logic before this ADR is Accepted |
| **Ordering Note** | The `compute_recognition()` signature must be agreed before Prana Grid implements its preview, because both CR and Prana Grid call the same function — divergence reintroduces preview drift (the exact risk AC-CR-36 guards). |

## Context

### Problem Statement

The approved Combination Resolution GDD resolved three layers (primary tier, non-primary modifiers, adjacency effects). Playtesting intuition and design review surfaced that type *interactions* were generic and independent — a non-primary Voidblue behaves identically regardless of the primary type — leaving the "combinations" shallow and the Player-Fantasy promise ("Stormgold + Voidblue = silence before the strike") unfulfilled in the rules. A fourth layer was designed to add combinatorial depth that players *reason* about rather than memorise. That layer needs an architecture before any code is written, because it is consumed in two different phases (prep preview and combat resolution) and by a downstream system (SC&E).

### Current State

Combination Resolution resolves once per wave on `combat_started`, reading `committed_fragments: Array[PranaFragment]` and emitting a `SpellEffect` via `combo_resolved`. There is no prep-phase computation path and no notion of type-pair or core-anchored interaction. Prana Grid owns the in-progress (uncommitted) arrangement during Preparation.

### Constraints

- All resolution logic must be data-driven (project coding standard — no hardcoded gameplay values).
- Determinism: unit tests run headless with no SceneTree; the recognition logic must be a pure function of the fragment array (no timers, no RNG, no node state).
- ADR-0003 (signal-driven): CR must not poll; resolution is triggered by `combat_started`, preview by Prana Grid input events.
- Combat readability (Pillar 4 / cognitive-load risk): the on-screen number of distinct effects must stay bounded.
- The preview shown during prep MUST match what fires in combat for the same arrangement (Pillar 3 — no hidden logic).

### Requirements

- Reactions are keyed by an unordered Prana type pair and stored as external Resources (a data-driven matrix), not code.
- Cascades are computed generatively from a per-type facet table + a lead/modifier rule — no authored per-triad catalog (so the space scales with new types and requires no memorisation).
- One source of truth for recognition, callable both from the prep preview and from `combat_started` resolution.
- Output added to `SpellEffect` as `active_reactions` and `active_cascade`; SC&E owns all application.
- Cascade merges (consumes) the core↔neighbour pairwise reactions it supersedes, keeping clutter bounded.

## Decision

Introduce a **recognition layer** computed by a single stateless function and two new data types, with all application deferred to Spell Casting & Effects.

### Architecture

```
                    committed_fragments / working_fragments (Array[PranaFragment])
                                   │
        ┌──────────────────────────┴───────────────────────────┐
        │  CombinationResolution.compute_recognition(fragments) │  ← PURE, stateless
        │   1. scan cardinal-adjacent cross-type pairs          │
        │   2. lookup REACTION_MATRIX[sorted(a,b)] → ReactionDef │
        │   3. cascade: core (slot 4) neighbours → CascadeEffect │
        │   4. merge: remove core↔neighbour pairs from reactions │
        └───────────┬───────────────────────────────┬───────────┘
                    │ (prep phase)                  │ (combat_started)
                    ▼                               ▼
            Prana Grid preview            SpellEffect.active_reactions
            (live, on place/move)         SpellEffect.active_cascade
                                                   │ combo_resolved
                                                   ▼
                              Spell Casting & Effects (applies by
                              effect_kind / lead_type + modifiers)
```

### Key Interfaces

```gdscript
# game_enums.gd (ADR-0006 pure container) — explicit integer assignments (.tres stability)
enum ReactionKind {
    THERMAL_SHOCK = 0, DETONATE = 1, WITCHFIRE = 2, WILDFIRE = 3, SHORT_CIRCUIT = 4,
    WHITEOUT = 5, SIPHON = 6, SUPERCONDUCT = 7, SURGE = 8, PERMAFROST = 9,
}

# ReactionDef — external Resource, one per unordered pair (10 at MVP)
class_name ReactionDef extends Resource
@export var id: StringName
@export var name: String
@export var type_a: int          # lower type id
@export var type_b: int          # higher type id
@export var effect_kind: GameEnums.ReactionKind
@export var magnitude: float
@export var description: String

# CascadeEffect — produced at runtime (not authored)
class_name CascadeEffect extends RefCounted
var lead_type: int               # core type — sets burst shape
var modifiers: Array[int]        # 2–4 distinct neighbour types, sorted
var cascade_mult: float

# Stateless recognition — the single source of truth (Rule 16f / 17g / Formula 9 / 10)
static func compute_recognition(fragments: Array) -> Dictionary:
    # returns { "reactions": Array[ReactionDef], "cascade": CascadeEffect or null }
    # no node state, no RNG, no timers — pure function of `fragments`
```

### Implementation Guidelines

- `REACTION_MATRIX` is built once at load from the `ReactionDef` `.tres` files, keyed by `Vector2i(min(a,b), max(a,b))` (or an int `a*5+b`). Validate at load: `push_warning` once per defined-type pair that has no entry.
- `compute_recognition()` must be `static` (or live on a stateless helper) so Prana Grid can call it on its working arrangement without touching CR's cached `SpellEffect`. CR's `combat_started` handler calls the same function and copies the result into the emitted `SpellEffect`.
- Cascade is generative: a per-type facet table (lead shape + modifier facet) plus `cascade_mult = min(CASCADE_LEAD_MULT + |M|*CASCADE_MOD_DMG_BONUS, CASCADE_MULT_CAP)`. No `CascadeDef` resources — only tuning knobs.
- The merge step (Rule 17d) happens *inside* `compute_recognition()` so reactions and cascade are always mutually consistent in a single pass (no consumer can observe the un-merged intermediate).
- SC&E switches on `ReactionDef.effect_kind` and on `CascadeEffect.lead_type` + iterates `modifiers`; it owns the Thermal-Shock-vs-Shatter non-stacking rule (Formula 5 step 4).

## Alternatives Considered

### Alternative 1: Authored named-pattern catalog (the original "Glyph" proposal)

- **Description**: A fixed catalog of ~5 hand-authored grid patterns, each mapping to a named effect; matched by exact slot positions.
- **Pros**: Simple lookup; flavourful set-pieces.
- **Cons**: Shallow (memorise N recipes and you are done); **anti-experimentation** — an arrangement that does not match a recipe yields nothing, so players who do not know the recipes cannot reason their way in. Breaks the generative property of the existing layers.
- **Estimated Effort**: Low.
- **Rejection Reason**: Fails the core requirement — depth players *reason* about. Killed during design discussion in favour of a generative system.

### Alternative 2: Combat-side co-affliction reactions (Genshin-style, real-time)

- **Description**: Reactions trigger when two statuses from different types coexist on an enemy during combat.
- **Pros**: Cause and effect co-located on the enemy; generalises existing Shatter/Contagion immediately.
- **Cons**: Harder to unit-test (needs running SceneTree + timing); risks combat cognitive overload; the game's single-cast-per-wave structure blunts its dynamism.
- **Estimated Effort**: Medium–High.
- **Rejection Reason**: Deferred. The prep-adjacency model is deterministic, cheap, native to the prep-puzzle identity, and keeps combat readable. The combat-side vocabulary is reserved as a later unification of Shatter/Contagion/Follow-Through (GDD Rule 16h).

### Alternative 3: Duplicate the reaction logic in Prana Grid for the preview

- **Description**: Prana Grid computes its own preview independently of CR.
- **Pros**: No shared dependency.
- **Cons**: Two implementations drift; preview can silently disagree with what fires (violates Pillar 3).
- **Rejection Reason**: Rejected in favour of one shared stateless `compute_recognition()` (AC-CR-36 enforces parity).

## Consequences

### Positive

- Generative depth: 10 pairwise reactions + 50+ core-sensitive cascade variants from one rule, all reasoned from 5 element verbs — no recipe memorisation.
- Deterministic and unit-testable (pure function; AC-CR-30→44 need no SceneTree).
- Preview/combat parity guaranteed by construction (single function).
- Bounded clutter: cascade merge replaces up to four reaction icons with one.
- Fully data-driven matrix; adding a Prana type only requires new `ReactionDef` entries (cascade scales automatically).

### Negative

- New cross-system contract surface: Prana Grid (preview), SC&E (apply), Combat HUD (display) all take a dependency on the new fields.
- Combat cognitive load rises; mitigated by `MAX_ACTIVE_REACTIONS` and `MAX_CASCADE_MODIFIERS` knobs (the #1 playtest watch item).

### Neutral

- Existing Shatter/Contagion/Follow-Through remain combat-side and unchanged at MVP; a future ADR may re-express them in the reaction vocabulary.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Combat over-cluttered by stacked reactions/cascade | Medium | Medium | `MAX_ACTIVE_REACTIONS` (default unlimited) + cascade merge + `MAX_CASCADE_MODIFIERS`; tune at first reaction playtest |
| "Diversify maximally" becomes a dominant strategy | Low | Medium | Primary-tier opportunity cost (tall-vs-wide); cascade rewards core commitment, not flat diversity |
| Preview/combat logic drift | Low | High | Single stateless `compute_recognition()`; AC-CR-36 parity test |
| Generative cascade produces a degenerate combo at the multiplier cap | Low | Medium | `CASCADE_MULT_CAP` + `/balance-check` after tuning |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (frame time) | n/a | negligible — O(1): ≤12 cardinal edges + 4 core neighbours, scanned once per cast and once per grid edit | 16.6 ms/frame |
| Memory | n/a | ~10 small `ReactionDef` resources loaded once | < 512 MB |
| Load Time | n/a | +10 `.tres` loads at startup (negligible) | — |

Preview recomputation runs only on a grid place/move event (event-driven, ADR-0003), not per frame.

## Migration Plan

Additive — no existing behaviour changes.

1. Add `ReactionKind` enum to `game_enums.gd` (explicit integer assignments).
2. Author 10 `ReactionDef` `.tres` files + `REACTION_MATRIX` loader with load-time validation.
3. Implement static `compute_recognition()` (reactions + cascade + merge) with AC-CR-30→44 as the test gate.
4. Add `active_reactions` / `active_cascade` to `SpellEffect`; wire CR's `combat_started` handler to populate them.
5. Prana Grid calls `compute_recognition()` on place/move for the live preview.
6. SC&E consumes the new fields (separate SC&E story).

**Rollback plan**: The layer is additive and gated behind the new `SpellEffect` fields. Reverting means leaving `active_reactions` empty and `active_cascade` null — the three original layers resolve exactly as before.

## Validation Criteria

- [ ] AC-CR-30→44 pass (reaction arming, dedup, ordering, cascade lead/modifier, core-sensitivity, merge-vs-ring, corner exclusion).
- [ ] `compute_recognition()` is pure — same input yields identical output with no node/SceneTree dependency (AC-CR-36).
- [ ] Prana Grid preview and `combat_started` resolution produce identical recognition for the same arrangement.
- [ ] `REACTION_MATRIX` load-time validation warns on any missing defined-type pair.
- [ ] First reaction playtest confirms combat remains readable at typical (2–3 reaction) builds.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/combination-resolution.md` | Combination Resolution | Rule 16 — Prana Reaction layer (data-driven, adjacency-armed, previewed) | Data-driven `REACTION_MATRIX` of `ReactionDef` resources, armed in the stateless `compute_recognition()` |
| `design/gdd/combination-resolution.md` | Combination Resolution | Rule 17 / Formula 10 — generative core-sensitive Cascade | Per-type facet table + lead/modifier rule computed at runtime (no authored catalog); merge step inside the pure function |
| `design/gdd/combination-resolution.md` | Combination Resolution | Rule 16f / 17g — live prep preview matching combat | Single stateless function shared by Prana Grid preview and CR resolution |
| `design/gdd/combination-resolution.md` | Spell Casting & Effects | `SpellEffect.active_reactions` + `active_cascade` application contract | New typed fields on `SpellEffect`; SC&E switches on `effect_kind` / `lead_type` + `modifiers` |

## Related

- Extends: `design/gdd/combination-resolution.md` (Rules 16–17, Formulas 9–10, AC-CR-30→44)
- Depends on: ADR-0006 (GameEnums pure container), ADR-0008 (Prana Catalog immutability)
- Related: ADR-0009 (SC&E stat broker — SC&E remains the single application/broker point for reaction & cascade effects)
