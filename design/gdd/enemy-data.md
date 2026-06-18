# Enemy Data

> **Status**: Approved (2026-06-16)
> **Author**: Kusuma Putra + Claude Code Game Studios
> **Last Updated**: 2026-06-16 (GDD-B4: PROVISIONAL tag removed — H&D GDD now Approved; drop values remain provisional pending Prana Drop/Loot GDD)
> **Implements Pillar**: Pillar 2 (Power is Earned Through Understanding), Pillar 4 (Depth Over Breadth)

## Overview

Enemy Data is the canonical data layer that defines all enemy types in The Last Cipher. It holds the intrinsic, immutable properties of each enemy type — name, archetype class, elemental affiliation, base stats (HP, movement speed, attack damage), Prana drop reference, sprite dimensions, and wave threat value — as read-only definitions that every other system treats as ground truth. No consuming system may define its own enemy type properties or alias type names; all enemy identity originates here.

The four primary consumers are: **Enemy AI** (archetype routing for behavior tree selection), **Elemental Affiliation & Weakness** (`prana_affiliation` as the lookup key for damage multiplier calculation), **Wave / Encounter System** (threat value and spawn weight for wave composition), and **Prana Drop / Loot** (`drop_prana_type` and `drop_rate` for post-kill loot).

At MVP scope, Enemy Data defines exactly three enemy types: Drifter, Charger, and Cluster. A stub definition for the Warped Warden boss is included at Vertical Slice scope and will ship `inactive` at MVP. The data structure must accommodate future enemy types without modifying existing IDs — all existing IDs are stable; new entries are always appended.

Targeting shape, movement logic, aggro radius, and attack patterns are explicitly excluded: behavior is owned by Enemy AI. The elemental weakness multiplier table is owned by Elemental Affiliation & Weakness — Enemy Data declares only which element an enemy *is*, not what defeats it.

## Player Fantasy

Enemy Data is infrastructure the player never sees directly. Its fantasy is experienced one layer up: the moment a player enters Preparation Phase, sees a Charger and a Cluster positioned in the arena, and shifts their grid arrangement without thinking — because they have internalized what those archetypes do and which Prana they're weak to.

The design goal of this system is *legible threat*. A well-designed enemy catalog should become transparent to an experienced player: the archetype names, affiliation colors, and movement patterns should collapse into pure recognition after a few runs. Pillar 2 ("Power is Earned Through Understanding") lives here at the data level — every property in this catalog should be discoverable through play, not tooltips.

Players do not engage with Enemy Data as a system. They engage with enemy types as threats. This system succeeds when players describe their counter-strategy in enemy terms: *"The Cluster wave needed Stormgold center — interrupt the swarm before it closes in."* The catalog made that sentence possible.

*`creative-director` not consulted — lean mode. Review manually before production.*

## Detailed Design

### Core Rules

1. **Immutability**: All enemy type definitions are immutable at runtime. The catalog is loaded once at game startup and held read-only for the session. No system modifies an enemy definition during gameplay.

