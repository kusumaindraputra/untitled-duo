# Story 003: FP Damage Formula, Targeting, and Status Stubs

> **Epic**: Spell Casting & Effects
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3 hours
> **Manifest Version**: 2026-06-03
> **Last Updated**: —

## Context

**GDD**: `design/gdd/spell-casting-effects.md`
**Requirement**: `TR-SC-003`, `TR-SC-004`, `TR-SC-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: StatusEffectsManager Public API Contract (primary — SC&E must call check_and_apply_shatter() and apply_status() per this ADR)
**ADR Decision Summary**: SC&E calls `StatusEffectsManager.check_and_apply_shatter(target, base_damage)` before every DIRECT `apply_damage()` call. Status application via `apply_status(target, type, duration, spell_base_damage)` 4-arg signature. At FP scope, SEM's `has_status()` returns false for stubs (FREEZE/STUN/etc. are field-write stubs only per GDD Rule 8).

**Secondary ADRs**: ADR-0009 (aggregate_stat_bonus queries via get_stat_bonus()); ADR-0007 (apply_damage only through HealthAndDamage); ADR-0003 (spell_hit_element is Pattern 1 signal)

**Engine**: Godot 4.6 | **Risk**: LOW — formula math is pure GDScript; targeting abstracted via injectable test seam
**Engine Notes**: PhysicsDirectSpaceState2D.intersect_ray() for real targeting requires running physics world (headless-incompatible). Targeting is injectable via `_override_target: Node = null` test seam. AC-SC-07 and AC-SC-09 are [M] Manual.

**Control Manifest Rules (Core Layer)**:
- Required: All damage through `HealthAndDamage.apply_damage(target, raw_damage, element, source)` — source = DamageSource.DIRECT for SC&E hits
- Required: `StatusEffectsManager.check_and_apply_shatter(target, base_damage)` called before every DIRECT apply_damage (ADR-0011)
- Required: `spell_hit_element(target: Node, prana_type_id: int)` signal emitted per hit
- Required: `_rng: RandomNumberGenerator` injected via `@export` — seeded in test before_each() for deterministic rolls
- Forbidden: Direct HP modification — all damage through H&D
- Forbidden: tier_attack_modifier == 0.0 path must NOT call apply_damage

---

## Acceptance Criteria

*From GDD `design/gdd/spell-casting-effects.md`, scoped to this story:*

- [ ] **AC-SC-08** — No-target cast: `apply_damage` never called; `apply_status` never called; `_combo_index` advances normally
- [ ] **AC-SC-11** — Stormgold Follow-Through suppressed at FP: `_followthrough_window == 0.0` → `apply_damage` called with `round(20 × 1.15 × 1.20) = 28`; no ×1.30 Step 6 bonus
- [ ] **AC-SC-12** — Formula 1: Ashfire T1 neutral = 25: `apply_damage` called with `raw_damage = 25.0` (`round(20 × 1.25 × 1.00)`)
- [ ] **AC-SC-13** — Formula 3 Step 1 type branch: (a) primary_type=0 → `flat_stat_bonus = ASH_DMG`; (b) primary_type=3 → `flat_stat_bonus = FROST_DMG`; (c) primary_type=2 → `flat_stat_bonus = 0.0`. All three must pass
- [ ] **AC-SC-14** — Formula 3 Step 5 Shatter (mock SEM required): Deepfrost T1 vs Frozen target → `apply_damage(round(20 × 0.80 × 1.00 × 1.25) = 20)`. Note: inert in live game at FP (SEM.has_status returns false for field-write stubs)
- [ ] **AC-SC-15** — Formula 3 Step 9 Elemental affiliation: Ashfire T1 vs fire-affiliated enemy → `apply_damage(round(25.0 × 2.0) = 50)`
- [ ] **AC-SC-19** — Formula 7 FP status defaults (field-write stubs): Deepfrost T1, empty aggregate → `target.status_freeze_timer == 2.0`; Stormgold T1, empty aggregate → `target.status_stun_timer == 0.8`
- [ ] **AC-SC-20** — tier_attack_modifier == 0.0 guard: Verdant T2 (SELF, modifier=0.00) → `apply_damage` never called; secondary effect fires only. Deepfrost T3 index 2 (glacial field, modifier=0.00) → `apply_damage` never called
- [ ] **AC-SC-23** — ASH_CRIT applies at `_combo_index == 0` only: guaranteed crit (`_rng` seeded 0.0), first attack includes ×1.50; second attack does NOT
- [ ] **AC-SC-25** — Formula 7 with stat bonuses: `{"FROST_FREEZE_DUR": 0.5}` → `target.status_freeze_timer == 2.5`; `{"STORM_STUN_DUR": 0.4}` → `target.status_stun_timer == 1.2`
- [ ] **AC-SC-26** — `spell_hit_element(target, primary_type_id)` emitted exactly once per hit; NOT emitted on miss (no target)

---

## Implementation Notes

*Derived from ADR-0009, ADR-0011, GDD Rule 7 (damage formula):*

**Injectable test seams** (same Variant injection pattern as PlayerController.audio_system):
```gdscript
@export var _rng: RandomNumberGenerator           ## Injected in tests; auto-created in _ready()
@export var _health_and_damage: Variant = null   ## Set in _ready(); injectable for tests
@export var _status_effects: Variant = null       ## Set in _ready(); injectable for tests
var _override_target: Node = null                 ## Set directly in tests; null = use ray cast
var _fayde_ref: Node = null                       ## Cached in _ready() via player group lookup
```

In `_ready()`, initialize seams:
```gdscript
_rng = RandomNumberGenerator.new()
_health_and_damage = HealthAndDamage
_status_effects = StatusEffectsManager
_fayde_ref = get_tree().get_first_node_in_group(&"player")
```

**ATTACK_DATA constant** (FP inline — migrate to Resource at MVP):
```gdscript
## Attack data per [primary_type][primary_tier][attack_index].
## Keys: "modifier" (tier_attack_modifier), "cast_lock" (per-type override or CAST_LOCK_DURATION)
const ATTACK_DATA: Dictionary = {
    0: {  # Ashfire — base_damage_modifier = 1.25
        1: [{"modifier": 1.00}],
        2: [{"modifier": 1.00}, {"modifier": 1.25}],
        3: [{"modifier": 1.00}, {"modifier": 1.25}, {"modifier": 1.50}],
    },
    1: {  # Voidblue — base_damage_modifier = 0.90
        1: [{"modifier": 1.00}],
        2: [{"modifier": 1.00}, {"modifier": 1.10}],
        3: [{"modifier": 1.00}, {"modifier": 1.10}, {"modifier": 1.30}],
    },
    2: {  # Stormgold — base_damage_modifier = 1.15
        1: [{"modifier": 1.00}],
        2: [{"modifier": 1.00}, {"modifier": 1.20}],
        3: [{"modifier": 1.00}, {"modifier": 1.20}, {"modifier": 1.00}],
    },
    3: {  # Deepfrost — base_damage_modifier = 0.80
        1: [{"modifier": 1.00}],
        2: [{"modifier": 1.00}, {"modifier": 0.80}],
        3: [{"modifier": 1.00}, {"modifier": 0.80}, {"modifier": 0.00}],  # T3 index 2 = glacial field
    },
    4: {  # Verdant — base_damage_modifier = 0.70
        1: [{"modifier": 1.00}],
        2: [{"modifier": 1.00}, {"modifier": 0.00}],  # T2 index 1 = SELF shield pulse
        3: [{"modifier": 1.00}, {"modifier": 0.00}, {"modifier": 1.20}],
    },
}
const BASE_SPELL_DAMAGE: float = 20.0
```

**_fire_attack() — Formula 3 implementation**:
```gdscript
func _fire_attack(attack_index: int) -> void:
    var se: SpellEffect = _current_spell_effect
    var tier: int = se.primary_tier
    var pt: int = se.primary_type

    var attack_entry: Dictionary = ATTACK_DATA[pt][tier][attack_index]
    var tier_mod: float = attack_entry["modifier"]

    # tier_attack_modifier == 0.0 guard: skip damage chain entirely
    if tier_mod == 0.0:
        _fire_secondary_effect(pt, tier, attack_index)
        return

    # Select target (inject _override_target in tests; real ray cast in game)
    var target: Node = _override_target if _override_target != null else _select_primary_target()

    # No-target: combo advances but no damage or status
    if target == null:
        return

    # Step 1 — flat stat bonus (type-conditional)
    var flat_stat: float = 0.0
    if pt == 0:
        flat_stat = se.aggregate_stat_bonus.get(&"ASH_DMG", 0.0)
    elif pt == 3:
        flat_stat = se.aggregate_stat_bonus.get(&"FROST_DMG", 0.0)

    # Step 2
    var eff_base: float = BASE_SPELL_DAMAGE + flat_stat

    # Step 3 — base_damage_modifier (burn_bonus via Ashfire NP — empty at FP)
    var eff_mod: float = clampf(se.base_damage_modifier, 0.0, 1.40)

    # Step 4 — core damage
    var raw: float = eff_base * eff_mod * tier_mod

    # Step 5 — Shatter (ADR-0011): delegates to SEM; inert at FP (has_status returns false for stubs)
    raw = _status_effects.check_and_apply_shatter(target, raw)

    # Step 6 — Follow-Through: always 0.0 at FP (_followthrough_window not set by Enemy AI at FP)
    # _followthrough_window timer omitted at FP — Step 6 never activates

    # Step 7 — Blind bonus: always false at FP (SEM.has_status returns false for stub instances)
    if _status_effects.has_status(target, GameEnums.BaseStatus.BLIND):
        raw *= (1.0 + se.aggregate_stat_bonus.get(&"VOID_DMG_VS_BLIND", 0.0))

    # Step 8 — ASH_CRIT (first chain attack only; any primary type)
    if _combo_index == 1:  # _combo_index already incremented before _fire_attack in _trigger_cast
        var ash_crit: float = se.aggregate_stat_bonus.get(&"ASH_CRIT", 0.0)
        if ash_crit > 0.0 and _rng.randf() < ash_crit:
            raw *= 1.50

    # Step 9 — Elemental affiliation [FP inline — remove at MVP when EA&W implements this]
    var spell_element: GameEnums.DamageClass = PranaCatalog.get_type(pt).damage_class
    if spell_element != GameEnums.DamageClass.NONE and target.get(&"prana_affiliation") == spell_element:
        raw *= 2.0

    # Step 10
    _health_and_damage.apply_damage(target, raw, null, GameEnums.DamageSource.DIRECT)
    spell_hit_element.emit(target, pt)

    # FP status field-write stubs (GDD Rule 8 — field writes only; SEM not wired at FP)
    _apply_fp_status_stubs(target, pt, se)
