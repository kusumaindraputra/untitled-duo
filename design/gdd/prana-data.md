# Prana Data

> **Status**: Approved
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-23
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding), Pillar 4 (Depth Over Breadth)

## Overview

Prana Data is the canonical data layer that defines all five Prana types in The Last Cipher. It holds the intrinsic, immutable properties of each type — name, element, semantic identity, color assignment (from the art bible), icon specification, visual burst shape, audio signature, cast animation, and gameplay categorization (damage class, base status class, base damage modifier) — as read-only definitions that every other system treats as ground truth. Targeting shape is explicitly excluded: spell shapes emerge from grid arrangement and are owned by Combination Resolution. No consuming system may define its own type properties or alias type names; all Prana identity originates here.

The six primary consumers are: **Prana Grid** (slot rendering and identity — which tile displays which Prana type), **Combination Resolution** (combo lookup keyed by type pairing and spatial arrangement), **Spell Casting & Effects** (VFX routing and audio cue selection by type), **Elemental Affiliation & Weakness** (weakness multiplier lookup keyed by enemy affiliation vs. incoming Prana type), **Prana Drop / Loot** (drop table entries keyed by type), and **Meta-Progression** (Vertical Slice — unlock state per Prana type).

At MVP scope, Prana Data defines exactly five types: Ashfire, Voidblue, Stormgold, Deepfrost, and Verdant. The data structure must be designed to accommodate future types (Vertical Slice adds up to five more, Full Vision up to twenty), but no placeholder entries are shipped; the catalog is exactly what is playable.

## Player Fantasy

Prana Data is infrastructure the player never sees directly. Its fantasy is experienced one layer up: the moment a returning player glances at a wave preview, sees an Ashfire-aligned enemy, and reaches for the Deepfrost slot without reading a tooltip — because they have internalized the catalog.

The design goal of this system is *legible mastery*. A well-designed Prana catalog should feel transparent to an experienced player: the type names, color identities, and semantic descriptions should collapse into pure recognition after a few runs. Pillar 2 ("Power is Earned Through Understanding") lives here at the data level — every property in this catalog should be discoverable through play, not documentation.

Players do not engage with Prana Data as a system. They engage with Prana types as identities. This system succeeds when players describe their strategy in Prana terms: *"I ran Deepfrost and Verdant into the center — the combo froze them in place and Verdant kept me going long enough to finish them off."* The catalog made that sentence possible.

*`creative-director` consulted — full review complete (2026-05-23).*

## Detailed Design

### Core Rules

1. **Immutability**: All Prana type definitions are immutable at runtime. The catalog is loaded once at game startup and held in memory read-only for the duration of the session. No system modifies a Prana type definition during gameplay.

2. **Properties of each Prana type definition:**

   | Property | Type | Description |
   |----------|------|-------------|
   | `id` | int (enum) | Machine-readable identifier. Used for all code lookups, comparisons, and serialization. Never reassigned. |
   | `name` | String | Canonical display name for UI tooltips and debug output. |
   | `element` | String | Human-readable element category (e.g., "Fire / Destruction"). Lore display only. |
   | `semantic_identity` | String | One-sentence flavor text for tooltips. |
   | `color` | Color | Hex color for grid slot, damage numbers, synergy glow, VFX. (Locked by art bible §4.2.) |
   | `icon` | Texture2D | 8×8 px silhouette icon for colorblind fallback display. (Locked by art bible §4.5.) |
   | `vfx_burst_shape` | enum (`VfxBurstShape`) | Routes VFX system to the correct particle preset. See enum definition below. |
   | `audio_signature` | AudioStream | Cast sound played on type activation. |
   | `cast_animation` | enum (`CastAnimation`) | Routes Fayde animation controller on cast. See enum definition below. |
   | `damage_class` | enum | Elemental damage type — used by Elemental Affiliation & Weakness for multiplier lookup. |
   | `base_status` | enum | Status effect this type naturally applies in single-type casts. Used by Combination Resolution as a fallback. |
   | `base_damage_modifier` | float | Scalar applied to raw `base_damage` on direct hit. Encodes the type's offense/control trade-off. Values range 0.70–1.25. |

   **`CastAnimation` enum** — define in a shared constants file (location determined by lead programmer at implementation):

   | Constant | Prana Type | Gesture |
   |----------|-----------|---------|
   | `CAST_THRUST` | Ashfire | Forward thrust — aggressive, forceful |
   | `CAST_REACH` | Voidblue | Slow reach outward — deliberate, concealing |
   | `CAST_SNAP` | Stormgold | Quick flick/snap — reflexive |
   | `CAST_PUSH` | Deepfrost | Two-hand slow push — patient, deliberate |
   | `CAST_BLOOM` | Verdant | Open-palm bloom — organic, expanding |

   **`VfxBurstShape` enum** — define in the same shared constants file:

   | Constant | Prana Type | Visual Shape (Art Bible §4.5) |
   |----------|-----------|-------------------------------|
   | `BURST_FLAME` | Ashfire | 3-spike upward flame cluster |
   | `BURST_SPIRAL` | Voidblue | Inward spiral / eye shape |
   | `BURST_LIGHTNING` | Stormgold | Forked lightning bolt |
   | `BURST_CRYSTAL` | Deepfrost | Hexagonal crystal / snowflake |
   | `BURST_VINE` | Verdant | Tri-leaf / spiral growth |

