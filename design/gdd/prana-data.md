# Prana Data

> **Status**: Approved
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-05-29
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding), Pillar 4 (Depth Over Breadth)

## Overview

Prana Data is the canonical data layer that defines all five Prana types in The Last Cipher. It holds the intrinsic, immutable properties of each type — name, element, semantic identity, color assignment (from the art bible), icon specification, visual burst shape, audio signature, cast animation, and gameplay categorization (damage class, base status class, base damage modifier) — as read-only definitions that every other system treats as ground truth. It also specifies the conditional depth behavior for each type: one non-announced mechanic per type discoverable through play, forming the second mastery layer that delivers Pillar 2. Targeting shape is explicitly excluded: spell shapes emerge from grid arrangement and are owned by Combination Resolution. No consuming system may define its own type properties or alias type names; all Prana identity originates here.

The six primary consumers are: **Prana Grid** (slot rendering and identity — which tile displays which Prana type), **Combination Resolution** (combo lookup keyed by type pairing and spatial arrangement), **Spell Casting & Effects** (VFX routing and audio cue selection by type), **Elemental Affiliation & Weakness** (weakness multiplier lookup keyed by enemy affiliation vs. incoming Prana type), **Prana Drop / Loot** (drop table entries keyed by type), and **Meta-Progression** (Vertical Slice — unlock state per Prana type).

At MVP scope, Prana Data defines exactly five types: Ashfire, Voidblue, Stormgold, Deepfrost, and Verdant. The data structure must be designed to accommodate future types (Vertical Slice adds up to five more, Full Vision up to twenty), but no placeholder entries are shipped; the catalog is exactly what is playable.

## Player Fantasy

Prana Data is infrastructure the player never sees directly. Its fantasy is experienced one layer up: the moment a returning player glances at a wave preview, sees an Ashfire-aligned enemy, and reaches for the Deepfrost slot without reading a tooltip — because they have internalized the catalog.

The design goal of this system is *legible mastery*. A well-designed Prana catalog should feel transparent to an experienced player: the type names, color identities, and semantic descriptions should collapse into pure recognition after a few runs. Pillar 2 ("Power is Earned Through Understanding") lives here at the data level — every property in this catalog should be discoverable through play, not documentation.

This system delivers mastery at two layers. The **first layer** (surface, runs 1–5) is visible within 1–2 casts: each type has a distinct modifier and an immediately observable status effect. The **second layer** (depth, runs 10–20) emerges through sustained play: each type has one conditional behavior — not announced in any tooltip — that players discover by paying attention. The discovery of that second layer is where Pillar 2 delivers its core promise.

Players do not engage with Prana Data as a system. They engage with Prana types as identities. This system succeeds when players describe their strategy in Prana terms: *"I ran Deepfrost and Verdant into the center — the combo froze them in place and Verdant kept me going long enough to finish them off."* The catalog made that sentence possible.

*`creative-director` consulted — full review complete (2026-05-23).*

## Detailed Design

### Core Rules

1. **Immutability**: All Prana type definitions are immutable at runtime. The catalog is loaded once at game startup and held in memory read-only for the duration of the session. No system modifies a Prana type definition during gameplay.

   **Enforcement mechanism**: `PranaCatalog.get_type(id: int) -> PranaType` always returns `original.duplicate_deep()` — producing a new wrapper object with independent property values. This ensures that a consumer modifying a returned `PranaType` instance cannot corrupt the catalog for other readers. (`duplicate(true)` is deprecated since Godot 4.5; use `duplicate_deep()`. File-backed assets like `AudioStream` and `Texture2D` share underlying data by reference — only property reassignment is isolated, which is the correct behavior.) See Implementation Notes for the ADR rationale.

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
   | `damage_class` | enum (`GameEnums.DamageClass`) | Elemental damage type — `FIRE`, `SHADOW`, `LIGHTNING`, `ICE`, or `NATURE`. Used by Elemental Affiliation & Weakness for multiplier lookup. |
   | `base_status` | enum (`GameEnums.BaseStatus`) | Status effect this type naturally applies in single-type casts: `BURN`, `BLIND`, `STUN`, `FREEZE`, or `REGENERATE`. Used by Combination Resolution as a fallback. |
   | `base_damage_modifier` | float | Scalar applied to raw `base_damage` on direct hit. Encodes the type's offense/control trade-off. Values range 0.70–1.25. |

   **`CastAnimation` enum** — defined in `src/data/game_enums.gd` (`class_name GameEnums`, NOT an Autoload). Access as `GameEnums.CastAnimation.CAST_THRUST`.

   | Constant | Prana Type | Gesture |
   |----------|-----------|---------|
   | `CAST_THRUST` | Ashfire | Forward thrust — aggressive, forceful |
   | `CAST_REACH` | Voidblue | Slow reach outward — deliberate, concealing |
   | `CAST_SNAP` | Stormgold | Quick flick/snap — reflexive |
   | `CAST_PUSH` | Deepfrost | Two-hand slow push — patient, deliberate |
   | `CAST_BLOOM` | Verdant | Open-palm bloom — organic, expanding |

   **`VfxBurstShape` enum** — defined in the same `GameEnums` file. Access as `GameEnums.VfxBurstShape.BURST_FLAME`.

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

6. **Catalog extensibility**: New entries are always appended. Existing IDs are never reassigned or removed. *(VS scope: when the first deprecation is needed, add `is_active: bool` as property 13 with default `true`. The current 12-property schema has no deprecation field.)*