2. **Properties of each enemy type definition:**

   | Property | Type | Description |
   |----------|------|-------------|
   | `id` | int (enum) | Machine-readable identifier. Used for all code lookups, comparisons, and serialization. Never reassigned. |
   | `name` | String | Canonical display name for UI, Wave Peek, and debug output. |
   | `archetype` | enum (`EnemyArchetype`) | Behavioral class — routes Enemy AI to the correct behavior tree. See enum definition below. |
   | `prana_affiliation` | enum (`DamageClass`) / null | Elemental identity used by Elemental Affiliation & Weakness for damage multiplier lookup. `null` = no affiliation (boss, future special types). |
   | `base_hp` | int | Starting health pool. Read by Health & Damage on spawn. *Provisional — finalize after Health & Damage GDD.* |
   | `base_damage` | float | Damage dealt per attack to Fayde. Read by Health & Damage on hit. *Provisional — finalize after Health & Damage GDD.* |
   | `base_move_speed` | float | Movement speed in pixels/second (base state). Enemy AI reads this; status effects from Prana Data (e.g., Freeze slow) apply as multipliers to this value. *Provisional.* |
   | `drop_prana_type` | int (PranaType ID) / null | Which Prana type this enemy drops on death. Read by Prana Drop / Loot. `null` = no drop (boss handled separately). |
   | `drop_rate` | float / null | Drop probability 0.0–1.0. `null` for boss. *Provisional — finalize after Prana Drop / Loot GDD.* |
   | `wave_threat_value` | int / null | Threat budget cost for wave composition. Read by Wave / Encounter System. `null` = not spawnable via wave budgeting (boss only). |
   | `sprite_size` | Vector2i | Sprite dimensions in pixels (locked by art bible). |
   | `status` | enum (`EnemyStatus`) | `active` = in MVP gameplay; `vs_scope` = defined, ships inactive at MVP; `inactive` = deprecated. |

   **`EnemyArchetype` enum:**

   | Constant | Behavior Intent |
   |----------|----------------|
   | `SEEKER` | Pursues Fayde at base move speed; melee attack on contact. Standard enemy. |
   | `RUSHER` | Moves slowly; telegraphs a directional charge (high damage if it connects, dodgeable with wind-up read). Burst attacker. |
   | `SWARMER` | Moves in formation with other Swarmer units; individually weak; dangerous in groups. Wave / Encounter System should spawn these in sets of 3–5. |
   | `BOSS` | Special encounter; behavior defined in Boss Encounter GDD. Enemy Data provides base stats only. |

   **`EnemyStatus` enum:** `active` | `vs_scope` | `inactive`

3. **Identification by ID**: All systems identify enemy types by their `id` (integer) in data structures and serialization. No system compares enemy types by string name.

4. **Behavior exclusion**: Aggro radius, pathfinding logic, state machine transitions, attack animation frames, and patrol paths are NOT in Enemy Data — they belong to Enemy AI. Enemy Data declares *what* an enemy is; Enemy AI declares *how* it acts.

5. **Boss stub at VS scope**: The Warped Warden definition is included in the catalog with `status = vs_scope`. It is loaded at startup but no game system spawns a `vs_scope` entry — the Wave / Encounter System filters these out. Its definition ensures that when Boss Encounter GDD is designed, it can reference a stable enemy ID.

6. **Catalog extensibility**: New entries are always appended. Existing IDs are never reassigned or removed; deprecated entries use `status = inactive`.

7. **Provisional flag**: Base stat values (`base_hp`, `base_damage`, `base_move_speed`) are confirmed — Health & Damage GDD is Approved (2026-06-16). Drop values (`drop_rate`, `drop_prana_type`) remain provisional until the **Prana Drop / Loot GDD** is authored (Vertical Slice scope).

---

**The MVP Enemy Catalog (3 active + 1 boss stub):**

| ID | Name | Archetype | Prana Affiliation | `base_hp` | `base_damage` | `base_move_speed` | `drop_prana_type` | `drop_rate` | `wave_threat_value` | Sprite Size | Status |
|----|------|-----------|-------------------|-----------|---------------|-------------------|-------------------|-------------|---------------------|-------------|--------|
| 0 | **Drifter** | Seeker | Shadow (Voidblue) | 20 | 8.0 | 80 px/s | Voidblue (ID 1) | *0.50* | 1 | 16×16 px | active |
| 1 | **Charger** | Rusher | Ice (Deepfrost) | 35 | 20.0 | 50 px/s (base) | Deepfrost (ID 3) | *0.40* | 2 | 12×20 px | active |
| 2 | **Cluster** | Swarmer | Lightning (Stormgold) | 12 | 4.0 | 70 px/s | Stormgold (ID 2) | *0.60* | 1 | 24×24 px | active |
| 3 | **Warped Warden** | Boss | null | 500 | 25.0 | 40 px/s | null | null | null | 48×48 px | vs_scope |

*Drop values (`drop_rate`, `drop_prana_type`) remain provisional — subject to revision after Prana Drop / Loot GDD is authored. Base stat values are confirmed.*

---

### States and Transitions

Enemy Data has no runtime states. It is a static catalog — nothing transitions.