3. **Identification by ID**: All systems identify Prana types by their `id` (enum constant) in data structures, comparisons, and serialization. Display names are looked up from the catalog by ID. No system compares types by string name.

4. **Targeting shape is not a Prana Data property**: Spell shape (cone, ray, burst, expanding area) emerges from grid arrangement and is owned by Combination Resolution. Prana Data owns elemental identity and damage class only.

5. **Resonance not stored in MVP**: At MVP scope, Prana Data includes no Resonance field. Resonance is narrative-only. If Resonance becomes a gameplay system in a later tier, a `resonance_weight` field will be added without breaking existing IDs.

6. **Catalog extensibility**: New entries are always appended. Existing IDs are never reassigned or removed; deprecated entries use `status = inactive` rather than deletion.

---

**The Five Prana Types (MVP Catalog):**

| ID | Name | Element | Semantic Identity | Color | Damage Class | Base Status | `base_damage_modifier` |
|----|------|---------|-------------------|-------|-------------|------------|----------------------|
| 0 | **Ashfire** | Fire / Destruction | Ambition that burns everything — including plans. Force without precision. | `#F24C1D` | Fire | Burn (DoT 2s) | 1.25 |
| 1 | **Voidblue** | Shadow / Void | Silence that reveals what was always there. Control, concealment, deception. | `#4A5EF5` | Shadow | Blind (miss chance 2s) | 0.90 |
| 2 | **Stormgold** | Lightning / Speed | Reflex made visible. Reaction, disruption, momentum. | `#FFCC00` | Lightning | Stun (interrupt 0.5s) | 1.15 |
| 3 | **Deepfrost** | Ice / Time | Patience imposed on a world that resists it. Slowing, crystallizing, trapping. | `#3DD9F0` | Ice | Freeze (root + 50% slow 2s) | 0.80 |
| 4 | **Verdant** | Nature / Growth | Endurance that outlasts the fight. Recovery, resilience, persistence under pressure. | `#1AC953` | Nature | Regenerate (HP over 3s) | 0.70 |

*Visual/audio properties (icon, VFX burst shape, audio signature, cast animation) are locked in art bible §4.2 and §4.5 — see that document for full specs.*

### States and Transitions

Prana Data has no runtime states. There is nothing to transition — it is a static catalog.

**VS note (out of MVP scope):** Meta-Progression will add an `is_unlocked` flag per type. This flag lives in Meta-Progression's save data, not in the type definition. Prana Grid queries Meta-Progression for unlock state at load time; Prana Data remains unaware of unlock state.

### Interactions with Other Systems

| Consuming System | What it reads | Interface |
|----------------|--------------|-----------|
| **Prana Grid** | `id`, `name`, `color`, `icon`, all visual properties | Full type definition lookup by ID for slot rendering |
| **Combination Resolution** | `id`, `damage_class`, `base_status` | Keyed lookup by ID for combo resolution; `base_status` as single-type fallback |
| **Spell Casting & Effects** | `vfx_burst_shape`, `audio_signature`, `cast_animation` | Per-type routing by ID on spell cast event |
| **Elemental Affiliation & Weakness** | `id`, `damage_class` | `damage_class` used as key for weakness multiplier table |
| **Prana Drop / Loot** | `id`, `name`, `color` | Drop table entries keyed by ID; name+color for loot panel display |
| **Meta-Progression** *(VS)* | `id` | Prana type ID as key for unlock state — never modifies definitions |
| **Status Effects** | MVP | `base_status` enum value (routing) + all tick parameters, durations, and concurrency rules (provisional — ownership transfers to Status Effects GDD when authored) | Hard — Status Effects implements the behavior Prana Data specifies |

*Full review complete — `game-designer`, `systems-designer`, `qa-lead`, `creative-director` consulted (2026-05-23).*

## Formulas