7. **Conditional depth behaviors (second-layer mastery)**: Each Prana type has one conditional mechanic not shown in any tooltip. Discoverable through sustained play (typically apparent after 10–20 casts in the right circumstances). Status Effects and Spell Casting & Effects must implement these behaviors. They are rule specifications for consuming systems, not stored data fields in PranaType.

   | Type | Conditional Behavior | Discovery Signal |
   |------|---------------------|-----------------|
   | **Ashfire** — *Burn Contagion* | When a target dies while afflicted with Burn, Burn transfers to the nearest enemy within `burn_contagion_range` (default 200px — see Tuning Knobs) at a fixed 2.0s duration (not the tunable `burn_duration`). *Rationale: Contagion spread is a deliberate chain-spread power cap — Burn cannot cascade at maximum configured duration.* | Player sees fire jump to a second enemy after a kill. |
   | **Voidblue** — *Deepening Doubt* | Each time an enemy with Blind misses an attack due to Blind, the Blind timer extends by `deepening_doubt_extension` (default 0.5s — see Tuning Knobs), capped at `deepening_doubt_cap = 2.0 × blind_duration` (at canonical `blind_duration=2.0s`, cap = 4.0s). Cap is computed at load time from the tunable `blind_duration` value — never hardcoded. Fast-attacking enemies stay confused longer. | Player notices Blind lasting longer against high-frequency attackers. |
   | **Stormgold** — *Lightning Follow-Through* | A Stormgold cast made within 1.5s of a successful Stun interrupt (one that cancelled an in-progress enemy attack animation — not applied to an idle enemy) deals +30% direct damage. Formula: `follow_through_damage = base_damage × base_damage_modifier × 1.30` — multiplicative, not additive to the modifier. Example: `base_damage=20, stormgold_modifier=1.15 → 20 × 1.15 × 1.30 = 29.9 → round to 30`. | Player casts Stormgold to interrupt, rapidly casts again, sees a larger damage number. |
   | **Deepfrost** — *Shatter* | A Frozen enemy (during the root window) that takes `DamageSource.DIRECT` or `DamageSource.CONTACT` damage receives +25% bonus damage on that hit. Formula: `shatter_damage = base_damage × base_damage_modifier × 1.25` — multiplicative, not additive to the modifier; applied before `elemental_multiplier`. Example: `base_damage=20, deepfrost_modifier=0.80 → round(20 × 0.80 × 1.25) = 20` (Shatter exactly compensates for Deepfrost's low modifier on impact hits). `DamageSource.DOT` ticks do not trigger Shatter — impact only. | Player hits a Frozen enemy with another spell and sees a bonus damage value. |
   | **Verdant** — *Injury Bloom* | If Regen is active on Fayde when she takes `DamageSource.CONTACT` damage, an additional immediate Regen tick fires at the moment of impact (`regen_tick_magnitude × fayde_max_hp` HP — uses the same tunable value as a normal Regen tick). | Player takes a hit while regenerating and notices an extra green tick. |

   *Shatter (Deepfrost) creates the most powerful inter-type synergy: Deepfrost root → any offensive type for +25% bonus. Combination Resolution GDD should acknowledge this pairing explicitly.*

   **Discovery Signal Contract** — design requirement for VFX pipeline and Status Effects GDDs. Each conditional behavior must be accompanied by a minimum required visual signal that makes the behavior unmissable. The discovery signal column above is the target experience; the table below is the implementation contract:

   | Type | Minimum Required Visual | Consuming GDD |
   |------|------------------------|---------------|
   | Ashfire — Burn Contagion | Distinct particle arc or trail visually linking the killed enemy to the new Burn target; must be visible at screen scale during multi-enemy combat | VFX pipeline, Status Effects |
   | Voidblue — Deepening Doubt | Visible timer extension animation on the Blind overlay (e.g., shimmer pulse or icon refresh) each time the timer extends; must be distinguishable from the baseline overlay | Status Effects, VFX pipeline |
   | Stormgold — Lightning Follow-Through | A visual glow or charge-up indicator on the Stormgold slot/attack for the 1.5s window duration, indicating the follow-through bonus is available; must be legible while the player is casting | Status Effects, Combat HUD |
   | Deepfrost — Shatter | A distinct crack-effect or impact flash on the Frozen target when Shatter triggers; bonus damage number must be visually distinct from a standard hit number | VFX pipeline, Status Effects |
   | Verdant — Injury Bloom | The extra Regen tick must produce a visible green heal number distinct from the scheduled tick cycle; must fire at the frame of impact, not deferred | Status Effects, VFX pipeline |

   These requirements must be referenced in the VFX pipeline GDD and Status Effects GDD at authoring time. Without this contract, Layer 2 mastery relies on players noticing behaviors that will be visually indistinguishable from normal play.

8. **Status effect visual confirmation requirements**: Each status must display a persistent visual indicator on its target for the full duration of the status, independent of whether the status has triggered an event yet. This is a design requirement to be consumed by the Status Effects and VFX pipeline GDDs.

   | Status | Required Visual | Rationale |
   |--------|----------------|-----------|
   | Burn | Persistent flame/ember overlay on enemy | Ticks are self-confirming; overlay reinforces timing |
   | Blind | Persistent eye-shimmer overlay on enemy for full duration | 50% miss: player needs confirmation before a miss occurs |
   | Stun | Enemy animation freeze-frame for full duration; distinct full-body flash | 0.8s minimum — must be perceptible at the tuning floor |
   | Freeze | Ice crystal overlay; enemy fully stops (root) then shows slowed movement | Deterministic root is self-confirming; overlay reinforces |
   | Regenerate | Persistent green particle aura on Fayde for full duration | 6 HP / 100 HP = 6% bar movement — imperceptible without aura |
   | Stun — re-application rejected | A brief desaturated pulse on the enemy's existing freeze-frame (distinct from the initial full-body flash) when a second Stun application is ignored. Must be visually distinguishable from a fresh Stun application. *(Consuming GDDs: Status Effects, Combat HUD)* | Without a rejection signal, players conflate "Stun refreshed" with "Stun ignored" — either misconception breaks the mastery arc for Stun timing. |

---

**The Five Prana Types (MVP Catalog):**

| ID | Name | Element | Semantic Identity | Color | Damage Class | Base Status | `base_damage_modifier` |
|----|------|---------|-------------------|-------|-------------|------------|----------------------|
| 0 | **Ashfire** | Fire / Destruction | Ambition that burns everything — including plans. Force without precision. | `#F24C1D` | Fire | Burn (DoT 2s) | 1.25 |
| 1 | **Voidblue** | Shadow / Void | The doubt that makes a weapon waver. Enemies lose the thread of their own intention. | `#4A5EF5` | Shadow | Blind (miss chance 2s) | 0.90 |
| 2 | **Stormgold** | Lightning / Speed | The moment before an attack arrives, Stormgold is already there. | `#FFCC00` | Lightning | Stun (interrupt, 0.8s min) | 1.15 |
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
| **Status Effects** | `base_status` enum value (routing) + all tick parameters, durations, and concurrency rules (provisional — ownership transfers to Status Effects GDD when authored) | Hard — Status Effects implements the behavior Prana Data specifies |

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
| Tick count | `burn_tick_count` | int | 1–N | `floor(burn_duration / burn_tick_rate)` = floor(2.0 / 0.5) = **4**. Must use `floor()` — float division produces non-integer results at non-even tuning values. Fractional remainder window is silently discarded: the last tick fires at exactly `burn_tick_count × burn_tick_rate` seconds, then the status expires cleanly. |
| Tick interval | `burn_tick_rate` | float | seconds | **0.5s** per tick |
| Total duration | `burn_duration` | float | seconds | **2.0s** |

**Output Range:** 0 to unbounded (scales with `base_damage`). The `max(0, base_damage)` guard ensures negative `base_damage` never produces a healing DoT. `base_damage` is expected to be positive by contract from Spell Casting & Effects, but the formula-level clamp is the safety guarantee.

**Example:** `base_damage` = 10 → burn_total = 10 × 0.08 × 4 = **3.2 bonus damage** (32% of the direct hit). Ashfire effective total: (10 × 1.25) + 3.2 = **15.7 per cast** (effective multiplier: 1.57, not 1.25 — see modifier table note).

**Burn tick damage application (cross-system contract with Health & Damage):** Each Burn tick is processed individually by Health & Damage's `final_damage` formula, including the `target_max_hp` clamp. No single Burn tick can deal more damage than the target's remaining HP. The `DamageSource.DOT` value is passed to `final_damage` per tick. This is the canonical contract — Burn ticks are not special-cased outside the standard damage pipeline.

---

### Formula 2: Regenerate Total Healing

The `regen_total` formula is defined as:

`regen_total = fayde_max_hp × regen_tick_magnitude × regen_tick_count`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Fayde's max HP | `fayde_max_hp` | int | 1–unbounded | Defined in Health & Damage GDD |
| HP per tick | `regen_tick_magnitude` | float | 0.0–1.0 | Fraction of `fayde_max_hp` per tick. **Value: 0.02** |
| Tick count | `regen_tick_count` | int | 1–N | `floor(regen_duration / regen_tick_rate)` = floor(3.0 / 1.0) = **3**. Same `floor()` rule as Burn. Fractional remainder window discarded. |
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
| **Stun** | Stormgold | 0.8s min (see Tuning Knobs) | Binary | Hard interrupt only — cancels enemy current action. No damage component. Enemy displays a visual freeze-frame for the full Stun duration (see Core Rule 8). |
| **Freeze** | Deepfrost | 2.0s | Root: binary + Slow: 50% | Root is an absolute position lock (binary). Slow reduces enemy movement speed by 50% (fixed). No formula needed. |

*`burn_tick_magnitude`, `regen_tick_magnitude`, and `blind_miss_chance` are the primary tuning targets for balance iteration after Health & Damage GDD is complete.*

## Edge Cases

- **If a Prana type ID is requested that does not exist in the catalog**: Return null and log an error. No system should silently proceed with a missing type — null behavior must surface as a programmer error during development, not a runtime game state. (Prana Data guarantees: all valid IDs are contiguous integers from 0 to N-1 in the MVP catalog.)

- **If Burn is applied to an enemy already burning (Ashfire cast twice on same target)**: The existing Burn timer resets to full duration (2.0s) and `burn_tick_magnitude` stays at 0.08. Burn does NOT stack — a second Burn application refreshes, not multiplies. *Rationale: Stacking would make rapid Ashfire casts trivially dominant and create DoT overflow that is difficult to read visually.*

- **If Regenerate is triggered while Fayde is already regenerating**: The existing Regen timer resets to full duration (3.0s). Regen does NOT stack. Same rule as Burn refresh.

- **If Regenerate ticks when Fayde is already at max HP**: The tick does nothing — HP cannot exceed `fayde_max_hp`. No overflow, no carry-forward. Healing a full-HP Fayde is wasted — intentional design pressure to use Verdant opportunistically, not freely.

- **If two different statuses from two different Prana types are active simultaneously** (e.g., enemy has Freeze from Deepfrost and then gets hit by Ashfire): Both statuses are active simultaneously. Burn and Freeze do not cancel each other. An enemy can be Frozen (rooted + slowed) AND Burning (DoT) at the same time.

- **General Stun concurrency rule**: Stun does **not** pause Burn, Regen, or Blind timers. Only Freeze receives the pause treatment (see below). Rationale: Freeze's pause protects earned lockdown duration — a positioning investment the player should not lose to a Stormgold follow-up. Burn (DoT on enemy), Regen (healing on Fayde), and Blind (evasion window on enemy) all run independently of whether the enemy can act. An enemy that is Stunned while Burning continues to take Burn ticks; Fayde's active Regen continues to tick; an enemy's Blind window counts down regardless of Stun.

- **If Stun is applied to an already-Frozen enemy**: Stun takes precedence for its configured duration (canonical: **0.8s**) — the enemy is stunned (interrupting any action). The Freeze timer **pauses** during the Stun window; it does not count down. When Stun expires, Freeze resumes with its full remaining duration intact. *Rationale: Pause model is fair to the player — they do not lose Freeze time they earned.*

- **Freeze root and slow concurrency**: Both effects (position root AND 50% movement slow) are active simultaneously for the full 2.0s duration. The slow does not wait for the root to expire — it runs in parallel. If a future Resistance mechanic breaks the root early, the slow remains until the 2.0s timer expires.

- **If Stun is applied to an enemy mid-attack animation**: The attack animation is cancelled immediately. The enemy's attack does not resolve. The Stun timer (canonical: **0.8s**) begins from the cancel frame. *This is the core value proposition of Stormgold — interrupt timing matters.*

- **If Blind is applied to an enemy that has no attack in the next 2.0s** (e.g., a downed or retreating enemy): Blind expires without triggering any miss check. The status is wasted. This is valid gameplay — Blind timing is a skill expression.

- **If a Prana type that hasn't been unlocked (VS scope) is somehow requested at runtime**: Treat as invalid ID. Meta-Progression owns the unlock gate — Prana Data does not enforce it.

- **If `base_damage` is 0 or negative when `burn_total` is calculated**: Burn total = 0. No negative DoT. `base_damage` is expected to be a positive float by contract from Spell Casting & Effects — clamp behavior at 0 is a safety fallback, not an intended game state.

- **If `fayde_max_hp` is 0 when `regen_total` is calculated**: Regen total = 0. This is a game-ending condition (Fayde dead or HP system error) — handle at the Health & Damage level, not Prana Data. Prana Data formula output of 0 is safe behavior.

- **If Freeze is applied to an enemy while Stun is already active**: The Freeze timer does NOT begin counting down during the remaining Stun window — Freeze enters the paused state from the moment of application. When Stun expires, Freeze resumes from its full configured duration (2.0s). The remaining Stun time consumes no Freeze duration. This is the symmetric complement of the Stun-onto-Frozen rule; regardless of application order, Stun and Freeze do not overlap their active time windows.

- **If Blind is re-applied while already active**: Blind timer resets to 2.0s (refresh model, consistent with Burn and Regen). Miss chance stays 50%. Deepening Doubt extension ticks that were pending are discarded — only the freshly set 2.0s applies.

- **If Stun is re-applied while already active**: The second Stun application is ignored — the existing Stun timer continues to its natural expiry. Stun is a one-shot interrupt; stacking it via rapid Stormgold casts would create a de facto guaranteed lockdown that bypasses its intended timing skill-expression.

- **If Freeze is re-applied while already active (not in Stun-pause state)**: Freeze timer resets to 2.0s (refresh model). Both root and 50% slow restart from full duration simultaneously.

- **If Freeze is re-applied while it is in the Stun-pause state**: The paused Freeze timer resets to 2.0s. When Stun expires, Freeze resumes from 2.0s — not from the previous remaining duration.

- **If Blind is active on an enemy that is also Frozen**: Blind timer continues counting down (Freeze does not pause Blind — only Stun pauses Freeze; no other status pauses anything else). A Frozen enemy cannot attack, so Blind will expire unused if no attack occurs during the overlap window. This is the same wasted-Blind behavior as documented for retreating enemies — it is a player skill-expression cost, not an error.

- **Burn Contagion — no valid spread target**: If a target dies while Burning but no enemy is within `burn_contagion_range` (default 200px), Burn does not spread. The status expires on the killed target. No fallback, no error.

- **Lightning Follow-Through — Stun applied to idle enemy does not qualify**: A Stun that interrupts an enemy not currently executing an attack animation (idle, patrolling, recovering) does NOT open the 1.5s follow-through window. Only Stuns that actively cancel an in-progress attack animation qualify. The window opens only on a confirmed interrupt event.

- **Shatter — DoT ticks do not trigger the bonus**: `DamageSource.DOT` ticks (Burn ticks) applied to a Frozen enemy do NOT trigger Shatter. Only `DamageSource.DIRECT` or `DamageSource.CONTACT` hits apply the +25% bonus. Shatter is an impact mechanic — DoT is not impact.

- **Shatter — Deepfrost's own cast does not self-proc on first application**: When Deepfrost casts, it applies Freeze and delivers a `DamageSource.DIRECT` hit to the target simultaneously. Shatter does NOT proc on this hit — Shatter requires the Freeze root window to be *already active* when the hit is processed. On Deepfrost's first cast against a target, Freeze is not yet active at hit-processing time. On a *second* Deepfrost cast against the same Frozen enemy, the existing Freeze root window IS active (Freeze refreshes via the re-application rule), so Shatter DOES proc and the Freeze timer resets to 2.0s in the same frame. This prevents Deepfrost from gaining a passive self-Shatter bonus on every first cast while preserving the inter-cast Shatter synergy (a reward for sustained Deepfrost use or Deepfrost follow-ups). The `DamageSource.DIRECT` vs. Freeze-active ordering is owned by Spell Casting & Effects GDD.

- **Deepening Doubt — extension cap enforcement**: The Blind timer cap is `deepening_doubt_cap = 2.0 × blind_duration` — computed at load time from the tunable `blind_duration` value, never hardcoded. At canonical `blind_duration=2.0s`, cap = 4.0s. A very fast-attacking enemy that misses 10 times cannot push Blind beyond the cap. Cap is enforced per-tick: `new_timer = min(current_timer + deepening_doubt_extension, deepening_doubt_cap)`.

- **Injury Bloom — i-frame interaction**: If Fayde takes `DamageSource.CONTACT` damage during an active i-frame window (`fayde_iframe_duration = 0.5s`), the i-frame absorbs the hit and Fayde's HP does not change. In this case, **Injury Bloom does NOT fire** — Bloom triggers only when real CONTACT damage is applied (i.e., when `final_damage > 0` is applied to Fayde's HP). An i-framed hit is not a damage event for Bloom purposes. This prevents swarm scenarios (multiple simultaneous hits during one i-frame) from generating multiple free healing ticks.