**VS note:** The `status` field is a catalog management property, not a runtime state. It is read once at startup to filter which entries are active.

---

### Interactions with Other Systems

| Consuming System | What it reads | Interface |
|----------------|--------------|-----------|
| **Enemy AI** | `id`, `archetype`, `base_hp`, `base_damage`, `base_move_speed` | Full type definition lookup by ID at spawn; `archetype` routes to behavior tree |
| **Elemental Affiliation & Weakness** | `id`, `prana_affiliation` | `prana_affiliation` is the lookup key for the weakness multiplier table; `null` affiliation → 1.0× multiplier for all incoming Prana types |
| **Wave / Encounter System** | `id`, `wave_threat_value`, `status` | Wave budgeting uses `wave_threat_value`; only `active` entries are spawnable |
| **Prana Drop / Loot** | `id`, `drop_prana_type`, `drop_rate` | Drop logic reads these fields per enemy type; `null` drop fields = no drop event |
| **Health & Damage** | `base_hp`, `base_damage` | Uses these as initial values at spawn; subsequent damage tracked by Health & Damage's own state |

*Specialist agents not consulted — lean mode. Review manually before production.*

## Formulas

> **Ownership note:** Base stat values (`base_hp`, `base_damage`, `base_move_speed`) are confirmed — Health & Damage GDD is Approved (2026-06-16). Drop values (`drop_rate`) remain provisional pending Prana Drop / Loot GDD (VS scope).

### Cross-System Formula: Effective Move Speed Under Slow

Enemy Data's `base_move_speed` is modified by status effects applied by Prana casts. The effective speed formula is:

`effective_move_speed = base_move_speed × max(0, 1 - slow_percentage)`

**Variables:**
| Variable | Symbol | Type | Source | Description |
|----------|--------|------|--------|-------------|
| Base movement speed | `base_move_speed` | float (px/s) | Enemy Data (this GDD) | Intrinsic speed from the enemy catalog |
| Applied slow fraction | `slow_percentage` | float (0.0–1.0) | Status Effects GDD (provisional: Prana Data) | 0.0 = no slow; 0.50 = Deepfrost Freeze slow |

**Output Range:** 0 to `base_move_speed`

**Example — Drifter under Freeze:**
`effective_move_speed = 80 × max(0, 1 - 0.50) = 80 × 0.50 = 40 px/s`

**Example — Charger under Freeze:**
`effective_move_speed = 50 × max(0, 1 - 0.50) = 50 × 0.50 = 25 px/s`

