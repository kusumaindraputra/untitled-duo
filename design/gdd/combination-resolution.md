# Combination Resolution

> **Status**: Approved (2026-05-29)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-28
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding), Pillar 3 (Chaos Has Consequences), Pillar 4 (Depth Over Breadth)

## Overview

Combination Resolution is the logic layer that transforms the player's committed Prana Fragment arrangement into spell effect data for each wave. After `combat_started` fires, Combination Resolution reads `committed_fragments: Array[PranaFragment]` (length 9, null = empty slot) from Prana Grid — each fragment carrying a Prana `type_id`, a `level`, a random `stat_property`, and an array of random `adjacency_effects` — and resolves the arrangement into a `SpellEffect` payload delivered to Spell Casting & Effects via the `combo_resolved` signal.

Resolution operates on four simultaneous layers. The **primary layer**: the fragment in slot 4 (centre) determines the attack identity; the sum of all same-type fragment levels across all slots determines the primary tier (tier 1 = 1 attack, tier 2 = 2-attack chain, tier 3 = 3-attack chain), with each tier unlocking stronger type-specific effects. The **non-primary layer**: fragments of different types in non-centre slots each contribute modifier effects independently — multiple non-primary types stack simultaneously, each scaling by its own effective fill count. The **adjacency layer**: each fragment can carry N random conditional effects (N = fragment level) that fire only when specified cardinal neighbors (above, below, left, right) contain required Prana types; triggered effects are collected from all fragments and passed into the SpellEffect. The **reaction layer**: when two *different* Prana types occupy cardinally adjacent slots, their element pairing arms a named **Prana Reaction** (one per unordered type pair, drawn from a 10-entry Reaction Matrix); multiple reactions can arm simultaneously, are previewed live in the Preparation Phase grid, and are applied additively on top of the other three layers. When the core is flanked by two or more distinct neighbor types, those core-adjacent reactions merge into a single core-led **Cascade** — the recognition layer's higher-order tier.

Each fragment also contributes a `stat_property` bonus (always active, regardless of neighbors) that is summed into `aggregate_stat_bonus` in the payload. The player begins each run with one level-1 fragment of their chosen Core Prana pre-placed in the centre slot; subsequent fragments are collected as enemy drops during the run. All resolution logic is data-driven — primary tier effects, non-primary modifier effects, the adjacency `EffectModifier` pool, and stat property values are stored in external Resources, never hardcoded.

The fantasy the system delivers is the moment of confirmation: the arrangement the player spent 5–15 seconds constructing in Preparation Phase resolves into exactly what they intended — or exactly what they failed to anticipate.

## Player Fantasy

> *`creative-director` not consulted — Lean mode. Review manually before production.*

Combination Resolution is where the player's thinking becomes visible. During Preparation Phase, the player built a plan: *Deepfrost in the centre to root the Charger, Ashfire on all four cardinal neighbours to burn through the pack the moment it's trapped.* The fantasy delivered by this system is the moment that plan fires — and the player finds out if they understood the system well enough.

When the combo resolves cleanly — when Deepfrost locks the wave exactly as planned and the Ashfire neighbours light them up in sequence — the satisfaction belongs entirely to the player. They figured it out. The system gave them the tools; they made the decision. This is the emotional core of Pillar 2: *"Power is Earned Through Understanding."*

The first-discovery version of this fantasy is arguably stronger. A player who stumbles into a pairing they hadn't used before — Stormgold centre with Voidblue corners producing something unexpected — and sees the result land perfectly will pause the game to think about why. That pause is the system working. The combination table should be designed so that the first time a player sees a new named combination fire, they feel surprised and then immediately understand why it worked. *"Of course lightning plus shadow makes that — silence before the strike."*

The failure version matters equally. An arrangement that produced a weak or wrong outcome — the wrong type in the centre against a wave the player misread — must resolve with enough legibility that the player can diagnose their mistake during the cast animation. *"I should have put Stormgold in centre, not the corner. The interrupt never triggered because my primary was Ashfire."* The combination the player sees fire is the combination they built. No hidden logic, no silent failure — exactly Pillar 3's contract.

The system serves two player types simultaneously: the player who reads all 10 named combination tooltips before their first run, and the player who discovers every combo by accident over 20 runs. Both should arrive at the same mastery, through different paths.

## Detailed Design

> *Specialist agents not consulted — Lean mode. Review manually before production.*

### Core Rules

**1. PranaFragment data model.** Each grid slot holds one `PranaFragment` with four properties:

| Property | Type | Description |
|----------|------|-------------|
| `type_id` | `int` (0–4) | Which Prana type this fragment is |
| `level` | `int` (≥ 1) | Determines tier weight AND how many adjacency effects it carries |
| `stat_property` | `StatProperty` | One random stat bonus (e.g., damage +10, armor +2); **always active** when the fragment is placed in the grid, regardless of neighbors |
| `adjacency_effects` | `Array[AdjacencyEffect]` | N random conditional effects where **N = level**; each fires only when its spatial conditions are met |

A lv.1 fragment carries 1 adjacency effect. A lv.3 fragment carries 3 independent adjacency effects. Each `AdjacencyEffect` has:

| Sub-property | Type | Description |
|-------------|------|-------------|
| `required_neighbors` | `Array[NeighborCondition]` | All conditions must be satisfied simultaneously (AND logic) |
| `effect` | `EffectModifier` | What fires when all conditions are met |

Each `NeighborCondition`:

| Sub-property | Type | Description |
|-------------|------|-------------|
| `direction` | `enum` (ABOVE, BELOW, LEFT, RIGHT) | Which of the four cardinal neighbors must match |
| `required_type_id` | `int` (0–4, or –1 = any type) | Which Prana type must occupy that neighbor slot |

**2. Centre slot is required; centre type is the primary type.** Slot 4 must contain a fragment before Confirm is accepted (Prana Grid enforces this). The `type_id` of slot 4's fragment is the primary type for this wave.

**3. Effective primary count.** Sum the `level` values of all fragments whose `type_id` matches the primary type across all 9 slots:

`effective_primary_count = Σ fragment[i].level  for all i where fragment[i].type_id == primary_type`

**4. Primary tier** (from effective primary count):

| Effective primary count | Tier | Combo attacks |
|------------------------|------|--------------|
| 1–2 | Tier 1 | 1 attack |
| 3–5 | Tier 2 | 2 attacks |
| 6+ | Tier 3 | 3 attacks |

**5. Non-primary effective count** (per type). For each non-centre slot containing a non-primary type, sum those fragments' levels independently per type:

`effective_nonprimary_count(T) = Σ fragment[i].level  for all i ≠ 4 where fragment[i].type_id == T`

**6. Non-primary tier** (per type):

| Effective non-primary count | Tier |
|---------------------------|------|
| 0 | Inactive |
| 1–2 | Tier 1 — base modifier |
| 3+ | Tier 2 — enhanced modifier |

**7. Multiple non-primaries stack.** All non-primary types meeting the threshold contribute simultaneously. Per-type non-primary effects are defined in Section D.

**8. Adjacency effect resolution.** After computing primary and non-primary tiers, Combination Resolution evaluates each fragment's adjacency effects:

```
for each slot i (0–8) where fragment[i] exists:
    for each adjacency_effect in fragment[i].adjacency_effects:
        satisfied = true
        # Empty required_neighbors array = vacuously satisfied = always triggers
        # (used by ADJ_DOUBLE_HIT — no spatial condition)
        for each condition in adjacency_effect.required_neighbors:
            neighbor_slot = get_cardinal_neighbor(i, condition.direction)
            if neighbor_slot does not exist (out of grid bounds):
                satisfied = false; break
            if fragment[neighbor_slot] is null:
                satisfied = false; break
            if condition.required_type_id != –1 and fragment[neighbor_slot].type_id != condition.required_type_id:
                satisfied = false; break
        if satisfied:
            add adjacency_effect.effect to active_adjacency_effects
```

All triggered effects across all fragments are collected. They are applied simultaneously — no priority ordering among adjacency effects (Section D defines conflict resolution when two effects modify the same attack).

**9. Cardinal neighbor lookup.** Slot index `i` maps to row `r = i / 3` (integer division), col `c = i % 3`.

| Direction | Neighbor slot index | Valid only if |
|-----------|-------------------|---------------|
| ABOVE | `i – 3` | `r > 0` |
| BELOW | `i + 3` | `r < 2` |
| LEFT | `i – 1` | `c > 0` |
| RIGHT | `i + 1` | `c < 2` |

A fragment at a grid edge or corner cannot satisfy conditions whose required direction points out of bounds — those adjacency effects can never trigger from those positions. This is intentional design pressure: position choice matters for activating adjacency effects.

**10. Fragment stat aggregation.** Every placed fragment's `stat_property` is summed into `aggregate_stat_bonus` regardless of adjacency. Adjacency effects that contain additional stat bonuses (`EffectModifier` of type STAT_BONUS) are added only if their conditions are met.

**11. SpellEffect payload:**

| Field | Type | Description |
|-------|------|-------------|
| `primary_type` | `int` (0–4) | Type ID of centre fragment |
| `primary_tier` | `int` (1–3) | From effective primary count |
| `base_damage_modifier` | `float` | From `PranaCatalog.get_type(primary_type).base_damage_modifier` |
| `aggregate_stat_bonus` | `Dictionary[StringName, float]` | Summed stat_property values from all fragments + any triggered STAT_BONUS adjacency effects |
| `primary_base_status` | `GameEnums.BaseStatus` | Primary type's `base_status`; **SC&E MUST apply this on every primary attack regardless of `non_primary_modifiers` content** |
| `non_primary_modifiers` | `Array[NonPrimaryModifier]` | One entry per active non-primary type |
| `active_adjacency_effects` | `Array[EffectModifier]` | All adjacency effects whose conditions were satisfied this wave |
| `active_reactions` | `Array[ReactionDef]` | All Prana Reactions armed this wave (one per distinct cardinally-adjacent cross-type pair); empty if no two different types are cardinally adjacent. SC&E applies each by `effect_kind`. See Rule 16 and Formula 9. |
| `active_cascade` | `CascadeEffect` | The core-anchored Cascade for this wave, or null if the core has fewer than 2 distinct neighbor types. When present, the core↔neighbor pairwise reactions it consumes are absent from `active_reactions`. See Rule 17 and Formula 10. |

**11b. NonPrimaryModifier schema.** Each entry in `non_primary_modifiers` is a typed struct:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `type_id` | `int` (0–4) | — | Which Prana type this modifier represents |
| `tier` | `int` (1–2) | — | 1 = base modifier; 2 = enhanced modifier |
| `burn_bonus` | `float` | `0.0` | Ashfire T2 additive `ASHFIRE_NP_BONUS` to primary's `base_damage_modifier`; 0.0 if not Ashfire T2 |
| `window_extension` | `float` | `0.0` | Stormgold T1 `combo_continuation_window` extension in seconds; 0.0 if not active |
| `final_attack_stun` | `bool` | `false` | Stormgold T2: true if final chain attack applies Stun (0.8s) |
| `heal_amplifier` | `float` | `1.0` | Verdant T2 heal amplifier on all healing during active Regen window; 1.0 = no amplification |
| `freeze_duration` | `float` | `0.0` | Deepfrost T2 non-primary Freeze duration in seconds; 0.0 if not Deepfrost T2 |
| `chill_slow_pct` | `float` | `0.0` | Deepfrost T1/T2 Chill slow fraction; 0.0 if not active |

Unused fields take their default values — Spell Casting reads only the relevant field per `type_id`. For example, a Verdant T1 modifier has `type_id=4, tier=1, heal_amplifier=1.0` (no amplification at T1) and all other fields at default.

**11c. Stat delivery contract.** `aggregate_stat_bonus` and `non_primary_modifiers` are wave-scoped payloads: Spell Casting & Effects receives `SpellEffect` at `combo_resolved`, caches the full payload for the wave duration, and is responsible for providing relevant stat values to downstream systems on request:

- Status Effects queries SC&E for status-modifying stats (e.g., `FROST_FREEZE_DUR`, `VOID_BLIND_DUR`, `STORM_STUN_DUR`) when applying a status — SC&E returns the delta from `aggregate_stat_bonus`.
- Health & Damage queries SC&E for heal-modifying stats (e.g., `VER_HEAL_FLAT`) when `apply_heal()` is called during the wave — SC&E returns the flat bonus to add.
- `VOID_MISS_CHANCE` and `ASH_CRIT` are read by SC&E directly when executing chain attacks.
- `STORM_COMBO_SPD` is applied to the `combo_continuation_window` at wave start alongside any window extensions from `non_primary_modifiers`.
- SC&E clears its cached payload on `preparation_started`.

This makes SC&E the single stat broker for the wave. No system reads `aggregate_stat_bonus` directly from SpellEffect outside SC&E.

**12. Combo chain.** Sequential with `combo_continuation_window` timing window (Hades Gauntlet model); missing the window resets to first attack. Chain state owned by Spell Casting & Effects.

**13. Core Prana run start.** Player picks one Prana type as Core at run start. Begins wave 1 with 1 lv.1 fragment of that type in the centre slot.

**14. All data is data-driven.** Primary/non-primary effect tables, `EffectModifier` pool, stat property tables, adjacency effect generation rules — all in external Resource files.

**15. All-empty handling.** Cannot occur in normal play. If received: `push_error()`, emit `combo_resolved` with `primary_type = –1`, Spell Casting treats as no-op.

**16. Prana Reaction layer (recognition).** After the primary, non-primary, and adjacency layers resolve, CR scans `committed_fragments` for cardinally adjacent pairs of *different* Prana types and arms a **Prana Reaction** for each distinct unordered type pair present.