- **Lightning Follow-Through — window replacement on second interrupt**: If a second qualifying interrupt (a Stormgold Stun that cancels an in-progress enemy attack animation) occurs while a Follow-Through window is already open, the window timer **resets to 1.5s** — the new interrupt replaces the previous window, it does not stack a new one. Multiple simultaneous interrupts in a multi-enemy wave do not accumulate into a permanent +30% bonus.

- **Burn Contagion — chain depth**: Transferred Burn (applied to a new target via Contagion on a kill) is **Contagion-inert** — it does not trigger Contagion again if the new target is killed while Burning. Only direct Ashfire casts can initiate Contagion. This prevents unlimited cascade chains in clustered waves.

## Dependencies

### Upstream Dependencies (what Prana Data requires)

**None.** Prana Data is a Foundation layer system. It is loaded first at runtime and requires no other game system to function. All values are author-time constants.

*Visual and audio assets (icons, audio streams) are loaded from disk — Prana Data requires the engine's resource loading system (Godot's `ResourceLoader`) to be available, but this is an engine requirement, not a game system dependency.*

### Downstream Dependents (what requires Prana Data)

All seven are **hard dependencies** — these systems cannot function without Prana Data being initialized.

| Dependent System | Priority | What It Needs | Nature |
|----------------|----------|--------------|--------|
| **Prana Grid** | MVP | Full type definitions (id, name, color, icon, visual properties) | Hard — cannot render grid slots without the type catalog |
| **Combination Resolution** | MVP | `id`, `damage_class`, `base_status` per type | Hard — combo lookup table is keyed by Prana type ID |
| **Spell Casting & Effects** | MVP | `vfx_burst_shape`, `audio_signature`, `cast_animation` per type | Hard — cannot route VFX/audio without type identity |
| **Elemental Affiliation & Weakness** | MVP | `id`, `damage_class` | Hard — weakness multiplier table is keyed by damage class |
| **Prana Drop / Loot** | MVP | `id`, `name`, `color` | Hard — drop entries are keyed by Prana type ID |
| **Meta-Progression** | Vertical Slice | `id` | Hard — unlock flags keyed by Prana type ID |
| **Status Effects** | MVP | `base_status` enum (routing) + all conditional depth behavior specifications (Core Rule 7) | Hard — Status Effects implements every status behavior specified in this GDD; it cannot be designed or implemented without this document |

