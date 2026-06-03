# Story 004: Death Sequencing and Instance ID Guard

> **Epic**: Enemy Instance
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: ~3h
> **Manifest Version**: 2026-05-30
> **Last Updated**: 2026-05-31

## Context

**GDD**: `design/gdd/enemy-ai.md`
**Requirement**: `TR-EAI-004`

**ADR Governing Implementation**: ADR-0007: HealthAndDamage Singleton
**ADR Decision Summary**: `enemy_killed(instance_id, type_id, prana_affiliation)` is the death trigger signal emitted by H&D. Enemy Instance listens and matches `instance_id` to self. Must use `queue_free()` ONLY (never `free()`) to preserve the one-frame node-lifetime guarantee for Prana Drop / Loot.

**Secondary ADR**: ADR-0003 (signal connection in `_ready()`)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `queue_free()` vs `free()` distinction is critical — `queue_free()` defers to end-of-frame. `AnimationPlayer.animation_finished` signal stable.

**Control Manifest Rules (Core layer)**:
- Required: `queue_free()` only for enemy node cleanup — NEVER `free()`.
- Required: Scene nodes disconnect from Autoload signals in `_exit_tree()`.
- Forbidden: Never call `free()` on enemy node — use `queue_free()` only.

---

## Acceptance Criteria

- [ ] **AC-EAI-15** — GIVEN enemy alive in CHASING with `_contact_timer` running, WHEN `enemy_killed` fires with matching `instance_id`, THEN in the SAME frame: `_state == DEAD`, `velocity == Vector2.ZERO`, `_contact_timer == 0`, `$HitArea.monitoring == false`. All four hold simultaneously.
- [ ] **AC-EAI-16** — GIVEN enemy transitions to DEAD, WHEN death handler runs, THEN `$AnimationPlayer.is_playing() == true` AND `$AnimationPlayer.get_current_animation() == "death"`.
- [ ] **AC-EAI-17** — GIVEN "death" animation is playing, WHEN `animation_finished("death")` fires, THEN `queue_free()` called — verified by confirming `is_instance_valid(enemy)` returns `true` WITHIN the signal handler (node alive at animation_finished moment; freed only at frame end).
- [ ] **AC-EAI-29** — GIVEN `AnimationPlayer` has NO "death" animation, WHEN enemy is killed, THEN a fallback one-shot timer fires `queue_free()` within `BASE_DEATH_DURATION` seconds. Enemy does not persist indefinitely.
- [ ] **AC-EAI-28** — GIVEN enemies A and B alive in COMBAT_PHASE, WHEN `enemy_killed` fires with B's `instance_id`, THEN A's `_state == CHASING`, A's velocity unchanged, no animation starts on A.

---

## Implementation Notes

**Death handler (connected in `_ready()`, already stubbed in Story 001):**
```gdscript
const BASE_DEATH_DURATION: float = 0.7

func _on_enemy_killed(instance_id: int, _type_id: int,
                      _prana_affiliation: GameEnums.DamageClass) -> void:
    # AC-EAI-28: instance ID guard
    if instance_id != get_instance_id():
        return

    # AC-EAI-15: simultaneous state changes
    _state = EnemyState.DEAD
    velocity = Vector2.ZERO
    _contact_timer = 0.0
    _fayde_in_contact = false
    $HitArea.monitoring = false

    # AC-EAI-16: play death animation
    if $AnimationPlayer.has_animation(&"death"):
        $AnimationPlayer.play(&"death")
        $AnimationPlayer.animation_finished.connect(
            _on_death_animation_finished, CONNECT_ONE_SHOT)
    else:
        # AC-EAI-29: fallback — no animation asset yet
        _start_death_fallback_timer()

func _on_death_animation_finished(_anim_name: StringName) -> void:
    queue_free()  # AC-EAI-17: queue_free only, never free()

func _start_death_fallback_timer() -> void:
    # Float accumulator fallback (ADR-0004: no Timer nodes)
    # Use a one-shot implementation tracking _death_timer in _physics_process
    _death_fallback_active = true
    _death_fallback_timer = BASE_DEATH_DURATION
```

