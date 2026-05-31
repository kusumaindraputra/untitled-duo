# Story 002: apply_damage() — Core Formula and Dead-Target Guard

> **Epic**: Health & Damage
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: ~3h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/health-damage.md`
**Requirement**: `TR-HD-002`, `TR-HD-005`, `TR-HD-011`

**ADR Governing Implementation**: ADR-0007: HealthAndDamage Singleton
**ADR Decision Summary**: `apply_damage(target, base_damage, element, source)` is the sole damage entry point. Pipeline: i-frame check → elemental multiplier → formula → HP update → signal emission → death check. Dead-target guard at step 2 rejects all calls on targets at 0 HP.

**Secondary ADRs**: ADR-0003 (signal-driven: emit `damage_taken` signal, not a return value), ADR-0010 (player group discrimination via `is_in_group(&"player")`)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `roundi()`, `clampi()`, `is_in_group()` all stable. No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: All damage through `HealthAndDamage.apply_damage(target, base_damage, element, source)` — no direct HP modification.
- Required: Target discrimination via `is_in_group(&"player")` / `is_in_group(&"enemy")`.
- Required: HP stored as `float`; damage numbers emitted as `int` via `roundi()`.
- Forbidden: Never access HP state directly from another system.

---

## Acceptance Criteria

*From GDD `design/gdd/health-damage.md`, scoped to this story:*

- [ ] **AC-HD-01** — Given Fayde at 100 HP, `apply_damage(fayde, 20.0, null, CONTACT)`: `_fayde_current_hp` equals 80.0 and `damage_taken(fayde, 20, 80)` emitted once.
- [ ] **AC-HD-02** — Given enemy `current_hp=35`, `apply_damage(enemy, 20.0, null, CONTACT)` with `damage_multiplier=1.25` (Deepfrost element → Charger 2×): `enemy.current_hp` equals 10.0 (`roundi(25.0)=25`, `35−25=10`).
- [ ] **AC-HD-03** — Given `base_damage=20.0` with `damage_multiplier=0.90`: `final_damage` equals 18 (`roundi(18.0)=18`).
- [ ] **AC-HD-04** — Given target `current_hp=10, max_hp=100`, hit with `base_damage=60.0` (overkill): `current_hp` equals 0 (clamp prevents negative HP).
- [ ] **AC-HD-05** — Given living target, `apply_damage(target, 0.0, null, CONTACT)`: `final_damage=0`; `current_hp` unchanged; `damage_taken` **NOT** emitted.
- [ ] **AC-HD-23** — Given Fayde in DEAD state (`current_hp=0`): `apply_damage(fayde, 20.0, null, CONTACT)` returns immediately; `current_hp` remains 0; no signal emitted; `player_died` not re-emitted.

---

## Implementation Notes

*Derived from ADR-0007 pipeline:*

```gdscript
func apply_damage(target: Node, base_damage: float,
                  element: GameEnums.DamageClass,
                  source: GameEnums.DamageSource) -> void:

    # Step 1 — dead-target guard (TR-HD-005)
    if target.is_in_group(&"player"):
        if _fayde_dead:
            return
    else:
        var id := target.get_instance_id()
        if not _enemy_registry.has(id) or _enemy_registry[id].is_dead:
            return

    # Step 1a — i-frame check (implemented in Story 003; stub as pass-through here)
    # Story 003 adds: if target.is_in_group(&"player") and source == CONTACT and _iframe_active: return

    # Step 1b — elemental multiplier (1.0 if element == null; EA&W system owns non-1.0 values)
    var multiplier: float = 1.0
    # Full multiplier lookup deferred to Elemental Affiliation & Weakness epic
    # For now: pass element through; multiplier stays 1.0 until EA&W is implemented

    # Step 2 — formula (TR-HD-009)
    var raw: float = base_damage * multiplier
    if raw == 0.0:
        return  # AC-HD-05: zero damage — no signal, no HP change
    var final_damage: int = roundi(raw)
    var current_hp: int = roundi(_get_current_hp(target))
    final_damage = clampi(final_damage, 0, current_hp)

    # Step 3 — apply HP
    if target.is_in_group(&"player"):
        _fayde_current_hp -= float(final_damage)
    else:
        _enemy_registry[target.get_instance_id()].current_hp -= float(final_damage)

    # Step 4 — emit signals (Story 005 adds: heavy_hit, player_died, enemy_killed)
    emit_signal("damage_taken", target, final_damage, roundi(_get_current_hp(target)))
    _check_hp_zone_change()  # Story 004 implements zone change logic

    # Step 5 — death check (Story 005 implements)