**Bidirectional consistency note:** Each of the above systems' GDDs must list Prana Data as an upstream dependency. When those GDDs are authored, their Dependencies sections should reference this document. Status Effects GDD additionally inherits all behavioral specifications from Core Rule 7 and the provisional Formulas section — see the Implementation Notes ownership transfer clause.

**Compound damage multiplier chain — flag for Elemental Affiliation & Weakness GDD:** `base_damage_modifier` is applied to `raw_spell_power` *before* the elemental weakness multiplier. The full chain is: `raw_spell_power × base_damage_modifier = spell_base_damage → × elemental_multiplier = final_damage (before round/clamp)`. The Elemental Affiliation & Weakness GDD must design its multiplier values with this chain in mind. Example: Ashfire (`base_damage_modifier = 1.25`) hitting a fire-weak enemy at `elemental_multiplier = 1.5` yields `20 × 1.25 × 1.5 = 37.5` — a one-shot on a 35 HP Charger. Weakness multipliers designed without awareness of the existing modifier chain will produce unintended one-shots.

## Implementation Notes

*(GDScript-specific guidance for the implementation team. Supplements design rules above.)*

**Immutability enforcement:** `PranaCatalog.get_type(id: int) -> PranaType` must return `original.duplicate_deep()` on every call. `duplicate_deep()` is the Godot 4.5+ replacement for the deprecated `duplicate(true)` — do not use the deprecated form. This produces a new `PranaType` wrapper object with independent property values. Note: `AudioStream` and `Texture2D` are file-backed assets; their underlying data is shared by reference across all copies (correct and expected — the engine does not copy pixel/audio data through `duplicate_deep()`). Only property reassignment on one wrapper (e.g., changing `my_type.base_damage_modifier`) is isolated from other callers. This is the enforcement mechanism for Core Rule 1. Record this decision in an ADR in `docs/architecture/`.

**Enum file:** `CastAnimation`, `VfxBurstShape`, `DamageClass`, `BaseStatus`, and **`DamageSource`** are all defined in `src/data/game_enums.gd` with `class_name GameEnums`. This is a plain script, NOT an Autoload. Access: `GameEnums.DamageClass.FIRE`, `GameEnums.DamageSource.DIRECT`, etc. The `class_name` makes it globally accessible without explicit `preload`.

`DamageSource` enum — combat primitive shared by Health & Damage, Status Effects, and Spell Casting:

| Constant | Value | Usage |
|----------|-------|-------|
| `DIRECT` | 0 | Standard spell hit — direct impact damage |
| `DOT` | 1 | Damage over time tick (e.g., Burn tick) |
| `CONTACT` | 2 | Physical contact / collision damage |

**Enum stability constraint:** All `GameEnums` enum values stored as `@export` properties in `.tres` Resource files **must use explicit integer assignments** (e.g., `enum DamageClass { FIRE = 0, SHADOW = 1, LIGHTNING = 2, ICE = 3, NATURE = 4 }`). Never reorder or insert without explicit values — `.tres` files serialize enums as integers; reordering silently loads wrong data with no error or warning.

**`game_enums.gd` constraint:** No `extends` beyond `RefCounted`, no `@onready`, no `preload` or `load` from any other game script. It is a pure enum container. Any import introduced creates a circular dependency risk for every system in the project.

**Autoload initialization order:** `PranaCatalog` must be the **first Autoload** in Project Settings → Autoloads. No other Autoload may call `PranaCatalog.get_type()` during its own `_ready()` — violation causes a guaranteed null crash at startup, not a subtle bug (dragging an Autoload above PranaCatalog in the editor is easy to do accidentally). Guard against this: `PranaCatalog` must declare `var _initialized: bool = false`, set it `true` at the end of `_ready()`, and `get_type()` must use a release-safe guard:

```gdscript
func get_type(id: int) -> PranaType:
    if not _initialized:
        push_error("PranaCatalog.get_type() called before _ready() — check Autoload order in Project Settings")
        return null
    # ... rest of function
```

**Do NOT use `assert(_initialized, ...)` for this guard.** In Godot 4.6, `assert()` is stripped from release export builds — it provides zero protection in any shipped build. `push_error()` writes to the engine error log in both debug and release exports and does not crash the game. Scene nodes (non-Autoload) are safe to call PranaCatalog in `_ready()` — Godot initializes all Autoloads before the main scene. Catalog loading is synchronous (`load()`, not threaded) — 5 `.tres` files, negligible startup cost. Record the initialization guard in the ADR.