**Fallback timer in `_physics_process` (add guard for DEAD state):**
```gdscript
var _death_fallback_active: bool = false
var _death_fallback_timer: float = 0.0

func _physics_process(delta: float) -> void:
    # ... existing guards ...
    if _death_fallback_active:
        _death_fallback_timer -= delta
        if _death_fallback_timer <= 0.0:
            queue_free()
        return
    # ... movement and contact code ...
```

**Note on AC-EAI-17 test**: `queue_free()` defers node removal to end of frame. Within `_on_death_animation_finished`, the node is still valid. Assert `is_instance_valid(enemy)` returns `true` INSIDE a connected signal handler that fires synchronously. After `process_frame` yields, the node will be gone. This test requires `await get_tree().process_frame` + subsequent `is_instance_valid` check.

**Performance**: fallback timer is a one-shot branch — active only for a single `BASE_DEATH_DURATION` window per enemy death, then `queue_free()`'d. Negligible ongoing cost; no per-frame allocations.

**Note on AC-EAI-20**: The dead-target guard (apply_damage called on a DEAD enemy) is tested in **H&D Story 005**, not here. EnemyInstance does not need to retest H&D's internal guard — it only ensures `$HitArea.monitoring = false` prevents new body_entered signals (AC-EAI-15).

---

## Out of Scope

- Story 001: Signal connection setup (already wired in `_ready()`)
- Story 003: `_contact_timer` reset (death handler sets to 0 — this story extends that)
- H&D Story 005: AC-EAI-20 dead-target guard (verified by H&D, not Enemy Instance)

---

## QA Test Cases

**AC-EAI-15 — Simultaneous state changes on kill**
- Given: Enemy alive; `_contact_timer = 0.15`; `$HitArea.monitoring = true`; H&D mock that emits `enemy_killed`
- When: `_on_enemy_killed(enemy.get_instance_id(), type_id, prana_affiliation)` called directly
- Then: All four simultaneously: `_state == DEAD`, `velocity == Vector2.ZERO`, `_contact_timer == 0`, `$HitArea.monitoring == false`

**AC-EAI-16 — death animation starts**
- Given: Enemy has AnimationPlayer with "death" animation; enemy transitions to DEAD
- When: `_on_enemy_killed(...)` called
- Then: `$AnimationPlayer.is_playing() == true`; `$AnimationPlayer.get_current_animation() == "death"`
- Note: May need AnimationPlayer in scene tree (`add_child`) for is_playing() to work headless

**AC-EAI-17 — queue_free called after animation**
- Given: Enemy in DEAD state; "death" animation playing
- When: `animation_finished` signal fired with `"death"` arg; check `is_instance_valid(enemy)` IN the handler
- Then: `is_instance_valid(enemy) == true` inside handler; after `await process_frame`, node is freed
- Implementation: Connect a test spy to `animation_finished` before the death handler

**AC-EAI-29 — Fallback timer when no animation**
- Given: Enemy AnimationPlayer has NO "death" animation; enemy killed
- When: `_on_enemy_killed(...)` called; `_physics_process(delta)` driven for `BASE_DEATH_DURATION * 60 + 1` frames
- Then: Enemy node is freed (confirm via `is_instance_valid` post-frames)

**AC-EAI-28 — Instance ID guard protects other enemies**
- Given: Enemies A (ID=100) and B (ID=200) in CHASING state; A's velocity = Vector2(80, 0)
- When: `_on_enemy_killed(200, ...)` called on enemy A's handler
- Then: A's `_state == CHASING`; A's velocity unchanged; A's AnimationPlayer not playing "death"

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/enemy-instance/death_sequencing_test.gd` — must pass headless
*(Note: Visual/Feel aspects of death animation (frames, timing) tested in Story 006)*

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (signal connections), Story 003 (contact timer var exists)
- Unlocks: Story 005 (integration tests require full death lifecycle)

---

## Completion Notes
**Completed**: 2026-06-03
**Criteria**: 5/5 passing
**Deviations**: ADVISORY — `BASE_DEATH_DURATION = 0.7` hardcoded const; logged to docs/tech-debt-register.md (EnemyStats migration)
**Test Evidence**: Integration — `tests/unit/enemy-instance/death_sequencing_test.gd` — 6/6 PASSED (GdUnit4 v6.1.3, Godot 4.6.2)
**Code Review**: Complete — CHANGES REQUIRED → DEAD-state guard + FRAMES_TO_DIE fix + suggestions → 33/33 PASSED
