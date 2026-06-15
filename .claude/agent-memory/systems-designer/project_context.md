---
name: project-context
description: The Last Cipher — current project state as of 2026-06-16; FP scope complete; Sprint 6/7 underway
metadata:
  type: project
---

The Last Cipher is a Godot 4.6 GDScript 2D isometric roguelike. FP (First Playable) scope is implemented. Core systems live: HealthAndDamage, StatusEffectsManager, SpellCastingEffects, CombinationResolution, WaveManager, PlayerController, EnemyInstance. GDDs are approved for: health-damage, combination-resolution, status-effects, wave-encounter-system, spell-casting-effects, prana-data, enemy-ai, enemy-data, prana-grid, combat-hud, game-state-scene-flow.

**Why:** Context for any future design work — know what is built vs. pending.
**How to apply:** When designing new systems, check what is already implemented. EA&W (Elemental Affiliation & Weakness) is NOT implemented — placeholder 2× multiplier used in SC&E Step 9. SEM not yet wired to enemies (FP uses field-write stubs). MVP is the next scope tier.

Key known tech debt that affects balance:
- SC&E Step 9 applies 2× multiplier on affinity match (should come from EA&W GDD — value not GDD-specified).
- `apply_status()` not called at FP — status effects are stubs only.
- `is_alive()` on PlayerController returns literal true (not wired to H&D).
- Many gameplay constants hardcoded (MOVE_SPEED, BASE_SPELL_DAMAGE, etc.) — tracked in tech-debt-register.md.