- **16a. Reaction Matrix.** Each of the 10 unordered type pairs maps to exactly one `ReactionDef` (full matrix in Formula 9). The matrix is data-driven (external Resource), keyed by the sorted `(type_a, type_b)` pair. A pair with no matrix entry arms nothing — all 10 are defined at MVP, so this cannot occur until new types are added.
- **16b. Trigger = cardinal adjacency.** A reaction arms when at least one cardinally adjacent (ABOVE/BELOW/LEFT/RIGHT, per Rule 9) pair of its two types exists anywhere in the grid. The centre slot is NOT excluded — a reaction may involve the primary type. Diagonal adjacency does NOT arm a reaction.
- **16c. Dedup by pair.** Each distinct type pair arms its reaction at most once per wave, regardless of how many adjacent instances exist. Intensity scaling by adjacency count is out of MVP scope (VS extension).
- **16d. Multiple reactions stack.** Unlike a single-winner model, all armed reactions are added to `active_reactions` and applied additively — this is the intended combinatorial depth. An optional `MAX_ACTIVE_REACTIONS` cap (Tuning Knobs) drops excess by ascending pair id if playtest reveals combat overload; uncapped at MVP.
- **16e. Reasoned, not memorized.** Each reaction is derived from the two elements' identities (IGNITE / SUPPRESS / CHAIN / BIND / NOURISH) so players predict outcomes from principle. Reactions are NOT hidden — they are previewed in the Preparation grid (Rule 16f), satisfying Pillar 3 (no hidden logic).
- **16f. Preview contract.** Prana Grid (Preparation Phase) MUST display every currently-armed reaction live as the player arranges fragments, updating on each placement/move, by calling the stateless `CombinationResolution.compute_reactions(fragments) -> Array[ReactionDef]`. This makes the grid self-teaching: rearrange → see the preview change → understand. Combat HUD MAY also surface armed reactions during the LOCKED/combat state. Cross-GDD contract — see Interactions and Dependencies.
- **16g. Effects reuse existing primitives.** Every MVP reaction is expressed in terms of mechanics already specified elsewhere (Burn, Blind, Stun, Freeze, Shatter, lifesteal, AoE splash, chain arc, combo-window extension, heal amplification) to bound implementation and balance cost. SC&E owns application, switching on each `ReactionDef.effect_kind`.
- **16h. Relationship to conditional depth behaviors.** Shatter, Burn Contagion, and Lightning Follow-Through (Prana Data Core Rule 7) are combat-side proto-reactions; they remain unchanged at MVP. Design intent: a later tier re-expresses them under the same Reaction vocabulary so prep-side and combat-side reactions share one language. No refactor at MVP.

**17. Cascade tier (core-anchored higher-order reaction).** When the core (slot 4) is flanked by two or more *distinct* neighbor types, the individual core↔neighbor reactions merge into a single **Cascade** — a core-led burst. The Cascade is the recognition layer's higher-order tier; it does not add a fifth resolution layer.

- **17a. Trigger.** Let `core_type = fragment[4].type_id`. Let `M` = the set of distinct `type_id`s among the four cardinal neighbors of slot 4 (slots 1, 3, 5, 7) that are non-null and ≠ `core_type`. A Cascade fires iff `|M| ≥ 2`. If `|M| == 1`, no Cascade fires and the single core↔neighbor pairwise reaction applies normally (Rule 16). If `|M| == 0`, neither fires.
- **17b. Lead and modifiers.** The Cascade's **lead** is `core_type` (it sets the burst's shape/identity); its **modifiers** are the types in `M` (each attaches its element facet to the burst). Up to 4 modifiers (`MAX_CASCADE_MODIFIERS = 4`, Tuning Knobs).
- **17c. Core-sensitive identity (generative).** The same set of types produces a *different* Cascade depending on which is the core, because the lead sets the burst shape while modifiers only flavor it. There is no authored cascade catalog — the effect is computed from one rule (Formula 10). 5 leads × modifier combinations yield 30+ predictable variants.
- **17d. Merge / replacement.** A firing Cascade **consumes** the core↔neighbor pairwise reactions for the types in `M` — they are NOT also emitted into `active_reactions` (one Cascade replaces up to four small reaction icons; clutter stays bounded). The four core-neighbor slots are mutually diagonal, so no neighbor↔neighbor pairwise reaction exists among them. Ring↔ring pairwise reactions in non-core slots are unaffected and resolve independently.
- **17e. Duplicate neighbor types.** A type occupying more than one neighbor slot contributes one modifier (set semantics) but still counts in full toward primary / non-primary tier (Formulas 1–4).
- **17f. Spatial language.** The core's cardinal cross (slots 1/3/5/7) is the Cascade engine; the corners (slots 0/2/6/8) never feed the Cascade — they serve primary-tier and ring reactions. Positioning intent is explicit: surround the core to flavor it, fill corners to support it.
- **17g. Preview.** The prep preview (Rule 16f) must also surface the armed Cascade (lead + modifier icons) live, computed via the same stateless path as reactions.

**18. Two hands (ADR-0057, 2026-09-27).** Fayde is made from two brothers: Ayden, raw power, and Faith, precise control. The grid's **left column (slots 0/3/6) is Ayden's hand** and its **right column (slots 2/5/8) is Faith's hand**. The middle column (1/4/7) belongs to neither. Any filled slot counts, whatever its type or level.

- **18a. Ayden's hand.** `hand_power_mult = 1 + power_per_prana × A`, where `A` is the filled Ayden slots (0–3). SC&E multiplies every primary chain hit by it (Step 8d, after Perfect). Reaction and Cascade bonus hits and the Special are not scaled.
- **18b. Faith's hand.** `hand_control_mult = 1 + control_per_prana × F`, where `F` is the filled Faith slots (0–3). SC&E multiplies the duration of the core Prana's own status (Burn, Blind, Stun, Freeze, Regenerate) by it. Reaction-applied statuses are not scaled.
- **18c. Touch.** When `A == F ≥ 1`, the hands touch and both bonuses (the part above 1.0) are multiplied by `touch_mult`.
- **18d. Tuning.** `assets/data/hands_tuning.tres`: `power_per_prana` 0.06, `control_per_prana` 0.12, `touch_mult` 1.5, and the slot lists. At most: +27 % damage and +54 % status time (3 + 3, touching).
- **18e. Preview.** The prep panel labels the columns AYDEN / FAITH (brightened while that hand holds Prana) and prints one line under the core with the active bonuses and the touch.
- **18f. Spatial language.** Slots 3 and 5 are both cardinal neighbours of the core (reactions, Cascade) and part of a hand, so placement now trades reaction value against hand balance. Corners feed the hands and primary tier only.

---

### States and Transitions

| Signal | Action |
|--------|--------|
| `combat_started` | Read `committed_fragments` from Prana Grid. Run full resolution (Rules 2–11). Cache `SpellEffect`. Emit `combo_resolved(spell_effect)`. |
| `preparation_started` | Clear cached `SpellEffect`. |

Combination Resolution is stateless — resolves once per wave. The combo chain state (`combo_index`, timing window countdown) is owned by Spell Casting & Effects.

---

### Interactions with Other Systems

| System | Interaction | Direction |
|--------|-------------|-----------|
| **Prana Grid** | Reads `committed_fragments: Array[PranaFragment]` (length 9, null = empty) via public getter after `combat_started`. Never writes. During Preparation Phase, calls the stateless `CombinationResolution.compute_reactions(fragments) -> Array[ReactionDef]` on its in-progress working arrangement on every fragment place/move to render the live reaction preview (Rule 16f). | CR ↔ Prana Grid |
| **Prana Data** | Reads `base_damage_modifier` and `base_status` per type via `PranaCatalog.get_type(id)`. | CR → Prana Data |
| **Spell Casting & Effects** | Emits `combo_resolved(spell_effect: SpellEffect)`. Spell Casting owns chain execution and applies all `active_adjacency_effects`. **Required contract**: SC&E must distinguish Freeze source (primary Deepfrost vs. Deepfrost non-primary modifier) to apply the correct Freeze duration (2.0s vs. `NONPRIMARY_FREEZE_DURATION = 1.0s`). SC&E must also cache `aggregate_stat_bonus` for the wave duration and act as stat broker to Status Effects and Health & Damage (see Rule 11c). | CR → Spell Casting |
| **Game State & Scene Flow** | Listens to `combat_started` and `preparation_started`. | CR listens |
| **Combat HUD** | May read cached `SpellEffect` to display primary tier, active non-primaries, triggered adjacency effect icons, and armed `active_reactions`. | Combat HUD → CR (read-only) |

> **⚠ Prana Grid GDD — two required updates:**
> 1. `committed_arrangement: Array[int]` → `committed_fragments: Array[PranaFragment]` (each slot now carries type_id, level, stat_property, and adjacency_effects array; null = empty slot)
> 2. Confirm must be blocked if slot 4 (centre) is empty, not just if all slots are empty
>
> **⚠ Prana Drop / Loot GDD** — fragment generation (random stat_property + random adjacency_effects[level]) is a First Playable requirement given the Core Prana model. A hardcoded starter set can substitute at First Playable scope before the full drop system is designed.

## Formulas

> *`systems-designer` consulted (lean mode — Formulas is HIGH implementation risk). Three design tensions resolved before writing: (1) Verdant T2 barrier = absorb entire next hit (not 1 HP cap); (2) Stormgold T2 Follow-Through = qualifying interrupt only, not auto; (3) ADJ_DOUBLE_HIT = position-free, lower drop weight compensates.*

---

### Formula 1: Effective Primary Count

`effective_primary_count = Σ fragment[i].level  for all i in [0,8] where fragment[i] != null AND fragment[i].type_id == primary_type`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Fragment level at slot i | `fragment[i].level` | int | 1–unbounded | Level of the fragment in slot i; null fragments are excluded by the condition |
| Primary type ID | `primary_type` | int | 0–4 | `type_id` of the fragment in slot 4 (centre) |
| Result | `effective_primary_count` | int | 1–unbounded | Minimum 1 because slot 4 must be filled |

**Output range:** 1 to unbounded. At First Playable (all lv.1), practical maximum = 9 if all slots share the same type.

**Example:** Ashfire in slots 0, 4, 7 (lv.1 each) + Deepfrost in slots 1, 3. `effective_primary_count = 1+1+1 = 3`.

---

### Formula 2: Primary Tier Lookup

`primary_tier = LOOKUP(effective_primary_count, PRIMARY_TIER_TABLE)`

| `effective_primary_count` | `primary_tier` | `combo_attack_count` |
|--------------------------|----------------|----------------------|
| 1–2 | 1 | 1 |
| 3–5 | 2 | 2 |
| 6+ | 3 | 3 |

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Effective primary count | `effective_primary_count` | int | 1–unbounded | Output of Formula 1 |
| Primary tier | `primary_tier` | int | 1–3 | Controls which primary effect definition fires |
| Combo attack count | `combo_attack_count` | int | 1–3 | Sequential attacks in the chain for this wave |

**Output range:** `primary_tier` is always 1, 2, or 3.

**Design note:** At First Playable (lv.1 only), Tier 3 requires 6 of 9 slots to hold the same type — a significant grid commitment that leaves little room for non-primary modifiers.

---

### Formula 3: Non-Primary Effective Count

`effective_nonprimary_count(T) = Σ fragment[i].level  for all i in {0,1,2,3,5,6,7,8} where fragment[i] != null AND fragment[i].type_id == T AND T != primary_type`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Non-primary type | `T` | int | 0–4, ≠ primary_type | Type being assessed; evaluated independently for each of the four remaining types |
| Valid slot indices | `i` | int | {0,1,2,3,5,6,7,8} | Centre (slot 4) excluded regardless of type |
| Result | `effective_nonprimary_count(T)` | int | 0–unbounded | 0 if type T is absent from ring |

**Constraint:** Primary-type fragments in non-centre slots contribute to Formula 1 only — they are excluded from all `effective_nonprimary_count(T)` calculations.

**Example:** Ashfire primary in slot 4; Deepfrost lv.1 in slots 1 and 3; Verdant lv.1 in slot 6; Ashfire lv.1 in slot 0. `effective_nonprimary_count(Deepfrost) = 2`. `effective_nonprimary_count(Verdant) = 1`. Ashfire not evaluated (it is the primary type).

---

### Formula 4: Non-Primary Tier Lookup

`nonprimary_tier(T) = LOOKUP(effective_nonprimary_count(T), NONPRIMARY_TIER_TABLE)`

| `effective_nonprimary_count(T)` | `nonprimary_tier(T)` | Active? |
|---------------------------------|----------------------|---------|
| 0 | 0 | No |
| 1–2 | 1 | Yes — base modifier |
| 3+ | 2 | Yes — enhanced modifier |

**Output range:** 0, 1, or 2 per type. Up to four types can be active simultaneously (the primary type is excluded).

---

### Formula 5: Primary Tier Effects Per Type

Attack damage formula applied within each tier entry:

`attack_damage = clamp(round(base_damage × base_damage_modifier × tier_attack_modifier), 0, target_max_hp)`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Spell base damage | `base_damage` | float | 1–unbounded | Defined in Health & Damage GDD; reference value = 20 |
| Prana type scalar | `base_damage_modifier` | float | 0.70–1.25 | Per-type constant from Prana Data (immutable) |
| Per-attack tier scalar | `tier_attack_modifier` | float | 0.80–1.50 | Scales individual attack within the chain; varies per tier and position |
| Target HP ceiling | `target_max_hp` | int | 1–unbounded | Clamp ceiling from Health & Damage pipeline |

**Multiplicative bonus stacking order.** When multiple modifiers apply to a single hit, they resolve in this order:

| Step | Operation | Source |
|------|-----------|--------|
| 1 | `effective_base = base_damage + flat_stat_bonus` | `ASH_DMG` or `FROST_DMG` stat (if applicable; added pre-modifier) |
| 2 | `effective_modifier = base_damage_modifier + burn_bonus` | Ashfire T2 non-primary `ASHFIRE_NP_BONUS` (additive, capped at 1.40) |
| 3 | `raw_damage = effective_base × effective_modifier × tier_attack_modifier` | Core formula |
| 4 | `× (1.25 + FROST_SHATTER_BONUS)` if target is Frozen and hit is DIRECT/CONTACT (Shatter); else `× (1 + REACT_THERMAL_BONUS)` on the first hit if Thermal Shock is armed | Shatter / Thermal Shock conditional — **mutually exclusive on one hit, never both** (see Edge Cases); apply the larger if both could qualify |
| 5 | `× (1.30 + STORM_FOLLOW_DMG)` if qualifying Stun interrupt within 1.5s | Follow-Through conditional |
| 6 | `× (1.0 + VOID_DMG_VS_BLIND_value)` if target has active Blind at moment of hit | VOID_DMG_VS_BLIND stat |
| 7 | `× 1.50` if ASH_CRIT roll succeeds (binary roll per first attack) | Critical hit |
| 8 | `clamp(round(result), 0, target_max_hp)` | Final clamp |