```

**`_apply_fp_status_stubs()` helper**:
Write `target.status_freeze_timer`, `target.status_stun_timer`, `target.status_burned`, `target.status_blinded_timer` per GDD Rule 8 Formula 7 durations. Use `target.set()` rather than direct field access to avoid GDScript type errors on nodes that don't declare these fields.

**`_select_primary_target()` (physics ray — real game only)**:
Use `get_viewport().get_world_2d().direct_space_state` + `PhysicsRayQueryParameters2D.create()` + `intersect_ray()`. Guard: if `_fayde_ref == null`, re-resolve via player group. Returns `null` if no hit.

**`_fire_secondary_effect()` stub**: for tier_attack_modifier == 0.0 cases (Verdant T2 shield pulse, Deepfrost T3 glacial field) — push_warning for unimplemented at FP; no crash.

**Integration with `_trigger_cast()` from Story 002**: Replace `# Story 003 will implement _fire_attack() here` placeholder with:
```gdscript
var current_index: int = _combo_index - 1  # _combo_index already incremented
_fire_attack(current_index)
```

**Note on _combo_index timing**: `_combo_index` is incremented BEFORE `_fire_attack()` is called. So inside `_fire_attack`, `_combo_index == 1` means this is the first attack (index 0). Adjust Step 8 guard accordingly: crit applies when `_combo_index == 1` (i.e., the just-incremented index after the first press).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- [Story 001]: State machine skeleton, SpellEffect Resource, get_stat_bonus()
- [Story 002]: Cast input gating, float accumulators, cast_hit_started, chain_index_changed
- [Story 004]: Integration test with real Autoloads
- [Future MVP]: Adjacency effects (ADJ_ECHO, ADJ_DOUBLE_HIT, ADJ_BARRIER_HIT), Stormgold T3 fork, real targeting with physics ray, EA&W integration for element param

