# Deep Audit — Sprint 6 Full Findings
**Date**: 2026-06-16
**Scope**: Entire codebase, Sprint 1 through Sprint 6 (all epics, all GDDs, all tests)
**Method**: 9 specialist agents run in parallel (godot-specialist, gdscript-specialist,
lead-programmer, technical-director, qa-lead, audio-director, performance-analyst,
systems-designer, game-designer)
**Session**: 2026-06-15 → 2026-06-16 (session limit reset mid-run; agents re-spawned)

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| ✅ FIXED | Resolved in this session (commits 6325db6, ad66ac3, 3b7b7eb) |
| 🔴 CRITICAL | Runtime crash risk or silent gameplay-breaking bug |
| 🟡 WARNING | Architectural violation, correctness gap, or test reliability risk |
| 🔵 ADVISORY | Tech debt, maintainability concern, or improvement opportunity |
| 📐 DESIGN | Requires design decision or document update only |
| ⚙️ ADR | Architecture Decision Record gap or violation |
| 🧪 TEST | Test quality or coverage issue |

---

## Part 1 — Code Findings

### 1.1 Runtime Crash Risks (CRITICAL)

| ID | File | Line | Finding | Status |
|----|------|------|---------|--------|
| C-1 | `src/systems/status_effects_manager.gd` | 332 | `(instance.target as Node2D).global_position` — unguarded `as` cast returns null if target is not Node2D; `.global_position` on null crashes on enemy death with active Burn | ✅ FIXED |
| C-2 | `src/ui/combat_hud.gd` | 523 | `PranaCatalog.get_type(_current_primary_type).color` — no null guard; invalid type ID returns null; `.color` on null crashes at start of every chain | ✅ FIXED |
| C-3 | `src/systems/spell_casting_effects.gd` | 346 | `raw *= 2.0` — 2× affinity multiplier has no GDD source. Balance risk: could double-stack with formula multipliers. No crash, but a gameplay correctness issue | 🟡 OPEN |

### 1.2 Architecture Violations (ADR)