> **Ownership note — provisional:** Tick parameters, duration values, and status interaction rules documented in this section are captured here for design purposes. When the **Status Effects GDD** (System #7) is authored, it takes ownership of all behavioral specifications. At that point, Prana Data retains only the `base_status` enum routing value per type — all tick rates, magnitudes, and concurrency rules transfer to Status Effects. Treat the parameters here as authoritative provisional inputs to that design.

### Per-Type Damage Modifier Table

Each Prana type applies a `base_damage_modifier` scalar to raw spell damage. This value is an intrinsic property of the type — it reflects the tradeoff between direct damage and status control strength.

| Prana Type | `base_damage_modifier` | Role Balance |
|-----------|----------------------|-------------|
| Ashfire | **1.25** | Pure offense — no control utility |
| Stormgold | **1.15** | Damage + brief interrupt |
| Voidblue | **0.90** | Damage + probabilistic control |
| Deepfrost | **0.80** | Damage + guaranteed lockdown |
| Verdant | **0.70** | Sustain only — not an offensive type |

*Weighted average of `base_damage_modifier`: 0.96. Note: this average excludes Burn DoT. Ashfire's true effective multiplier is **1.57** (= 1.25 base + 0.08×4 DoT), making it 36% stronger than Stormgold in raw output. See Formula 1 for the full breakdown.*

`base_damage` is defined in the Health & Damage GDD (undesigned — values here are provisional until that GDD is complete).

---

### Formula 1: Burn Total Damage

The `burn_total` formula is defined as:

`burn_total = max(0, base_damage) × burn_tick_magnitude × burn_tick_count`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Raw spell damage | `base_damage` | float | 1–unbounded | Defined in Health & Damage GDD |
| Damage per tick | `burn_tick_magnitude` | float | 0.0–1.0 | Fraction of `base_damage` per tick. **Value: 0.08** |
| Tick count | `burn_tick_count` | int | 1–N | `duration / tick_rate` = 2.0 / 0.5 = **4** |
| Tick interval | `burn_tick_rate` | float | seconds | **0.5s** per tick |
| Total duration | `burn_duration` | float | seconds | **2.0s** |

**Output Range:** 0 to unbounded (scales with `base_damage`). The `max(0, base_damage)` guard ensures negative `base_damage` never produces a healing DoT. `base_damage` is expected to be positive by contract from Spell Casting & Effects, but the formula-level clamp is the safety guarantee.

**Example:** `base_damage` = 10 → burn_total = 10 × 0.08 × 4 = **3.2 bonus damage** (32% of the direct hit). Ashfire effective total: (10 × 1.25) + 3.2 = **15.7 per cast** (effective multiplier: 1.57, not 1.25 — see modifier table note).

---

### Formula 2: Regenerate Total Healing

The `regen_total` formula is defined as:

`regen_total = fayde_max_hp × regen_tick_magnitude × regen_tick_count`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Fayde's max HP | `fayde_max_hp` | int | 1–unbounded | Defined in Health & Damage GDD |
| HP per tick | `regen_tick_magnitude` | float | 0.0–1.0 | Fraction of `fayde_max_hp` per tick. **Value: 0.02** |
| Tick count | `regen_tick_count` | int | 1–N | `duration / tick_rate` = 3.0 / 1.0 = **3** |
| Tick interval | `regen_tick_rate` | float | seconds | **1.0s** per tick |
| Total duration | `regen_duration` | float | seconds | **3.0s** |

**Output Range:** 0 to unbounded (scales with `fayde_max_hp`)

**Example:** `fayde_max_hp` = 100 → regen_total = 100 × 0.02 × 3 = **6 HP total** (6% max HP over 3s). Covers chip damage and grazes; does not compensate for a full hit.

---

### Status Effect Fixed Parameters (Non-Formula)

These statuses have no formula — their effect is binary or a fixed value:

| Status | Applied By | Duration | Magnitude | Notes |
|--------|-----------|----------|-----------|-------|
| **Blind** | Voidblue | 2.0s | **50% miss chance** | Probabilistic — each enemy attack has 50% to miss while active. No formula needed: coin flip per attack event. |
| **Stun** | Stormgold | 0.5s | Binary | Hard interrupt only — cancels enemy current action. No damage component, no additional magnitude. |
| **Freeze** | Deepfrost | 2.0s | Root: binary + Slow: 50% | Root is an absolute position lock (binary). Slow reduces enemy movement speed by 50% (fixed). No formula needed. |

*`burn_tick_magnitude`, `regen_tick_magnitude`, and `blind_miss_chance` are the primary tuning targets for balance iteration after Health & Damage GDD is complete.*

## Edge Cases

- **If a Prana type ID is requested that does not exist in the catalog**: Return null and log an error. No system should silently proceed with a missing type — null behavior must surface as a programmer error during development, not a runtime game state. (Prana Data guarantees: all valid IDs are contiguous integers from 0 to N-1 in the MVP catalog.)

- **If Burn is applied to an enemy already burning (Ashfire cast twice on same target)**: The existing Burn timer resets to full duration (2.0s) and `burn_tick_magnitude` stays at 0.08. Burn does NOT stack — a second Burn application refreshes, not multiplies. *Rationale: Stacking would make rapid Ashfire casts trivially dominant and create DoT overflow that is difficult to read visually.*

- **If Regenerate is triggered while Fayde is already regenerating**: The existing Regen timer resets to full duration (3.0s). Regen does NOT stack. Same rule as Burn refresh.

- **If Regenerate ticks when Fayde is already at max HP**: The tick does nothing — HP cannot exceed `fayde_max_hp`. No overflow, no carry-forward. Healing a full-HP Fayde is wasted — intentional design pressure to use Verdant opportunistically, not freely.

- **If two different statuses from two different Prana types are active simultaneously** (e.g., enemy has Freeze from Deepfrost and then gets hit by Ashfire): Both statuses are active simultaneously. Burn and Freeze do not cancel each other. An enemy can be Frozen (rooted + slowed) AND Burning (DoT) at the same time.

- **General Stun concurrency rule**: Stun does **not** pause Burn, Regen, or Blind timers. Only Freeze receives the pause treatment (see below). Rationale: Freeze's pause protects earned lockdown duration — a positioning investment the player should not lose to a Stormgold follow-up. Burn (DoT on enemy), Regen (healing on Fayde), and Blind (evasion window on enemy) all run independently of whether the enemy can act. An enemy that is Stunned while Burning continues to take Burn ticks; Fayde's active Regen continues to tick; an enemy's Blind window counts down regardless of Stun.

- **If Stun is applied to an already-Frozen enemy**: Stun takes precedence for 0.5s — the enemy is stunned (interrupting any action). The Freeze timer **pauses** during the Stun window; it does not count down. When Stun expires, Freeze resumes with its full remaining duration intact. *Rationale: Pause model is fair to the player — they do not lose Freeze time they earned.*

- **Freeze root and slow concurrency**: Both effects (position root AND 50% movement slow) are active simultaneously for the full 2.0s duration. The slow does not wait for the root to expire — it runs in parallel. If a future Resistance mechanic breaks the root early, the slow remains until the 2.0s timer expires.

- **If Stun is applied to an enemy mid-attack animation**: The attack animation is cancelled immediately. The enemy's attack does not resolve. The 0.5s Stun timer begins from the cancel frame. *This is the core value proposition of Stormgold — interrupt timing matters.*

- **If Blind is applied to an enemy that has no attack in the next 2.0s** (e.g., a downed or retreating enemy): Blind expires without triggering any miss check. The status is wasted. This is valid gameplay — Blind timing is a skill expression.

- **If a Prana type that hasn't been unlocked (VS scope) is somehow requested at runtime**: Treat as invalid ID. Meta-Progression owns the unlock gate — Prana Data does not enforce it.

- **If `base_damage` is 0 or negative when `burn_total` is calculated**: Burn total = 0. No negative DoT. `base_damage` is expected to be a positive float by contract from Spell Casting & Effects — clamp behavior at 0 is a safety fallback, not an intended game state.

- **If `fayde_max_hp` is 0 when `regen_total` is calculated**: Regen total = 0. This is a game-ending condition (Fayde dead or HP system error) — handle at the Health & Damage level, not Prana Data. Prana Data formula output of 0 is safe behavior.

## Dependencies

### Upstream Dependencies (what Prana Data requires)

**None.** Prana Data is a Foundation layer system. It is loaded first at runtime and requires no other game system to function. All values are author-time constants.

*Visual and audio assets (icons, audio streams) are loaded from disk — Prana Data requires the engine's resource loading system (Godot's `ResourceLoader`) to be available, but this is an engine requirement, not a game system dependency.*