---

## QA Test Cases

*From qa-plan-sprint-3-2026-06-03.md (S3-08 section). Implement against these.*

**Test file**: `tests/unit/spell-casting-effects/damage_formula_test.gd`

**Test harness**: Inject `_rng`, `_health_and_damage`, `_status_effects` as mocks. Set `_override_target` to a `MockEnemy` node. Add SC&E to tree (`add_child(sce)`) then `set_process(false)` — mirrors SEM pattern.

- **AC-SC-08**: No-target cast — no damage or status
  - Given: SC&E in READY, valid SpellEffect; `_override_target = null` (ray returns null in test)
  - When: `_trigger_cast()` called
  - Then: `apply_damage` never called; `apply_status` never called; `_combo_index == 1`

- **AC-SC-11**: Follow-Through suppressed (Stormgold T2 index 1, `_followthrough_window = 0.0`)
  - Given: Stormgold T2 SpellEffect (base_damage_modifier=1.15, combo_attack_count=2); MockHD spy; `_override_target` = MockEnemy
  - When: cast index 1 fires (`_combo_index = 2` pre-fire; attack_index = 1)
  - Then: `apply_damage` called with `raw ≈ 28.0` (`round(20 × 1.15 × 1.20) = 28`); no ×1.30 multiplier

- **AC-SC-12**: Ashfire T1 neutral = 25
  - Given: Ashfire T1 SpellEffect (primary_type=0, primary_tier=1, base_damage_modifier=1.25); empty aggregate; MockHD
  - When: cast fires at index 0
  - Then: `apply_damage` called with `raw_damage ≈ 25.0`