Steps 4–7 are independent multipliers applied sequentially. All four can co-occur on the same hit; order is fixed as listed above to ensure deterministic results. Spell Casting & Effects is responsible for applying steps 4–7.

---

#### Type 0 — Ashfire (base_damage_modifier = 1.25, base_status = Burn)

Thematic identity: **melee dance combo** — Avatar Fire Nation martial arts reference. Fluid spinning strikes at close range; each hit in the chain is a continuation of a dance sequence. Fayde must close to melee distance (`ASHFIRE_MELEE_RANGE = 80px`) to land the combo. The T3 eruption radiates outward from **Fayde's position** (spinning 360°), not from the target.

| Tier | Combo Attacks | Attack Sequence | Status per Hit | Example total (base_damage=20) |
|------|--------------|-----------------|----------------|-------------------------------|
| **T1** | 1 | Spinning fire strike: `1.00×` — close-range melee spin directed at target | Burn (2.0s) on hit | `round(20 × 1.25 × 1.00)` = **25** |
| **T2** | 2 | First: Fire palm strike `1.00×`; Second: Sweeping fire kick `1.25×` — flowing 2-hit dance sequence | Burn on first; Burn refreshes on second | First = **25**, Second = `round(20 × 1.25 × 1.25)` = **31**; total = **56** |
| **T3** | 3 | First: Fire palm strike `1.00×`; Second: Sweeping fire kick `1.25×`; Third: Spinning 360° eruption `1.50×` — Fayde pivots and releases fire in all directions (`AREA_AROUND_FAYDE`, radius `ASHFIRE_T3_AOE_RADIUS = 80px`) | Burn on each hit (refresh); Burn applied to all secondary eruption targets at full magnitude | First = **25**, Second = **31**, Third = `round(20 × 1.25 × 1.50)` = **38** per target in radius; total single-target = **94** |

