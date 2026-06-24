## CascadeEffect — A core-anchored higher-order Prana Reaction (GDD Rule 17 / Formula 10).
##
## Produced at runtime by CombinationResolution.compute_recognition() — NOT authored as a
## resource. A Cascade fires when the grid core (slot 4) has ≥2 distinct cardinal-neighbor
## types. The `lead_type` (core) sets the burst's shape; each `modifiers` entry attaches an
## element facet. This is generative: there is no authored per-triad catalog — the effect is
## computed from one rule, so the same set of types yields a different Cascade depending on
## which type is the core (core-sensitivity, Rule 17c).
##
## RefCounted (not Resource) by design (ADR-0016): it is wave-scoped runtime output stored on
## SpellEffect.active_cascade and never serialized. SpellCastingEffects reads `lead_type` for
## the burst shape, iterates `modifiers` for facets, and applies `cascade_mult` to the burst
## damage (Formula 10).
class_name CascadeEffect
extends RefCounted

## Core (slot 4) type id (0–4). Sets the Cascade burst's shape/identity (the "lead").
var lead_type: int = -1

## Distinct cardinal-neighbor type ids feeding the Cascade, sorted ascending (2–4 entries).
## Each attaches its element facet to the burst. Deduplicated (set semantics, Rule 17e).
var modifiers: Array[int] = []

## Damage multiplier applied to the Cascade burst.
## = min(CASCADE_LEAD_MULT + |modifiers| × CASCADE_MOD_DMG_BONUS, CASCADE_MULT_CAP).
var cascade_mult: float = 1.0