**Tick parameter ownership:** `burn_duration`, `burn_tick_rate`, `regen_duration`, `regen_tick_rate`, and all status durations/magnitudes are provisional design inputs in this GDD. Their permanent home is the **Status Effects GDD (System #7)**. At implementation, these values live as **`@export var`** with `@export_range` constraints matching the safe ranges in the Tuning Knobs table — not as properties in `PranaType.tres` files, which only store the 12 per-type properties. (`@export const` is invalid GDScript syntax — constants are compile-time values and cannot be inspector-editable, which would violate the Tuning Knobs designer-adjustable requirement.)

**Integer-multiple enforcement:** The Status Effects class must assert at load time that `burn_duration` is an integer multiple of `burn_tick_rate` (and `regen_duration` of `regen_tick_rate`). Non-conforming values silently produce one fewer tick than expected (e.g., `burn_tick_rate=0.3s`, `burn_duration=2.0s` → `floor(2.0/0.3) = 6` ticks instead of 7, delivering 48% DoT instead of 56% with no error). Required asserts:
```gdscript
assert(fmod(burn_duration, burn_tick_rate) < 0.001, "burn_duration must be an integer multiple of burn_tick_rate")
assert(fmod(regen_duration, regen_tick_rate) < 0.001, "regen_duration must be an integer multiple of regen_tick_rate")
```

**`.tres` enum serialization — verification required before implementation sprint:** The enum stability constraint (explicit integer assignments for all `GameEnums` enum constants) rests on Godot 4.6 serializing `@export` enum properties as integers, not string names. This must be manually verified before any `.tres` files are authored: create a throwaway Resource with `@export var damage_class: GameEnums.DamageClass`, save as `.tres`, open in a text editor and inspect the serialized value. If integer: explicit assignments are mandatory (reordering silently corrupts data). If string name: explicit assignments are good practice but not a safety requirement. Record the verification result in the ADR.

**Missing-asset handling:** `PranaCatalog._ready()` must validate all loaded types explicitly — null checks alone are insufficient. Asset properties (`audio_signature`, `icon`) produce `null` on missing files. Scalar properties (`base_damage_modifier`, enum values) default to `0` / first enum constant on corrupt `.tres` files, silently hiding corruption while passing null checks. Required startup assertions for each loaded type: (1) `type.id` equals its expected catalog index; (2) `type.base_damage_modifier > 0.0`; (3) `type.name` is non-empty; (4) `type.audio_signature != null`; (5) `type.icon != null`. A null `AudioStream` produces a silent cast; a null `Texture2D` produces a blank grid slot; a `base_damage_modifier` of `0.0` produces zero-damage spells with no in-game error. All violations must surface as startup asserts during development.

**Color comparison:** `PranaType.color` is stored in `.tres` as float components, not hex strings. Tests must use `Color.is_equal_approx()`, not `== Color("#F24C1D")`.

## Tuning Knobs

All values listed here should be designer-adjustable without code changes — stored in external config or Resource files, not hardcoded.

| Knob | Current Value | Safe Range | What breaks if too high | What breaks if too low |
|------|-------------|-----------|------------------------|----------------------|
| `ashfire_damage_modifier` | 1.25 | 1.0–1.4 | Ashfire dominates all other offensive types; optimal grid is all-Ashfire | Ashfire feels like a control type with an irrelevant DoT — loses its identity |
| `stormgold_damage_modifier` | 1.15 | 1.0–1.3 | Stormgold replaces Ashfire as default damage type | Stormgold becomes punishing to slot — 0.8s stun doesn't justify the damage loss |
| `voidblue_damage_modifier` | 0.90 | 0.75–1.05 | Voidblue combines reliable damage with a near-50% global miss rate — too powerful | Voidblue is clearly inferior in all scenarios; Blind is not worth the modifier penalty |
| `deepfrost_damage_modifier` | 0.80 | 0.65–0.95 | Deepfrost deals near-full damage AND guarantees root+slow — dominant against all enemies | Even with root+slow, the damage penalty makes Deepfrost a dead slot unless enemies require control |
| `verdant_damage_modifier` | 0.70 | 0.55–0.80 | Verdant becomes a viable damage type — removes the trade-off, destroys sustain identity | Players never slot Verdant — the healing isn't worth the damage loss even in long fights |
| `burn_tick_magnitude` | 0.08 | 0.04–0.15 ⚠️ | Burn DoT becomes primary damage source; Ashfire optimal even against fire-resistant enemies | Burn feels like a visual effect, not a mechanic — Ashfire loses depth |
| `burn_duration` | 2.0s | 1.0–3.0s ⚠️ | Long enough that follow-up spells always benefit from DoT; removes positioning pressure | Burn is barely perceptible — refreshing it becomes meaningless |
| `burn_tick_rate` | 0.5s | 0.25–1.0s ⚠️ | Very frequent ticks create rapid number spam — readability suffers | Sparse ticks make 2s burn feel like a delayed, unreliable effect |
| `blind_miss_chance` | 0.50 | 0.25–0.70 | Near-immunity to incoming damage in multi-enemy encounters | Blind feels like a visual cosmetic, not a control tool |
| `blind_duration` | 2.0s | 1.0–3.0s | Voidblue provides sustained near-evasion throughout a wave | Too brief to use strategically around enemy attacks |
| `deepening_doubt_extension` | 0.5s | 0.25–1.0s | Extension reaches cap in fewer misses — Deepening Doubt becomes trivially powerful against fast attackers | Extension is too small to notice against any but the highest-frequency attackers; Deepening Doubt depth behavior becomes inaccessible |
| `stun_duration` | 0.8s | 0.8–1.0s | Stun approaches guaranteed lockdown for slow wind-up bosses | Below 0.8s is perceptibility-prohibited: the visual freeze-frame (Core Rule 8) requires at least 0.8s to register in real-time action. *Minimum raised from 0.25s to 0.8s after design-review — perceptibility is a design constraint, not a tuning preference.* |
| `freeze_duration` | 2.0s | 1.5–3.0s | Deepfrost trivializes positioning — enemies never reach Fayde | Freeze barely disrupts enemy paths — root+slow loses strategic value |
| `freeze_slow_pct` | 50% | 30–70% | Near-complete speed reduction; effectively extends root duration | Enemies move nearly at full speed — Freeze root becomes the only meaningful effect |
| `regen_tick_magnitude` | 0.02 | 0.01–0.05 | Verdant can sustain through moderate hits — removes positioning pressure | Regen covers only 1–3% HP total — irrelevant to run survival |
| `regen_duration` | 3.0s | 2.0–5.0s | Verdant provides sustained healing between casts — sustain becomes passive | Too brief to be worth slotting unless Fayde is taking hits in rapid succession |

| `burn_contagion_range` | 200px | 100–400px | Contagion chains cascade across entire waves — Ashfire clears clustered enemies for free | Contagion almost never triggers — Ashfire depth behavior is effectively inaccessible in normal wave compositions |

**Interaction warnings:**
- `blind_miss_chance` and `blind_duration` interact: raising both simultaneously risks effective immunity in multi-enemy waves. Adjust one at a time.
- `burn_tick_magnitude` and `ashfire_damage_modifier` interact: Ashfire's total damage is the sum of both. If buffing Ashfire, reduce one; don't raise both.
- **⚠️ Linked Burn constraint — `burn_tick_magnitude × floor(burn_duration / burn_tick_rate)` must not exceed 0.60.** These three knobs (marked ⚠️ in the table above) cannot be tuned independently to their stated individual extremes — doing so simultaneously yields `0.15 × floor(3.0/0.25) = 1.80`, violating the cap by 3×. The stated individual ranges are limits for single-axis adjustment only, not simultaneously achievable. Combined constraint: `burn_tick_magnitude × floor(burn_duration / burn_tick_rate) ≤ 0.60`. Adjust only one axis at a time.
- **`burn_duration` must always be ≥ `burn_tick_rate`** (at least one tick must fire). If violated, Burn is visually active but deals zero damage. Same constraint: `regen_duration ≥ regen_tick_rate`.
- **`burn_duration` must be an integer multiple of `burn_tick_rate`** (same for `regen_duration` / `regen_tick_rate`). Non-integer-multiple values cause `floor()` float-precision edge cases where GDScript may silently produce one fewer tick than expected.
- **Burn cap — code enforcement required:** The 0.60 cap on `burn_tick_magnitude × floor(burn_duration / burn_tick_rate)` must be enforced with an assert in the Status Effects class at load time: `assert(burn_tick_magnitude * floor(burn_duration / burn_tick_rate) <= 0.60, "Burn cap exceeded — adjust burn_tick_magnitude, burn_duration, or burn_tick_rate")`. Prose documentation alone is insufficient under deadline pressure.
- **`burn_contagion_range` and `burn_duration` interact:** Contagion always transfers Burn at a fixed 2.0s duration regardless of the current `burn_duration` setting. If `burn_duration` is tuned below 2.0s (e.g., 1.0s), Contagion spread applies a *longer* Burn than a direct Ashfire cast — Contagion becomes proportionally more powerful as `burn_duration` decreases. Adjust together; do not lower `burn_duration` without reviewing whether the 2.0s Contagion fixed duration is still appropriate.
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

49 criteria listed below (AC-PD-33 split into 33a/33b/33c; AC-PD-44 split into 44/44b/44c; AC-PD-04c added for reference-type property isolation; net +5 from original 44) across two evidence types per coding standards:
- **Logic-type (unit tests)** — BLOCKING gate in `tests/unit/prana-data/`.
- **Integration-type** — BLOCKING gate; requires integration test OR documented playtest as evidence (not satisfied by unit test alone — timer-driven behavior requires a running Godot SceneTree). Integration test location: `tests/integration/prana-data/`.
- 2 criteria (AC-PD-19, AC-PD-29) are **relocated** — they test Enemy AI / animation behavior, not Prana Data. They are listed below with a relocation note and are NOT part of the Prana Data blocking gate.
- AC-PD-18 is **Advisory** (explicitly not in CI BLOCKING gate — configure with GUT skip tag).
- AC-PD-42 is **blocked** on Enemy AI GDD authoring — removed from Prana Data BLOCKING gate.
- **Ownership note:** ACs PD-20 through PD-44c test runtime status behavior, not catalog data. These are provisional Prana Data integration tests. When Status Effects GDD is authored, migrate these ACs to the Status Effects test suite. Until that migration, they remain here as the integration boundary for this catalog's behavior contracts.

*Advisory note — Blind RNG (AC-PD-18): The 50% miss chance is specified as a per-attack coin flip. Whether a seeded or unseeded RNG is used is a technical decision for the lead programmer. If unseeded: use a 95% confidence interval (approximately 469–531 misses in 1,000 trials — not 450–550, which is a 68% interval that will produce false CI failures at higher frequency than documented). If seeded: rewrite as a deterministic test using a fixed seed.*

*Integration test location: `tests/integration/prana-data/`. All Integration-type ACs (marked with the Integration tag) are implemented in this directory.*

---

### Data Integrity

**AC-PD-01 — Catalog loads exactly five types at startup**
GIVEN the game application starts, WHEN Prana Data finishes initialization, THEN the catalog contains exactly 5 entries with IDs 0, 1, 2, 3, and 4 — no more, no fewer.

**AC-PD-02 — All five type definitions are correctly identified**
GIVEN the catalog has been loaded, WHEN queried for each ID 0–4, THEN the `name` values are: ID 0 = "Ashfire", ID 1 = "Voidblue", ID 2 = "Stormgold", ID 3 = "Deepfrost", ID 4 = "Verdant" — each distinct and non-null.

**AC-PD-03 — Every type definition contains all 12 required properties**
GIVEN the catalog has been loaded, WHEN any type definition is retrieved by ID, THEN the returned object has non-null values for all 12 properties: `id`, `name`, `element`, `semantic_identity`, `color`, `icon`, `vfx_burst_shape`, `audio_signature`, `cast_animation`, `damage_class`, `base_status`, `base_damage_modifier`.

**AC-PD-04 — Catalog returns consistent values across reads** *(Logic — unit test)*
GIVEN the catalog has been loaded and a type definition is read once and stored in a local variable, WHEN the catalog is read again for the same ID, THEN the two returned definitions are identical in all 12 properties. This test requires only two sequential reads with no intervening game state.

**AC-PD-04b — Scalar mutation by one caller is not visible to another** *(Logic — unit test)*
GIVEN the catalog is loaded, Caller A calls `get_type(0)` and sets `caller_a_instance.base_damage_modifier = 99.0`, AND Caller B then calls `get_type(0)` independently, THEN `caller_b_instance.base_damage_modifier` equals the original catalog value (1.25) — not 99.0.

**AC-PD-04c — Reference-type property mutation by one caller is not visible to another** *(Logic — unit test)*
GIVEN the catalog is loaded, Caller A calls `get_type(0)` and replaces `caller_a_instance.icon` with a preloaded stub texture (`preload("res://tests/fixtures/stub_icon.png")`), AND Caller B then calls `get_type(0)` independently, THEN `caller_b_instance.icon` is the original catalog icon — not the stub. (This confirms that `duplicate_deep()` isolates property reassignment on reference-type fields, not just scalar fields.)

**AC-PD-05 — DELETED** *(moved to consuming system test suites)*
The contract that Combination Resolution, Elemental Affiliation & Weakness, and Prana Drop / Loot use integer IDs (not string names) for Prana lookups is each system's own responsibility. This criterion tested other systems' behavior, not Prana Data's. It has been moved to those systems' test suites where it belongs.

**AC-PD-06 — Targeting shape is absent from all type definitions**
GIVEN the catalog has been loaded, WHEN any type definition is retrieved by ID, THEN `"targeting_shape" in prana_type`, `"cast_shape" in prana_type`, and `"spell_shape" in prana_type` each evaluate to `false` — verified using GDScript's `in` operator, not property access (direct property access on a non-existent field throws an error in GDScript 4).

**AC-PD-07 — No Resonance field is present in any MVP type definition**
GIVEN the catalog has been loaded, WHEN any type definition is retrieved by ID, THEN `"resonance" in prana_type` and `"resonance_weight" in prana_type` each evaluate to `false` — verified using GDScript's `in` operator.

**AC-PD-08 — IDs 0–4 are stable across sessions** *(Logic — unit test)*
GIVEN the catalog is loaded, WHEN each ID 0–4 is queried, THEN: ID 0 `name == "Ashfire"` and `damage_class == GameEnums.DamageClass.FIRE`; ID 1 `name == "Voidblue"` and `damage_class == GameEnums.DamageClass.SHADOW`; ID 2 `name == "Stormgold"` and `damage_class == GameEnums.DamageClass.LIGHTNING`; ID 3 `name == "Deepfrost"` and `damage_class == GameEnums.DamageClass.ICE`; ID 4 `name == "Verdant"` and `damage_class == GameEnums.DamageClass.NATURE` — asserted against hard-coded expected constants. (Session-restart stability is guaranteed by the `.tres` file contract, not runtime state; a single-session constant assertion is the correct automated test.)

---

### Formula Verification

**AC-PD-09 — Burn total damage formula: 4 ticks × 8% × base_damage** *(Logic — unit test)*
GIVEN `base_damage` = 10, `burn_tick_magnitude` = 0.08, `burn_tick_count` = 4, WHEN `burn_total` is computed as `max(0, base_damage) × burn_tick_magnitude × burn_tick_count`, THEN the result equals 3.2. No enemy, no timer, no SceneTree required. (Timer behavior is covered by AC-PD-10.)

**AC-PD-10 — Burn ticks at 0.5s intervals** *(Integration — requires running SceneTree timer)*
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

**AC-PD-16 — Regen total healing formula: 3 ticks × 2% × fayde_max_hp** *(Logic — unit test)*
GIVEN `fayde_max_hp` = 100, `regen_tick_magnitude` = 0.02, `regen_tick_count` = 3, WHEN `regen_total` is computed as `fayde_max_hp × regen_tick_magnitude × regen_tick_count`, THEN the result equals 6.0. No player character, no timer, no SceneTree required. (Timer behavior is covered by AC-PD-17.)

**AC-PD-17 — Regen ticks at 1.0s intervals** *(Integration — requires running SceneTree timer)*
GIVEN Regen is applied to Fayde at T=0 with `fayde_max_hp` = 100, WHEN time advances and tick events are recorded, THEN HP restore events occur at T=1.0s, T=2.0s, and T=3.0s — exactly three events, none earlier than 1.0s apart.

**AC-PD-18 — Blind applies 50% miss chance per attack** *(Advisory — not in CI BLOCKING gate; see Open Question #1)*
GIVEN an enemy has Blind applied, WHEN that enemy makes 1,000 attacks during the Blind window, THEN the number of misses falls between **469 and 531** — the miss check is per-attack (coin flip), not periodic. *(95% confidence interval for p=0.5, n=1000; the prior 450–550 range was a 68% CI and would produce excessive false CI failures.)*
*Advisory: If the lead programmer chooses a seeded RNG for Blind's miss check (see Open Question #1), rewrite as a deterministic test using a fixed seed — preferred. This AC is explicitly NOT part of the Prana Data BLOCKING gate and must be configured with a skip tag in GUT to prevent non-deterministic CI failures.*

**AC-PD-19 — Stun interrupts with no additional magnitude** *(RELOCATED — belongs in Enemy AI / Status Effects test suite, not Prana Data. Tests animation cancellation behavior, not catalog data.)*
GIVEN an enemy is in an attack animation, WHEN a Stormgold cast applies Stun, THEN the attack animation cancels immediately, the enemy cannot act for the Stun duration, and normal behavior resumes after expiry with no secondary effect.

**AC-PD-20 — Freeze applies binary root AND 50% slow simultaneously for 2.0s** *(Integration)*
GIVEN an enemy is moving with `speed_modifier = 1.0` and `is_rooted = false`, WHEN a Deepfrost cast applies Freeze in the same frame, THEN before the next physics process step: `enemy.is_rooted == true` AND `enemy.speed_modifier == 0.50` — both flags set in the same frame. Both flags remain true until T=2.0s expires, at which point both reset simultaneously. *(Note: `is_rooted` is a binary position-lock flag, NOT implemented as `speed_modifier = 0.0` — these are distinct properties.)*

**AC-PD-21 — Blind duration is 2.0s** *(Integration — requires running SceneTree timer)*
GIVEN an enemy has Blind applied at T=0, WHEN T=2.0s passes with no attacks made, THEN Blind is no longer active and subsequent attacks resolve without any miss chance applied.

**AC-PD-22 — Freeze duration is 2.0s** *(Integration — requires running SceneTree timer)*
GIVEN an enemy has Freeze applied at T=0, WHEN T=2.0s passes, THEN root is released, 50% slow is removed, and the enemy returns to full movement speed simultaneously.

---

### Edge Case Behavior

**AC-PD-23 — Invalid ID lookup returns null and logs an error**
GIVEN the catalog is loaded with IDs 0–4, WHEN any system requests ID 5 (or any integer not in the catalog), THEN the return value is null AND an error is written to the engine log — no default/fallback type is silently returned.

**AC-PD-24 — Burn refresh on re-application (no stack)** *(Integration — requires running SceneTree timer)*
GIVEN an enemy has Burn active with 1.0s remaining, WHEN an Ashfire cast applies Burn again, THEN the Burn timer resets to 2.0s, `burn_tick_magnitude` remains 0.08, and the enemy does not receive more burn damage per tick than the single-stack value.

**AC-PD-25 — Regen refresh on re-application (no stack)** *(Integration — requires running SceneTree timer)*
GIVEN Fayde has Regen active with 1.0s remaining, WHEN a Verdant cast applies Regen again, THEN the Regen timer resets to 3.0s, the stored `regen_tick_magnitude` fraction remains **0.02** (the fraction of `fayde_max_hp` — not the computed absolute value `0.02 × fayde_max_hp`), and each tick continues to heal exactly `0.02 × fayde_max_hp` HP — Fayde does not receive more healing per tick than the single-stack value.

**AC-PD-26 — Regen tick at max HP is a no-op**
GIVEN Fayde is at exactly `fayde_max_hp` with Regen active, WHEN a Regen tick fires, THEN Fayde's HP does not exceed `fayde_max_hp` — the value before and after the tick is identical, no overflow is stored or carried forward.

**AC-PD-27 — Burn and Freeze coexist independently** *(Integration)*
GIVEN an enemy has Freeze active with **0.5s already elapsed** (Freeze timer reads **1.5s ± 0.05s** remaining), WHEN an Ashfire cast hits the same enemy and applies Burn in the same frame, THEN: (1) both Freeze and Burn are active simultaneously; (2) the Freeze timer still reads **1.5s ± 0.05s** — unchanged by the Burn application; (3) both effects resolve independently until their respective durations expire.

**AC-PD-28 — Stun takes precedence over Freeze; Freeze timer pauses during Stun** *(Integration — requires concurrent Stun + Freeze state and timer)*
GIVEN an enemy has Freeze active with 1.5s remaining, WHEN Stun is applied, THEN for the Stun duration the enemy is stunned and the Freeze timer is paused (not counting down); at Stun expiry, Freeze resumes with **1.5s ± 0.05s remaining** (one-frame tolerance at 60fps — do not assert exact float equality).

**AC-PD-29 — Stun mid-animation cancels attack immediately** *(RELOCATED — belongs in Enemy AI / Status Effects test suite. Tests animation cancellation behavior, not catalog data.)*
GIVEN an enemy is at any frame of an attack animation that has not yet resolved damage, WHEN Stun is applied, THEN the animation stops on the current frame, no damage event fires from that attack, and the enemy is stunned for the configured Stun duration.

**AC-PD-30 — Blind expires unused when no attack occurs** *(Integration — requires running SceneTree timer)*
GIVEN an enemy has Blind applied at T=0 and makes zero attacks between T=0 and T=2.0s, WHEN T=2.0s passes, THEN Blind is no longer active, no miss-check event was triggered, and the game state has no record of pending miss checks.

**AC-PD-31 — burn_total is 0 when base_damage is 0**
GIVEN `base_damage` = 0, WHEN Ashfire applies Burn, THEN `burn_total` = 0 — each tick deals 0 damage, no negative damage is applied, and no error is thrown.

**AC-PD-32 — regen_total is 0 when fayde_max_hp is 0**
GIVEN `fayde_max_hp` = 0, WHEN Verdant applies Regen, THEN `regen_total` = 0 — each tick heals 0 HP, Fayde's HP does not change, and no error is thrown.

**AC-PD-33a — Stun does not pause Burn timer** *(Integration)*
GIVEN an enemy has Burn active with 2.0s remaining, WHEN Stun is applied at T=0, THEN at Stun expiry the Burn timer has counted down by the Stun duration (within ±0.05s) and at least one Burn tick has fired during the Stun window — Stun did not pause or skip the Burn timer.

**AC-PD-33b — Stun applied to an enemy does not pause Fayde's Regen timer** *(Integration)*
GIVEN Fayde has Regen active with **T_remaining ≥ 1.0s** (guarantees at least one 1.0s-interval Regen tick fires within any Stun window), WHEN **an enemy** is Stunned for the canonical 0.8s duration (Stun applies to enemies, not to Fayde), THEN Fayde's Regen timer continues counting down at its normal rate and at least one Regen tick fires during the Stun window — Stun applied to an enemy does not affect Fayde's active timers.

**AC-PD-33c — Stun does not pause Blind timer** *(Integration)*
GIVEN an enemy has both Stun and Blind active simultaneously, WHEN Stun expires, THEN the Blind timer has counted down by the Stun duration (within ±0.05s) — Blind was not paused during the Stun window.

**AC-PD-34 — base_status property matches catalog table for all five types**
GIVEN the catalog is loaded, WHEN each type definition is retrieved, THEN: Ashfire's `base_status` is the `Burn` enum constant, Voidblue's is `Blind`, Stormgold's is `Stun`, Deepfrost's is `Freeze`, and Verdant's is `Regenerate` — each value is the correct enum constant, non-null, and distinct from the others.

---

### Status Effect Re-Application and Concurrency

**AC-PD-35 — Freeze applied to Stunned enemy: timer enters paused state from application** *(Integration)*
GIVEN an enemy has Stun active with 0.3s remaining, WHEN Deepfrost applies Freeze, THEN the Freeze timer does not count down during the remaining Stun window; at Stun expiry, Freeze begins from **2.0s ± 0.05s** — the 0.3s of remaining Stun consumed no Freeze duration.

**AC-PD-36 — Blind refreshes on re-application** *(Integration)*
GIVEN an enemy has Blind active with 0.5s remaining, WHEN Voidblue applies Blind again, THEN the Blind timer resets to 2.0s and the miss chance remains 50% — no stacked miss bonus.

**AC-PD-37 — Stun re-application while active is ignored** *(Integration)*
GIVEN an enemy has Stun active with 0.3s remaining, WHEN Stormgold applies Stun again, THEN the Stun timer continues from **0.3s ± 0.05s** (it does not reset to full duration) and the enemy's total Stun window is not extended by the second application.

**AC-PD-38 — Freeze refreshes on re-application** *(Integration)*
GIVEN an enemy has Freeze active with 0.8s remaining (not in Stun-pause), WHEN Deepfrost applies Freeze again, THEN the Freeze timer resets to **2.0s ± 0.05s** — both root and 50% slow extend simultaneously to the new full duration.

**AC-PD-39 — Blind timer continues during Freeze; Freeze does not pause Blind** *(Integration)*
GIVEN an enemy has Blind (1.5s remaining) and Freeze simultaneously active, WHEN 1.5s passes during which the enemy cannot attack (Frozen), THEN Blind expires at its natural time — the Freeze state did not pause the Blind timer. No miss-check was triggered during the overlap.

---

### Conditional Depth Behaviors

**AC-PD-40 — Burn Contagion: Burn transfers to nearest in-range enemy on kill** *(Integration)*
GIVEN Target A has Burn active with 1.5s remaining AND Target B is placed at distance ≤ `burn_contagion_range` (test fixture: 200px — update when Status Effects GDD defines the canonical value), WHEN Target A is killed, THEN Target B has Burn applied at full duration (2.0s ± 0.05s reset) — Burn transferred from the kill. If no enemy is within `burn_contagion_range`, Burn expires on Target A with no transfer and no error.
*Note: this AC uses `burn_contagion_range` as defined in Prana Data's Tuning Knobs table (canonical default: 200px). Update the test fixture if that tuning value changes, or if the Status Effects GDD overrides it after the ownership transfer.*

**AC-PD-41 — Deepening Doubt: Blind timer extends by `deepening_doubt_extension` per miss, capped at `deepening_doubt_cap`** *(Integration)*
GIVEN an enemy has Blind applied (timer = 2.0s), WHEN the enemy makes 5 attacks that each miss due to Blind, THEN the Blind timer equals `min(2.0 + 5 × deepening_doubt_extension, deepening_doubt_cap)`. At canonical values (extension=0.5s, cap=2.0 × blind_duration=4.0s): `min(2.0 + 2.5, 4.0) = 4.0s`. A 6th miss does not extend the timer beyond `deepening_doubt_cap`.

**AC-PD-42 — Lightning Follow-Through: +30% direct damage after confirmed interrupt** *(Integration — blocked pending Enemy AI GDD)*
GIVEN Stormgold applied Stun that cancelled an in-progress enemy attack animation (a "confirmed interrupt" — distinguished from a Stun applied to an idle or non-attacking enemy), WHEN a second Stormgold cast hits within 1.5s of that interrupt, THEN the direct hit damage equals `base_damage × stormgold_modifier × 1.30`. A Stun applied to an idle enemy does NOT open this window — no follow-through bonus applies.
*Blocked: this AC requires an observable system signal or state property that distinguishes "confirmed interrupt" from "idle Stun." This mechanism (e.g., a `stun_interrupt_confirmed` signal, or an enemy `ai_state` transition from `ATTACKING` → `STUNNED`) must be defined in the Enemy AI GDD. This AC cannot be written with confidence until that mechanism is specified. Remove from the Prana Data BLOCKING gate until Enemy AI GDD is authored.*

**AC-PD-43 — Shatter: +25% bonus damage on direct hit to Frozen enemy; DoT excluded** *(Integration)*
GIVEN an enemy has Freeze active (root window), WHEN a spell with `DamageSource.DIRECT` and `base_damage = 20`, `base_damage_modifier = 1.0` (test uses modifier=1.0 to isolate the Shatter bonus) hits the enemy, THEN applied damage = `round(20 × 1.0 × 1.25) = 25`. A subsequent `DamageSource.DOT` tick on the same Frozen enemy does NOT include the 25% bonus. Deepfrost-modifier case (modifier=0.80): `round(20 × 0.80 × 1.25) = 20` — Shatter exactly compensates for Deepfrost's low modifier on impact hits, confirming multiplicative application. *(Note: `base_damage_modifier` here refers to the Prana type's modifier from the catalog — `1.0` is used in the primary fixture to isolate the Shatter multiplier from type-specific values; the `0.80` case confirms the formula is `base_damage × base_damage_modifier × 1.25`, not `base_damage × (base_damage_modifier + 0.25)`.)*

**AC-PD-44 — Injury Bloom: extra Regen tick fires immediately on contact damage during Regen** *(Integration)*
GIVEN Fayde has Regen active with **T_remaining = 1.5s** remaining, WHEN Fayde takes `DamageSource.CONTACT` damage (real damage applied, not i-frame blocked), THEN: (1) exactly one additional Regen tick fires **in the same physics frame that `final_damage` is applied to Fayde's HP** — not deferred to the next frame; the tick heals `regen_tick_magnitude × fayde_max_hp` HP; (2) the Regen timer reads **1.5s ± 0.05s** after the extra tick fires — it was not reset to 3.0s.

**AC-PD-44b — Injury Bloom does NOT fire on i-framed CONTACT hits** *(Integration)*
GIVEN Fayde has Regen active AND Fayde is within the `fayde_iframe_duration` (0.5s) window after a previous hit, WHEN a second `DamageSource.CONTACT` hit arrives during the i-frame, THEN no extra `regen_tick_magnitude × fayde_max_hp` Regen tick fires — the i-frame absorbed the hit and Fayde's HP did not change. The Regen timer is unaffected.

**AC-PD-44c — Injury Bloom does NOT fire on DamageSource.DIRECT hits to Fayde** *(Integration)*
GIVEN Fayde has Regen active, WHEN Fayde takes `DamageSource.DIRECT` damage (e.g., a ranged spell impact), THEN no extra Regen tick fires — Injury Bloom triggers only on `DamageSource.CONTACT`, not all incoming damage types.

---

*Revision (round 4) 2026-05-29: B-A resolved (Shatter formula explicit in Rule 7 + AC-PD-43 Deepfrost modifier test case added); B-B resolved (Integration tags added to AC-PD-24/25/30); R-1 (Stun rejection visual added to Rule 8 table); R-2 (Contagion × burn_duration interaction warning added to Tuning Knobs); R-3 (Deepfrost self-Shatter edge case added); R-4 (AC-PD-40 ownership note corrected). Verdict upgraded to APPROVED.*

*Full review (round 3): `game-designer`, `systems-designer`, `qa-lead`, `godot-gdscript-specialist`, `creative-director` consulted (2026-05-26). 49 criteria (AC-PD-04c added for reference-type isolation; AC-PD-27 numeric timer assertion added; AC-PD-33b T_remaining constrained; AC-PD-41 parameterized for deepening_doubt_extension/cap; AC-PD-43 type_modifier renamed to base_damage_modifier; AC-PD-44 frame-precision and regen_tick_magnitude parameter added). Prior round 2 items resolved: assert() → push_error() Autoload guard; integer-multiple enforcement assert spec added; Deepening Doubt cap formula derived from blind_duration; Follow-Through formula explicitly multiplicative; Burn cap safe-range labels clarified; Injury Bloom uses regen_tick_magnitude; Contagion fixed-2.0s rationale documented; deepening_doubt_extension added as tuning knob; entities.yaml stun_duration hotfixed to 0.8s; .tres enum serialization verification gate added.*

## Known Design Tensions

These risks are documented so downstream system authors inherit the awareness rather than re-discovering them.

| Tension | Impact | Resolution Owner |
|---------|--------|-----------------|
| **Voidblue (Blind) viability depends on enemy attack frequency.** Against slow or non-attacking enemies, Blind expires unused and Voidblue reduces to a 0.90 modifier only — worse than Stormgold (1.15, guaranteed interrupt). | Encounter design must include enough fast-attacking enemies to make Blind consistently useful. Without this, Voidblue is a dominated choice in many wave compositions. | Wave / Encounter System GDD |
| **Verdant is structurally weak without an enemy archetype that requires sustain.** 6% HP regen rarely justifies trading a grid slot for pure offense unless the encounter creates attrition pressure (long waves, DoT enemies, chip damage loops). | Encounter design must define at least one wave archetype where healing-per-second matters more than peak damage output. | Wave / Encounter System GDD |
| **Deepfrost + Ashfire is the implied dominant two-type pairing** (root + DoT). If no encounter type punishes this combination, it becomes generically optimal, reducing run-to-run variety and undermining Pillar 1. | Combination Resolution should acknowledge this pairing and either provide diminishing returns or create enemy types that resist it. | Combination Resolution GDD, Boss Encounter GDD |
| **Pillar 2 depth ("Power is Earned Through Understanding") is partially deferred.** The second-layer conditional behaviors (Core Rule 7) add a depth gradient at the per-type level. Emergent combination depth depends on Combination Resolution and Elemental Affiliation & Weakness — neither designed yet. If those systems' interaction spaces are shallow, the pillar's full promise is not delivered. | Combination Resolution GDD is load-bearing for upper-tier Pillar 2 depth. | Combination Resolution GDD |
| **Verdant viability requires a specific encounter archetype.** At nominal tuning, Verdant has negative expected HP value against the Charger (6 HP healed vs. ~10 HP expected exposure from extended kill time). Verdant is viable only when cumulative encounter chip damage exceeds approximately **15 HP per 10-second window** — sustained attrition, not burst. Without this encounter archetype, Verdant is a trap pick in most wave compositions. | Encounter design must include at least one wave archetype that creates meaningful attrition pressure. If Combination Resolution combo bonuses for Verdant are insufficient to close the gap, Verdant's modifier or regen magnitude must be revisited. | Wave / Encounter System GDD, Combination Resolution GDD |
| **Ashfire dominant-strategy risk — pre-implementation gate — RESOLVED 2026-05-31.** ~~The Status Effects implementation sprint is blocked on this decision.~~ **Gate closed:** Charger (RUSHER/gap-closer, highest-threat FP unit) affiliation changed from Fire/Ashfire → Ice/Deepfrost. Charger is a natural anti-Ashfire archetype: Burn DoT is wasted against a gap-closer that reaches Fayde in <2s; Deepfrost Freeze lockdown and Stormgold Stun are strategically superior. All-Ashfire is no longer the discovered optimal in the FP arena. Verdant remains a FP gap (no enemy target), but only 1 of 5 types lacks coverage. Status Effects sprint now unblocked. | **RESOLVED** — Wave / Encounter System GDD updated 2026-05-31 |

## Open Questions

| # | Question | Owner | Priority | Notes |
|---|----------|-------|----------|-------|
| 1 | **Blind RNG model**: Is the 50% miss chance per-attack using a seeded or unseeded RNG? Seeded enables deterministic replay and makes AC-PD-18 a proper unit test; unseeded requires a statistical range test that will fail ~0.2% per CI run. **Recommendation: seeded RNG** — also provides replay consistency across runs. If seeded, flag to `technical-director` as a potential ADR (seeded RNG becomes a project-wide convention). | Lead programmer | Resolve before implementation sprint | AC-PD-18 is classified Advisory until this decision is made |
| 2 | **Boss status immunity** — **RESOLVED (deferred with gate)**: Boss status immunity rules are deferred to the Boss Encounter GDD. However, this is now a **hard pre-implementation gate for Status Effects**: Status Effects must NOT implement boss-specific immunity rules until Boss Encounter GDD specifies them. Provisional assumption: bosses are susceptible to all 5 statuses at full effect until the Boss Encounter GDD overrides this. The Status Effects GDD must include an explicit placeholder section for boss immunity rules and must be revisited when Boss Encounter GDD is authored. | Game designer | Resolve at Boss Encounter GDD authoring | Status Effects implementation may proceed with provisional full-susceptibility; must be revisited at Boss Encounter design |
| 3 | **Multiple same-type Prana in one grid**: Can a player place Ashfire in two or more grid slots simultaneously? If yes, does doubling up on a type stack the modifier, apply the status twice, or produce a different combo effect? Prana Data does not forbid this; Combination Resolution must define the rule. | Game designer | Resolve in Combination Resolution GDD | Flag for Combination Resolution GDD authoring |
