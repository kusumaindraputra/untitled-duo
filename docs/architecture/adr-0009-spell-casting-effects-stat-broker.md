# ADR-0009: SpellCastingEffects Wave-Scoped Stat Broker

## Status
Accepted

## Date
2026-05-29

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (GDScript / Data Ownership) |
| **Knowledge Risk** | LOW — `Dictionary.get()`, `StringName`, direct Autoload method calls all unchanged since Godot 4.0; typed `Dictionary[StringName, float]` syntax requires Godot 4.4+ (post-cutoff), satisfied by project's 4.6 pin |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | `Dictionary[StringName, float]` typed dictionary — added in Godot 4.4 |
| **Verification Required** | None — all runtime APIs (`Dictionary.get()`, `StringName`, class_name Autoload access) are stable since Godot 4.0 |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (Accepted) — SC&E must be registered as Autoload #9; H&D (#6) and SEM (#7) call `get_stat_bonus()` at runtime (not in `_ready()`), so no initialization ordering violation occurs. ADR-0003 (Accepted) — direct method call (Pattern 2) is the approved cross-system communication pattern for return-value queries. |
| **Enables** | StatusEffectsManager MVP implementation (stat-modified DoT and status durations require this interface); Health & Damage heal amplification wiring (VER_HEAL_FLAT, barrier scaling) |
| **Blocks** | StatusEffectsManager MVP story implementation; Health & Damage GDD cross-reference update |
| **Ordering Note** | ADR-0002 and ADR-0003 must both be Accepted before any SpellCastingEffects or StatusEffectsManager implementation story begins. |

## Context

### Problem Statement
After `CombinationResolution.combo_resolved` fires, the wave's `SpellEffect` payload contains `aggregate_stat_bonus: Dictionary[StringName, float]` — the combined stat modifiers for the current wave that affect spell damage, status durations, heal amplification, and barrier HP. Multiple systems need access to these stat values during wave execution:

- **SC&E** itself: reads in the damage chain (Formulas 3, 7, 8) and adjacency effect calculations
- **StatusEffectsManager (MVP)**: reads `FROST_FREEZE_DUR`, `STORM_STUN_DUR`, `VOID_BLIND_DUR`, etc. during DoT tick application
- **HealthAndDamage**: reads `VER_HEAL_FLAT` for heal flat-bonus scaling during the wave

Without a registered owner and interface, each consuming system might independently subscribe to `combo_resolved` and maintain its own `SpellEffect` cache. This creates multiple owners of the wave payload with independent cache-clear obligations on `preparation_started`, and no single authoritative source.

### Constraints
- SC&E is Autoload #9; H&D is #6; SEM is #7. ADR-0002 Rule 3 prohibits calling a higher-registered Autoload during `_ready()`. The stat broker method is called during gameplay execution (damage pipeline, `_process()` DoT tick) — not during `_ready()` — so no ordering violation occurs.
- Godot signals are void-return only (ADR-0003). A stat query requiring a return value must use a direct method call (Pattern 2), not a signal (Pattern 1).
- `aggregate_stat_bonus` is wave-stable: set once from `SpellEffect` on `combo_resolved`, unchanged until `preparation_started`. No locking or version-checking is needed.

### Requirements
- Single owner of the wave's SpellEffect stat payload
- Zero-safe return value when no wave is active (null cache must not crash callers)
- Callers must not subscribe to `combo_resolved` themselves for the purpose of reading stat bonuses
- Interface must be synchronous — callers are inside the damage pipeline or a DoT tick

## Decision

**SpellCastingEffects is the sole wave-scoped stat broker.** It owns `_current_spell_effect: SpellEffect` and exposes one read-only method for stat queries:

```gdscript
## Returns the stat delta for stat_id from the current wave's SpellEffect.
## Returns 0.0 if no SpellEffect is cached (between waves or cache cleared).
## The SpellEffect payload is wave-stable — caching the return value is safe
## for the duration of a single wave.
func get_stat_bonus(stat_id: StringName) -> float:
    if _current_spell_effect == null:
        return 0.0
    return _current_spell_effect.aggregate_stat_bonus.get(stat_id, 0.0)
```

Cache lifecycle:
- **Set** in `_on_combo_resolved(spell_effect: SpellEffect)` — called when `CombinationResolution.combo_resolved` fires
- **Cleared** to `null` in `_on_preparation_started()` — called when `GameStateManager.preparation_started` fires

No other Autoload subscribes to `combo_resolved` for the purpose of caching stat data.

### Architecture Diagram

```
CombinationResolution
        │
        │  combo_resolved(spell_effect)           [Signal — ADR-0003 Pattern 1]
        ▼
SpellCastingEffects  ──owns──▶  _current_spell_effect  ──cleared on preparation_started
        │
        │  get_stat_bonus(stat_id) → float        [Method call — ADR-0003 Pattern 2]
        ├──────────────────────────────────────▶  HealthAndDamage (#6)
        │                                         (heal/barrier scaling: VER_HEAL_FLAT)
        └──────────────────────────────────────▶  StatusEffectsManager (#7)
                                                  (DoT/duration queries at MVP)
```

