# Architecture Traceability Index
Last Updated: 2026-05-29
Engine: Godot 4.6 (Compatibility renderer)

## Coverage Summary
- Total requirements: 105
- Covered: 49 (47%)
- Partial: 17 (16%)
- Gaps: 39 (37%)

## Full Matrix

| TR ID | GDD | System | Requirement (abbreviated) | ADR Coverage | Status |
|-------|-----|--------|---------------------------|--------------|--------|
| TR-GSF-001 | game-state-scene-flow.md | Game State | GameStateManager as Autoload singleton position 3 | ADR-0002 | ✅ |
| TR-GSF-002 | game-state-scene-flow.md | Game State | get_tree().paused — PAUSABLE/ALWAYS process modes | ADR-0002 + ADR-0004 | ✅ |
| TR-GSF-003 | game-state-scene-flow.md | Game State | await get_tree().process_frame in scene transitions | ADR-0005 | ✅ |
| TR-GSF-004 | game-state-scene-flow.md | Game State | Persistent HUD via CanvasLayer on permanent main.tscn | ADR-0005 | ✅ |
| TR-GSF-005 | game-state-scene-flow.md | Game State | Re-entrancy guard on _request_transition() | — | ❌ |
| TR-GSF-006 | game-state-scene-flow.md | Game State | call_deferred() for boss_defeated → RUN_SUMMARY | ADR-0007 (partial) | ⚠️ |
| TR-GSF-007 | game-state-scene-flow.md | Game State | preparation_started payload: wave_index, waves_remaining | ADR-0003 (partial) | ⚠️ |
| TR-GSF-008 | game-state-scene-flow.md | Game State | death_started first signal in COMBAT→DEATH_SCREEN | ADR-0003 (partial) | ⚠️ |
| TR-PD-001 | prana-data.md | Prana Data | PranaCatalog accessible at _ready() — Autoload #1 | ADR-0002 | ✅ |
| TR-PD-002 | prana-data.md | Prana Data | get_type() returns duplicate_deep() copy | ADR-0008 | ✅ |
| TR-PD-003 | prana-data.md | Prana Data | Explicit integer assignments on GameEnums | ADR-0006 | ✅ |
| TR-PD-004 | prana-data.md | Prana Data | GameEnums extends RefCounted, NOT Autoload | ADR-0006 | ✅ |
| TR-PD-005 | prana-data.md | Prana Data | push_error() not assert() for _initialized guard | ADR-0008 | ✅ |
| TR-PD-006 | prana-data.md | Prana Data | Burn tick constraint assert in StatusEffectsManager | — | ❌ |
| TR-PD-007 | prana-data.md | Prana Data | @export var (not const) for PranaType properties | — | ❌ |
| TR-ED-001 | enemy-data.md | Enemy Data | EnemyCatalog accessible at _ready() — Autoload #2 | ADR-0002 | ✅ |
| TR-ED-002 | enemy-data.md | Enemy Data | EnemyCatalog immutability via duplicate_deep() | ADR-0008 | ✅ |
| TR-ED-003 | enemy-data.md | Enemy Data | EnemyType.scene: PackedScene field for spawning | ADR-0007 | ✅ |
| TR-ED-004 | enemy-data.md | Enemy Data | prana_affiliation uses DamageClass.NONE not null | ADR-0006 + ADR-0007 (partial) | ⚠️ |
| TR-HD-001 | health-damage.md | Health & Damage | Single apply_damage() entry point | ADR-0007 | ✅ |
| TR-HD-002 | health-damage.md | Health & Damage | Single apply_heal() entry point | ADR-0007 | ✅ |
| TR-HD-003 | health-damage.md | Health & Damage | roundi() for final_damage rounding | ADR-0007 | ✅ |
| TR-HD-004 | health-damage.md | Health & Damage | I-frame 0.5s via float accumulator | ADR-0007 + ADR-0004 | ✅ |
| TR-HD-005 | health-damage.md | Health & Damage | enemy_killed signal with full payload | ADR-0007 | ✅ |
| TR-HD-006 | health-damage.md | Health & Damage | player_hp_zone_changed on zone boundary | ADR-0007 | ✅ |
| TR-HD-007 | health-damage.md | Health & Damage | heavy_hit signal at threshold | ADR-0007 | ✅ |
| TR-HD-008 | health-damage.md | Health & Damage | force_end_iframe_window() test seam | ADR-0007 | ✅ |
| TR-HD-009 | health-damage.md | Health & Damage | instance_from_id() + is_instance_valid() guard | ADR-0007 | ✅ |
| TR-HD-010 | health-damage.md | Health & Damage | Step 1a: is_in_group("player") + is_invincible() | ADR-0007 | ✅ |
| TR-HD-011 | health-damage.md | Health & Damage | PlayerController via group lookup | ADR-0007 | ✅ |
| TR-HD-012 | health-damage.md | Health & Damage | run_started: HP reset + zone reset + signal | ADR-0007 | ✅ |
| TR-PC-001 | player-controller.md | Player Controller | CharacterBody2D.move_and_slide() screen-space | ADR-0001 (partial) | ⚠️ |
| TR-PC-002 | player-controller.md | Player Controller | Float accumulators for dash/footstep timers | ADR-0004 | ✅ |
| TR-PC-003 | player-controller.md | Player Controller | PROCESS_MODE_PAUSABLE | ADR-0004 | ✅ |
| TR-PC-004 | player-controller.md | Player Controller | _is_invincible flag + is_invincible() method | ADR-0007 | ✅ |
| TR-PC-005 | player-controller.md | Player Controller | Footstep shuffle-bag 3 variants | — | ❌ |
| TR-PC-006 | player-controller.md | Player Controller | "player" group membership | ADR-0010 PROPOSED | ⚠️ |
| TR-PC-007 | player-controller.md | Player Controller | cast_hit_started → CAST_LOCKED sub-state | ADR-0003 (partial) | ⚠️ |
| TR-PC-008 | player-controller.md | Player Controller | get_facing_direction() 8-dir snap | — | ❌ |
| TR-PC-009 | player-controller.md | Player Controller | class_name PlayerController for GUT | — | ❌ |
| TR-PG-001 | prana-grid.md | Prana Grid | Dual-input: mouse drag + gamepad cursor (HIGH RISK) | — | ❌ |
| TR-PG-002 | prana-grid.md | Prana Grid | committed_fragments Array[PranaFragment] length 9 | ADR-0003 (partial) | ⚠️ |
| TR-PG-003 | prana-grid.md | Prana Grid | Phase-gate states driven by GSM signals | ADR-0003 | ✅ |
| TR-PG-004 | prana-grid.md | Prana Grid | Centre slot validation + arrangement_confirmed | — | ❌ |
| TR-PG-005 | prana-grid.md | Prana Grid | PROCESS_MODE_PAUSABLE preserves state | ADR-0004 | ✅ |
| TR-PG-006 | prana-grid.md | Prana Grid | is_loadout_valid() for GSM transition validation | ADR-0003 (partial) | ⚠️ |
| TR-CR-001 | combination-resolution.md | Combination Resolution | Data-driven Resource files | — | ❌ |
| TR-CR-002 | combination-resolution.md | Combination Resolution | combo_resolved signal once per wave | ADR-0003 | ✅ |
| TR-CR-003 | combination-resolution.md | Combination Resolution | SpellEffect typed payload schema | — | ❌ |
| TR-CR-004 | combination-resolution.md | Combination Resolution | Cache cleared on preparation_started | ADR-0003 (partial) | ⚠️ |
| TR-CR-005 | combination-resolution.md | Combination Resolution | Cardinal neighbor bounds checking | — | ❌ |
| TR-CR-006 | combination-resolution.md | Combination Resolution | No direct aggregate_stat_bonus reads outside SC&E | ADR-0009 PROPOSED | ⚠️ |
| TR-SC-001 | spell-casting-effects.md | Spell Casting | SC&E Autoload #9, 4 states | ADR-0002 | ✅ |
| TR-SC-002 | spell-casting-effects.md | Spell Casting | Float accumulators for all timing | ADR-0004 | ✅ |
| TR-SC-003 | spell-casting-effects.md | Spell Casting | PhysicsDirectSpaceState2D.intersect_ray() | — | ❌ |
| TR-SC-004 | spell-casting-effects.md | Spell Casting | _rng @export for deterministic tests | — | ❌ |
| TR-SC-005 | spell-casting-effects.md | Spell Casting | get_stat_bonus() stat broker | ADR-0009 PROPOSED | ⚠️ |
| TR-SC-006 | spell-casting-effects.md | Spell Casting | cast_hit_started signal | ADR-0003 | ✅ |
| TR-SC-007 | spell-casting-effects.md | Spell Casting | spell_hit_element signal | ADR-0003 | ✅ |
| TR-SC-008 | spell-casting-effects.md | Spell Casting | chain_index_changed signal | ADR-0003 | ✅ |
| TR-SE-001 | status-effects.md | Status Effects | StatusEffectsManager Autoload #7 | ADR-0002 | ✅ |
| TR-SE-002 | status-effects.md | Status Effects | Float accumulators for all tick timers | ADR-0004 | ✅ |
| TR-SE-003 | status-effects.md | Status Effects | apply_status() 4-arg API — CONFLICTS with architecture.md | — | ❌ |
| TR-SE-004 | status-effects.md | Status Effects | check_and_apply_shatter() — CONFLICTS with architecture.md | — | ❌ |
| TR-SE-005 | status-effects.md | Status Effects | has_status() — CONFLICTS with architecture.md | — | ❌ |
| TR-SE-006 | status-effects.md | Status Effects | Enemy.apply_speed_modifier(float) required | — | ❌ |
| TR-SE-007 | status-effects.md | Status Effects | Enemy.apply_stun(float) required | — | ❌ |
| TR-SE-008 | status-effects.md | Status Effects | Burn Contagion distance scan on enemy death | — | ❌ |
| TR-SE-009 | status-effects.md | Status Effects | Wave/phase clear via preparation_started | ADR-0004 (partial) | ⚠️ |
| TR-EAI-001 | enemy-ai.md | Enemy AI | CharacterBody2D.move_and_slide() | ADR-0001 (partial) | ⚠️ |
| TR-EAI-002 | enemy-ai.md | Enemy AI | Area2D dedicated contact hitbox | — | ❌ |
| TR-EAI-003 | enemy-ai.md | Enemy AI | ENEMY_MIN_CONTACT_INTERVAL >= 0.3s | ADR-0007 | ✅ |
| TR-EAI-004 | enemy-ai.md | Enemy AI | AnimationPlayer + queue_free() node-lifetime guarantee | ADR-0007 | ✅ |
| TR-EAI-005 | enemy-ai.md | Enemy AI | "enemy" group + not "player" group | ADR-0010 PROPOSED | ⚠️ |
| TR-EAI-006 | enemy-ai.md | Enemy AI | Degenerate direction guard (NaN prevention) | — | ❌ |
| TR-EAI-007 | enemy-ai.md | Enemy AI | apply_speed_modifier() + apply_stun() methods | — | ❌ |
| TR-EAI-008 | enemy-ai.md | Enemy AI | get_first_node_in_group("player") for Fayde | ADR-0010 PROPOSED | ⚠️ |
| TR-EAI-009 | enemy-ai.md | Enemy AI | PROCESS_MODE_PAUSABLE | ADR-0004 | ✅ |
| TR-WES-001 | wave-encounter-system.md | Wave / Encounter | WaveManager sole signal emitter | ADR-0003 | ✅ |
| TR-WES-002 | wave-encounter-system.md | Wave / Encounter | Simultaneous spawn in single frame | — | ❌ |
| TR-WES-003 | wave-encounter-system.md | Wave / Encounter | Kill tracking via enemy_killed | ADR-0007 | ✅ |
| TR-WES-004 | wave-encounter-system.md | Wave / Encounter | Spawn markers as Node2D in arena scene | — | ❌ |
| TR-WES-005 | wave-encounter-system.md | Wave / Encounter | FP: all_waves_cleared + boss_defeated same handler | — | ❌ |
| TR-CH-001 | combat-hud.md | Combat HUD | CombatHUD CanvasLayer layer 10 PROCESS_MODE_ALWAYS | ADR-0005 | ✅ |
| TR-CH-002 | combat-hud.md | Combat HUD | All updates via signals — no polling | ADR-0003 | ✅ |
| TR-CH-003 | combat-hud.md | Combat HUD | get_viewport().get_canvas_transform() coordinate conversion | — | ❌ |
| TR-CH-004 | combat-hud.md | Combat HUD | PranaCatalog colors for chain dots | — | ❌ |
| TR-CH-005 | combat-hud.md | Combat HUD | spell_hit_element + damage_taken per-frame correlation | — | ❌ |
| TR-CH-006 | combat-hud.md | Combat HUD | Label pool cap 12 nodes oldest-first eviction | — | ❌ |
| TR-RM-001 | run-management.md | Run Management | RunManager Autoload #10 | ADR-0002 | ✅ |
| TR-RM-002 | run-management.md | Run Management | get_run_data() returns copy | — | ❌ |
| TR-RM-003 | run-management.md | Run Management | Registered after GameStateManager | ADR-0002 | ✅ |
| TR-RM-004 | run-management.md | Run Management | No _process() loop — signal-only updates | ADR-0003 | ✅ |
| TR-AS-001 | audio-system.md | Audio System | 4-bus architecture with StringName constants | — | ❌ |
| TR-AS-002 | audio-system.md | Audio System | SFX pool 24 nodes priority eviction | — | ❌ |
| TR-AS-003 | audio-system.md | Audio System | Music A/B crossfade Tween.set_parallel(true) | — | ❌ |
| TR-AS-004 | audio-system.md | Audio System | play_event() routing by bus field | — | ❌ |
| TR-AS-005 | audio-system.md | Audio System | Process modes for all 6 audio node types | ADR-0004 (partial) | ⚠️ |
| TR-AS-006 | audio-system.md | Audio System | set_music_volume() clamped to -3.0 dB max | — | ❌ |
| TR-AS-007 | audio-system.md | Audio System | set_amb_volume() clamped to -10.0 dB max | — | ❌ |
| TR-AS-008 | audio-system.md | Audio System | END cues must be non-looping (finished signal) | — | ❌ |
| TR-AS-009 | audio-system.md | Audio System | DYING min hold 1.5s before END_DEFEAT | — | ❌ |
| TR-AS-010 | audio-system.md | Audio System | AutoLoad registered after GameStateManager | ADR-0002 | ✅ |
| TR-AS-011 | audio-system.md | Audio System | Stinger player non-pooled PROCESS_MODE_ALWAYS | — | ❌ |
| TR-AS-012 | audio-system.md | Audio System | Pool timestamp oldest-first (smallest ticks_msec) | — | ❌ |