### Downstream Dependents (what requires Prana Data)

All six are **hard dependencies** — these systems cannot function without Prana Data being initialized.

| Dependent System | Priority | What It Needs | Nature |
|----------------|----------|--------------|--------|
| **Prana Grid** | MVP | Full type definitions (id, name, color, icon, visual properties) | Hard — cannot render grid slots without the type catalog |
| **Combination Resolution** | MVP | `id`, `damage_class`, `base_status` per type | Hard — combo lookup table is keyed by Prana type ID |
| **Spell Casting & Effects** | MVP | `vfx_burst_shape`, `audio_signature`, `cast_animation` per type | Hard — cannot route VFX/audio without type identity |
| **Elemental Affiliation & Weakness** | MVP | `id`, `damage_class` | Hard — weakness multiplier table is keyed by damage class |
| **Prana Drop / Loot** | MVP | `id`, `name`, `color` | Hard — drop entries are keyed by Prana type ID |
| **Meta-Progression** | Vertical Slice | `id` | Hard — unlock flags keyed by Prana type ID |

**Bidirectional consistency note:** Each of the above systems' GDDs must list Prana Data as an upstream dependency. When those GDDs are authored, their Dependencies sections should reference this document.

## Tuning Knobs

All values listed here should be designer-adjustable without code changes — stored in external config or Resource files, not hardcoded.