*Ownership: This formula is implemented by Status Effects (System #7). Enemy Data provides `base_move_speed`; the formula logic lives in Status Effects.*

---

### Provisional Stat Ratios (Balance Reference)

These are not formulas — they are ratio targets to preserve during Health & Damage GDD design:

| Enemy | `base_hp` | Relative HP | `base_damage` | Relative Damage |
|-------|-----------|-------------|---------------|-----------------|
| Drifter | *20* | 1× (baseline) | *8.0* | 1× (baseline) |
| Charger | *35* | 1.75× | *20.0* | 2.5× |
| Cluster | *12* | 0.60× | *4.0* | 0.5× |
| Warped Warden *(VS)* | *500* | 25× | *25.0* | 3.1× |

**Design intent:** Charger is the high-burst threat (hits hard, dies slower than Drifter). Cluster is individually fragile (dies fast, hits soft). The health gap between Cluster and boss should feel dramatic.

`base_damage` is specified in Health & Damage GDD. All italicized values will be reconciled when that GDD is complete.

## Edge Cases

**1. `null` field received by a consuming system**

`drop_prana_type`, `drop_rate`, and `wave_threat_value` are legitimately `null` for the Warped Warden boss. Consuming systems must explicitly check for `null` before using these values — a null drop field means no drop event occurs; a null threat value means the entry is not spawnable via wave budgeting. Treating `null` as `0` is a bug: a `wave_threat_value` of `0` would imply the entry is free to spawn, which is incorrect.

**2. `vs_scope` enemy spawned by accident**

If Wave / Encounter System fails to filter `vs_scope` entries and spawns a Warped Warden during MVP gameplay, the result is undefined (no Boss Encounter GDD exists at MVP). The filter must be applied at wave population time, not at spawn time. The Warped Warden's entry existing in the catalog is not a spawn authorization.

**3. Lookup of an `inactive` entry**

If a consuming system requests an entry whose `status` is `inactive`, the catalog returns the definition but the requesting system must treat it as not found for gameplay purposes. `inactive` entries are present for ID stability only — they must never be instantiated or displayed. Systems that enumerate the catalog for gameplay (Wave / Encounter System) must exclude `inactive` entries in the same filter pass as `vs_scope`.

**4. Unknown ID lookup**

If a consuming system requests an ID that does not exist in the catalog (never assigned, or out of range), the catalog returns `null` — not a default entry. The requesting system must handle a `null` return as an error condition. This case should not occur in valid gameplay; an assertion or error log is appropriate.

**5. Cluster spawned below minimum group size**

The Wave / Encounter System note recommends spawning Cluster units in groups of 3–5. If wave budget is too small to spawn 3 Clusters but the composer selects Cluster, it must either:
- (a) increase the spawn count to 3 and accept the budget overage, or
- (b) substitute a different enemy type.

Option (a) is preferred to preserve the archetype's design intent. Wave / Encounter System GDD must specify this override behavior explicitly.

**6. Drifter and Cluster share threat value = 1**

This is intentional, not an error. Threat value is a budget cost, not a ranking. A Drifter and a Cluster occupy the same budget slot but play differently. Wave / Encounter System should not treat equal threat values as interchangeable — spawn selection uses additional heuristics (wave composition variety, archetype mixing). Equal threat = equal cost, not equal gameplay role.

**7. Boss stats used before Health & Damage GDD is finalized**

The Warped Warden's `base_hp` and `base_damage` values are provisional. If Boss Encounter GDD is authored before Health & Damage GDD finalizes these values, Boss Encounter must reference provisional figures from this catalog and flag them as unresolved. The Boss Encounter GDD must not hardcode different stat values — it must read from Enemy Data by ID. Final reconciliation happens when Health & Damage GDD is approved.

## Dependencies

### Systems That Depend on Enemy Data

| System | What it needs from Enemy Data | Bidirectional contract |
|--------|-------------------------------|----------------------|
| **Enemy AI** | Full type definition by ID at spawn; `archetype` routes to behavior tree | Enemy AI must declare Enemy Data as a dependency in its GDD |
| **Elemental Affiliation & Weakness** | `prana_affiliation` per enemy type as the lookup key into the weakness multiplier table | Elemental Affiliation & Weakness must declare Enemy Data as a dependency |
| **Wave / Encounter System** | `wave_threat_value`, `status` — wave composition reads these to select and budget spawns | Wave / Encounter System must declare Enemy Data as a dependency |
| **Prana Drop / Loot** | `drop_prana_type`, `drop_rate` — determines what drops and how often after enemy death | Prana Drop / Loot must declare Enemy Data as a dependency |
| **Health & Damage** | `base_hp`, `base_damage` — initial values at spawn; Health & Damage tracks state from there | Health & Damage must declare Enemy Data as a dependency |

### Enemy Data's Own Dependencies

Enemy Data has **no runtime dependencies**. It is a Foundation layer system — it is loaded at startup from static data and makes no calls into any other system.

*Design-time dependency:* The numeric values in Enemy Data (`base_hp`, `base_damage`, `base_move_speed`) are provisional until Health & Damage GDD establishes the game's damage model. Enemy Data will be revised (values only, not structure) after Health & Damage GDD is approved.

### Soft Coupling — Status Effects

`base_move_speed` is used by Status Effects via the `effective_move_speed` formula (Section D). Status Effects does not import Enemy Data directly — it receives `base_move_speed` as a parameter when an enemy is spawned. This is a data-pass dependency, not a structural one.

## Tuning Knobs

All numeric values in Enemy Data are data-driven — they live in the catalog and can be adjusted without code changes. However, not all values are equal in how they should be tuned.

### Primary Tuning Levers (safe to adjust in playtesting)

| Knob | Current Value | Safe Range | What it affects | What breaks if wrong |
|------|--------------|------------|-----------------|----------------------|
| `wave_threat_value` — Drifter | 1 | 1–3 | Wave composition density; a lower threat = more Drifters per wave | If too low, Drifter waves feel overwhelming; if too high, Drifters appear too rarely |
| `wave_threat_value` — Charger | 2 | 1–4 | Charger frequency relative to budget; Charger is the high-danger unit | If too low, Chargers flood waves and overwhelm; if too high, players rarely face the read-and-dodge challenge |
| `wave_threat_value` — Cluster | 1 | 1–2 | Cluster frequency; shares budget weight with Drifter | If equal to Charger, swarms become rare; keep ≤ Charger value |
| `drop_rate` — Drifter | 0.50 | 0.30–0.70 | Voidblue Prana economy; Drifters are the most common enemy | If too high, Voidblue floods; if too low, players can't build around it |
| `drop_rate` — Charger | 0.40 | 0.25–0.60 | Deepfrost Prana economy; Charger is rarer, so drop rate compensates | If too low, Deepfrost becomes inaccessible without dedicated Charger targeting |
| `drop_rate` — Cluster | 0.60 | 0.40–0.75 | Stormgold Prana economy; high drop rate compensates for low per-unit threat | Stormgold abundance is intentional — Cluster waves are hard to farm |

### Secondary Tuning Levers (provisional — defer to Health & Damage GDD)

| Knob | Current Value | Notes |
|------|--------------|-------|
| `base_hp` — all enemies | *20 / 35 / 12 / 500* | Provisional. Do not tune these independently of the damage model. |
| `base_damage` — all enemies | *8.0 / 20.0 / 4.0 / 25.0* | Provisional. Charger's 2.5× damage multiplier is a design intent, not a final value. |
| `base_move_speed` — all enemies | *80 / 50 / 70 / 40 px/s* | Speed ratios (Drifter fastest, Charger slowest) are intentional. Absolute values may shift. |

### Structural Constraints (not tuning knobs — do not change without GDD revision)

- **Enemy count at MVP:** 3 active types. Adding a 4th requires a GDD revision (new entry, dependency audit).
- **Boss affiliation:** `null`. Changing this changes the entire Elemental Affiliation & Weakness interaction for the boss encounter. Treat as locked until Boss Encounter GDD is authored.
- **Sprite sizes:** Locked by art bible. `sprite_size` is not a tuning knob.
- **ID assignments:** Never reassigned. Appending new IDs at the end is the only valid change.

## Visual/Audio Requirements

Enemy Data is a pure data catalog — it has no direct visual or audio output. Requirements belong to consuming systems:

- **Sprite dimensions**: `sprite_size` values defined here lock the art pipeline. See art bible §3 (sprite standards) and §4 (enemy visual direction). The art team reads these values as authoritative pixel budgets.
- **Affiliation color**: `prana_affiliation` maps to art bible §4.2 Prana colors. Enemy Data declares only which affiliation applies; consuming systems handle color rendering.
- **Animation**: Enemy animation frames and frame timing are owned by Enemy AI, not Enemy Data.
- **Audio**: Enemy sound cues are owned by the Audio System and Enemy AI. Enemy Data declares no audio events.

## UI Requirements

Enemy Data is not directly rendered. UI requirements belong to consuming systems:

- **Debug / editor tooling**: A read-only catalog inspector may be useful during development. This is a tools concern, not a player-facing UI requirement.

## Acceptance Criteria

### Catalog Integrity

**AC-ED-01** — The catalog contains exactly 3 entries with `status = active` at MVP: IDs 0 (Drifter), 1 (Charger), 2 (Cluster). A unit test that enumerates all entries and filters by `active` must return exactly these three IDs.

**AC-ED-02** — The catalog contains exactly 1 entry with `status = vs_scope` at MVP: ID 3 (Warped Warden). A unit test confirms this count.

**AC-ED-03** — No two entries share the same `id`. A unit test that asserts uniqueness across all catalog entries must pass.

**AC-ED-04** — Each entry's `name` matches the canonical name from this GDD: ID 0 = "Drifter", ID 1 = "Charger", ID 2 = "Cluster", ID 3 = "Warped Warden". A unit test verifies all four exact string values.

**AC-ED-05** — Each active entry's `prana_affiliation` matches: Drifter = Shadow/Voidblue, Charger = Ice/Deepfrost, Cluster = Lightning/Stormgold. The Warped Warden's `prana_affiliation` is `null`. Unit test verifies all four.

**AC-ED-06** — Each active entry's `archetype` matches: Drifter = `SEEKER`, Charger = `RUSHER`, Cluster = `SWARMER`, Warped Warden = `BOSS`. Unit test verifies all four.

### Immutability and Load Behavior

**AC-ED-07** — The catalog is loaded once at game startup. Requesting the same entry twice within a session returns identical values. A unit test reads ID 0 twice and asserts equality.

**AC-ED-08** — No system can modify a catalog entry at runtime. Attempt to set any field on a returned entry must either fail silently (value unchanged) or raise an error. Verified by unit test asserting the field value is unchanged after a write attempt.

### Null Handling

**AC-ED-09** — Requesting entry ID 3 (Warped Warden) and reading `wave_threat_value` returns `null`, not `0`. Unit test asserts strict null, not falsy.

**AC-ED-10** — Requesting entry ID 3 and reading `drop_prana_type` returns `null`. Unit test asserts strict null.

**AC-ED-11** — Requesting a non-existent ID (e.g., ID 99) returns `null` from the catalog. Unit test confirms null return, not a default entry.

### Status Filtering

**AC-ED-12** — A catalog query filtered by `status = active` never returns the Warped Warden (ID 3). Unit test asserts ID 3 is absent from filtered results.

**AC-ED-13** — A catalog query filtered by `status = active` never returns any `inactive` entry. Unit test asserts no inactive IDs appear in filtered results.

### Sprite Size

**AC-ED-14** — Each entry's `sprite_size` matches the art bible values: Drifter = 16×16, Charger = 12×20, Cluster = 24×24, Warped Warden = 48×48. Unit test verifies all four.

### Consumer Interface Contracts

**AC-ED-15** — Enemy AI can look up a complete type definition by ID in a single catalog call. Integration test confirms a lookup by ID returns all required fields (id, name, archetype, base_hp, base_damage, base_move_speed) in one call.

**AC-ED-16** — Wave / Encounter System can enumerate all entries where `status = active` AND `wave_threat_value` is not null. Integration test confirms only IDs 0, 1, 2 appear in this query at MVP.

## Open Questions

1. **Deepfrost enemy (FP gap — RESOLVED 2026-05-31):** Charger's affiliation changed from Fire/Ashfire → Ice/Deepfrost to satisfy the anti-Ashfire gate in prana-data.md (≥30% of wave compositions must disincentivize all-Ashfire play). Charger is a gap-closer (Rusher) — Freeze lockdown and Deepfrost 2× bonus are now strategically optimal against the highest-threat FP enemy, rewarding "Power is Earned Through Understanding."

2. **Verdant enemy (FP gap):** No active FP enemy has a Verdant affiliation. Verdant Prana has no 2× target at FP. Verdant's sustain identity (Regen) is still playable but lacks a natural encounter archetype. Encounter design must define an attrition archetype at MVP scope (see prana-data.md open question re: Verdant viability). Verdant is the 1 remaining "trap pick" at FP scope (down from 2 of 5 before this change).

3. **Cluster minimum spawn enforcement:** Edge Case 5 recommends Wave / Encounter System prefer budget overage over underspawning Clusters. This is a heuristic, not a rule. Wave / Encounter System GDD must decide whether this is a hard rule or advisory.

4. **Boss affiliation at Vertical Slice:** If Boss Encounter GDD introduces elemental phases for the Warped Warden, the `null` affiliation will need to become a dynamic value. This requires a catalog extension — either a separate boss phase definition or a new field. Flag for Boss Encounter GDD authoring.

*Specialist agents not consulted — lean mode. Review manually before production.*