---

## Known Gaps

All ❌ requirements above, with suggested ADRs from the review report:

### Blocking (Tier 1)
- **TR-SE-003/004/005** → write ADR: "StatusEffectsManager Public API Contract"
- **TR-PG-001** → write ADR: "PranaGrid Dual-Input Focus Model (Godot 4.6)"

### High Priority (Tier 2)
- **TR-AS-001–012** (10 gaps) → write ADR: "AudioSystem Implementation Contract"
- **TR-SC-003** → write ADR: "Spell Targeting and Collision Layer Architecture"
- **TR-SE-006/007 + TR-EAI-007** → write ADR: "Enemy AI Status Effect Interface Contract"

### Medium Priority (Tier 3)
- TR-GSF-005, TR-CR-001, TR-CR-003, TR-CR-005, TR-WES-002, TR-WES-004, TR-WES-005, TR-EAI-002, TR-EAI-006

### Low Priority (Tier 4)
- TR-PC-005, TR-PC-008, TR-PC-009, TR-PD-006, TR-PD-007, TR-CH-003–006, TR-RM-002

---

## History

| Date | Covered | Partial | Gap | Total | Notes |
|------|---------|---------|-----|-------|-------|
| 2026-05-29 | 49 (47%) | 17 (16%) | 39 (37%) | 105 | First population — 10 ADRs reviewed |