| Knob | Current Value | Safe Range | What breaks if too high | What breaks if too low |
|------|-------------|-----------|------------------------|----------------------|
| `ashfire_damage_modifier` | 1.25 | 1.0–1.4 | Ashfire dominates all other offensive types; optimal grid is all-Ashfire | Ashfire feels like a control type with an irrelevant DoT — loses its identity |
| `stormgold_damage_modifier` | 1.15 | 1.0–1.3 | Stormgold replaces Ashfire as default damage type | Stormgold becomes punishing to slot — 0.5s stun doesn't justify the damage loss |
| `voidblue_damage_modifier` | 0.90 | 0.75–1.05 | Voidblue combines reliable damage with a near-50% global miss rate — too powerful | Voidblue is clearly inferior in all scenarios; Blind is not worth the modifier penalty |
| `deepfrost_damage_modifier` | 0.80 | 0.65–0.95 | Deepfrost deals near-full damage AND guarantees root+slow — dominant against all enemies | Even with root+slow, the damage penalty makes Deepfrost a dead slot unless enemies require control |
| `verdant_damage_modifier` | 0.70 | 0.55–0.80 | Verdant becomes a viable damage type — removes the trade-off, destroys sustain identity | Players never slot Verdant — the healing isn't worth the damage loss even in long fights |
| `burn_tick_magnitude` | 0.08 | 0.04–0.15 | Burn DoT becomes primary damage source; Ashfire optimal even against fire-resistant enemies | Burn feels like a visual effect, not a mechanic — Ashfire loses depth |
| `burn_duration` | 2.0s | 1.0–3.0s | Long enough that follow-up spells always benefit from DoT; removes positioning pressure | Burn is barely perceptible — refreshing it becomes meaningless |
| `burn_tick_rate` | 0.5s | 0.25–1.0s | Very frequent ticks create rapid number spam — readability suffers | Sparse ticks make 2s burn feel like a delayed, unreliable effect |
| `blind_miss_chance` | 0.50 | 0.25–0.70 | Near-immunity to incoming damage in multi-enemy encounters | Blind feels like a visual cosmetic, not a control tool |
| `blind_duration` | 2.0s | 1.0–3.0s | Voidblue provides sustained near-evasion throughout a wave | Too brief to use strategically around enemy attacks |
| `stun_duration` | 0.5s | 0.25–1.0s | Stun becomes a guaranteed-interrupt lockdown — Stormgold dominant for boss fights | Stun is too brief to interrupt wind-up animations reliably — Stormgold loses its identity. *Playtest flag: 0.5s is likely below new-player perceptibility threshold — expect to raise to 0.75–1.0s after first combat playtest.* |
| `freeze_duration` | 2.0s | 1.5–3.0s | Deepfrost trivializes positioning — enemies never reach Fayde | Freeze barely disrupts enemy paths — root+slow loses strategic value |
| `freeze_slow_pct` | 50% | 30–70% | Near-complete speed reduction; effectively extends root duration | Enemies move nearly at full speed — Freeze root becomes the only meaningful effect |
| `regen_tick_magnitude` | 0.02 | 0.01–0.05 | Verdant can sustain through moderate hits — removes positioning pressure | Regen covers only 1–3% HP total — irrelevant to run survival |
| `regen_duration` | 3.0s | 2.0–5.0s | Verdant provides sustained healing between casts — sustain becomes passive | Too brief to be worth slotting unless Fayde is taking hits in rapid succession |

**Interaction warnings:**
- `blind_miss_chance` and `blind_duration` interact: raising both simultaneously risks effective immunity in multi-enemy waves. Adjust one at a time.
- `burn_tick_magnitude` and `ashfire_damage_modifier` interact: Ashfire's total damage is the sum of both. If buffing Ashfire, reduce one; don't raise both.
- `regen_tick_magnitude` is contingent on enemy damage values (defined in Health & Damage GDD). Finalize after that GDD is complete.

## Visual/Audio Requirements

Prana Data is a data catalog — visual and audio properties per type are defined in the asset fields of each `PranaType` definition (`icon`, `vfx_burst_shape`, `audio_signature`). The content of those assets is specified in the **Art Bible**:

- **Colors** (§4.2): Exact hex values for each Prana type, locked. Prana Data's `color` field references these directly.
- **Icons** (§4.5): 8×8 px silhouette icon shapes per type. Icon assets are assigned to the `icon` field. Colorblind-mode scaling (8×8 → 12×12 + letter label) is specified there.
- **Audio signatures** (§4.5 / §4.6): Per-type cast sounds (e.g., Ashfire = crackle-whoosh). These are assigned to the `audio_signature` field.
- **VFX burst shapes**: Defined by the `VfxBurstShape` enum in this document (see property table above). Particle asset creation is owned by the Art/VFX pipeline.

No additional visual or audio specification is required from Prana Data.

## UI Requirements

Prana Data has no direct UI. The display of Prana types in the grid, tooltips, and HUD is owned by the **Prana Grid GDD** (not yet authored) and the **Combat HUD GDD** (not yet authored). When those GDDs are authored, they will read type properties (`id`, `name`, `color`, `icon`, `semantic_identity`) from this catalog.

No UI specification is required from Prana Data itself.

## Acceptance Criteria

All 32 criteria are Logic-type (formulas, data integrity, state machines) — automated unit tests in `tests/unit/prana-data/` are a **BLOCKING gate** before any story touching this system can be marked Done. Reviewed by `qa-lead` (lean mode, 2026-05-23).