- **AC-SC-13**: Step 1 type branch (three sub-cases):
  - (a) primary_type=0, aggregate={"ASH_DMG": 5.0} → effective_base = 25.0
  - (b) primary_type=3, aggregate={"FROST_DMG": 3.0} → effective_base = 23.0
  - (c) primary_type=2, aggregate={"ASH_DMG": 5.0, "FROST_DMG": 3.0} → effective_base = 20.0 (Stormgold gets 0.0 bonus)

- **AC-SC-14**: Shatter (mock SEM returns has_status=true)
  - Given: Deepfrost T1 SpellEffect; MockSEM where `check_and_apply_shatter(target, raw)` returns `raw * 1.25`; empty aggregate
  - When: cast fires
  - Then: `apply_damage` called with `raw ≈ 20.0` (`round(20 × 0.80 × 1.00 × 1.25)`)

- **AC-SC-15**: Elemental affiliation 2×
  - Given: Ashfire T1 SpellEffect; MockEnemy with `prana_affiliation = DamageClass.FIRE`
  - When: cast fires
  - Then: `apply_damage` called with `raw ≈ 50.0` (`round(25.0 × 2.0)`)

- **AC-SC-19**: FP status stubs — default durations
  - Given: Deepfrost T1, empty aggregate; MockEnemy target
  - When: cast fires
  - Then: `target.status_freeze_timer == 2.0`
  - Given: Stormgold T1, empty aggregate
  - When: cast fires
  - Then: `target.status_stun_timer == 0.8`

- **AC-SC-20**: tier_attack_modifier == 0.0 suppresses apply_damage
  - Given (a): Verdant T2 SpellEffect (combo_attack_count=2); `_combo_index` set to advance to index 1 (modifier=0.00)
  - When: attack at index 1 fires
  - Then: `apply_damage` never called
  - Given (b): Deepfrost T3 SpellEffect; cast at index 2 (modifier=0.00)
  - When: attack at index 2 fires
  - Then: `apply_damage` never called

- **AC-SC-23**: ASH_CRIT guard — index 0 only
  - Given: aggregate={"ASH_CRIT": 1.0}; `_rng.randf()` always returns 0.0 (seeded); Stormgold T2 (combo_attack_count=2)
  - When: first cast (attack_index=0) fires
  - Then: `apply_damage` raw_damage includes ×1.50
  - When: second cast (attack_index=1) fires (after lock expires)
  - Then: `apply_damage` raw_damage does NOT include ×1.50

- **AC-SC-25**: Formula 7 with stat bonuses
  - Given: Deepfrost T1, aggregate={"FROST_FREEZE_DUR": 0.5}
  - When: cast fires
  - Then: `target.status_freeze_timer == 2.5`
  - Given: Stormgold T1, aggregate={"STORM_STUN_DUR": 0.4}
  - When: cast fires
  - Then: `target.status_stun_timer == 1.2`

- **AC-SC-26**: spell_hit_element emitted once per hit; not on miss
  - Given: Ashfire T1 SpellEffect; spy on `spell_hit_element`; MockEnemy target
  - When: cast fires
  - Then: spy count == 1; call args == (target, 0)
  - Given: `_override_target = null` (no target)
  - When: cast fires
  - Then: spy count == 0

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/spell-casting-effects/damage_formula_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (SpellEffect Resource, _current_spell_effect, state machine); Story 002 DONE (_trigger_cast() hook exists, float accumulators in place)
- Unlocks: Story 004 (integration test requires full damage chain working end-to-end)