### Key Interfaces

```gdscript
# ── Public stat broker (SpellCastingEffects Autoload) ────────────────────────
func get_stat_bonus(stat_id: StringName) -> float

# ── Registered stat keys (defined by PranaData GDD / PranaCatalog) ───────────
# Callers use StringName literals: SpellCastingEffects.get_stat_bonus(&"ASH_DMG")

# Flat damage bonuses
&"ASH_DMG"               # Ashfire flat damage added to effective_base
&"FROST_DMG"             # Deepfrost flat damage added to effective_base

# Damage multiplier bonuses
&"FROST_SHATTER_BONUS"   # Added to 1.25 Shatter multiplier (Step 5)
&"STORM_FOLLOW_DMG"      # Added to 1.30 Follow-Through multiplier (Step 6)
&"VOID_DMG_VS_BLIND"     # Added to 1.0 Blind damage bonus (Step 7)
&"ASH_CRIT"              # Crit chance float 0.0–1.0 (Step 8)

# Status duration bonuses (seconds, additive)
&"FROST_FREEZE_DUR"      # Added to Freeze duration formula
&"STORM_STUN_DUR"        # Added to Stun duration formula
&"VOID_BLIND_DUR"        # Added to Blind duration formula
&"VOID_STAGGER_DUR"      # Added to Stagger duration formula
&"ADJ_STATUS_EXT"        # Adjacency status extension bonus (primary target only)

# Utility bonuses
&"STORM_COMBO_SPD"       # Combo continuation window extension (seconds)
&"VER_BARRIER_HP"        # Barrier HP additive bonus
&"VER_HEAL_FLAT"         # Heal flat-HP bonus (applied by SC&E to apply_heal calls)
```

All callers access stat bonuses via `SpellCastingEffects.get_stat_bonus(&"KEY")`. Direct access to `_current_spell_effect.aggregate_stat_bonus` from outside SC&E is forbidden.

## Alternatives Considered

