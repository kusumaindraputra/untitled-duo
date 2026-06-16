# Architecture Review Report

> **Date:** 2026-05-29
> **Engine:** Godot 4.6 (Compatibility renderer, OpenGL 3.3 / D3D12 Windows)
> **Reviewer:** /architecture-review (full mode) + godot-specialist consultation
> **GDDs Reviewed:** 14 (all First Playable + MVP systems)
> **ADRs Reviewed:** 10 (ADR-0001–0010; 8 Accepted, 2 Proposed)
> **TR Registry:** Populated — 105 requirements (first run)

---

## Coverage Summary

| Status | Count | % |
|--------|-------|---|
| ✅ Covered — ADR exists and explicitly addresses | 49 | 47% |
| ⚠️ Partial — ADR partially covers or mentions in passing | 17 | 16% |
| ❌ Gap — no ADR addresses this requirement | 39 | 37% |
| **Total requirements** | **105** | **100%** |

The 8 Accepted ADRs form a sound foundation. Gaps cluster in three areas: the Audio System (Autoload #5, no ADR at all), the StatusEffectsManager public API (conflicting definitions in architecture.md vs the GDD), and the PranaGrid dual-input model (HIGH RISK with Godot 4.6 dual-focus breaking change).

---

## Traceability Matrix (condensed)

Full TR-ID list in `docs/architecture/tr-registry.yaml`. Summary by system:

| System | GDD | TRs | Covered | Partial | Gap |
|--------|-----|-----|---------|---------|-----|
| Game State & Scene Flow | game-state-scene-flow.md | 8 | 4 | 3 | 1 |
| Prana Data | prana-data.md | 7 | 5 | 0 | 2 |
| Enemy Data | enemy-data.md | 4 | 3 | 1 | 0 |
| Health & Damage | health-damage.md | 12 | 12 | 0 | 0 |
| Player Controller | player-controller.md | 9 | 3 | 3 | 3 |
| Prana Grid | prana-grid.md | 6 | 2 | 2 | 2 |
| Combination Resolution | combination-resolution.md | 6 | 1 | 2 | 3 |
| Spell Casting & Effects | spell-casting-effects.md | 8 | 5 | 1 | 2 |
| Status Effects | status-effects.md | 9 | 2 | 1 | 6 |
| Enemy AI | enemy-ai.md | 9 | 3 | 3 | 3 |
| Wave / Encounter System | wave-encounter-system.md | 5 | 2 | 0 | 3 |
| Combat HUD | combat-hud.md | 6 | 2 | 0 | 4 |
| Run Management | run-management.md | 4 | 3 | 0 | 1 |
| Audio System | audio-system.md | 12 | 1 | 1 | 10 |

### Coverage Gaps by Priority

**Tier 1 — Blocking (resolve before any implementation sprint)**

| TR ID | Requirement | Suggested ADR |
|-------|-------------|---------------|
| TR-SE-003 | apply_status() 4-arg API — conflicts with architecture.md 3-arg definition | /architecture-decision "StatusEffectsManager Public API Contract" |
| TR-SE-004 | check_and_apply_shatter() — not in architecture.md at all | (same ADR) |
| TR-SE-005 | has_status() — architecture.md shows is_frozen()/is_blinded() instead | (same ADR) |
| TR-PG-001 | PranaGrid dual-input: Godot 4.6 dual-focus requires custom _selected_slot_index + Control overlay, NOT grab_focus() | /architecture-decision "PranaGrid Dual-Input Focus Model (Godot 4.6)" |

**Tier 2 — High Priority (required before Audio/Status/Enemy sprints)**

| TR ID | Requirement | Suggested ADR |
|-------|-------------|---------------|
| TR-AS-001–012 | Audio System: 4-bus, pool, crossfade, stinger, process modes — no ADR for any of these | /architecture-decision "AudioSystem Implementation Contract" |
| TR-SC-003 | PhysicsDirectSpaceState2D.intersect_ray() for spell targeting — no ADR (confirmed correct API by specialist) | /architecture-decision "Spell Targeting and Collision Layer Architecture" |
| TR-SE-006/007 + TR-EAI-007 | Enemy AI must expose apply_speed_modifier() and apply_stun() for SEM | /architecture-decision "Enemy AI Status Effect Interface Contract" |

**Tier 3 — Medium Priority (feature layer, defer to sprint)**

TR-GSF-005 (re-entrancy guard), TR-CR-001 (data-driven Resources), TR-CR-003 (SpellEffect schema), TR-WES-002/004/005, TR-EAI-002/006

**Tier 4 — Low Priority (implementation details)**

TR-PC-005/008/009, TR-PD-006/007, TR-CH-003–006, TR-RM-002

---

## Cross-ADR Conflicts

### 🔴 CONFLICT 1: StatusEffectsManager API — architecture.md vs Status Effects GDD

**architecture.md (API Boundaries section) states:**
```
StatusEffectsManager.is_frozen(target: Node) -> bool
StatusEffectsManager.is_blinded(target: Node) -> bool
```

**Status Effects GDD defines:**
```
apply_status(target, status_type, duration, spell_base_damage = 0.0)  # 4-arg API
has_status(target: Node, status_type: GameEnums.BaseStatus) -> bool
check_and_apply_shatter(target: Node, base_damage: float) -> float
```

**Impact:** Implementation will break — either architecture.md is wrong or the GDD is wrong. SC&E Formula 3 Step 5 already references `check_and_apply_shatter()`. The GDD API is functionally more complete and correct.

**Resolution:**
1. Update architecture.md API Boundaries to match the Status Effects GDD
2. Write ADR-0011: StatusEffectsManager Public API Contract

---

### 🟠 CONFLICT 2: apply_status() argument count — SC&E GDD vs Status Effects GDD

**SC&E GDD Rule 8** calls `apply_status(target, status_id, effective_duration)` — 3 args
**Status Effects GDD** defines 4-arg form with `spell_base_damage = 0.0` default
**Status Effects GDD** flags this explicitly: *"SC&E Rule 8 must be updated to pass effective_base as 4th argument for Burn applications"*

**Impact:** Burn DoT will deal 0 damage per tick if SC&E doesn't pass spell_base_damage. The conflict is flagged in the GDD but not resolved in any ADR.

**Resolution:** SC&E GDD must be updated to call `apply_status(target, BURN, effective_duration, effective_base)` before StatusEffectsManager implementation begins.

---

### 🟠 CONFLICT 3: GameEnums BaseStatus — missing CHILL and STAGGER

**ADR-0006 formally defines:**
```
enum BaseStatus { BURN = 0, BLIND = 1, STUN = 2, FREEZE = 3, REGENERATE = 4 }
```

**Status Effects GDD requires** STATUS_CHILL (value 5) and STATUS_STAGGER (value 6). Neither exists in the ADR.

**Impact:** Any compilation using these values fails at the GameEnums lookup. The Status Effects GDD explicitly flags this: *"⚠️ GameEnums update required."*

**Engine specialist confirms:** Safe to append with explicit integer assignments (`CHILL = 5, STAGGER = 6`). No existing .tres files will be affected. GDScript `match` statements may need updating — add to code review checklist.

**Resolution:** Revise ADR-0006 or write addendum adding CHILL = 5, STAGGER = 6 to BaseStatus.

---

### 🟡 CONFLICT 4: ADR-0009 and ADR-0010 are Proposed, not Accepted

Per `docs/CLAUDE.md`: *"Stories referencing a Proposed ADR are auto-blocked."*

**ADR-0009** (SC&E Stat Broker — Proposed) blocks:
- Any StatusEffectsManager or H&D story that queries stat bonuses via get_stat_bonus()
- Covers TR-SC-005, TR-CR-006

**ADR-0010** (Player Group Convention — Proposed) blocks:
- Any EnemyAI, SpellCastingEffects, or H&D story using group-based target discrimination
- Covers TR-PC-006, TR-EAI-005, TR-EAI-008

**Resolution:** Accept both ADRs before any implementation story creation.

---

## ADR Dependency Order (Topological Sort)

No dependency cycles detected.

```
Foundation (no dependencies):
  1. ADR-0001: Isometric View
  2. ADR-0006: GameEnums Pure Container

Core (requires Foundation):
  3. ADR-0002: Autoload Architecture (foundational to all remaining)
  4. ADR-0008: PranaCatalog Immutability (requires ADR-0002)
  5. ADR-0003: Signal-Driven Architecture (requires ADR-0002)
  6. ADR-0004: Float Accumulator Timer (requires ADR-0002)
  7. ADR-0005: Persistent HUD Sub-Scene Swap (requires ADR-0002)
  8. ADR-0007: HealthAndDamage Singleton (requires ADR-0002, ADR-0003)

Feature (requires all Core Accepted):
  9. ADR-0009: SC&E Wave-Scoped Stat Broker ⚠️ PROPOSED — accept before implementation
 10. ADR-0010: Player Group Convention       ⚠️ PROPOSED — accept before implementation
```

**Unresolved dependency warnings:**
- ADR-0009 is Proposed: any story referencing `get_stat_bonus()` is auto-blocked
- ADR-0010 is Proposed: any story using `"player"` / `"enemy"` group lookup is auto-blocked

---

## Engine Compatibility Audit

### Verified Correct ✅

| ADR | API / Pattern | Specialist Verdict |
|-----|---------------|-------------------|
| ADR-0001 | TileMapLayer + TILE_SHAPE_ISOMETRIC | CONFIRM — supported in 4.6 Compatibility |
| ADR-0001 | Node2D.y_sort_enabled | CONFIRM — replaces deprecated YSort node |
| ADR-0002 | PackedScene.instantiate() | CONFIRM — deprecated instance() correctly avoided |
| ADR-0003 | Callable signal connections | CONFIRM — string-based connections correctly avoided |
| ADR-0004 | PROCESS_MODE_PAUSABLE halts _process() | CONFIRM — unchanged since 4.0; propagates immediately |
| ADR-0005 | await get_tree().process_frame | CONFIRM — correct idiom for queue_free() propagation |
| ADR-0006 | .tres enum serializes as integer | CONFIRM — explicit integer assignments are CRITICAL, not optional |
| ADR-0008 | duplicate_deep() isolation | CONFIRM — scalar props independent; AudioStream/Texture2D shared by RID (correct) |
| TR-SC-003 | PhysicsDirectSpaceState2D.intersect_ray() | CONFIRM — correct 2D ray API; 2D physics unchanged in 4.6 |
| ADR-0008 | push_error() not assert() for guards | CONFIRM — assert() stripped from Godot 4.6 release exports |

### Engine Risks — Unresolved

| Risk | ADR | Severity | Detail |
|------|-----|----------|--------|
| TileMapLayer isometric unverified | ADR-0001 | **HIGH** | QQ-01 open — must verify against Godot 4.6 editor before IsometricRoom implementation sprint |
| .tres enum verification not yet done | ADR-0006 | **MEDIUM** | Create throwaway Resource, save as .tres, inspect in text editor — must do before any .tres files authored |
| duplicate_deep() isolation not yet tested | ADR-0008 | **MEDIUM** | Run AC-0008-01/02 before PranaCatalog implementation |
| PranaGrid dual-focus — Godot 4.6 breaking change | (no ADR) | **MEDIUM-HIGH** | See GDD Revision Flag below |

### Engine Specialist Additional Findings

**ADR-0001 — Y-sort pivot caveat:**
Specialist confirms: Y-sort on a 48×48px boss sprite requires the sprite origin/pivot to sit at the character's **feet**, not the visual center. A center-pivoted boss will sort by its visual midpoint and appear above entities it should be behind. This is an art-spec enforcement requirement, not an engine limitation. Add to art bible before boss sprite production begins.

**ADR-0005 — SceneManager re-entry gap:**
Specialist identifies: if `change_room()` is called twice in the same frame while the `await get_tree().process_frame` is pending, the second call finds `_sub_scene_container.get_child_count() == 0` and may instantiate a second scene on top. Add a `_transitioning: bool` guard flag to block re-entry during the await window.

**ADR-0006 — BaseStatus CHILL + STAGGER:**
Specialist confirms: appending `CHILL = 5, STAGGER = 6` with explicit integer assignments will not affect any existing .tres files. GDScript `match` statements with exhaustive arms won't warn — add exhaustive-match check to code review checklist.

**PranaGrid dual-focus mitigation (specialist recommendation):**
For gamepad mode, drive slot selection via a separate `_selected_slot_index: int` variable, not via `grab_focus()`. Render the gamepad cursor as a custom overlay (Sprite2D or StyleBox override). In mouse mode, ignore `grab_focus()` entirely. This separates the two input models cleanly and avoids Godot 4.6 dual-focus ambiguity.

**General project.godot tip:**
Enable text-based project.godot format (Project Settings → Editor → Version Control → Use Text-Based Project Settings) for human-readable Autoload registration order diffs in git.

---

## GDD Revision Flags (Architecture → Design Feedback)

| GDD | Assumption | Reality (from engine-reference / ADR) | Action |
|-----|-----------|---------------------------------------|--------|
| prana-grid.md | Mouse drag and gamepad d-pad navigation can be implemented on the same Control node without special dual-focus handling | Godot 4.6 dual-focus breaking change: mouse/touch focus and keyboard/gamepad focus are now separate systems; mixing them on the same node requires custom cursor management | Revise PranaGrid GDD interaction model to specify: gamepad uses _selected_slot_index variable + Control overlay overlay, NOT grab_focus() |

No other GDD revision flags found — all other GDD design assumptions are consistent with verified engine behavior.

---

## Architecture Document Coverage (Phase 6)

`docs/architecture/architecture.md` vs `design/gdd/systems-index.md`:

- ✅ All 14 First Playable/MVP systems appear in architecture layers
- ✅ All 10 Autoloads positioned correctly
- ✅ Data flow scenarios cover all critical paths
- ✅ No orphaned architecture (all architecture modules have corresponding GDDs)
- ❌ architecture.md API Boundaries list `is_frozen()` + `is_blinded()` for StatusEffectsManager but GDD defines different API (Conflict 1)

**Systems-index vs GDD status discrepancy:**
The systems-index.md (last updated 2026-05-26) marks all 11 systems as "Approved" but several GDD file headers show:
- Spell Casting & Effects: **"In Review"** (not Approved)
- Status Effects: **"In Review"** (not Approved)
- Player Controller: **"In Revision"** (not Approved)
- Enemy Data: **"In Design"** (not Approved)

GDD file headers are authoritative. The systems-index is stale and should be updated.

---

## Verdict: ⚠️ CONCERNS

The 8 Accepted ADRs form a sound, conflict-free foundation at the Foundation and Core layers. Signal-driven communication, Autoload order, float accumulator timers, and HUD persistence are all correctly specified and engine-verified.

**Pre-gate checklist items that are blocking `/gate-check pre-production`:**

| Item | Status |
|------|--------|
| ADR-0009 Accepted | ❌ Proposed |
| ADR-0010 Accepted | ❌ Proposed |
| StatusEffectsManager API conflict resolved | ❌ Open |
| GameEnums BaseStatus CHILL/STAGGER added | ❌ Open |
| Audio System ADR written | ❌ Missing |
| PranaGrid dual-input ADR written | ❌ Missing |
| tests/unit/ directory | ❌ Missing — run /test-setup |
| tests/integration/ directory | ❌ Missing — run /test-setup |
| .github/workflows/tests.yml | ❌ Missing — run /test-setup |
| design/ux/interaction-patterns.md | ❌ Missing — run /ux-design |
| design/accessibility-requirements.md | ❌ Missing — run /ux-design |

---

## Required ADRs (Priority Order)

| Priority | Action | Unblocks |
|----------|--------|---------|
| 1 | **Accept ADR-0009** | H&D, SEM, SC&E stories using stat bonuses |
| 2 | **Accept ADR-0010** | EnemyAI, SC&E, H&D stories using group lookup |
| 3 | Write ADR: "StatusEffectsManager Public API Contract" | Resolves Conflicts 1 + 2; enables SEM implementation |
| 4 | Write ADR: "AudioSystem Implementation Contract" | 10 uncovered TRs on foundational Autoload #5 |
| 5 | Write ADR: "PranaGrid Dual-Input Focus Model (Godot 4.6)" | HIGH RISK engine change; QQ-02 resolution |
| 6 | Revise ADR-0006: add CHILL=5, STAGGER=6 to BaseStatus | Compilation blocker for SEM/SC&E code |
| 7 | Write ADR: "Spell Targeting and Collision Layer Architecture" | SC&E implementation clarity |
| 8 | Write ADR: "Enemy AI Status Effect Interface Contract" | SEM → EnemyAI interface (apply_speed_modifier, apply_stun) |

---

## Handoff

### Immediate actions (top 3 by impact)

1. **Accept ADR-0009 and ADR-0010** — zero new work required; just change status from Proposed to Accepted after review
2. **Write ADR-0011: StatusEffectsManager Public API Contract** — resolves the most dangerous conflict (Burn DoT would silently deal 0 damage)  
3. **Run `/test-setup`** — required before gate-check regardless of ADR status

### Pre-gate checklist

```
❌ tests/unit/           → run /test-setup
❌ tests/integration/    → run /test-setup
❌ .github/workflows/    → run /test-setup
❌ design/ux/interaction-patterns.md  → run /ux-design
❌ design/accessibility-requirements.md → run /ux-design
```

All 5 pre-gate items are ❌. **`/gate-check pre-production` is not yet available.**

Run `/test-setup` and `/ux-design` first, then accept ADR-0009/0010 and write missing ADRs, then re-run `/architecture-review` to verify coverage improves before attempting the gate check.

---

*Report generated by /architecture-review full — 2026-05-29*  
*Engine specialist: godot-specialist (Godot 4.6)*
*TR registry: docs/architecture/tr-registry.yaml (105 requirements, first population)*