**T3 eruption targeting**: `AREA_AROUND_FAYDE` — all enemies within `ASHFIRE_T3_AOE_RADIUS` of **Fayde's position** at the moment of the spinning pivot. This is distinct from `AREA_AT_TARGET` (centered on the primary target's position). The dancer is the origin. `ASHFIRE_T3_AOE_RADIUS` and `ASHFIRE_MELEE_RANGE` are tuning knobs defined in the SC&E GDD (system #3).

---

#### Type 1 — Voidblue (base_damage_modifier = 0.90, base_status = Blind)

Thematic identity: shadow pressure, control escalation, attack suppression rather than raw output.

| Tier | Combo Attacks | Attack Sequence | Status per Hit | Example total (base_damage=20) |
|------|--------------|-----------------|----------------|-------------------------------|
| **T1** | 1 | Single reaching strike: `1.00×` | Blind (2.0s) on hit | `round(20 × 0.90 × 1.00)` = **18** |
| **T2** | 2 | First: Strike `1.00×`; Second: Shadow pull `1.10×` — draws nearest non-targeted enemy 60px closer to Fayde | Blind on first; Stagger (0.3s, interrupts movement transitions — does not cancel attack animations, does not open Follow-Through window) on second | First = **18**, Second = `round(20 × 0.90 × 1.10)` = **20**; total = **38** |
| **T3** | 3 | First: Strike `1.00×`; Second: Pull `1.10×`; Third: Void collapse `1.30×` — applies Blind to ALL enemies currently on screen, not just primary target | Blind on first; Stagger on second; mass Blind on third | First = **18**, Second = **20**, Third = `round(20 × 0.90 × 1.30)` = **23**; total = **61** |

Stagger is a new status exclusive to Voidblue — distinct from Stun. It is not registered in Prana Data. Duration tracking is owned by `StatusEffectsManager` (stub at MVP — duration tracking + movement-interrupt via `apply_stun`); see Status Effects GDD.

---

#### Type 2 — Stormgold (base_damage_modifier = 1.15, base_status = Stun)

Thematic identity: speed and interrupt. Rewards quick inputs and enemy timing reads.

| Tier | Combo Attacks | Attack Sequence | Status per Hit | Example total (base_damage=20) |
|------|--------------|-----------------|----------------|-------------------------------|
| **T1** | 1 | Quick snap strike: `1.00×` | Stun (0.8s) on hit | `round(20 × 1.15 × 1.00)` = **23** |
| **T2** | 2 | First: Snap `1.00×`; Second: Lightning follow `1.20×` — if and only if the first attack's Stun was a **qualifying interrupt** (the Stun cancelled an in-progress enemy attack animation), the second attack receives the Lightning Follow-Through +30% bonus from Prana Data. If the first Stun was applied to an idle enemy, the second attack deals `1.20×` without the bonus. | Stun on first; no additional status on second | First = **23**; Second with Follow-Through = `round(20 × 1.15 × 1.20 × 1.30)` = **36**; Second without = `round(20 × 1.15 × 1.20)` = **28**; best-case total = **59** |
| **T3** | 3 | First: Snap `1.00×`; Second: Follow `1.20×` (Follow-Through as above); Third: Chain strike `1.00×` that forks to nearest non-targeted enemy at `0.60×` of the third attack's damage | Stun on first; Stun refreshed on third (fork does not apply Stun) | First = **23**, Second = **36** or **28**, Third = **23** + fork = `round(20 × 1.15 × 0.60)` = **14**; best-case total = **82** single-target-equivalent |

Follow-Through integration note: The second attack in the T2 chain automatically falls within the 1.5s window if the first attack's Stun was a qualifying interrupt. Players who haven't discovered Follow-Through still see higher damage; players who have understand why the numbers differ based on enemy state.

---

#### Type 3 — Deepfrost (base_damage_modifier = 0.80, base_status = Freeze)

Thematic identity: patience and control. Lowest direct damage; highest setup value.

| Tier | Combo Attacks | Attack Sequence | Status per Hit | Example total (base_damage=20) |
|------|--------------|-----------------|----------------|-------------------------------|
| **T1** | 1 | Slow two-hand push: `1.00×` | Freeze (2.0s root + 50% slow) on hit | `round(20 × 0.80 × 1.00)` = **16** |
| **T2** | 2 | First: Push `1.00×` (primary target); Second: Frost line `0.80×` — hits all enemies in a 100px line extending from Fayde through the primary target | Freeze on first (primary target); Freeze on second (all line targets) | First = **16**, Second = `round(20 × 0.80 × 0.80)` = **13** per line target; primary chain total = **29** |
| **T3** | 3 | First: Push `1.00×`; Second: Frost line `0.80×`; Third: Glacial field — **0 direct damage** — creates a 120px radius slow zone at primary target position for `GLACIAL_FIELD_DURATION = 3.0s`; any enemy entering the zone has movement speed reduced by `FREEZE_SLOW_PCT = 50%` (slow only, no root, does not trigger Shatter) | Freeze on first; Freeze on second; slow zone on third | First = **16**, Second = **13** per line target; Third = 0 damage + 3.0s slow aura |

Deepfrost T3's third attack intentionally deals zero damage. The zone slow combined with prior Freeze applications is the longest lockdown window in the game. `GLACIAL_FIELD_DURATION` and the zone radius are tuning knobs.

---

#### Type 4 — Verdant (base_damage_modifier = 0.70, base_status = Regenerate)

Thematic identity: endurance and attrition. Lowest direct damage; highest sustained survival contribution.

| Tier | Combo Attacks | Attack Sequence | Status / Sustain | Example total (base_damage=20) |
|------|--------------|-----------------|-----------------|-------------------------------|
| **T1** | 1 | Bloom strike: `1.00×` | Regen applied to Fayde on hit (6 HP over 3.0s per Prana Data Formula 2) | `round(20 × 0.70 × 1.00)` = **14** + 6 HP regen |
| **T2** | 2 | First: Bloom strike `1.00×`; Second: Verdant shield pulse — **0 direct damage** — grants Fayde a **one-hit absorb barrier** that absorbs the **entire next incoming hit completely, regardless of damage magnitude**, within `BARRIER_DURATION = 4.0s`. The barrier HP value `round(base_damage × base_damage_modifier × BARRIER_COEFFICIENT)` is the cumulative absorption pool for **multi-hit tick scenarios** only: if multiple rapid hits arrive within the window, the barrier absorbs them until its HP is depleted; any hit that would exhaust the remaining pool is only partially absorbed. A single hit of any magnitude is always fully absorbed — the barrier acts as one-hit immunity for single-hit events. | Regen on first; one-hit absorb barrier on second | First = **14** + Regen; Second = 0 damage + barrier (one-hit immunity for single hits; multi-hit pool = `round(20 × 0.70 × 0.10)` = **1 HP** cumulative across rapid-tick scenarios) |
| **T3** | 3 | First: Bloom `1.00×`; Second: Shield pulse (barrier as above); Third: Rejuvenating strike `1.20×` — on hit, triggers an immediate bonus Regen tick (`regen_tick_magnitude × fayde_max_hp = 2 HP`) AND starts a fresh full Regen cycle (resets timer to 3.0s per refresh rule) | Regen on first; barrier on second; fresh Regen + immediate 2 HP tick on third | First = **14** + Regen start; Second = barrier; Third = `round(20 × 0.70 × 1.20)` = **17** + 2 HP immediate tick + Regen reset to 3s (replaces T1 Regen). Total sustain: ~**10–14 HP** across 3s post-T3 hit (lower bound if T1 Regen fired one tick before T3; upper bound only if chain timing allows T1 Regen to complete before T3 fires — unusual at 2.0s window). |

`BARRIER_COEFFICIENT = 0.10` and `BARRIER_DURATION = 4.0s` are tuning knobs. The barrier absorbs any single incoming hit in full (one-hit immunity). The barrier HP value governs multi-hit tick depletion only — the coefficient controls how many rapid ticks the barrier can absorb before the pool is exhausted.

---

### Formula 6: Non-Primary Modifier Effects Per Type

Non-primary modifiers apply on top of the primary cast without replacing it. Multiple types active simultaneously — all apply. Unless otherwise noted, modifiers affect the first attack in the chain only.

---

#### Ashfire as Non-Primary

**Tier 1 (effective 1–2):** First hit applies Burn in addition to the primary type's normal status. If primary already applies Burn, timer refreshes.

**Tier 2 (effective 3+):** As Tier 1, plus additive bonus to primary's `base_damage_modifier` for all chain attacks:

`modified_primary_modifier = base_damage_modifier + ASHFIRE_NP_BONUS`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Primary type base modifier | `base_damage_modifier` | float | 0.70–1.25 | From Prana Data |
| Ashfire T2 non-primary bonus | `ASHFIRE_NP_BONUS` | float | 0.15 (tuning knob) | Additive to primary modifier for all chain attacks |
| Cap | — | float | 1.40 | `modified_primary_modifier` capped at 1.40 |

**Example:** Deepfrost primary (0.80) + Ashfire T2 non-primary: `0.80 + 0.15 = 0.95`. Each Deepfrost attack deals `round(20 × 0.95) = 19` instead of 16. Deepfrost T1 + Ashfire T2 non-primary + Shatter on frozen target: `round(20 × 0.95 × 1.25) = 24` — matching Stormgold's base output. This is the legitimate Deepfrost+Ashfire path: powerful but requiring 3+ Ashfire fragments in ring slots.

---

#### Voidblue as Non-Primary

**Tier 1 (effective 1–2):** First hit has `VOIDBLUE_NP_CHANCE = 0.30` probability to apply Blind (2.0s).

**Tier 2 (effective 3+):** Blind application is guaranteed (`VOIDBLUE_NP_CHANCE = 1.00`). All enemies with active Blind at cast time have their timer extended by `VOIDBLUE_NP_EXTEND = 1.0s`.

| Knob | Value | Description |
|------|-------|-------------|
| `VOIDBLUE_NP_CHANCE` | 0.30 (T1), 1.00 (T2) | Blind application probability |
| `VOIDBLUE_NP_EXTEND` | 1.0s | Flat Blind timer extension on cast for already-Blinded enemies |

---

#### Stormgold as Non-Primary

**Tier 1 (effective 1–2):** `combo_continuation_window` extended by `STORMGOLD_NP_WINDOW_T1 = 0.3s`. Passed as a modifier parameter in SpellEffect; owned by Spell Casting.

**Tier 2 (effective 3+):** Window extended as Tier 1, plus final attack in chain applies Stun (0.8s) regardless of primary type.

| Knob | Value | Description |
|------|-------|-------------|
| `STORMGOLD_NP_WINDOW_T1` | 0.3s | Combo window extension |
| `final_attack_stun` | bool | True when Stormgold T2 non-primary is active |

---

#### Deepfrost as Non-Primary

**Tier 1 (effective 1–2):** All enemies hit by chain attacks receive Chill — `CHILL_SLOW_PCT = 15%` movement slow for `CHILL_DURATION = 2.0s`. Chill does not apply Freeze, does not trigger Shatter.

`chill_effective_speed = base_move_speed × (1 - CHILL_SLOW_PCT)`

**Tier 2 (effective 3+):** First attack applies a `NONPRIMARY_FREEZE_DURATION = 1.0s` Freeze (root + 50% slow) — shorter than primary Deepfrost Freeze (2.0s). Opens a Shatter window for subsequent chain attacks. All remaining attacks apply Chill.

Shatter within T2 non-primary Freeze window: subsequent chain attacks during the 1.0s Freeze apply +25% Shatter bonus per Prana Data conditional depth rules.

| Knob | Value | Description |
|------|-------|-------------|
| `CHILL_SLOW_PCT` | 0.15 | Chill movement slow fraction |
| `CHILL_DURATION` | 2.0s | Chill duration |
| `NONPRIMARY_FREEZE_DURATION` | 1.0s | Tier 2 non-primary Freeze duration (shorter than primary's 2.0s) |

---

#### Verdant as Non-Primary

**Tier 1 (effective 1–2):** Regen applied to Fayde at **cast time** (not on hit — fires before attacks resolve). `regen_total = 6 HP over 3.0s`. Refreshes if Regen already active.

**Tier 2 (effective 3+):** As Tier 1 (cast-time Regen), plus: all healing Fayde receives during the active Regen window is amplified by `VERDANT_NP_HEAL_AMP = 1.25`.

`amplified_heal = heal_amount × VERDANT_NP_HEAL_AMP`

Amplified Regen tick: `2 HP × 1.25 = 3 HP`. Total amplified Regen: `3 × 3 = 9 HP`. Injury Bloom tick during amplified window: `2 HP × 1.25 = 3 HP`.

| Knob | Value | Description |
|------|-------|-------------|
| `VERDANT_NP_HEAL_AMP` | 1.25 | Multiplier on all healing during active Regen window |

---

### Formula 7: Adjacency EffectModifier Pool

Each `AdjacencyEffect` a fragment carries draws one `EffectModifier` from the pool below. The effect fires when all `required_neighbors` conditions are met. `required_type_id = –1` means any type satisfies the condition.

**Pool design constraints:**
- Every effect is meaningful when triggered — no trivially weak results
- Effects are player-readable on first trigger (no hidden state)
- Position-dependent conditions create spatial design pressure (intentional)
- `ADJ_DOUBLE_HIT` is position-free (triggers from any slot); compensate with lower drop weight in the Prana Drop / Loot GDD

| ID | Effect Name | Neighbor Condition | Combat Effect |
|----|------------|-------------------|---------------|
| `ADJ_DOUBLE_HIT` | Double Hit | None — always active when fragment is placed in any slot | First chain attack fires twice before advancing. Second firing deals `0.75×` first hit's damage. Status applies on both (refresh). |
| `ADJ_PIERCE` | Pierce | Any 1 cardinal neighbor, any type | First chain attack passes through primary target and hits next enemy in targeting direction at `0.60×` damage. Status applies on pierce target. |
| `ADJ_SPLASH` | Splash AoE | Any 2 cardinal neighbors, any types | First chain attack hits all enemies within `ADJ_SPLASH_RADIUS = 60px` of primary target at `0.50×` damage. No status on secondary splash targets. |
| `ADJ_STATUS_EXTEND` | Status Extend | One vertical neighbor — randomly assigned as ABOVE or BELOW at fragment generation; direction is fixed per fragment instance and visible in UI — must match **this fragment's own Prana type** (`required_type_id = fragment.type_id` at generation; not a dynamic sentinel for the primary type) | Primary type's applied status extended by `ADJ_STATUS_EXT = 1.0s` on primary target. Burn tick count recalculated: `floor((duration + 1.0) / tick_rate)`. |
| `ADJ_COMBO_EXTEND` | Combo Window Extend | Any 1 cardinal neighbor (LEFT or RIGHT), any type | `combo_continuation_window` extended by `ADJ_COMBO_WIN = 0.5s`. Stacks additively with Stormgold non-primary window extension. |
| `ADJ_EXTRA_HIT` | Extra Combo Hit | Any 1 cardinal neighbor must match primary type | Bonus attack appended to end of chain at `0.80×` of chain's final attack modifier. Applies primary status. Does not increase `primary_tier`. |
| `ADJ_LIFESTEAL` | Lifesteal | Any 1 cardinal neighbor must be Verdant (type 4) | Fayde heals `ADJ_LIFESTEAL_PCT = 0.20` × `final_damage` per chain hit. At 25 damage: **5 HP** per hit. Applied via `apply_heal()`. |
| `ADJ_FROST_BURST` | Frost Burst | Any 1 cardinal neighbor must be Deepfrost (type 3) | On first enemy kill during chain, Frost Burst fires at kill position: `ADJ_FROST_SLOW = 0.30` movement slow to enemies within `ADJ_FROST_RADIUS = 80px` for `1.5s`. Does not trigger if no kill occurs. |
| `ADJ_CHAIN_LIGHTNING` | Chain Lightning | Any 1 cardinal neighbor must be Stormgold (type 2) | Second chain attack (if `combo_attack_count ≥ 2`) arcs to nearest non-targeted enemy at `0.70×` second attack's damage. If only one enemy present, arc hits primary for bonus `0.70×` hit. No status on arc. |
| `ADJ_REGEN_ON_HIT` | Regen on Hit | Any 1 cardinal neighbor must be Verdant (type 4) | Each chain hit triggers an immediate Regen tick on Fayde: `regen_tick_magnitude × fayde_max_hp = 2 HP`. Max 3 ticks (Tier 3 chain). Applied via `apply_heal()`. |
| `ADJ_BURN_INTENSIFY` | Burn Intensify | ABOVE = Ashfire (type 0) AND BELOW = Ashfire (type 0) | `burn_tick_magnitude` increased by `ADJ_BURN_INTENSIFY_BONUS = 0.04` for this cast. At base 0.08 → 0.12 per tick. Total Burn: `base_damage × 0.12 × 4`. At base_damage=20: **9.6** instead of 6.4. |
| `ADJ_PHASE_SHIFT` | Phase Shift | LEFT = Voidblue (type 1) AND RIGHT = Voidblue (type 1) | Fayde becomes intangible for `ADJ_PHASE_DURATION = 0.6s` after cast resolves, negating any CONTACT damage. Does not stack with existing i-frame — longer window takes precedence. |
| `ADJ_BARRIER_HIT` | Barrier on Kill | Any 1 cardinal neighbor, any type | First kill in the chain grants Fayde a one-hit absorb barrier (absorbs entire next hit) lasting `ADJ_BARRIER_DUR = 5.0s`. If no kill occurs, no barrier. |
| `ADJ_ECHO` | Echo Strike | ABOVE = any type | After full chain resolves, an Echo Strike fires automatically after `ADJ_ECHO_DELAY = 0.8s` at `0.50×` first attack's modifier. Targets the nearest live enemy at fire time; if no enemies remain, Echo is suppressed. Applies primary type's status. Does not consume combo input. |

**Condition notation:** "Any 1 cardinal neighbor must be X" means one specific direction (ABOVE, BELOW, LEFT, or RIGHT) is assigned randomly at fragment generation. The direction is fixed per fragment instance and visible to the player in the UI.

**Tuning knobs from this pool:** `ADJ_SPLASH_RADIUS`, `ADJ_STATUS_EXT`, `ADJ_COMBO_WIN`, `ADJ_LIFESTEAL_PCT`, `ADJ_FROST_SLOW`, `ADJ_FROST_RADIUS`, `ADJ_BURN_INTENSIFY_BONUS`, `ADJ_PHASE_DURATION`, `ADJ_BARRIER_DUR`, `ADJ_ECHO_DELAY` — all designer-adjustable.

**Drop weight guidance for Prana Drop / Loot GDD:**
- Lower weight (rare): `ADJ_BURN_INTENSIFY`, `ADJ_PHASE_SHIFT` (multi-direction AND conditions), `ADJ_EXTRA_HIT`
- Standard weight: most single-condition effects
- `ADJ_DOUBLE_HIT` is position-free (no spatial condition) — assign lower drop weight to compensate for ease of activation

---

### Formula 8: Fragment Stat Property Pool

Each `PranaFragment` carries one `StatProperty` (always active when placed, regardless of neighbor conditions). Stat type is drawn from the fragment's type-specific sub-pool. This makes type identity readable: a Deepfrost fragment always contributes a control-oriented stat.

**Per-level value scaling:**

`stat_value(level) = stat_base_value × level`

| Variable | Symbol | Type | Description |
|----------|--------|------|-------------|
| Base stat value | `stat_base_value` | type-dependent | The per-level increment; lv.1 = base value, lv.2 = 2×, lv.3 = 3× |
| Fragment level | `level` | int ≥ 1 | First Playable = always 1 |
| Stat bonus | `stat_value` | type-dependent | Active contribution while fragment is in any grid slot |

---

#### Ashfire Stat Pool (damage-focused)

| Stat ID | Name | `stat_base_value` | lv.1 | lv.2 | lv.3 |
|---------|------|------------------|------|------|------|
| `ASH_DMG` | Direct Damage Flat | +5 | +5 | +10 | +15 |
| `ASH_BURN_TICK` | Burn Tick Magnitude Bonus | +0.02 | +0.02 | +0.04 | +0.06 |
| `ASH_CHAIN_DMG` | Combo Chain Bonus (attacks 2+) | +3 flat | +3 | +6 | +9 |
| `ASH_CRIT` | Critical Hit Chance (first chain attack) | +5% | +5% | +10% | +15% |

`ASH_DMG` is added to `base_damage` before modifiers: `attack_damage = round((base_damage + stat_value) × modifier)`. `ASH_CRIT` at 15% = `1.50×` damage on crit (binary roll).

---

#### Voidblue Stat Pool (control-focused)

| Stat ID | Name | `stat_base_value` | lv.1 | lv.2 | lv.3 |
|---------|------|------------------|------|------|------|
| `VOID_BLIND_DUR` | Blind Duration Flat | +0.5s | +0.5s | +1.0s | +1.5s |
| `VOID_MISS_CHANCE` | Blind Miss Chance Bonus | +5% | +5% | +10% | +15% |
| `VOID_DMG_VS_BLIND` | Damage vs Blinded Bonus | +15% | +15% | +30% | +45% |
| `VOID_STAGGER_DUR` | Stagger Duration Bonus | +0.1s | +0.1s | +0.2s | +0.3s |

`VOID_MISS_CHANCE` hard cap: `blind_miss_chance + stat_value ≤ 0.90`. `VOID_DMG_VS_BLIND` is multiplicative on `attack_damage` when target has active Blind at moment of hit.

---

#### Stormgold Stat Pool (speed/interrupt-focused)

| Stat ID | Name | `stat_base_value` | lv.1 | lv.2 | lv.3 |
|---------|------|------------------|------|------|------|
| `STORM_STUN_DUR` | Stun Duration Flat | +0.2s | +0.2s | +0.4s | +0.6s |
| `STORM_COMBO_SPD` | Combo Window Extension | +0.3s | +0.3s | +0.6s | +0.9s |
| `STORM_CHAIN_DMG` | Second-Hit Flat Bonus | +4 | +4 | +8 | +12 |
| `STORM_FOLLOW_DMG` | Follow-Through Bonus Amp | +5% | +5% | +10% | +15% |

`STORM_FOLLOW_DMG` raises Follow-Through from `×1.30` to `×(1.30 + stat_value)`. `STORM_COMBO_SPD` stacks with Stormgold non-primary modifier.

---

#### Deepfrost Stat Pool (control/setup-focused)

| Stat ID | Name | `stat_base_value` | lv.1 | lv.2 | lv.3 |
|---------|------|------------------|------|------|------|
| `FROST_FREEZE_DUR` | Freeze Duration Flat | +0.5s | +0.5s | +1.0s | +1.5s |
| `FROST_SHATTER_BONUS` | Shatter Bonus Amp | +5% | +5% | +10% | +15% |
| `FROST_CHILL_WIDE` | Chill Slow Amount Bonus | +5% | +5% | +10% | +15% |
| `FROST_DMG` | Direct Damage Flat | +3 | +3 | +6 | +9 |

`FROST_DMG` is added to `base_damage` before modifiers: `attack_damage = clamp(round((base_damage + stat_value) × base_damage_modifier × tier_attack_modifier), 0, target_max_hp)` — same pre-modifier application as `ASH_DMG`. `FROST_SHATTER_BONUS` raises Shatter from `×1.25` to `×(1.25 + stat_value)`. `FROST_CHILL_WIDE` hard cap: `CHILL_SLOW_PCT + stat_value ≤ 0.40`.

---

#### Verdant Stat Pool (sustain-focused)

| Stat ID | Name | `stat_base_value` | lv.1 | lv.2 | lv.3 |
|---------|------|------------------|------|------|------|
| `VER_REGEN_TICK` | Regen Tick Magnitude Bonus | +0.01 | +0.01 | +0.02 | +0.03 |
| `VER_BARRIER_HP` | Barrier Absorb Bonus | +3 HP | +3 HP | +6 HP | +9 HP |
| `VER_LIFESTEAL_PCT` | Lifesteal Percent Bonus | +5% | +5% | +10% | +15% |
| `VER_HEAL_FLAT` | Heal Flat Bonus | +2 HP | +2 HP | +4 HP | +6 HP |

`VER_REGEN_TICK` at lv.1: `0.02 + 0.01 = 0.03` per tick → `100 × 0.03 × 3 = 9 HP` total instead of 6 HP. `VER_BARRIER_HP` increases the barrier's multi-hit cumulative absorption pool (at lv.1: pool = base barrier_HP + 3). Single-hit immunity is unaffected — the pool only matters when multiple rapid hits arrive within the window. `VER_HEAL_FLAT` adds to every healing event while the fragment is placed (Regen ticks, Lifesteal, Injury Bloom).

---

### Formula 9: Prana Reaction Matrix

**Reaction arming algorithm** (runs after Formulas 1–8, on `committed_fragments`; also exposed as the stateless `compute_reactions(fragments)` used by the prep preview):

```
active_reactions = []
seen_pairs = {}                                    # set of sorted (type_a, type_b)
for each slot i in [0,8] where fragment[i] != null:
    for each direction in [ABOVE, BELOW, LEFT, RIGHT]:
        j = get_cardinal_neighbor(i, direction)    # Rule 9 lookup; skip if out of bounds
        if fragment[j] == null: continue
        if fragment[i].type_id == fragment[j].type_id: continue   # same type = no reaction
        key = sort(fragment[i].type_id, fragment[j].type_id)
        if key in seen_pairs: continue
        seen_pairs.add(key)
        rdef = REACTION_MATRIX[key]
        if rdef != null: active_reactions.append(rdef)
sort active_reactions ascending by (type_a, type_b)   # deterministic order
```

Each same-type pair is skipped; each distinct cross-type adjacent pair contributes exactly one reaction (deduped). Output order is deterministic: ascending by `(type_a, type_b)`.

**`ReactionDef` schema** (external Resource, one per pair):

| Field | Type | Description |
|-------|------|-------------|
| `id` | `StringName` | e.g. `REACT_THERMAL_SHOCK` |
| `name` | `String` | Display name for preview / HUD |
| `type_a` | `int` (0–4) | Lower type id of the pair |
| `type_b` | `int` (0–4) | Higher type id of the pair |
| `effect_kind` | `enum ReactionKind` | Routes SC&E application logic |
| `magnitude` | `float` | Primary tuning value (see Tuning Knobs) |
| `description` | `String` | One-line preview tooltip text |

**The Reaction Matrix (10 entries — MVP).** Verbs in parentheses show the derivation players reason from (Ashfire = IGNITE, Voidblue = SUPPRESS, Stormgold = CHAIN, Deepfrost = BIND, Verdant = NOURISH):

| Pair (verbs) | `effect_kind` | Reaction | Effect (reuses existing primitive) | Knob(s) |
|------|--------------|----------|------------------------------------|------|
| Ashfire+Deepfrost (IGNITE+BIND) | `THERMAL_SHOCK` | **Thermal Shock** | First DIRECT/CONTACT hit on a target this cast gets ×(1 + `REACT_THERMAL_BONUS`) burst, even without a pre-existing Freeze — generalises Shatter (thermal crack). Does NOT stack with Shatter on the same hit (Edge Cases). | `REACT_THERMAL_BONUS = 0.25` |
| Ashfire+Stormgold (IGNITE+CHAIN) | `DETONATE` | **Detonate** | On the first enemy kill in the chain, an AoE burst fires at kill position: `REACT_DETONATE_DMG × base_damage` to enemies within `REACT_DETONATE_RADIUS`. | `REACT_DETONATE_DMG = 0.50`, `REACT_DETONATE_RADIUS = 70px` |
| Ashfire+Voidblue (IGNITE+SUPPRESS) | `WITCHFIRE` | **Witchfire** | Any Burn applied this cast also applies Blind for `REACT_WITCHFIRE_BLIND` (burning enemies flail). | `REACT_WITCHFIRE_BLIND = 1.0s` |
| Ashfire+Verdant (IGNITE+NOURISH) | `WILDFIRE` | **Wildfire** | Burn applied this cast immediately spreads once to the nearest enemy within `REACT_WILDFIRE_RANGE` at application time (generalises Contagion to apply-time; fixed 2.0s spread, Contagion-inert). | `REACT_WILDFIRE_RANGE = 150px` |
| Voidblue+Stormgold (SUPPRESS+CHAIN) | `SHORT_CIRCUIT` | **Short Circuit** | First Stun this cast is treated as a guaranteed qualifying interrupt (opens Follow-Through even vs idle) AND Stuns the nearest second enemy for `REACT_SHORTCIRCUIT_STUN`. *("silence before the strike" — fulfils the Player-Fantasy promise.)* | `REACT_SHORTCIRCUIT_STUN = 0.8s` |
| Voidblue+Deepfrost (SUPPRESS+BIND) | `WHITEOUT` | **Whiteout** | While a target has both Blind and an active slow/Freeze, its Blind miss chance is raised to `REACT_WHITEOUT_MISS`. | `REACT_WHITEOUT_MISS = 0.90` |
| Voidblue+Verdant (SUPPRESS+NOURISH) | `SIPHON` | **Siphon** | Damage dealt to Blinded enemies heals Fayde `REACT_SIPHON_LEECH × final_damage` (via `apply_heal`). | `REACT_SIPHON_LEECH = 0.20` |
| Stormgold+Deepfrost (CHAIN+BIND) | `SUPERCONDUCT` | **Superconduct** | When the primary target is Frozen/slowed, chain attacks arc to one extra nearest enemy at `REACT_SUPERCONDUCT_ARC × damage` (ice conducts lightning). | `REACT_SUPERCONDUCT_ARC = 0.60` |
| Stormgold+Verdant (CHAIN+NOURISH) | `SURGE` | **Surge** | `combo_continuation_window` extended by `REACT_SURGE_WINDOW`; each chain hit heals Fayde `REACT_SURGE_HEAL` HP. | `REACT_SURGE_WINDOW = 0.4s`, `REACT_SURGE_HEAL = 2 HP` |
| Deepfrost+Verdant (BIND+NOURISH) | `PERMAFROST` | **Permafrost** | While ≥1 enemy is Frozen, Fayde's Regen ticks are amplified ×`REACT_PERMAFROST_AMP` (safe healing window). | `REACT_PERMAFROST_AMP = 1.50` |

**Output range:** `active_reactions` holds 0–10 entries. A typical 2–3 type build arms 1–3 reactions; arming all 10 is not achievable on a 9-slot grid.

**Example:** Deepfrost (centre, slot 4), Ashfire (slot 1, ABOVE slot 4), Verdant (slot 3, LEFT of slot 4). Adjacent cross-type pairs: (Deepfrost, Ashfire) via slot 1↔4 and (Deepfrost, Verdant) via slot 3↔4. `active_reactions = [Thermal Shock, Permafrost]`. Ashfire and Verdant are not adjacent to each other, so Wildfire does NOT arm. The prep preview shows both reaction names the moment this arrangement is built; moving Verdant to slot 0 (diagonal to centre) would drop Permafrost from the preview, teaching the cardinal-adjacency rule.

---

### Formula 10: Cascade Resolution (generative, core-sensitive)

A Cascade is computed from one rule — no per-triad authoring. The **lead** (core type) sets the burst's shape; each **modifier** (distinct neighbor type) attaches its element facet. This yields 30+ predictable variants (5 leads × combinations of 2–4 modifiers) from a single rule.

**Cascade arming** (runs on `committed_fragments`, after Formula 9; also exposed via the stateless preview path):

```
core_type = fragment[4].type_id              # null centre already handled upstream
M = {}                                        # set of distinct modifier type_ids
for slot in [1, 3, 5, 7]:                      # the four cardinal neighbors of centre
    if fragment[slot] != null and fragment[slot].type_id != core_type:
        M.add(fragment[slot].type_id)
if |M| < 2:
    active_cascade = null                      # |M|==1 leaves the core pairwise reaction (Rule 16) intact
else:
    M = first MAX_CASCADE_MODIFIERS of sorted(M)        # cap; default 4 = no drop
    active_cascade = CascadeEffect(lead_type = core_type, modifiers = M, cascade_mult = ...)
    remove every core↔m pairwise reaction (m in M) from active_reactions   # Rule 17d merge
```

**`CascadeEffect` schema:** `{ lead_type: int (0–4), modifiers: Array[int] (2–4 distinct, sorted), cascade_mult: float }`. SC&E reads `lead_type` for burst shape, iterates `modifiers` for facets, and applies `cascade_mult` to `cascade_damage`.

**Per-type facets** (LEAD = expression when this type is the core; MODIFIER = facet when it is a neighbor):

| Type (verb) | LEAD — burst shape | MODIFIER — facet added to the burst |
|-------------|--------------------|-------------------------------------|
| Ashfire (IGNITE) | Fire **nova** — AoE burst around the primary target (radius `CASCADE_AOE_RADIUS`) | Burst applies **Burn** (standard 2.0s) to everything it hits |
| Voidblue (SUPPRESS) | Shadow **collapse** — effect spreads to all enemies in a wide cluster | Burst applies **Blind** for `CASCADE_BLIND_DUR` |
| Stormgold (CHAIN) | Lightning **chain** — burst arcs across nearest enemies | Burst also **arcs** to `CASCADE_ARC_TARGETS` extra enemy/enemies |
| Deepfrost (BIND) | Frost **field** — burst lands as a slow/freeze zone at the target | Burst applies **Freeze** for `CASCADE_FREEZE_DUR` (root + slow) |
| Verdant (NOURISH) | Bloom **pulse** — burst centred on Fayde (sustain) | Burst **heals** Fayde `CASCADE_LIFESTEAL × damage dealt` |

**Cascade damage** (one burst, fired after the primary chain resolves):

`cascade_mult = min(CASCADE_LEAD_MULT + |M| × CASCADE_MOD_DMG_BONUS, CASCADE_MULT_CAP)`

`cascade_damage = clamp(round(base_damage × base_damage_modifier(core) × cascade_mult), 0, target_max_hp)`

| Variable | Range | Description |
|----------|-------|-------------|
| `base_damage` | 1–unbounded | Health & Damage reference = 20 |
| `base_damage_modifier(core)` | 0.70–1.25 | Core type's Prana Data scalar |
| `\|M\|` | 2–4 | Number of distinct modifier types |
| `CASCADE_LEAD_MULT` | 1.0 (knob) | Base cascade burst strength |
| `CASCADE_MOD_DMG_BONUS` | 0.10 (knob) | Added per modifier — rewards commitment |
| `CASCADE_MULT_CAP` | 1.6 (knob) | Hard ceiling on `cascade_mult` |

**Targeting note:** the lead sets where the burst goes. A Verdant lead (Bloom, Fayde-centred) deals minimal direct damage; its offensive modifiers (Burn/Blind/Freeze/arc) attach to the nearest enemies within `CASCADE_AOE_RADIUS` of the primary target, while the Nourish portion heals Fayde. Verdant-as-modifier always heals Fayde regardless of lead.

**Worked example (answers the core-sensitivity question).** Types present {Ashfire, Voidblue, Stormgold}:
- **Core = Ashfire**, neighbors Voidblue + Stormgold (`|M| = 2`): lead = Fire nova; modifiers add Blind + arc → a **blinding, arcing fire nova**. `cascade_mult = 1.0 + 2×0.10 = 1.20`; damage = `round(20 × 1.25 × 1.20) = 30` per nova target, applying Blind, arcing to 1 extra enemy.
- **Core = Stormgold**, neighbors Voidblue + Ashfire (`|M| = 2`): lead = Lightning chain; modifiers add Blind + Burn → a **blinding, burning lightning chain**. `cascade_mult = 1.20`; damage = `round(20 × 1.15 × 1.20) = 28` per chained target, applying Blind + Burn.

Same three types, **different Cascade** — the lead (core) decides the shape; the modifiers decide the flavor. Both are fully predictable from the facet table without any authored entry.

**Output range:** one `CascadeEffect` or null. At default knobs `cascade_mult` ∈ {1.20, 1.30, 1.40} for `|M|` = 2, 3, 4 respectively (max 1.40); `CASCADE_MULT_CAP = 1.6` is tuning headroom that does not bite at default values.

## Edge Cases

> *Specialist agents not consulted — Lean mode.*

- **If `committed_fragments` is received with slot 4 null (centre empty):** Cannot occur in normal play (Prana Grid's centre-required rule blocks confirmation). If received: `push_error("CombinationResolution: slot 4 is null — centre-required rule violated in Prana Grid")`. Emit `combo_resolved` with `primary_type = –1`. Spell Casting treats this as a no-op cast.

- **If `committed_fragments` has all 9 slots null:** Same handling as above — `push_error()`, emit no-op SpellEffect.

- **If all 9 fragments are the same type (e.g., 9 Ashfire lv.1):** Valid arrangement. `effective_primary_count = 9`, `primary_tier = 3`. No non-primary modifiers are active. Adjacency effects that require a different-type neighbor cannot trigger — not an error.

- **If a fragment's adjacency condition specifies a direction pointing out of bounds for its grid position (e.g., ABOVE on a top-row fragment):** The condition is immediately unsatisfied. Adjacency effect does not trigger. No error logged — valid (non-triggerable) fragment state.

- **If two active adjacency effects both modify the same attack parameter simultaneously (e.g., two `ADJ_STATUS_EXTEND` effects):** Both apply additively. Total extension = sum of both values. If the combined result causes a status tick count to exceed a cap defined in the Status Effects GDD, the Status Effects cap applies at the consuming system — not here.

- **If `ADJ_EXTRA_HIT` and `ADJ_DOUBLE_HIT` are both active:** Both apply. The chain becomes: standard attacks → first attack fires twice in-place (Double Hit) → bonus attack appended at end (Extra Hit). Spell Casting sees `combo_attack_count + 1` total chain length. Double Hit does not append; it repeats in-place.

- **If `ADJ_ECHO` is mid-delay when `preparation_started` fires:** Echo is cancelled. The cached SpellEffect is cleared. Echo does not fire into the next wave's preparation phase.

- **If `ADJ_ECHO` is mid-delay when `death_started` or any run-ending signal fires:** Echo is cancelled identically to `preparation_started` — the delay timer is stopped, no Echo Strike fires, and the cached SpellEffect is cleared. Echo must not fire during death animation or run summary screens.

- **If `effective_primary_count` exceeds 9 (possible at higher levels):** Tier 3 is the maximum. Any count ≥ 6 resolves to Tier 3 with no error.

- **If `effective_nonprimary_count(T)` is very large:** Tier 2 is the maximum non-primary tier. Any count ≥ 3 resolves to Tier 2 with no error.

- **If Verdant non-primary Tier 2 amplifier is active with `VER_HEAL_FLAT` stat bonus:** Apply flat bonus first, then amplifier: `amplified_heal = (heal_amount + VER_HEAL_FLAT) × VERDANT_NP_HEAL_AMP`.

- **If Deepfrost T2 non-primary Freeze (1.0s) is applied to an already-Frozen enemy:** Per Prana Data refresh rule, Freeze timer resets to the applied duration — 1.0s, not the primary Deepfrost's 2.0s. If the enemy had 1.8s remaining, it resets to 1.0s. Spell Casting must track Freeze source to apply the correct duration.

- **If `ADJ_BARRIER_HIT` and Verdant T2 shield pulse barrier are both active simultaneously:** Two independent barriers. First-granted absorbs first. No stacking on a single hit — two barriers do not double absorption.

- **If multiple combo window extensions are active simultaneously (Stormgold non-primary + `ADJ_COMBO_EXTEND` + `STORM_COMBO_SPD` stat):** All extend additively. No cap at First Playable scope. If playtest reveals excessive window tolerance, add `COMBO_WINDOW_MAX` tuning knob.

- **If the Core Prana starter fragment is replaced during the run by a drop:** No special CR handling — it is simply a different fragment in slot 4. Core Prana selection has no persistent effect on CR after run start.

- **If the primary target dies from the first chain attack before `ADJ_CHAIN_LIGHTNING`'s arc fires:** Arc re-targets to the nearest surviving enemy at the moment the second attack resolves. If no other enemies remain, the arc is suppressed. No error logged.

- **If the primary target dies from the first firing of `ADJ_DOUBLE_HIT` (1.00× hit):** The second firing (0.75×) is suppressed — no primary target remains. Chain advances to the next attack normally. No error logged.

- **If two reacting types are present but only diagonally adjacent (never cardinally):** No reaction arms. Diagonal is not a cardinal neighbor (Rule 9). Intentional positioning pressure — not an error.

- **If the same reacting pair is cardinally adjacent in several places (e.g., Ashfire–Deepfrost adjacent at two seams):** The reaction arms exactly once (dedup per Rule 16c). `active_reactions` contains one entry for that pair.

- **If all 9 fragments are the same type:** No two different types are adjacent → `active_reactions` is empty. Not an error (mirrors the no-non-primary case).

- **If both Thermal Shock (reaction) and Shatter (Deepfrost conditional) would apply to the same hit:** They do NOT stack multiplicatively. SC&E applies the larger single first-hit bonus only (at default values both are +0.25, so net ×1.25, never ×1.50). Prevents a double-dip on the same "ice + impact" fantasy.

- **If a reaction's secondary-target effect has no eligible target (Short Circuit second enemy, Detonate AoE with no nearby enemy, Superconduct arc, Wildfire spread):** The secondary portion is suppressed; the primary portion (if any) still applies. No error logged — mirrors `ADJ_CHAIN_LIGHTNING` / `ADJ_FROST_BURST` behavior.

- **If a reaction depends on a live status that is not present at apply time (Whiteout needs Blind+slow; Permafrost needs a Frozen enemy):** The reaction is *armed* but its conditional effect simply does not fire until/unless that status exists during the cast. Armed ≠ guaranteed-to-fire. No error — same contract as adjacency effects whose runtime condition is unmet.

- **If `MAX_ACTIVE_REACTIONS` is configured > 0 and more reactions arm than the cap:** Excess reactions are dropped in ascending `(type_a, type_b)` order so the kept set is deterministic. At MVP the cap is `0` (unlimited) — no reactions are ever dropped.

- **If a future Prana type is added (VS) and the Reaction Matrix has no entry for one of its pairs:** That pair arms nothing. `REACTION_MATRIX` load-time validation must `push_warning` once per missing defined-type pair so gaps surface during development rather than silently producing dead adjacencies.

- **Short Circuit vs. the Follow-Through "idle Stun does not qualify" rule:** Short Circuit deliberately overrides Prana Data's rule that a Stun on an idle enemy does not open the Follow-Through window — when Short Circuit is armed, the first Stun is *forced* to qualify regardless of enemy state. This is an intentional reaction exception, not a contradiction. SC&E and Prana Data must treat the armed-Short-Circuit case as the documented exception to the idle-Stun rule.

- **If Permafrost (regen amp ×1.50) and Verdant non-primary heal amp (×1.25) are both active:** They stack **multiplicatively** (`2 HP × 1.50 × 1.25 = 3.75 HP/tick`). This is an intentional reward for a Frost+Verdant build that also fields 3+ Verdant ring fragments. Flagged for playtest: if over-sustain emerges, the resolution is to make heal amplifiers take the **max** rather than the product — decided at balance time, not here.

- **If the core has exactly 1 distinct neighbor type (`|M| == 1`):** No Cascade fires. The single core↔neighbor pairwise reaction (Rule 16) applies normally — the Cascade threshold is 2 distinct modifiers. No error.

- **If the core has 0 distinct neighbor types (`|M| == 0`):** all neighbors null or same type as the core. No Cascade, no core pairwise reaction. Primary resolution is unaffected.

- **If a neighbor slot holds the core type itself:** It is excluded from `M` (same type = no reaction/modifier) but counts in full toward `effective_primary_count` (Formula 1). Surrounding the core with its own type pumps primary tier instead of feeding the Cascade — the explicit tall-vs-wide trade-off.

- **If the same modifier type occupies two or more neighbor slots:** It contributes exactly one modifier to the Cascade (set semantics, Rule 17e) but each fragment still counts toward primary / non-primary tier.

- **If a Cascade fires while ring↔ring pairwise reactions also exist (non-core slots):** Only the core↔neighbor pairwise reactions are consumed by the Cascade (Rule 17d). Ring↔ring reactions (e.g., an Ashfire–Voidblue pair both in corner-adjacent ring slots) still emit into `active_reactions` independently. Assert both the Cascade and the surviving ring reaction are present.

- **If a Verdant-lead Cascade has offensive modifiers but no enemy within `CASCADE_AOE_RADIUS` of the primary target:** The offensive facets (Burn/Blind/Freeze/arc) are suppressed for lack of a target; the Nourish heal on Fayde still applies. No error.

- **If `MAX_CASCADE_MODIFIERS` is configured below 4 and more distinct neighbor types are present:** Excess modifiers are dropped in ascending `type_id` so the kept set is deterministic. At MVP the cap is 4 — no modifier is ever dropped on the 3×3 grid (max 4 cardinal neighbors).

- **If an Ashfire-lead Cascade nova overlaps an Ashfire primary T3 eruption (both AoE around similar origin):** They fire as two distinct bursts and do not merge or double-count a single hit; each applies its own damage and Burn independently. Flagged for VFX legibility and balance review — the visual must keep them distinguishable.

## Dependencies

### Systems That Depend on Combination Resolution

| System | What it needs | Nature |
|--------|---------------|--------|
| **Spell Casting & Effects** (#3, First Playable) | `SpellEffect` resource via `combo_resolved(spell_effect)` signal — primary type, primary tier, combo count, non-primary modifiers, adjacency effects, aggregate stat bonus — to execute the cast chain, apply modifiers, and route VFX/audio | Hard — cannot execute any cast without CR output |
| **Combat HUD** (#22, First Playable) | Cached `SpellEffect` for displaying primary tier and active non-primary modifier icons during LOCKED state | Soft — minimal display possible without CR; enriched display requires it |
| **Run Summary Screen** (#23, Vertical Slice) | Access to resolved combo history for post-run statistics | Soft — deferred to VS scope |
| **Loadout Slots** (#18, Vertical Slice) | Resolution of saved arrangements for loadout preview | Soft — deferred to VS scope |
| **Tutorial / Onboarding** (#31, Vertical Slice) | Observation of combo resolution outputs to trigger tutorial prompts | Soft — deferred to VS scope |

### Combination Resolution's Own Dependencies

| System | What CR needs | Nature |
|--------|---------------|--------|
| **Prana Grid** (#1, First Playable) | `committed_fragments: Array[PranaFragment]` (length 9, null = empty) via public getter after `combat_started`; each element carries `type_id`, `level`, `stat_property`, `adjacency_effects` | Hard — no fragment data = no resolution |
| **Prana Data** (#4, Approved) | `base_damage_modifier` and `base_status` per type via `PranaCatalog.get_type(id)` | Hard — both are required SpellEffect fields |
| **Game State & Scene Flow** (#27, Approved) | `combat_started` (trigger resolution) and `preparation_started` (invalidate cache) signals | Hard — CR has no independent game-phase knowledge |

**Bidirectional consistency notes:**
- Spell Casting & Effects GDD must list CR as an upstream dependency and specify it reads `SpellEffect` exclusively via `combo_resolved`.
- Prana Grid GDD must list CR as a downstream dependent and confirm the `committed_fragments: Array[PranaFragment]` interface (change from current `committed_arrangement: Array[int]`).
- Prana Data GDD already lists CR as a downstream dependent — confirmed.

**Cross-GDD change flags (carried forward from Section C):**
1. **Prana Grid GDD**: (a) `committed_arrangement: Array[int]` → `committed_fragments: Array[PranaFragment]`; (b) Confirm blocked if slot 4 is empty; (c) **NEW** — must render the live Prana Reaction **and** Cascade preview during Preparation Phase by calling the stateless reaction/cascade computation on every place/move (Rules 16f, 17g)
2. **Prana Drop / Loot GDD**: must define `PranaFragment` generation (type, level, random `stat_property`, random `adjacency_effects[level]`) — a First Playable dependency given the Core Prana model
3. **Spell Casting & Effects GDD**: must read `SpellEffect.active_reactions` (apply each by `effect_kind`, Formula 9) **and** `SpellEffect.active_cascade` (apply the core-led burst by `lead_type` + `modifiers`, Formula 10); owns the Thermal-Shock-vs-Shatter non-stacking rule, the `ReactionKind` enum routing, and the Cascade burst targeting/facet application
4. **Combat HUD GDD**: may display `active_reactions` during the LOCKED/combat state (read-only)
5. **Prana Data**: Reaction vocabulary is intended to later subsume Shatter / Burn Contagion / Follow-Through (Rule 16h) — flag only, no change required at MVP

## Tuning Knobs

| Knob | Symbol | Current Value | Safe Range | Effect if too high | Effect if too low |
|------|--------|---------------|------------|-------------------|-------------------|
| Primary tier threshold 1 upper | `PRIMARY_T1_MAX` | 2 | 1–3 | Tier 2 reaches trivially — 2-attack chains become default | Tier 2 unreachable at lv.1 scope |
| Primary tier threshold 2 upper | `PRIMARY_T2_MAX` | 5 | 3–7 | Tier 3 is easy — high combo counts become default | Tier 3 crowds out all non-primary slots |
| Non-primary tier 2 threshold | `NP_TIER2_MIN` | 3 | 2–5 | Enhanced non-primary feels default | Tier 2 non-primary unreachable at lv.1 scope |
| Combo continuation window | `combo_continuation_window` | 2.0s (TBD by playtest) | 0.8–3.0s | Chain timing has no skill expression | Too tight for age 7+ accessibility target |
| Ashfire T3 AoE radius | `ASHFIRE_T3_AOE_RADIUS` | 80px | 40–150px | Eruption clears entire waves — positioning irrelevant | AoE barely catches secondary targets |
| Glacial field duration | `GLACIAL_FIELD_DURATION` | 3.0s | 1.5–5.0s | Trivializes approach lanes | Zone expires before enemies can be driven into it |
| Glacial field radius | `GLACIAL_FIELD_RADIUS` | 120px | 60–200px | Full-wave slow guaranteed | Zone too small; positional value lost |
| Verdant barrier duration | `BARRIER_DURATION` | 4.0s | 2.0–8.0s | Barrier persists through multiple attack waves | Too short for slow-reaction players to benefit |
| Verdant barrier coefficient | `BARRIER_COEFFICIENT` | 0.10 | 0.05–0.30 | High barrier HP absorbs many weak multi-ticks | Barrier HP too low for multi-hit resilience |
| Ashfire non-primary bonus | `ASHFIRE_NP_BONUS` | 0.15 | 0.05–0.25 | Ashfire non-primary becomes mandatory in all builds | Too small to shift Deepfrost/Verdant primary damage meaningfully |
| Voidblue non-primary T1 blind chance | `VOIDBLUE_NP_CHANCE` | 0.30 | 0.15–0.50 | Probabilistic Blind approaches guaranteed | Effect too unreliable to notice |
| Voidblue non-primary Blind extension | `VOIDBLUE_NP_EXTEND` | 1.0s | 0.3–2.0s | Blind extended to cap quickly | T2 non-primary feels identical to T1 |
| Stormgold non-primary window extension | `STORMGOLD_NP_WINDOW_T1` | 0.3s | 0.1–1.0s | Combined with other extensions, window becomes trivially long | No perceptible value in action |
| Deepfrost non-primary chill slow | `CHILL_SLOW_PCT` | 0.15 | 0.05–0.40 (hard cap) | Chill approaches Freeze-level slow | Too minor to notice; feels cosmetic |
| Deepfrost non-primary Freeze duration | `NONPRIMARY_FREEZE_DURATION` | 1.0s | 0.5–1.5s | Approaches primary Freeze — removes primary vs. non-primary tension | Too short to land follow-up attacks in Shatter window |
| Verdant non-primary heal amplifier | `VERDANT_NP_HEAL_AMP` | 1.25 | 1.05–1.50 | Sustain trivializes Charger attrition | T2 feels identical to T1 |
| Adjacency Splash radius | `ADJ_SPLASH_RADIUS` | 60px | 30–120px | Hits all enemies in cramped arenas | Equivalent to no AoE |
| Adjacency Status Extension | `ADJ_STATUS_EXT` | 1.0s | 0.3–2.0s | Durations become extremely long | Indistinguishable from non-extended |
| Adjacency Combo Window Extension | `ADJ_COMBO_WIN` | 0.5s | 0.2–1.5s | Timing constraint disappears | Too small to help struggling players |
| Adjacency Lifesteal percent | `ADJ_LIFESTEAL_PCT` | 0.20 | 0.05–0.35 | Lifesteal sustains through heavy damage; Verdant neighbor feels mandatory | Too low to register as meaningful |
| Adjacency Burn Intensify bonus | `ADJ_BURN_INTENSIFY_BONUS` | 0.04 | 0.02–0.08 | Approaches Prana Data burn cap (Status Effects must enforce ≤ 0.60 combined constraint) | Indistinguishable from non-intensified Burn |
| Adjacency Phase Shift duration | `ADJ_PHASE_DURATION` | 0.6s | 0.3–1.0s | Post-cast i-frame trivializes aggressive enemy responses | Too short to protect against point-blank hits |
| Adjacency Echo delay | `ADJ_ECHO_DELAY` | 0.8s | 0.3–2.0s | Echo reads as a 4th chain attack at short delays — timing identity lost | Too late; echo catches only standing enemies |
| Max active reactions | `MAX_ACTIVE_REACTIONS` | 0 (unlimited) | 0–6 | (n/a — higher only loosens cap) | Caps combinatorial depth; reactions silently dropped, undermining the system's purpose |
| Thermal Shock bonus | `REACT_THERMAL_BONUS` | 0.25 | 0.10–0.40 | Fire+ice burst dominates; mirrors/exceeds Shatter value | Reaction feels cosmetic vs a plain hit |
| Detonate damage | `REACT_DETONATE_DMG` | 0.50 | 0.25–0.80 | Kill-detonations clear clustered waves for free | Burst too weak to matter |
| Detonate radius | `REACT_DETONATE_RADIUS` | 70px | 40–120px | Detonation hits whole arenas | Radius too small to catch a second enemy |
| Witchfire blind | `REACT_WITCHFIRE_BLIND` | 1.0s | 0.5–2.0s | Burn builds gain near-permanent evasion suppression | Blind window too brief to land around an enemy attack |
| Wildfire spread range | `REACT_WILDFIRE_RANGE` | 150px | 80–300px | Burn cascades across packs at apply-time | Spread almost never finds a second target |
| Short Circuit second stun | `REACT_SHORTCIRCUIT_STUN` | 0.8s | 0.8–1.0s | Approaches two-target guaranteed lockdown | Below 0.8s breaks Stun perceptibility floor (Prana Data Core Rule 8) |
| Whiteout miss chance | `REACT_WHITEOUT_MISS` | 0.90 | 0.60–0.95 | Near-immunity vs Blind+slow stacks | Indistinct from baseline Blind |
| Siphon leech | `REACT_SIPHON_LEECH` | 0.20 | 0.05–0.35 | Sustains through heavy damage vs blinded packs | Heal too small to register |
| Superconduct arc | `REACT_SUPERCONDUCT_ARC` | 0.60 | 0.30–0.90 | Frozen targets become free multi-hits | Arc damage negligible |
| Surge window extension | `REACT_SURGE_WINDOW` | 0.4s | 0.1–1.0s | Combined with other extensions, window becomes trivially long | No perceptible chain benefit |
| Surge heal per hit | `REACT_SURGE_HEAL` | 2 HP | 1–5 HP | Chains become passive sustain engines | Heal irrelevant to survival |
| Permafrost regen amp | `REACT_PERMAFROST_AMP` | 1.50 | 1.10–2.00 | Freeze builds heal through any attrition | T-feels identical to un-amplified Regen |
| Max cascade modifiers | `MAX_CASCADE_MODIFIERS` | 4 | 2–4 | (n/a — 4 is the grid maximum) | Caps Cascade richness; some neighbor flavor silently dropped |
| Cascade base multiplier | `CASCADE_LEAD_MULT` | 1.0 | 0.6–1.4 | Cascade burst outdamages the primary chain | Cascade feels like a cosmetic flourish |
| Cascade per-modifier bonus | `CASCADE_MOD_DMG_BONUS` | 0.10 | 0.05–0.20 | Wide builds out-scale tall builds on damage | No reward for adding modifiers |
| Cascade multiplier cap | `CASCADE_MULT_CAP` | 1.6 | 1.2–2.0 | 4-modifier cascades spike damage | Cap bites before 4 modifiers matter |
| Cascade AoE radius | `CASCADE_AOE_RADIUS` | 90px | 50–160px | Nova/field clears whole arenas | Burst barely catches a second enemy |
| Cascade blind facet duration | `CASCADE_BLIND_DUR` | 1.0s | 0.5–2.0s | Voidblue-fed cascades grant sustained evasion | Blind too brief to matter |
| Cascade freeze facet duration | `CASCADE_FREEZE_DUR` | 1.0s | 0.5–1.5s | Approaches primary Freeze lockdown | Too short to set up a follow-up |
| Cascade arc targets | `CASCADE_ARC_TARGETS` | 1 | 1–3 | Stormgold-fed cascades hit whole packs | Arc facet feels absent |
| Cascade lifesteal | `CASCADE_LIFESTEAL` | 0.15 | 0.05–0.30 | Verdant-fed cascades over-sustain | Heal negligible |

**Interaction warnings:**
- `STORMGOLD_NP_WINDOW_T1` + `ADJ_COMBO_WIN` + `STORM_COMBO_SPD` stat all stack on `combo_continuation_window`. Add `COMBO_WINDOW_MAX` safety cap if playtest reveals excessive tolerance.
- `ADJ_BURN_INTENSIFY_BONUS` + `ASH_BURN_TICK` both raise `burn_tick_magnitude`. Prana Data burn cap constraint (`burn_tick_magnitude × tick_count ≤ 0.60`) enforced by Status Effects — not CR.
- `CHILL_SLOW_PCT` + `FROST_CHILL_WIDE`: hard cap 0.40. `VOID_MISS_CHANCE` + stat bonus: hard cap 0.90. Both caps enforced at stat property application.
- `REACT_THERMAL_BONUS` overlaps Shatter (+0.25 default). They do NOT stack on the same hit (Edge Cases) — SC&E applies the larger single bonus. When tuning either above 0.25, review the combined "ice + impact" power budget.
- `REACT_SURGE_WINDOW` also stacks on `combo_continuation_window` alongside `STORMGOLD_NP_WINDOW_T1`, `ADJ_COMBO_WIN`, and `STORM_COMBO_SPD`. Include it when sizing any `COMBO_WINDOW_MAX` safety cap.
- `REACT_WHITEOUT_MISS` is a *set-to* value, not additive — it overrides the effective miss chance (still ≤ the 0.90 Blind hard cap) while both Blind and slow are active. Keep ≤ 0.90 to respect the global Blind cap.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

> *`qa-lead` consulted (lean mode — Acceptance Criteria is HIGH implementation risk). 44 criteria; 41 Logic (unit-testable, no SceneTree), 3 Integration (signal bus / timer). All Section C core rules and Section D formulas covered, including the Prana Reaction layer (Rule 16 / Formula 9) and the Cascade tier (Rule 17 / Formula 10).*

---

### AC-CR-01: Centre slot determines primary type *(Logic)*
**Given** slot 4 = Deepfrost (type 3) lv.1; slots 0 and 2 = Ashfire (type 0) lv.1 each
**When** `combat_started` fires and CR resolves
**Then** `SpellEffect.primary_type == 3`
**Pass**: Assert `spell_effect.primary_type == 3`. Ashfire fragments in surrounding slots must not override the centre.

---

### AC-CR-02: Effective primary count sums levels across all same-type slots *(Logic)*
**Given** slot 4 = Ashfire lv.2, slot 0 = Ashfire lv.1, slot 7 = Ashfire lv.3; all other slots null
**When** CR resolves
**Then** `effective_primary_count = 6`; `SpellEffect.primary_tier == 3`
**Pass**: Assert `spell_effect.primary_tier == 3`.

---

### AC-CR-03: Non-centre same-type fragments contribute to primary count, not non-primary *(Logic)*
**Given** slot 4 = Ashfire lv.1 (primary), slot 0 = Ashfire lv.1 (non-centre, same type); all other slots null
**When** CR resolves
**Then** `effective_primary_count = 2`; `SpellEffect.primary_tier == 1`; no Ashfire entry in `non_primary_modifiers`
**Pass**: Assert `primary_tier == 1`. Assert no Ashfire `NonPrimaryModifier` in `non_primary_modifiers`.

---

### AC-CR-04: Primary tier T1/T2 seam — count 2 vs. 3 *(Logic)*
**Given** (a) arrangement with `effective_primary_count = 2`; (b) arrangement with `effective_primary_count = 3`
**When** CR resolves each independently
**Then** (a) `primary_tier == 1`; (b) `primary_tier == 2`
**Pass**: Both assertions must pass; either failure is a threshold defect.

---

### AC-CR-05: Primary tier T2/T3 seam — count 5 vs. 6 *(Logic)*
**Given** (a) arrangement with `effective_primary_count = 5`; (b) arrangement with `effective_primary_count = 6`
**When** CR resolves each independently
**Then** (a) `primary_tier == 2`; (b) `primary_tier == 3`
**Pass**: Both assertions must pass.

---

### AC-CR-06: Effective primary count above 9 resolves to tier 3 without error *(Logic)*
**Given** slot 4 = Ashfire lv.5, slot 0 = Ashfire lv.5 (`effective_primary_count = 10`); all other slots null
**When** CR resolves
**Then** `SpellEffect.primary_tier == 3`; no `push_error` triggered; no exception thrown
**Pass**: Assert `primary_tier == 3` and no error output.

---

### AC-CR-07: Non-primary effective count excludes the centre slot *(Logic)*
**Given** slot 4 = Ashfire lv.1 (primary), slot 0 = Deepfrost lv.2 (non-centre); no other Deepfrost fragments
**When** CR resolves
**Then** `effective_nonprimary_count(Deepfrost) = 2`; `non_primary_modifiers` contains Deepfrost at tier 1
**Pass**: Assert Deepfrost `NonPrimaryModifier` with `tier == 1` is present.

---

### AC-CR-08: Non-primary tier 0 — type absent from non-centre slots *(Logic)*
**Given** slot 4 = Stormgold lv.1 (primary); all non-centre slots null or Stormgold only; no Deepfrost anywhere in non-centre slots
**When** CR resolves
**Then** `non_primary_modifiers` contains no Deepfrost entry
**Pass**: Assert no `NonPrimaryModifier` with `type_id == 3` in `non_primary_modifiers`.

---

### AC-CR-09: Non-primary tier 1 — count 1 and count 2 both produce tier 1 *(Logic)*
**Given** (a) slot 4 = Ashfire lv.1, slot 1 = Deepfrost lv.1 (non-primary count 1); (b) slot 4 = Ashfire lv.1, slots 1 and 3 = Deepfrost lv.1 each (non-primary count 2)
**When** CR resolves each independently
**Then** both produce Deepfrost `NonPrimaryModifier.tier == 1`
**Pass**: Assert tier 1 in both arrangements.

---

### AC-CR-10: Non-primary tier T1/T2 seam — count 2 vs. 3 *(Logic)*
**Given** (a) slot 4 = Ashfire lv.1; non-centre Deepfrost fragments summing to level 2; (b) same primary; non-centre Deepfrost summing to level 3
**When** CR resolves each independently
**Then** (a) Deepfrost `NonPrimaryModifier.tier == 1`; (b) Deepfrost `NonPrimaryModifier.tier == 2`
**Pass**: Both assertions must pass.

---

### AC-CR-11: Multiple non-primary types active simultaneously *(Logic)*
**Given** slot 4 = Stormgold lv.1 (primary), slot 0 = Ashfire lv.2 (non-primary count 2), slot 1 = Deepfrost lv.1 (count 1), slot 2 = Verdant lv.1 (count 1); all other slots null
**When** CR resolves
**Then** `non_primary_modifiers` contains exactly three entries: Ashfire tier 1, Deepfrost tier 1, Verdant tier 1; no Stormgold entry
**Pass**: Assert `non_primary_modifiers.size() == 3`. Assert each expected type and tier. Assert no Stormgold entry.

---

### AC-CR-12: All-same-type arrangement — no non-primary modifiers *(Logic)*
**Given** all 9 slots = Ashfire lv.1 (`effective_primary_count = 9`)
**When** CR resolves
**Then** `SpellEffect.primary_tier == 3`; `non_primary_modifiers` is empty; no error
**Pass**: Assert `primary_tier == 3`, `non_primary_modifiers.size() == 0`, no `push_error`.

---

### AC-CR-13: Base damage modifier and fallback status sourced from PranaCatalog *(Logic)*
**Given** slot 4 = Verdant lv.1 (primary); `PranaCatalog.get_type(4)` returns `base_damage_modifier = 0.70` and `base_status = REGENERATE`
**When** CR resolves
**Then** `SpellEffect.base_damage_modifier == 0.70`; `SpellEffect.primary_base_status == REGENERATE`
**Pass**: Assert both fields match PranaCatalog values. Use a test double for PranaCatalog returning known values.

---

### AC-CR-14: Stat aggregation sums all placed fragments regardless of adjacency *(Logic)*
**Given** slot 4 = Ashfire lv.1 with `stat_property = {ASH_DMG: 5}`, slot 0 = Deepfrost lv.1 with `stat_property = {FROST_DMG: 3}`, slot 2 = Verdant lv.1 with `stat_property = {VER_HEAL_FLAT: 2}`; no adjacency conditions satisfied
**When** CR resolves
**Then** `aggregate_stat_bonus == {ASH_DMG: 5, FROST_DMG: 3, VER_HEAL_FLAT: 2}`
**Pass**: Assert dictionary equality. Confirm no extra keys are present.

---

### AC-CR-15: Triggered adjacency STAT_BONUS adds to aggregate_stat_bonus *(Logic)*
**Given** slot 4 = Ashfire lv.1 with `stat_property = {ASH_DMG: 5}` and one adjacency effect `required_neighbors = []` (no condition), `effect = {type: STAT_BONUS, key: ASH_DMG, value: 10}`
**When** CR resolves
**Then** `aggregate_stat_bonus["ASH_DMG"] == 15` (5 from stat_property + 10 from triggered adjacency)
**Pass**: Assert `aggregate_stat_bonus["ASH_DMG"] == 15`.

---

### AC-CR-16: Adjacency effect with no required_neighbors always triggers *(Logic)*
**Given** slot 4 = Ashfire lv.1 with one adjacency effect `required_neighbors = []`, `effect = ADJ_DOUBLE_HIT`; all surrounding slots null
**When** CR resolves
**Then** `active_adjacency_effects` contains `ADJ_DOUBLE_HIT`
**Pass**: Assert `active_adjacency_effects` contains the `ADJ_DOUBLE_HIT` modifier. Surrounding nulls confirm no neighbor is required.

---

### AC-CR-17: Adjacency effect triggers when all AND conditions are satisfied *(Logic)*
**Given** slot 4 = Ashfire lv.1 with one adjacency effect `required_neighbors = [{ABOVE, type 0}, {BELOW, type 0}]`, `effect = ADJ_BURN_INTENSIFY`; slot 1 (ABOVE slot 4) = Ashfire lv.1; slot 7 (BELOW slot 4) = Ashfire lv.1
**When** CR resolves
**Then** `active_adjacency_effects` contains `ADJ_BURN_INTENSIFY`
**Pass**: Assert `ADJ_BURN_INTENSIFY` is present in `active_adjacency_effects`.

---

### AC-CR-18: Adjacency effect does NOT trigger when only one of two AND conditions is satisfied *(Logic)*
**Given** same fragment as AC-CR-17 (requires ABOVE = Ashfire AND BELOW = Ashfire); slot 1 = Ashfire lv.1; slot 7 = null or Deepfrost
**When** CR resolves
**Then** `active_adjacency_effects` does NOT contain `ADJ_BURN_INTENSIFY`
**Pass**: Assert `ADJ_BURN_INTENSIFY` is absent. Partial condition satisfaction must not trigger the effect.

---

### AC-CR-19: Out-of-bounds neighbor direction does not trigger and does not error *(Logic)*
**Given** slot 0 (top-left corner, row 0) contains a fragment with one adjacency effect `required_neighbors = [{ABOVE, type -1}]`; no row above slot 0 exists
**When** CR resolves
**Then** the effect is absent from `active_adjacency_effects`; no `push_error` is triggered
**Pass**: Assert effect absent. Assert no error output. Boundary miss is a valid design-state, not a bug.

---

### AC-CR-20: Null neighbor slot does not satisfy a neighbor condition *(Logic)*
**Given** slot 4 = Ashfire lv.1 with one adjacency effect `required_neighbors = [{LEFT, type -1}]`; slot 3 (LEFT of slot 4) = null
**When** CR resolves
**Then** the effect is absent from `active_adjacency_effects`
**Pass**: Assert effect absent. A null occupant in a valid grid position counts as unsatisfied — not a wildcard match.

---

### AC-CR-21: Wrong neighbor type does not satisfy a typed condition *(Logic)*
**Given** slot 4 = Ashfire lv.1 with one adjacency effect `required_neighbors = [{RIGHT, type 2}]` (requires Stormgold); slot 5 (RIGHT of slot 4) = Deepfrost lv.1
**When** CR resolves
**Then** the effect is absent from `active_adjacency_effects`
**Pass**: Assert effect absent. A present but wrong-type neighbor must not satisfy a typed condition.

---

### AC-CR-22: required_type_id = -1 (wildcard) matches any present neighbor type *(Logic)*
**Given** slot 4 = Ashfire lv.1 with one adjacency effect `required_neighbors = [{RIGHT, type -1}]`; slot 5 = Deepfrost lv.1
**When** CR resolves
**Then** the effect appears in `active_adjacency_effects`
**Pass**: Assert effect present. Wildcard must accept any non-null neighbor type.

---

### AC-CR-23: Multiple adjacency effects across multiple fragments are all collected *(Logic)*
**Given** slot 4 = Ashfire lv.1 with `ADJ_DOUBLE_HIT` (no condition); slot 0 = Deepfrost lv.1 with `ADJ_STATUS_EXTEND` requiring `{BELOW: any type}`; slot 3 (BELOW slot 0) = Ashfire lv.1 satisfying the condition
**When** CR resolves
**Then** `active_adjacency_effects` contains both `ADJ_DOUBLE_HIT` and `ADJ_STATUS_EXTEND`
**Pass**: Assert `active_adjacency_effects.size() == 2` and both effects are present.

---

### AC-CR-24: Null centre slot emits no-op SpellEffect and pushes error *(Logic)*
**Given** slot 4 = null; all other slots any state
**When** `combat_started` fires and CR resolves
**Then** `push_error` is called (identifying null centre); `combo_resolved` is emitted with `SpellEffect.primary_type == -1`
**Pass**: Assert `push_error` was called. Assert `combo_resolved` emitted. Assert `spell_effect.primary_type == -1`.

---

### AC-CR-25: All-null arrangement emits no-op SpellEffect and pushes error *(Logic)*
**Given** all 9 slots null
**When** `combat_started` fires and CR resolves
**Then** `push_error` is called; `combo_resolved` emitted with `SpellEffect.primary_type == -1`
**Pass**: Same assertions as AC-CR-24.

---

### AC-CR-26: `combo_resolved` emitted exactly once after every valid resolution *(Integration)*
**Given** any valid arrangement (slot 4 non-null); a signal spy connected to `combo_resolved`
**When** `combat_started` fires
**Then** signal spy receives exactly one call; `spell_effect.primary_type` is in range 0–4
**Pass**: Assert spy call count == 1. Assert `primary_type` is 0–4.

---

### AC-CR-27: `preparation_started` clears the cached SpellEffect *(Integration)*
**Given** CR has resolved and cached a SpellEffect from a prior `combat_started`
**When** `preparation_started` fires; then `combat_started` fires again with a different arrangement
**Then** the second `combo_resolved` payload reflects the new arrangement, not the prior one; the cache was cleared between waves
**Pass**: Assert first and second `SpellEffect.primary_type` differ when different arrangements are used. Assert the second resolution is not stale.

---

### AC-CR-28: ADJ_ECHO mid-delay cancels when `preparation_started` fires *(Integration)*
**Given** slot 4 has a fragment with `ADJ_ECHO` (condition satisfied); `combat_started` fires; the `ADJ_ECHO_DELAY = 0.8s` timer has not elapsed
**When** `preparation_started` fires before the delay expires
**Then** no Echo Strike fires; no second `combo_resolved` or echo signal is emitted into the preparation phase; cache is null
**Pass**: Assert no additional signal emission after `preparation_started`. Assert cache is cleared.

---

### AC-CR-29: `primary_base_status` populated alongside active non-primary modifiers *(Logic)*
**Given** slot 4 = Ashfire lv.1 (primary); slot 0 = Deepfrost lv.1 (`effective_nonprimary_count(Deepfrost) = 1` → non-primary tier 1); all other slots null
**When** CR resolves
**Then** `SpellEffect.primary_base_status == GameEnums.BaseStatus.BURN`; `non_primary_modifiers` contains exactly one entry: Deepfrost with `tier == 1`
**Pass**: Assert `primary_base_status == BURN`. Assert `non_primary_modifiers.size() == 1` with `type_id == 3` and `tier == 1`. Confirms the SC&E contract: `primary_base_status` is always populated regardless of `non_primary_modifiers` content.

---

### AC-CR-30: Reaction arms on cardinal adjacency of two different types *(Logic)*
**Given** slot 4 = Deepfrost lv.1 (primary); slot 1 = Ashfire lv.1 (ABOVE slot 4); all other slots null
**When** CR resolves
**Then** `active_reactions` contains exactly one entry whose `effect_kind == THERMAL_SHOCK`
**Pass**: Assert `active_reactions.size() == 1` and the entry's `effect_kind == THERMAL_SHOCK`.

---

### AC-CR-31: Diagonal-only adjacency does NOT arm a reaction *(Logic)*
**Given** slot 4 = Deepfrost lv.1; slot 0 = Ashfire lv.1 (diagonal to slot 4, not cardinal); all other slots null
**When** CR resolves
**Then** `active_reactions` is empty
**Pass**: Assert `active_reactions.size() == 0`. Diagonal adjacency must not arm a reaction (Rule 16b).

---

### AC-CR-32: Same-type cardinal adjacency arms no reaction *(Logic)*
**Given** slot 4 = Ashfire lv.1; slot 1 = Ashfire lv.1 (ABOVE); all other slots null
**When** CR resolves
**Then** `active_reactions` is empty
**Pass**: Assert `active_reactions.size() == 0`. Two same-type neighbors never react.

---

### AC-CR-33: Duplicate reacting pair dedups to a single reaction *(Logic)*
**Given** slot 4 = Deepfrost lv.1; slot 1 = Ashfire lv.1 (ABOVE slot 4); slot 5 = Ashfire lv.1 (RIGHT of slot 4) — Deepfrost–Ashfire cardinal adjacency exists at two seams
**When** CR resolves
**Then** `active_reactions` contains exactly one `THERMAL_SHOCK` entry
**Pass**: Assert exactly one entry with `effect_kind == THERMAL_SHOCK` (dedup per Rule 16c).

---

### AC-CR-34: Multiple distinct reactions arm simultaneously, deterministically ordered *(Logic)*
**Given** slot 4 = Deepfrost lv.1 (type 3); slot 1 = Ashfire lv.1 (type 0, ABOVE); slot 3 = Verdant lv.1 (type 4, LEFT)
**When** CR resolves
**Then** `active_reactions` contains exactly two entries — Thermal Shock (pair 0,3) and Permafrost (pair 3,4) — in ascending `(type_a, type_b)` order; no Wildfire (Ashfire and Verdant are not adjacent)
**Pass**: Assert size == 2; assert order is `[THERMAL_SHOCK, PERMAFROST]`; assert no `WILDFIRE` entry.

---

### AC-CR-35: All-same-type arrangement arms no reactions, no error *(Logic)*
**Given** all 9 slots = Ashfire lv.1
**When** CR resolves
**Then** `active_reactions` is empty; no `push_error`
**Pass**: Assert `active_reactions.size() == 0` and no error output.

---

### AC-CR-36: `compute_reactions` is stateless and pure (preview parity) *(Logic)*
**Given** a fixed `fragments` array with one cardinal cross-type pair
**When** `CombinationResolution.compute_reactions(fragments)` is called twice with no intervening state change
**Then** both calls return equal `Array[ReactionDef]` (same ids, same order); the result depends only on the input array, not on any combat/cached state
**Pass**: Assert the two returned arrays are equal. Confirms the prep preview and the resolution pass share one deterministic function (Rule 16f).

---

### AC-CR-37: Reaction involving the centre (primary) type is not excluded *(Logic)*
**Given** slot 4 = Stormgold lv.1 (primary, type 2); slot 5 = Voidblue lv.1 (type 1, RIGHT of slot 4); all other slots null
**When** CR resolves
**Then** `active_reactions` contains the `SHORT_CIRCUIT` entry (centre slot participates in reactions — Rule 16b)
**Pass**: Assert an entry with `effect_kind == SHORT_CIRCUIT` is present. *(Note: with only one distinct core neighbor, `|M| == 1`, so no Cascade fires and the core pairwise reaction survives — see AC-CR-39.)*

---

### AC-CR-38: Cascade fires at ≥2 distinct core-neighbor types; lead = core type *(Logic)*
**Given** slot 4 = Ashfire lv.1 (type 0); slot 1 = Voidblue lv.1 (type 1, ABOVE); slot 5 = Stormgold lv.1 (type 2, RIGHT); all other slots null
**When** CR resolves
**Then** `active_cascade != null`; `active_cascade.lead_type == 0`; `active_cascade.modifiers == [1, 2]` (sorted)
**Pass**: Assert cascade present, `lead_type == 0`, `modifiers == [1, 2]`.

---

### AC-CR-39: Exactly one distinct core neighbor → no Cascade, core pairwise reaction survives *(Logic)*
**Given** slot 4 = Stormgold lv.1 (type 2); slot 5 = Voidblue lv.1 (type 1); all other slots null (`|M| == 1`)
**When** CR resolves
**Then** `active_cascade == null`; `active_reactions` contains `SHORT_CIRCUIT`
**Pass**: Assert `active_cascade == null` and the `SHORT_CIRCUIT` reaction is present (threshold is 2 distinct modifiers — Rule 17a).

---

### AC-CR-40: Same three types, different core → different Cascade lead *(Logic)*
**Given** (a) slot 4 = Ashfire (type 0), slot 1 = Voidblue (type 1), slot 5 = Stormgold (type 2); (b) slot 4 = Stormgold (type 2), slot 1 = Voidblue (type 1), slot 5 = Ashfire (type 0)
**When** CR resolves each independently
**Then** (a) `active_cascade.lead_type == 0` with `modifiers == [1, 2]`; (b) `active_cascade.lead_type == 2` with `modifiers == [0, 1]`
**Pass**: Both assertions pass. Confirms core-sensitivity — the lead changes the Cascade identity even with the same three types present (Rule 17c / Formula 10).

---

### AC-CR-41: Cascade consumes core↔neighbor pairwise but not ring↔ring pairwise *(Logic)*
**Given** slot 4 = Deepfrost (type 3); slot 1 = Ashfire (type 0); slot 5 = Verdant (type 4) — core has two distinct neighbors → Cascade; additionally slot 0 = Ashfire (type 0) and slot 3 = Voidblue (type 1) form a ring↔ring Ashfire–Voidblue cardinal pair
**When** CR resolves
**Then** `active_cascade != null`; the Thermal Shock (Ash+Frost) and Permafrost (Frost+Verd) core pairwise reactions are ABSENT from `active_reactions`; the ring Witchfire (Ash+Void) reaction IS present
**Pass**: Assert cascade present; assert no `THERMAL_SHOCK`/`PERMAFROST` in `active_reactions`; assert `WITCHFIRE` present (Rule 17d).

---

### AC-CR-42: Duplicate neighbor type dedups to one modifier but counts toward tier *(Logic)*
**Given** slot 4 = Ashfire (type 0); slot 1 and slot 7 = Voidblue lv.1 each (type 1, ABOVE and BELOW); slot 5 = Stormgold lv.1 (type 2)
**When** CR resolves
**Then** `active_cascade.modifiers == [1, 2]` (Voidblue appears once); `effective_nonprimary_count(Voidblue) == 2`
**Pass**: Assert `modifiers == [1, 2]` and Voidblue non-primary count is 2 (Rule 17e).

---

### AC-CR-43: Four distinct core neighbors → four modifiers; cascade_mult respects cap *(Logic)*
**Given** slot 4 = Ashfire (type 0); slots 1/3/5/7 = Voidblue/Stormgold/Deepfrost/Verdant (types 1/2/3/4) — four distinct neighbors
**When** CR resolves (default knobs: `CASCADE_LEAD_MULT=1.0`, `CASCADE_MOD_DMG_BONUS=0.10`, `CASCADE_MULT_CAP=1.6`)
**Then** `active_cascade.modifiers == [1, 2, 3, 4]`; `cascade_mult == min(1.0 + 4×0.10, 1.6) == 1.40`
**Pass**: Assert four modifiers and `cascade_mult == 1.40` (Formula 10).

---

### AC-CR-44: Corner slots do not feed the Cascade *(Logic)*
**Given** slot 4 = Ashfire (type 0); slot 0 = Voidblue, slot 2 = Stormgold, slot 6 = Deepfrost, slot 8 = Verdant (all four corners distinct, none cardinally adjacent to centre); all cardinal-neighbor slots (1/3/5/7) null
**When** CR resolves
**Then** `active_cascade == null` (no core-adjacent distinct neighbors)
**Pass**: Assert `active_cascade == null`. Corners are diagonal to the core and never contribute Cascade modifiers (Rule 17f).

---

*Coverage map: AC-CR-01–12 = Section C core rules 1–12; AC-CR-02–06 = Formula 1–2 (primary count/tier); AC-CR-07–10 = Formula 3–4 (non-primary count/tier); AC-CR-13 = Formula 5/6 payload fields; AC-CR-14–15 = Formula 8 stat aggregation; AC-CR-16–23 = Formula 7 adjacency pool (no-condition, AND-satisfied, AND-partial, bounds, null, type mismatch, wildcard, multi-fragment); AC-CR-24–28 = signal contract + edge cases; AC-CR-29 = primary_base_status / non-primary coexistence (SC&E contract); AC-CR-30–37 = Rule 16 / Formula 9 Prana Reaction layer (cardinal arm, diagonal-skip, same-type-skip, dedup, multi-stack + order, all-same empty, pure preview parity, centre participation); AC-CR-38–44 = Rule 17 / Formula 10 Cascade tier (≥2-neighbor arm + lead, |M|==1 no-cascade, core-sensitivity, merge vs ring survival, duplicate dedup, four-modifier cap, corner exclusion).*

## Open Questions

[To be designed]