*Advisory note — Blind RNG (AC-PD-18): The 50% miss chance is specified as a per-attack coin flip. Whether a seeded or unseeded RNG is used is a technical decision for the lead programmer. A statistical range test (450–550 misses in 1,000 trials) is the QA fallback for unseeded implementations.*

---

### Data Integrity

**AC-PD-01 — Catalog loads exactly five types at startup**
GIVEN the game application starts, WHEN Prana Data finishes initialization, THEN the catalog contains exactly 5 entries with IDs 0, 1, 2, 3, and 4 — no more, no fewer.

**AC-PD-02 — All five type definitions are correctly identified**
GIVEN the catalog has been loaded, WHEN queried for each ID 0–4, THEN the `name` values are: ID 0 = "Ashfire", ID 1 = "Voidblue", ID 2 = "Stormgold", ID 3 = "Deepfrost", ID 4 = "Verdant" — each distinct and non-null.

**AC-PD-03 — Every type definition contains all 12 required properties**
GIVEN the catalog has been loaded, WHEN any type definition is retrieved by ID, THEN the returned object has non-null values for all 12 properties: `id`, `name`, `element`, `semantic_identity`, `color`, `icon`, `vfx_burst_shape`, `audio_signature`, `cast_animation`, `damage_class`, `base_status`, `base_damage_modifier`.

**AC-PD-04 — No property is modified after catalog load** *(reclassified: unit test, no combat encounter required)*
GIVEN the catalog has been loaded and a type definition is read once and stored in a local variable, WHEN the catalog is read again for the same ID, THEN the two returned definitions are identical in all 12 properties — no property mutated between the two reads. This test requires only two sequential reads with no intervening game state.

**AC-PD-05 — DELETED** *(moved to consuming system test suites)*
The contract that Combination Resolution, Elemental Affiliation & Weakness, and Prana Drop / Loot use integer IDs (not string names) for Prana lookups is each system's own responsibility. This criterion tested other systems' behavior, not Prana Data's. It has been moved to those systems' test suites where it belongs.

**AC-PD-06 — Targeting shape is absent from all type definitions**
GIVEN the catalog has been loaded, WHEN any type definition is retrieved by ID, THEN the returned object has no property named `targeting_shape`, `cast_shape`, `spell_shape`, or any field describing area-of-effect geometry.

**AC-PD-07 — No Resonance field is present in any MVP type definition**
GIVEN the catalog has been loaded, WHEN any type definition is retrieved by ID, THEN the returned object has no property named `resonance`, `resonance_weight`, or any resonance-related field.

**AC-PD-08 — IDs 0–4 are stable across sessions**
GIVEN the game is launched, played for one run, and relaunched, WHEN the same Prana type ID is queried in both sessions, THEN the `name` and `damage_class` values are identical in both sessions.

---

### Formula Verification

**AC-PD-09 — Burn total damage formula: 4 ticks × 8% × base_damage**
GIVEN an enemy has no active Burn and `base_damage` = 10, WHEN an Ashfire single-type cast is applied, THEN the enemy receives exactly 4 Burn ticks over 2.0s each dealing 0.8 damage, for a total of 3.2 bonus damage.

**AC-PD-10 — Burn ticks at 0.5s intervals**
GIVEN Burn is applied to an enemy at T=0 with `base_damage` = 10, WHEN time advances and tick events are recorded, THEN tick damage events occur at T=0.5s, T=1.0s, T=1.5s, and T=2.0s — exactly four events, none earlier than 0.5s apart.

**AC-PD-11 — Ashfire base_damage_modifier = 1.25**
GIVEN `base_damage` = 20 and the active type is Ashfire (ID 0), WHEN direct hit damage is calculated, THEN the modified hit damage equals 25.0 (= 20 × 1.25).

**AC-PD-12 — Stormgold base_damage_modifier = 1.15**
GIVEN `base_damage` = 20 and the active type is Stormgold (ID 2), WHEN direct hit damage is calculated, THEN the modified hit damage equals 23.0 (= 20 × 1.15).

**AC-PD-13 — Voidblue base_damage_modifier = 0.90**
GIVEN `base_damage` = 20 and the active type is Voidblue (ID 1), WHEN direct hit damage is calculated, THEN the modified hit damage equals 18.0 (= 20 × 0.90).

**AC-PD-14 — Deepfrost base_damage_modifier = 0.80**
GIVEN `base_damage` = 20 and the active type is Deepfrost (ID 3), WHEN direct hit damage is calculated, THEN the modified hit damage equals 16.0 (= 20 × 0.80).

**AC-PD-15 — Verdant base_damage_modifier = 0.70**
GIVEN `base_damage` = 20 and the active type is Verdant (ID 4), WHEN direct hit damage is calculated, THEN the modified hit damage equals 14.0 (= 20 × 0.70).