```

**Note on elemental multiplier**: At FP scope, only the Charger has a non-1.0 multiplier (Ice/Deepfrost = 2.0× per Elemental Affiliation & Weakness). Implement `_get_elemental_multiplier(target, element) -> float` as a stub returning 1.0 for now; the Elemental Affiliation & Weakness epic will replace this stub. Do NOT hardcode the 2× multiplier here.

**`_get_current_hp` helper:**
```gdscript
func _get_current_hp(target: Node) -> float:
    if target.is_in_group(&"player"):
        return _fayde_current_hp
    var id := target.get_instance_id()
    if _enemy_registry.has(id):
        return _enemy_registry[id].current_hp
    return 0.0
```

---

## Out of Scope

- Story 003: I-frame window (step 1a — `_iframe_active` check)
- Story 004: HP zone signal (`_check_hp_zone_change()` stub only in this story)
- Story 005: Death signals (`player_died`, `enemy_killed`), `heavy_hit`, first-run mercy

---

## QA Test Cases

**AC-HD-01 — Neutral CONTACT damage on Fayde**
- Given: `_fayde_current_hp = 100.0`; target in `"player"` group
- When: `apply_damage(fayde, 20.0, null, CONTACT)`
- Then: `_fayde_current_hp == 80.0`; `damage_taken` emitted once with args `(fayde, 20, 80)`
- Edge cases: `final_damage` must be `int` 20 (not `float` 20.0)

**AC-HD-02 — Damage with elemental multiplier (2×)**
- Given: enemy registered with `current_hp=35.0`; `damage_multiplier=2.0` injected via stub
- When: `apply_damage(enemy, 12.5, DEEPFROST, DIRECT)` → `roundi(12.5 × 2.0) = roundi(25.0) = 25`
- Then: enemy `current_hp == 10.0`
- Note: Until EA&W implemented, test by directly setting multiplier in stub or passing pre-multiplied base_damage

**AC-HD-03 — Damage with 0.90 multiplier rounds correctly**
- Given: target at any positive HP
- When: `apply_damage(target, 20.0, null, CONTACT)` with multiplier=0.90 (stub override)
- Then: `final_damage == 18` (not 17 or 19)

**AC-HD-04 — Overkill clamps to 0 HP**
- Given: target `current_hp=10.0, max_hp=100.0`
- When: `apply_damage(target, 60.0, null, CONTACT)` → `final_damage=clamp(60, 0, 10)=10`
- Then: `current_hp == 0.0`; `damage_taken` emitted with `final_damage=10`

**AC-HD-05 — Zero base_damage produces no signal**
- Given: target alive with `current_hp > 0`
- When: `apply_damage(target, 0.0, null, CONTACT)`
- Then: `current_hp` unchanged; `damage_taken` emit count == 0

**AC-HD-23 — Dead-target guard**
- Given: Fayde `_fayde_dead = true`, `current_hp = 0.0`
- When: `apply_damage(fayde, 20.0, null, CONTACT)`
- Then: `current_hp` still 0.0; no signal emitted; method returns without side effects

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/health-damage/apply_damage_pipeline_test.gd` — must pass headless

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (DONE — registry and HP vars must exist)
- Unlocks: Story 003 (i-frame needs apply_damage to arm it), Story 004 (heal/zones use same HP vars), Story 005 (death checks build on this pipeline)