### Alternative B: CombinationResolution as the Stat Broker
- **Description**: CR (Autoload #8) retains the `SpellEffect` post-emission and exposes `get_stat_bonus(stat_id) → float`. SC&E becomes a pure execution system with no internal SpellEffect cache.
- **Pros**: Payload stays with its originator; CR already owns the resolution logic; separation of execution (SC&E) and data (CR) is clean in theory.
- **Cons**: SC&E's damage chain, targeting logic, and non-primary modifier processing all require access to fields on `SpellEffect` beyond just `aggregate_stat_bonus` (e.g., `primary_type`, `primary_tier`, `non_primary_modifiers`, `active_adjacency_effects`). If CR holds the payload, SC&E must call `CombinationResolution.get_spell_effect()` (or equivalent) for every field it accesses throughout the wave. SC&E's runtime dependency on the full SpellEffect payload is unchanged — it simply routes through CR instead of its own cache. The stat broker role is split from SC&E while SC&E's actual data needs are unaffected.
- **Rejection Reason**: Adds one layer of indirection without reducing SC&E's dependency on the SpellEffect. SC&E must cache the payload regardless; making it the single cache owner eliminates the split and gives SC&E direct field access.

### Alternative C: GameStateManager Holds a Stat Reference
- **Description**: GSM (Autoload #3) subscribes to `combo_resolved`, stores `aggregate_stat_bonus`, and exposes `get_current_stat_bonus(stat_id) → float`. Clears the reference on `preparation_started`.
- **Pros**: Stats accessible from the central game state authority; no new interface on SC&E.
- **Cons**: GSM's domain is game state transition management, not spell mechanics or combat data. Placing spell stat data on GSM couples the state machine to combat-specific knowledge. GSM would need to subscribe to CR's `combo_resolved` signal, making the game state machine aware of spell resolution details that are entirely outside its responsibility.
- **Rejection Reason**: Violates separation of concerns. GSM manages transitions; SC&E manages the active wave's spell state.

## Consequences

### Positive
- Single cache owner — `preparation_started` cache clear happens in exactly one place (SC&E's `_on_preparation_started()`); no cascade clear is needed across multiple Autoloads
- Callers never subscribe to `combo_resolved` for data purposes — only SC&E connects to that signal for state management
- `get_stat_bonus()` returns `0.0` on null cache — callers can call it at any phase without null guards at the call site
- Trivially stubbed in GUT: inject a mock SC&E with a fixed dictionary; callers (H&D, SEM) require no real CR or SpellEffect objects in isolated tests

### Negative
- H&D (#6) and SEM (#7) gain a runtime dependency on SC&E (#9). Isolated unit tests for H&D or SEM must stub `SpellCastingEffects.get_stat_bonus()`. The interface is a single method with a single return type — the stub cost is negligible.
- Stat key strings originate from the PranaData GDD and PranaCatalog. If a key name changes upstream, SC&E's interface and all callers must be updated simultaneously.

### Risks
- **Risk**: A future system subscribes to `combo_resolved` to cache its own `SpellEffect` copy, creating two cache owners with independent state.
  **Mitigation**: This ADR registers SC&E as the sole `SpellEffect` cache owner (state_ownership registry entry). `/architecture-review` checks for duplicate state ownership. A new ADR must explicitly supersede this one to change the pattern.
- **Risk**: A caller caches the `get_stat_bonus()` return value across preparation/combat phase boundaries, reading a stale 0.0 after the next `combo_resolved`.
  **Mitigation**: The method doc comment notes that caching is safe only within a single wave (between `combo_resolved` and `preparation_started`). The return value is stable within a wave by design — callers that re-query each use are equally correct.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| spell-casting-effects.md | Rule 3 — SC&E exposes `get_stat_bonus(stat_id: StringName) → float` as the wave-scoped stat broker; Status Effects and H&D query SC&E, not SpellEffect directly | Formalizes Rule 3 as a registered architectural stance with a precise, version-controlled interface contract |
| spell-casting-effects.md | Formula 3 — `aggregate_stat_bonus.get()` in damage chain Steps 1–8 | SC&E reads its own cache directly (internal use); this ADR makes that ownership explicit |
| spell-casting-effects.md | Formula 7 — status durations via `aggregate_stat_bonus.get()` | SC&E-internal reads; ADR enables SEM to use the same method at MVP without holding its own cache |
| spell-casting-effects.md | Formula 8 — `aggregate_stat_bonus.get(&"VER_BARRIER_HP")` for barrier HP | SC&E-internal; this ADR enables H&D to call the same method for heal-side scaling |
| combination-resolution.md | Rule 11c — "SC&E is the single stat broker for the wave. No system reads `aggregate_stat_bonus` directly from SpellEffect outside SC&E." | Elevates the GDD's delivery contract to a registered architectural stance, enforced by registry entry and `/architecture-review` |
| status-effects.md (MVP) | StatusEffectsManager queries spell stat bonuses during DoT tick application | `SpellCastingEffects.get_stat_bonus()` is the approved Pattern 2 call; registered as an interface contract in the architecture registry |

## Performance Implications
- **CPU**: `get_stat_bonus()` is a single null check + `Dictionary.get()` — O(1), nanosecond cost. Called at most ~14 times per attack resolution at maximum stat pool depth.
- **Memory**: No additional memory beyond SC&E's existing `SpellEffect` cache. `aggregate_stat_bonus` has ≤ 14 keys at maximum progression — negligible Dictionary footprint.
- **Load Time**: No impact — `get_stat_bonus()` is a pure runtime query.
- **Network**: N/A

## Migration Plan
New project — no existing code to migrate. This interface is established before any SpellCastingEffects or StatusEffectsManager implementation story begins.

## Validation Criteria
1. **AC-0009-01**: `get_stat_bonus(&"ANY_KEY")` returns `0.0` when `_current_spell_effect == null` — no null reference crash
2. **AC-0009-02**: `get_stat_bonus(&"ASH_DMG")` returns the correct float from a test SpellEffect with `aggregate_stat_bonus = {&"ASH_DMG": 5.0}`
3. **AC-0009-03**: `get_stat_bonus(&"MISSING_KEY")` returns `0.0` for a key not present in `aggregate_stat_bonus`
4. **AC-0009-04**: `_on_preparation_started()` sets `_current_spell_effect` to `null`; subsequent `get_stat_bonus()` calls return `0.0`
5. **AC-0009-05**: No Autoload's `_ready()` subscribes to `CombinationResolution.combo_resolved` for the purpose of caching a `SpellEffect` (code review gate — enforced by registry's state_ownership entry)

## Related Decisions
- [ADR-0002: Autoload Architecture](adr-0002-autoload-architecture.md) — SC&E is Autoload #9; H&D is #6; SEM is #7; registration order constrains when `_ready()` connections are safe
- [ADR-0003: Signal-Driven Architecture](adr-0003-signal-driven-architecture.md) — Pattern 2 (direct method call) governs `get_stat_bonus()`; signals cannot carry return values, so the query must be a method call
- [ADR-0007: HealthAndDamage as Autoload Singleton](adr-0007-health-damage-autoload-singleton.md) — H&D calls `SpellCastingEffects.get_stat_bonus()` for heal and barrier scaling at MVP
- [ADR-0008: PranaCatalog Immutability](adr-0008-prana-catalog-immutability.md) — stat keys in `aggregate_stat_bonus` originate from PranaType resource data managed by PranaCatalog
- [design/gdd/spell-casting-effects.md](../../design/gdd/spell-casting-effects.md) — GDD that defines the stat broker pattern (Rule 3, Formulas 3/7/8)
- [design/gdd/combination-resolution.md](../../design/gdd/combination-resolution.md) — GDD that defines the stat delivery contract (Rule 11c)