**AC-PD-16 — Regen total healing formula: 3 ticks × 2% × fayde_max_hp**
GIVEN Fayde has `fayde_max_hp` = 100 and no active Regen, WHEN a Verdant single-type cast applies Regenerate, THEN Fayde receives exactly 3 Regen ticks over 3.0s each restoring 2 HP (= 100 × 0.02), for a total of 6 HP.

**AC-PD-17 — Regen ticks at 1.0s intervals**
GIVEN Regen is applied to Fayde at T=0 with `fayde_max_hp` = 100, WHEN time advances and tick events are recorded, THEN HP restore events occur at T=1.0s, T=2.0s, and T=3.0s — exactly three events, none earlier than 1.0s apart.

**AC-PD-18 — Blind applies 50% miss chance per attack** *(RNG model advisory — see Open Question #1)*
GIVEN an enemy has Blind applied, WHEN that enemy makes 1,000 attacks during the Blind window, THEN the number of misses falls between 450 and 550 — the miss check is per-attack (coin flip), not periodic.
*Advisory: This test is non-deterministic with an unseeded RNG (~0.2% false-positive rate per CI run). If the lead programmer chooses a seeded RNG for Blind's miss check (see Open Question #1), rewrite this AC as a deterministic test using a fixed seed. Until the RNG model is decided, this AC is classified as Advisory rather than BLOCKING for CI.*

**AC-PD-19 — Stun lasts 0.5s and interrupts with no additional magnitude**
GIVEN an enemy is in an attack animation, WHEN a Stormgold cast applies Stun, THEN the attack animation cancels immediately, the enemy cannot act for 0.5s, and normal behavior resumes at T=0.5s with no secondary effect.

**AC-PD-20 — Freeze applies binary root AND 50% slow simultaneously for 2.0s**
GIVEN an enemy is moving at speed `v`, WHEN a Deepfrost cast applies Freeze, THEN immediately the enemy cannot change position (root: binary) AND movement speed becomes `v × 0.50` — both effects active simultaneously for the full 2.0s before either resolves.

**AC-PD-21 — Blind duration is 2.0s**
GIVEN an enemy has Blind applied at T=0, WHEN T=2.0s passes with no attacks made, THEN Blind is no longer active and subsequent attacks resolve without any miss chance applied.

**AC-PD-22 — Freeze duration is 2.0s**
GIVEN an enemy has Freeze applied at T=0, WHEN T=2.0s passes, THEN root is released, 50% slow is removed, and the enemy returns to full movement speed simultaneously.

---

### Edge Case Behavior

**AC-PD-23 — Invalid ID lookup returns null and logs an error**
GIVEN the catalog is loaded with IDs 0–4, WHEN any system requests ID 5 (or any integer not in the catalog), THEN the return value is null AND an error is written to the engine log — no default/fallback type is silently returned.

**AC-PD-24 — Burn refresh on re-application (no stack)**
GIVEN an enemy has Burn active with 1.0s remaining, WHEN an Ashfire cast applies Burn again, THEN the Burn timer resets to 2.0s, `burn_tick_magnitude` remains 0.08, and the enemy does not receive more burn damage per tick than the single-stack value.

**AC-PD-25 — Regen refresh on re-application (no stack)**
GIVEN Fayde has Regen active with 1.0s remaining, WHEN a Verdant cast applies Regen again, THEN the Regen timer resets to 3.0s, the stored `regen_tick_magnitude` fraction remains **0.02** (the fraction of `fayde_max_hp` — not the computed absolute value `0.02 × fayde_max_hp`), and each tick continues to heal exactly `0.02 × fayde_max_hp` HP — Fayde does not receive more healing per tick than the single-stack value.

**AC-PD-26 — Regen tick at max HP is a no-op**
GIVEN Fayde is at exactly `fayde_max_hp` with Regen active, WHEN a Regen tick fires, THEN Fayde's HP does not exceed `fayde_max_hp` — the value before and after the tick is identical, no overflow is stored or carried forward.

**AC-PD-27 — Burn and Freeze coexist independently**
GIVEN an enemy has Freeze active, WHEN an Ashfire cast hits the same enemy and applies Burn, THEN both Freeze and Burn are active simultaneously — the Freeze timer has not reset, both effects resolve independently until their respective durations expire.

**AC-PD-28 — Stun takes precedence over Freeze; Freeze timer pauses during Stun**
GIVEN an enemy has Freeze active with 1.5s remaining, WHEN Stun (0.5s) is applied, THEN for 0.5s the enemy is stunned and the Freeze timer is paused (not counting down); at T=0.5s Stun expires and Freeze resumes with exactly 1.5s remaining.

**AC-PD-29 — Stun mid-animation cancels attack immediately**
GIVEN an enemy is at any frame of an attack animation that has not yet resolved damage, WHEN Stun is applied, THEN the animation stops on the current frame, no damage event fires from that attack, and the enemy is stunned for 0.5s.

**AC-PD-30 — Blind expires unused when no attack occurs**
GIVEN an enemy has Blind applied at T=0 and makes zero attacks between T=0 and T=2.0s, WHEN T=2.0s passes, THEN Blind is no longer active, no miss-check event was triggered, and the game state has no record of pending miss checks.

**AC-PD-31 — burn_total is 0 when base_damage is 0**
GIVEN `base_damage` = 0, WHEN Ashfire applies Burn, THEN `burn_total` = 0 — each tick deals 0 damage, no negative damage is applied, and no error is thrown.

**AC-PD-32 — regen_total is 0 when fayde_max_hp is 0**
GIVEN `fayde_max_hp` = 0, WHEN Verdant applies Regen, THEN `regen_total` = 0 — each tick heals 0 HP, Fayde's HP does not change, and no error is thrown.

**AC-PD-33 — Stun does not pause Burn, Regen, or Blind timers**
GIVEN an enemy has Burn active with 2.0s remaining, WHEN Stun (0.5s) is applied at T=0, THEN at T=0.5s (Stun expiry) the Burn timer has counted down to 1.5s remaining and exactly one Burn tick has fired during the Stun window — Stun did not pause or skip the Burn timer. *(The same holds for Regen on Fayde and Blind on an enemy: those timers continue counting down during the Stun window.)*

**AC-PD-34 — base_status property matches catalog table for all five types**
GIVEN the catalog is loaded, WHEN each type definition is retrieved, THEN: Ashfire's `base_status` is the `Burn` enum constant, Voidblue's is `Blind`, Stormgold's is `Stun`, Deepfrost's is `Freeze`, and Verdant's is `Regenerate` — each value is the correct enum constant, non-null, and distinct from the others.

*Full review: `game-designer`, `systems-designer`, `qa-lead`, `creative-director` consulted (2026-05-23). 34 criteria total (AC-PD-05 deleted, AC-PD-33/34 added). AC-PD-18 advisory pending Blind RNG model decision (Open Question #1). AC-PD-04 reclassified as unit test (double-read pattern, no combat encounter required).*

## Known Design Tensions

These risks are documented so downstream system authors inherit the awareness rather than re-discovering them.

| Tension | Impact | Resolution Owner |
|---------|--------|-----------------|
| **Voidblue (Blind) viability depends on enemy attack frequency.** Against slow or non-attacking enemies, Blind expires unused and Voidblue reduces to a 0.90 modifier only — worse than Stormgold (1.15, guaranteed interrupt). | Encounter design must include enough fast-attacking enemies to make Blind consistently useful. Without this, Voidblue is a dominated choice in many wave compositions. | Wave / Encounter System GDD |
| **Verdant is structurally weak without an enemy archetype that requires sustain.** 6% HP regen rarely justifies trading a grid slot for pure offense unless the encounter creates attrition pressure (long waves, DoT enemies, chip damage loops). | Encounter design must define at least one wave archetype where healing-per-second matters more than peak damage output. | Wave / Encounter System GDD |
| **Deepfrost + Ashfire is the implied dominant two-type pairing** (root + DoT). If no encounter type punishes this combination, it becomes generically optimal, reducing run-to-run variety and undermining Pillar 1. | Combination Resolution should acknowledge this pairing and either provide diminishing returns or create enemy types that resist it. | Combination Resolution GDD, Boss Encounter GDD |
| **Pillar 2 depth ("Power is Earned Through Understanding") is partially deferred.** Per-type discovery is shallow — 1–2 casts reveal a type's behavior. Deep strategic depth depends on Combination Resolution combos and elemental weakness interactions, neither of which is designed yet. | Combination Resolution GDD is load-bearing for Pillar 2. If that system's combo space is shallow, the pillar is not delivered. | Combination Resolution GDD |

## Open Questions

| # | Question | Owner | Priority | Notes |
|---|----------|-------|----------|-------|
| 1 | **Blind RNG model**: Is the 50% miss chance per-attack using a seeded or unseeded RNG? Seeded enables deterministic replay and makes AC-PD-18 a proper unit test; unseeded requires a statistical range test that will fail ~0.2% per CI run. **Recommendation: seeded RNG** — also provides replay consistency across runs. If seeded, flag to `technical-director` as a potential ADR (seeded RNG becomes a project-wide convention). | Lead programmer | Resolve before implementation sprint | AC-PD-18 is classified Advisory until this decision is made |
| 2 | **Boss status immunity**: Can bosses be Stunned, Blinded, Frozen, and Burned at full effect? Or do bosses have partial/full immunity to status effects? This affects whether all 5 Prana types are viable in the boss encounter. | Game designer | Resolve when designing Boss Encounter GDD | Common pattern: bosses immune to Stun/Freeze but susceptible to Burn/Blind at reduced duration |
| 3 | **Multiple same-type Prana in one grid**: Can a player place Ashfire in two or more grid slots simultaneously? If yes, does doubling up on a type stack the modifier, apply the status twice, or produce a different combo effect? Prana Data does not forbid this; Combination Resolution must define the rule. | Game designer | Resolve in Combination Resolution GDD | Flag for Combination Resolution GDD authoring |