| ID | File | Line | ADR | Finding | Status |
|----|------|------|-----|---------|--------|
| AV-1 | `src/systems/combination_resolution.gd` | 484 | ADR-0004 | `SceneTree.create_timer()` used for echo delay — forbidden; must use float accumulator pattern | 🟡 OPEN |
| AV-2 | `src/systems/combination_resolution.gd` | 326 | ADR-0002 | `get_node_or_null("/root/PranaCatalog")` string-path Autoload access — forbidden; must use class name directly | 🟡 OPEN |
| AV-3 | `src/scenes/debug_game_loop.gd` | 26 | ADR-0010 (GSM) | `GameStateManager._active_state = GameEnums.GameState.MAIN_MENU` — direct private state write bypassing state machine transition guard | 🟡 OPEN |
| AV-4 | `src/scenes/main.tscn` | — | ADR-0005 | PranaGrid at root level under `PranaGridLayer` — ADR-0005 requires PranaGrid inside `IsometricRoom.tscn` (`SubSceneContainer` node) | 🟡 OPEN |
| AV-5 | `src/systems/wave_manager.gd` | 107–108 | ADR-0010 (GSM) | Connects to `GameStateManager._on_all_waves_cleared` — private method. Must connect to the public `all_waves_cleared` signal instead | 🟡 OPEN |
| AV-6 | `docs/architecture/adr-0002-autoload-architecture.md` | — | ADR-0002 self | Rule 1 states `class_name` must match Autoload name — this constraint is unachievable in Godot 4.6 (class_name and file name must match, not Autoload name). ADR needs errata | 🔵 OPEN |
| AV-7 | `docs/architecture/adr-0002-autoload-architecture.md` | — | ADR-0002 | Live `project.godot` no longer matches ADR-0002 Autoload order. AudioSystem (#5) absent; SpellVFX at position #9 with no ADR — neither registered in ADR-0002 | 🟡 OPEN |

### 1.3 Logic Gaps

| ID | File | Line | Finding | Status |
|----|------|------|---------|--------|
| W-19 | `src/systems/wave_manager.gd` | 161 | `wave_cleared` signal declared but never emitted before `all_waves_cleared` | ✅ FIXED |
| W-1 | `src/gameplay/player_controller.gd` | 167 | `is_alive()` returns literal `true` regardless of state — latent logic bug; breaks death-state queries from SEM and H&D | 🟡 OPEN |
| W-2 | `src/gameplay/player_controller.gd` | 57 | `audio_system = get_node_or_null("/root/AudioSystem")` always returns null (AudioSystem not registered as Autoload) | 🟡 OPEN |
| W-3 | `src/systems/wave_manager.gd` | 107–108 | No `_exit_tree()` disconnect for `GameStateManager._on_all_waves_cleared` connection | 🔵 OPEN |
| W-4 | `src/ui/prana_grid.gd` | 89 | Unused `"prana_grid"` group registration — group added but never queried | 🔵 OPEN |
| W-5 | `src/ui/combat_hud.gd` | — | `const FAYDE_MAX_HP: int = 100` duplicates `HealthAndDamage.FAYDE_MAX_HP` — single-source violation | 🔵 OPEN |

### 1.4 Performance

| ID | File | Finding | Severity | Status |
|----|------|---------|----------|--------|
| PERF-C1 | `src/ui/spell_vfx.gd` | `ParticleProcessMaterial.new()` + `GPUParticles2D.new()` allocated per spell hit — GPU resource churn. Pre-pool 5 nodes (one per Prana type) instead | 🔴 OPEN — must fix before Feature layer |
| PERF-W1 | `src/systems/status_effects_manager.gd` | `.duplicate()` on every target's status array every `_physics_process` tick — ~600 Array allocations/second at 10 enemies × 3 statuses × 60fps | 🟡 OPEN |
| PERF-OK | `src/gameplay/player_controller.gd` | Float accumulator timer pattern correct (ADR-0004 ✓) | — |
| PERF-OK | `src/systems/status_effects_manager.gd` | All timer decrements use accumulator pattern (ADR-0004 ✓) | — |
| PERF-OK | `src/systems/combination_resolution.gd` | All CR timers except echo delay use accumulator (AV-1 above is the gap) | — |

### 1.5 Code Quality

| ID | File | Line | Finding | Status |
|----|------|------|---------|--------|
| Q-1 | `src/ui/prana_grid.gd` | — | `_create_ui_nodes()` is 138 lines — exceeds 40-line method limit; split into 3 private helpers | 🔵 OPEN |
| Q-2 | `src/ui/prana_grid.gd` | — | `_slot_nodes: Array` untyped — should be `Array[PranaGridSlot]` | 🔵 OPEN |
| Q-3 | `src/gameplay/enemy_instance.gd` | — | `$HitArea` / `$AnimationPlayer` accessed without caching (`@onready` unavailable for programmatic nodes); fine now but will cause N lookups in hot path when movement code lands | 🔵 OPEN |
| Q-4 | `src/ui/spell_vfx.gd` | — | Located in `src/ui/` but is an Autoload — wrong layer per ADR-0002 classification | 🔵 OPEN |
| Q-5 | Various | — | Multiple methods exceed 40-line limit: `player_controller._physics_process()` (~63 lines), `spell_casting_effects._fire_attack()` (~83 lines) | 🔵 OPEN |

### 1.6 Missing ADRs

| ID | System | Finding | Status |
|----|--------|---------|--------|
| ADR-M1 | SpellVFX | No ADR exists for SpellVFX Autoload — particle system architecture, pooling strategy, layer assignment undocumented | 🟡 OPEN — needed before Feature layer |
| ADR-M2 | Spell Targeting | No ADR for spell targeting/cast range decisions | 🟡 OPEN |
| ADR-M3 | Enemy AI (movement) | No ADR for FP enemy movement pattern (SEEKER/RUSHER/SWARMER behavior) | 🟡 OPEN |

### 1.7 Tech Debt Register Gaps

The following constants found in code are NOT in `docs/tech-debt-register.md`:

| Constant | File | Value | Missing Tracker |
|----------|------|-------|-----------------|
| `PRIMARY_T1_MAX`, `ADJ_ECHO_DELAY`, `BASE_ECHO_COUNT` | `combination_resolution.gd` | various | Not logged |
| `CAST_LOCK_DURATION = 0.12` | `spell_casting_effects.gd` | 0.12s | Not logged |
| `ASHFIRE_CAST_LOCK_DURATION = 0.20` | `spell_casting_effects.gd` | 0.20s | Not logged |
| `HEAVY_HIT_THRESHOLD` | `health_and_damage.gd` | — | Not logged |
| `FAYDE_HP_CRITICAL_CAREFUL`, `FAYDE_HP_CRITICAL_DESPERATE` | `health_and_damage.gd` | — | Not logged |
| `FIRST_RUN_DAMAGE_MULTIPLIER` | `health_and_damage.gd` | — | Not logged |
| Hardcoded cast ranges `80.0` / `150.0` | `spell_casting_effects.gd` | 403–404 | Not logged |

---

## Part 2 — GDD / Design Findings

### 2.1 Feature-Layer Gate Blockers (5 items — MUST close before Feature GDDs)

| # | Finding | GDD | Status |
|---|---------|-----|--------|
| GDD-B1 | SC&E status header "In Review" vs systems-index "Approved" — mismatch must resolve | `spell-casting-effects.md` | 🔴 OPEN |
| GDD-B2 | `apply_status` signature mismatch: SC&E calls with 3 args; Status Effects API requires 4 (`spell_base_damage` 4th arg). Silent bug: Burn deals 0 damage per tick without fix | `spell-casting-effects.md` | 🔴 OPEN |
| GDD-B3 | Prana Grid missing from SC&E Dependencies section (SC&E reads `committed_fragments` from Prana Grid directly) | `spell-casting-effects.md` | 🟡 OPEN |
| GDD-B4 | Enemy Data stat values all marked PROVISIONAL; H&D is now COMPLETE — stats must be confirmed and PROVISIONAL tag removed | `enemy-data.md` | 🟡 OPEN |
| GDD-B5 | `GameEnums.BaseStatus` missing `STATUS_CHILL` and `STATUS_STAGGER` — Status Effects GDD references these as stubs | `GameEnums` (code) | 🟡 OPEN |

### 2.2 GDD Status Mismatches (systems-index.md vs file headers)

| GDD | File Header | Index Status | Action |
|-----|-------------|-------------|--------|
| Spell Casting & Effects | In Review | Approved | Resolve: close "In Review" items or revert index |
| Status Effects | In Review | Approved | Resolve: file needs header updated after GDD-B5 fix |
| Enemy Data | In Design | Approved | Resolve: confirm stats, update header |
| Run Management | Designed (pending review) | Approved | Resolve: run `/design-review` to formally close |

### 2.3 Cross-GDD Consistency Gaps

| ID | Finding | Status |
|----|---------|--------|
| X-1 | Charger `prana_affiliation`: entities.yaml said Ashfire; wave-encounter-system GDD (2026-05-31) and enemy-data GDD both say Deepfrost | ✅ FIXED (entities.yaml updated) |
| X-2 | `sfx_fayde_dash` ownership: Audio System Interactions table attributes it to "Game Feel/Juice"; Player Controller GDD claims exclusive ownership. Contradiction must be resolved when Game Feel GDD is authored | 📐 OPEN |
| X-3 | Player Controller GDD does not explicitly close Audio System Open Question 3 (footstep audio dispatch model) | 📐 OPEN |
| X-4 | Combat HUD `spell_hit_element(target, prana_type_id)` signal: required by Rule 7 but not yet in SC&E's signal list | 📐 OPEN — Story-level, not design gate |
| X-5 | Enemy AI GDD does not specify `apply_speed_modifier` / `apply_stun` callee contracts (clamp rules, stacking policy) — required before Status Effects integration stories are written | 📐 OPEN |
| X-6 | SC&E must call `StatusEffectsManager.check_and_apply_shatter()` (not inline the check) per Combination Resolution Rule — flagged in CR GDD text but not tracked | 📐 OPEN — Story-level |

### 2.4 GDD Completeness Verdicts

| GDD | Verdict | Notes |
|-----|---------|-------|
| Prana Data | ✅ COMPLETE | 49 ACs, all testable |
| Prana Grid | ⚠️ MINOR GAP | Section name "Detailed Design" not "Detailed Rules"; layout contract with HUD provisional |
| Combination Resolution | ⚠️ MINOR GAP | SC&E call-site gaps not tracked (see X-6) |
| Spell Casting & Effects | 🔴 INCONSISTENT | GDD-B1/B2/B3 above — blocks Feature layer |
| Player Controller | ⚠️ MINOR GAP | Open Q3 on footstep audio not closed in GDD |
| Health & Damage | ✅ COMPLETE | 33 ACs, 10-step pipeline unambiguous |
| Status Effects | ⚠️ MINOR GAP | GDD-B5 + STATUS_CHILL/STAGGER stub enums needed |
| Enemy AI | ⚠️ MINOR GAP | apply_speed_modifier/apply_stun callee contracts unspecified |
| Enemy Data | 🔴 INCONSISTENT | All stats PROVISIONAL; header "In Design" contradicts index "Approved" |
| Wave Encounter System | ⚠️ MINOR GAP | Open Questions blank section; Visual/Audio deferred |
| Run Management | ⚠️ MINOR GAP | Header "pending review" not formally closed |
| Game State & Scene Flow | ✅ COMPLETE | 19 MVP ACs, all state transitions specified |
| Audio System | ✅ COMPLETE | 35+ ACs, 4-bus architecture, A/B crossfade; implementation-ready |
| Combat HUD | ⚠️ MINOR GAP | SC&E signal contract needed; 3 bidirectional ref updates pending |

---

## Part 3 — Test Findings

### 3.1 Fixed in Session

| ID | File | Finding | Status |
|----|------|---------|--------|
| TC-1 | `tests/unit/status-effects/sem_contagion_shatter_test.gd` | `after_test()` used `queue_free()` on tree-attached `_sem` — signal-on-freed-object race; replaced with `remove_child(_sem)` + `_sem.free()` | ✅ FIXED |
| TC-2 | `tests/integration/enemy-instance/enemy_instance_integration_test.gd` | 4 test functions did not follow `test_[system]_[scenario]_[expected_result]` naming convention | ✅ FIXED |

### 3.2 Already Handled in Code (Not Test Fixes)

| ID | Finding | Status |
|----|---------|--------|
| QA-C1 | `enemy_instance_skeleton_test.gd:207` — `_on_combat_started` + `_physics_process` called without scene tree; risk of `move_and_slide()` crash. Already mitigated by `is_inside_tree()` guard at `enemy_instance.gd:120` with explicit comment | ✅ NO CHANGE NEEDED |

### 3.3 Open Test Gaps

| ID | File | Finding | Status |
|----|------|---------|--------|
| TC-3 | `tests/unit/enemy-instance/*` | Integration test for Combination Resolution → StatusEffectsManager `check_and_apply_shatter()` call chain not covered | 🔵 OPEN |
| TC-4 | Various | `wave_cleared` signal emission now has no unit test verifying it fires before `all_waves_cleared` | 🟡 OPEN — add test for W-19 fix |

### 3.4 QA Evidence Files (all unchecked)

| File | Checks | Status |
|------|--------|--------|
| `production/qa/evidence/prana-grid-gamepad-adr0013.md` | 6/6 unchecked | Requires physical gamepad session |
| `production/qa/evidence/prana-grid-mouse-evidence.md` | 9/9 unchecked | Requires in-editor verification |
| `production/qa/evidence/combat-hud-chain-evidence.md` | 9/9 unchecked | Requires in-editor verification |

---

## Part 4 — Audio System Readiness

**ADR-0012 status**: Implementation-ready. Full spec in `design/gdd/audio-system.md`.

**Zero audio call sites in current codebase** (AudioSystem Autoload not registered — all calls silently no-op via `get_node_or_null`):
- `src/gameplay/player_controller.gd:57` — null reference
- `src/ui/spell_casting_effects.gd` — no audio calls yet
- `src/systems/health_and_damage.gd` — no audio calls yet
- `src/gameplay/enemy_instance.gd` — no audio calls yet
- `src/systems/wave_manager.gd` — no audio calls yet

**Recommended Sprint 7 Audio story breakdown** (7 stories, ~6.5 effort days):

| Story | Description | Est. |
|-------|-------------|------|
| AS-001 | Register AudioSystem Autoload (#5), 4-bus setup, `play_event()` stub | 0.5d |
| AS-002 | Music bus + A/B crossfade (2 AudioStreamPlayer nodes, volume tween) | 1.0d |
| AS-003 | SFX pool (24 slots, round-robin) | 1.0d |
| AS-004 | Ambient bus + A/B crossfade | 0.5d |
| AS-005 | Wire H&D → `sfx_fayde_hit`, `sfx_fayde_death` | 0.5d |
| AS-006 | Wire PlayerController → `sfx_fayde_dash`, `sfx_fayde_footstep` (after Open Q3 resolved) | 0.5d |
| AS-007 | Wire WaveManager → `music_combat_start`, `sfx_wave_complete` | 0.5d |

---

## Part 5 — Sprint 7 Recommendations

### Must Have (gate items — Sprint 7 day 1)

1. **ADR-0013 live gamepad gate** — connect gamepad, fill evidence file (6 mandatory checks)
2. **GDD Feature-layer gate** — close GDD-B1 through GDD-B5 (SC&E + Enemy Data + GameEnums)
3. **Audio System skeleton** — AS-001 + AS-002 + AS-003 (Autoload, 4-bus, SFX pool)
4. **SpellVFX particle pre-pool** — CRITICAL before Feature layer; pre-pool 5 nodes
5. **SpellVFX ADR** — write ADR-0015 before implementing pooling

### Should Have

6. **SC&E ADR-0004 fix** — combination_resolution `create_timer()` → float accumulator
7. **ADR-0005 fix** — move PranaGrid into IsometricRoom.tscn
8. **wave_manager private connection** — connect to public signal (AV-5)
9. **Enemy AI callee contracts** — `apply_speed_modifier`/`apply_stun` spec in enemy-ai.md
10. **Re-validation playtest** (carryover S6-07)
11. **Tech debt constants migration** — remaining hardcoded values to data files

### Nice to Have

12. **Isometric visual pass** — formal decision: schedule or descope to post-Feature-layer
13. **player_controller is_alive()** fix (latent bug, not yet exercised)
14. **ADR-0002 errata** — Godot 4.6 class_name rule correction
15. **TR-PG-001 registry text** — "Sprite2D cursor" → "Control overlay"
16. **SEM duplicate() optimization**

---

## Agents & Findings Source

| Specialist | Primary Findings |
|-----------|-----------------|
| godot-specialist | AV-1, AV-3, AV-4, AV-7 (project.godot drift), ADR-M1 |
| godot-gdscript-specialist | C-1, C-2, W-1 through W-5, Q-1 through Q-5 |
| lead-programmer | W-19, W-1, AV-2, W-5, ADR compliance |
| technical-director | AV-6, AV-7, ADR-M1, ADR-M2, ADR-M3 |
| qa-lead | TC-1, TC-2, QA-C1, TC-3 |
| audio-director | Audio call site gaps, AS-001–AS-007 story breakdown |
| performance-analyst | PERF-C1, PERF-W1, float accumulator audit |
| systems-designer | C-3 (2× affinity), X-1 (Charger affiliation), damage formula |
| game-designer | GDD-B1–B5, X-2–X-6, GDD completeness verdicts, systems-index mismatches |
